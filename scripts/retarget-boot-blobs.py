#!/usr/bin/env python3
"""Retarget stock boot HAL blobs to the symbols the recovery ramdisk exports.

Stock (Android 16) blobs reference symbols the OFOX 14.1 build does not export:
  _ZNSt3__122__libcpp_verbose_abortEPKcz  - missing from its libc++
  Join<vector<string>&, const char*>       - its libbase only exports the char form
Rewriting the names in .dynstr (NUL padded, section size unchanged) binds them
to abort() and to the exported Join instantiation instead.

usage: retarget-boot-blobs.py <stock_ramdisk_root> <out_dir>
"""
import hashlib
import os
import struct
import sys

ABORT_OLD = b"_ZNSt3__122__libcpp_verbose_abortEPKcz"
ABORT_NEW = b"abort"
JOIN_OLD = (b"_ZN7android4base4JoinIRNSt3__16vectorINS2_12basic_stringIcNS2_11"
            b"char_traitsIcEENS2_9allocatorIcEEEENS7_IS9_EEEEPKcEES9_OT_T0_")
JOIN_NEW = (b"_ZN7android4base4JoinINSt3__16vectorINS2_12basic_stringIcNS2_11"
            b"char_traitsIcEENS2_9allocatorIcEEEENS7_IS9_EEEEcEES9_RKT_T0_")

PATCHES = {
    "system/lib64/hw/android.hardware.boot@1.0-impl-1.2.so": [(ABORT_OLD, ABORT_NEW),
                                                              (JOIN_OLD, JOIN_NEW)],
    "system/lib64/vendor.sprd.hardware.boot@1.2.so": [(ABORT_OLD, ABORT_NEW)],
}


def dynstr_span(data):
    e_shoff, = struct.unpack_from("<Q", data, 0x28)
    e_shentsize, e_shnum, e_shstrndx = struct.unpack_from("<HHH", data, 0x3a)
    sh = lambda i: struct.unpack_from("<IIQQQQIIQQ", data, e_shoff + i * e_shentsize)
    strtab = data[sh(e_shstrndx)[4]:sh(e_shstrndx)[4] + sh(e_shstrndx)[5]]
    for i in range(e_shnum):
        name_off, off, size = sh(i)[0], sh(i)[4], sh(i)[5]
        name = strtab[name_off:strtab.index(b"\0", name_off)]
        if name == b".dynstr":
            return off, size
    sys.exit("no .dynstr")


def retarget(data, pairs):
    off, size = dynstr_span(data)
    dyn = data[off:off + size]
    for old, new in pairs:
        if len(new) + 1 > len(old) + 1:
            sys.exit("replacement longer than original: %r" % new)
        needle = b"\0" + old + b"\0"
        if needle in dyn:
            dyn = dyn.replace(needle, b"\0" + new + b"\0"
                              + b"\0" * (len(old) - len(new)), 1)
        elif b"\0" + new + b"\0" not in dyn:
            sys.exit("neither original nor retargeted name found: %r" % old)
    return data[:off] + dyn + data[off + size:]


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    root, out_dir = sys.argv[1], sys.argv[2]
    for rel, pairs in PATCHES.items():
        src = os.path.join(root, rel)
        with open(src, "rb") as f:
            out = retarget(f.read(), pairs)
        dst = os.path.join(out_dir, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(out)
        print("%s  %s" % (hashlib.sha256(out).hexdigest(), rel))


if __name__ == "__main__":
    main()
