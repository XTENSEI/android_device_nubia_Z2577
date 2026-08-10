#!/usr/bin/env python3
"""
Repack Z2577 vendor_boot: stock ramdisk as platform fragment + TWRP as recovery fragment.

Why: the TWRP build system produces a vendor_boot whose *platform* fragment (the one
uboot boots on a normal boot, BCB clean) is just snapuserd/e2fsck support files with
NO /init -- it cannot boot Android. A normal reboot with the TWRP vendor_boot therefore
can never reach Android, regardless of BCB state.

This script rebuilds vendor_boot as:
  fragment 0 (platform, normal boot): STOCK vendor ramdisk (proven to boot Android)
  fragment 1 (recovery,  boot-recovery in BCB): TWRP recovery ramdisk (proven to boot TWRP)
keeping the stock dtb + bootconfig + header.

Layout verified against real images (SPRD v4 vendor_boot, page 4096):
  [0:2128]       header (VNDRBOOT v4; vendor_ramdisk_size at 24, v4 fields at 2112)
  [2128:4096]    zero padding (vendor_ramdisk_table is all zeros on SPRD -- ignored)
  [4096:...]     vendor ramdisk: lz4-legacy fragment(s) back to back, each
                 [0x184C2102 magic][u32 compressed_size][lz4 block(s)]
  [...:...]      dtb (magic 0xd00dfeed), page-aligned
  [...:...]      bootconfig (androidboot.hardware=ums9230_6h10), page-aligned
  zero-pad to full partition size (100 MB)

Usage:
  repack-vendor-boot.py --stock stock_vendor_boot.img --twrp twrp_vendor_boot.img --out out.img
"""

import argparse
import struct
import sys

MAGIC_LZ4 = b'\x02\x21\x4c\x18'   # LZ4 legacy frame magic (SPRD ramdisk)
DTB_MAGIC = b'\xd0\x0d\xfe\xed'
PAGE = 4096
IMG_SIZE = 104857600              # vendor_boot partition size (100 MB)

def read_v4_header(data):
    # AOSP vendor_boot v3/v4 header field offsets (cmdline[2048] in the middle)
    magic = data[0:8]
    ver = struct.unpack_from('<I', data, 8)[0]
    page = struct.unpack_from('<I', data, 12)[0]
    vram_size = struct.unpack_from('<I', data, 24)[0]
    hdr_size = struct.unpack_from('<I', data, 2096)[0]
    dtb_size = struct.unpack_from('<I', data, 2100)[0]
    dtb_addr = struct.unpack_from('<Q', data, 2104)[0]
    tbl_size, tbl_num, tbl_esize, bootcfg_size = struct.unpack('<IIII', data[2112:2128])
    return dict(magic=magic, ver=ver, page=page, vram_size=vram_size, hdr_size=hdr_size,
                dtb_size=dtb_size, dtb_addr=dtb_addr, tbl_size=tbl_size,
                tbl_num=tbl_num, tbl_esize=tbl_esize, bootcfg_size=bootcfg_size)


def find_fragment(data, off, end):
    """Return (frag_bytes, next_off) for the lz4-legacy fragment starting at off.

    SPRD ramdisks are LZ4-legacy: [magic][u32 csize][block data] repeated.
    A fragment ends at: a zero size word (terminator), the next fragment's magic,
    or the region end. Garbage after the last block also terminates it.
    """
    assert data[off:off + 4] == MAGIC_LZ4, f'no lz4 magic at {off}'
    start = off
    p = off + 4
    while p + 4 <= end:
        csize = struct.unpack_from('<I', data, p)[0]
        if csize == 0:                      # legacy end marker
            return data[start:p + 4], p + 4
        if p + 4 + csize > end:             # block overruns region -> stop here
            return data[start:p], p
        p += 4 + csize
        if p + 4 <= end and data[p:p + 4] == MAGIC_LZ4:
            return data[start:p], p         # next fragment begins right here
    return data[start:end], end


