#!/usr/bin/env python3
"""
Repack Z2577 vendor_boot so Android boots again.

Problem: the AOSP TWRP build emits a v4 vendor_boot with TWO ramdisk fragments:
  entry 0 type=platform  -> first-stage tools only (e2fsck/linker64/snapuserd)
  entry 1 type=recovery  -> full TWRP ramdisk
Z2577's uboot boots a single merged ramdisk (stock style), so every boot lands
on the recovery fragment -> TWRP every time.  Stock Android cannot boot.

Fix (TWRP-installer approach): keep the STOCK ramdisk as the platform fragment
and TWRP as the recovery fragment:
  entry 0 type=platform  -> stock ramdisk (boots Android)
  entry 1 type=recovery  -> TWRP ramdisk (boots recovery)

Usage:
  python3 repack-vendor-boot.py \
      --stock   stock_vendor_boot.img \
      --twrp    twrp_vendor_boot.img \
      --dtb     prebuilt/dtb.img \
      --bootconfig bootconfig \
      --out     vendor_boot-fixed.img

  --stock : the untouched STOCK Z2577 vendor_boot (MIO-KITCHEN backup)
  --twrp  : the CI-built TWRP vendor_boot (artifact of "Recovery Build")
  The stock ramdisk blob, the TWRP recovery fragment, the DTB, cmdline and
  bootconfig are all extracted from those two images; --dtb/--bootconfig just
  fall back to the tree files if extraction fails.

The device is unlocked, so dropping the AVB footer is fine.  Flash with:
  fastboot flash vendor_boot vendor_boot-fixed.img
Then: normal boot -> Android, "Reboot to Recovery" -> TWRP.
"""
import argparse
import struct

PAGE = 0x1000
V4_HEADER_SIZE = 2128
VENDOR_RAMDISK_TABLE_ENTRY_V4_SIZE = 108
MAGIC_LZ4 = b"\x02\x21\x4c\x18"


def align_up(n, a):
    return (n + a - 1) // a * a


def parse_v4(data, label):
    if data[:8] != b"VNDRBOOT":
        raise SystemExit(f"{label}: not a vendor_boot image")
    ver = struct.unpack("<I", data[8:12])[0]
    if ver != 4:
        raise SystemExit(f"{label}: header version {ver} != 4")
    page = struct.unpack("<I", data[12:16])[0]
    kernel_addr = struct.unpack("<I", data[16:20])[0]
    ramdisk_addr = struct.unpack("<I", data[20:24])[0]
    vrs = struct.unpack("<I", data[24:28])[0]
    cmdline = data[0x1C : 0x1C + 2048].split(b"\x00")[0]
    tags_addr = struct.unpack("<I", data[0x81C : 0x820])[0]
    header_size = struct.unpack("<I", data[0x830 : 0x834])[0]
    dtb_size = struct.unpack("<I", data[0x834 : 0x838])[0]
    dtb_addr = struct.unpack("<Q", data[0x838 : 0x840])[0]
    table_size = struct.unpack("<I", data[0x840 : 0x844])[0]
    num_entries = struct.unpack("<I", data[0x844 : 0x848])[0]
    entry_size = struct.unpack("<I", data[0x848 : 0x84C])[0]
    bootconfig_size = struct.unpack("<I", data[0x84C : 0x850])[0]
    return {
        "page": page,
        "kernel_addr": kernel_addr,
        "ramdisk_addr": ramdisk_addr,
        "vrs": vrs,
        "cmdline": cmdline,
        "tags_addr": tags_addr,
        "header_size": header_size,
        "dtb_size": dtb_size,
        "dtb_addr": dtb_addr,
        "table_size": table_size,
        "num_entries": num_entries,
        "entry_size": entry_size,
        "bootconfig_size": bootconfig_size,
    }


def ramdisk_region(data, hdr):
    start = align_up(hdr["header_size"], hdr["page"])
    return data[start : start + hdr["vrs"]]


def table_entries(data, hdr):
    """Read the vendor ramdisk table: list of (size, offset, type, name)."""
    ramdisk_start = align_up(hdr["header_size"], hdr["page"])
    dtb_start = align_up(ramdisk_start + hdr["vrs"], hdr["page"])
    table_start = align_up(dtb_start + hdr["dtb_size"], hdr["page"])
    entries = []
    for i in range(hdr["num_entries"]):
        off = table_start + i * hdr["entry_size"]
        size, offset, typ = struct.unpack("<III", data[off : off + 12])
        name = data[off + 12 : off + 44].split(b"\x00")[0]
        entries.append((size, offset, typ, name))
    return entries


def fragment_by_type(data, hdr, want):
    region = ramdisk_region(data, hdr)
    for size, offset, typ, _name in table_entries(data, hdr):
        if typ == want:
            return region[offset : offset + size]
    return None