def align(x, a=PAGE):
    return (x + a - 1) // a * a


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--stock', required=True)
    ap.add_argument('--twrp', required=True)
    ap.add_argument('--out', required=True)
    args = ap.parse_args()

    stock = open(args.stock, 'rb').read()
    twrp = open(args.twrp, 'rb').read()

    sh = read_v4_header(stock)
    th = read_v4_header(twrp)
    assert sh['magic'] == b'VNDRBOOT' and th['magic'] == b'VNDRBOOT', 'bad magic'
    assert sh['ver'] == 4 and th['ver'] == 4, 'expected v4 vendor_boot'

    # --- extract stock platform fragment: the entire stock vendor ramdisk region ---
    s_off = align(sh['hdr_size'])
    s_frag, s_next = find_fragment(stock, s_off, s_off + sh['vram_size'])
    assert s_next - s_off == sh['vram_size'], \
        f'stock fragment {s_next - s_off} != vram {sh["vram_size"]}'
    print(f'stock platform fragment: {len(s_frag)} bytes (whole stock vendor ramdisk)')

    # --- extract TWRP recovery fragment: the SECOND fragment in the TWRP build ---
    t_off = align(th['hdr_size'])
    t_frag0, t_next = find_fragment(twrp, t_off, t_off + th['vram_size'])
    print(f'twrp fragment 0 (discarded): {len(t_frag0)} bytes')
    t_frag1, t_next2 = find_fragment(twrp, t_next, t_off + th['vram_size'])
    assert t_next2 - t_off <= th['vram_size'], 'twrp fragments overrun vram'
    print(f'twrp recovery fragment: {len(t_frag1)} bytes')

    # --- dtb + bootconfig from STOCK ---
    dtb_off = stock.find(DTB_MAGIC, s_off + sh['vram_size'])
    assert dtb_off > 0, 'dtb not found in stock'
    dtb = stock[dtb_off:dtb_off + sh['dtb_size']]
    bootcfg = stock[len(stock) - sh['bootcfg_size']:] if sh['bootcfg_size'] else b''
    if bootcfg.startswith(b'\x00') or b'androidboot.hardware' not in bootcfg:
        # bootconfig sits page-aligned after the dtb, not at EOF
        bc = stock.find(b'androidboot.hardware=ums9230_6h10')
        assert bc > 0, 'bootconfig not found in stock'
        bootcfg = stock[bc:bc + sh['bootcfg_size']]
    print(f'dtb: {len(dtb)} bytes, bootconfig: {len(bootcfg)} bytes ({bootcfg!r})')

    # --- assemble ---
    new_vram = s_frag + t_frag1
    hdr = bytearray(stock[:sh['hdr_size']])
    struct.pack_into('<I', hdr, 24, len(new_vram))            # vendor_ramdisk_size
    struct.pack_into('<IIII', hdr, 2112, 216, 2, 108, sh['bootcfg_size'])  # v4 fields
    # dtb/bootconfig offsets in header are load addresses; keep stock values

    out = bytearray(IMG_SIZE)
    out[:len(hdr)] = hdr
    p = align(len(hdr))
    out[p:p + len(new_vram)] = new_vram
    p = align(p + len(new_vram))
    out[p:p + len(dtb)] = dtb
    p = align(p + len(dtb))
    out[p:p + len(bootcfg)] = bootcfg
    # sanity: bootconfig is the last non-zero region
    assert len(bootcfg) == 0 or p + len(bootcfg) <= IMG_SIZE

    with open(args.out, 'wb') as f:
        f.write(out)
    print(f'wrote {args.out}: {len(out)} bytes, vram {len(new_vram)} bytes, '
          f'dtb@{p - align(len(dtb)) - len(dtb)} bootcfg@{p}')
    print('OK: normal boot -> stock Android, boot-recovery -> TWRP')


if __name__ == '__main__':
    main()