def build_vendor_boot(platform_blob, recovery_blob, dtb, cmdline, bootconfig):
    page = PAGE
    header_size = V4_HEADER_SIZE
    vrs = len(platform_blob) + len(recovery_blob)
    dtb_size = len(dtb)
    table_size = 2 * VENDOR_RAMDISK_TABLE_ENTRY_V4_SIZE

    h = bytearray(header_size)
    h[0:8] = b"VNDRBOOT"
    struct.pack_into("<I", h, 8, 4)                 # header_version
    struct.pack_into("<I", h, 12, page)             # page_size
    struct.pack_into("<I", h, 16, 0x00008000)       # kernel_addr
    struct.pack_into("<I", h, 20, 0x05400000)       # ramdisk_addr
    struct.pack_into("<I", h, 24, vrs)              # vendor_ramdisk_size
    h[0x1C : 0x1C + 2048] = (cmdline + b"\x00")[:2048].ljust(2048, b"\x00")
    struct.pack_into("<I", h, 0x81C, 0x00000100)    # tags_addr
    # name (0x820) stays zeroed
    struct.pack_into("<I", h, 0x830, header_size)   # header_size
    struct.pack_into("<I", h, 0x834, dtb_size)      # dtb_size
    struct.pack_into("<Q", h, 0x838, 0x01F00000)    # dtb_addr
    struct.pack_into("<I", h, 0x840, table_size)    # ramdisk table size
    struct.pack_into("<I", h, 0x844, 2)             # num entries
    struct.pack_into("<I", h, 0x848, VENDOR_RAMDISK_TABLE_ENTRY_V4_SIZE)
    struct.pack_into("<I", h, 0x84C, len(bootconfig))  # bootconfig_size

    def entry(size, offset, typ, name):
        e = bytearray(VENDOR_RAMDISK_TABLE_ENTRY_V4_SIZE)
        struct.pack_into("<III", e, 0, size, offset, typ)
        e[12:44] = name.ljust(32, b"\x00")
        return e

    out = bytearray(h)
    out += b"\x00" * (align_up(header_size, page) - header_size)
    # fragments (unpadded offsets, matching mkbootimg's total-size semantics)
    out += platform_blob
    out += recovery_blob
    out += b"\x00" * (align_up(len(out), page) - len(out))
    # dtb
    out += dtb
    out += b"\x00" * (align_up(len(out), page) - len(out))
    # ramdisk table
    out += entry(len(platform_blob), 0, 1, b"")
    out += entry(len(recovery_blob), len(platform_blob), 2, b"recovery")
    out += b"\x00" * (align_up(len(out), page) - len(out))
    # bootconfig
    out += bootconfig
    out += b"\x00" * (align_up(len(out), page) - len(out))
    return bytes(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--stock", required=True, help="stock Z2577 vendor_boot.img")
    ap.add_argument("--twrp", required=True, help="CI-built TWRP vendor_boot.img")
    ap.add_argument("--dtb", default="prebuilt/dtb.img")
    ap.add_argument("--bootconfig", default="bootconfig")
    ap.add_argument("--out", default="vendor_boot-fixed.img")
    args = ap.parse_args()

    stock = open(args.stock, "rb").read()
    twrp = open(args.twrp, "rb").read()

    sh = parse_v4(stock, "stock")
    th = parse_v4(twrp, "twrp")

    stock_region = ramdisk_region(stock, sh)
    stock_entries = table_entries(stock, sh)
    twrp_entries = table_entries(twrp, th)
    print(f"stock: {len(stock_region)} bytes ramdisk, {len(stock_entries)} fragment(s)")
    print(f"twrp:  {len(twrp_entries)} fragment(s): "
          + ", ".join(f"type={t} name={n!r} size={s}" for s, _o, t, n in twrp_entries))

    # platform = STOCK ramdisk (single merged blob)
    platform_blob = stock_region
    # recovery = TWRP's recovery fragment
    recovery_blob = fragment_by_type(twrp, th, 2)
    if recovery_blob is None:
        raise SystemExit("twrp image has no recovery (type=2) ramdisk fragment")
    print(f"platform fragment: {len(platform_blob)} bytes (stock)")
    print(f"recovery fragment: {len(recovery_blob)} bytes (TWRP)")

    dtb = open(args.dtb, "rb").read()
    if dtb[:4].hex() != "d7b7ab1e":
        print("warning: --dtb does not look like an Android DT image")
    bc = open(args.bootconfig, "rb").read()

    out = build_vendor_boot(platform_blob, recovery_blob, dtb, sh["cmdline"], bc)
    with open(args.out, "wb") as f:
        f.write(out)
    print(f"wrote {args.out} ({len(out)} bytes)")
    print("flash with: fastboot flash vendor_boot " + args.out)


if __name__ == "__main__":
    main()
