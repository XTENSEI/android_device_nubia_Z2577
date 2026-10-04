#!/sbin/sh
# start_mtp.sh - give the MTP server a gadget function if this kernel has one.
#
# MtpServer takes the FFS handle when /dev/usb-ffs/mtp/ep0 is writable and
# otherwise falls back to MtpDevHandle on /dev/mtp_usb. Both nodes only exist
# once a gadget function module registers an MTP function. This kernel has no
# ffs_mtp built in (no f_mtp.c, no CONFIG_USB_F_MTP) and the vendor partition
# ships no module for it. If vendor_dlkm happens to carry one, load it here;
# if not, log it and leave the MTP button to report the failure.

LOG=/tmp/start_mtp.log
exec > "$LOG" 2>&1

echo "start"

# TWRP mounts /vendor_dlkm during its fstab pass, after this service starts.
i=0
while [ $i -lt 60 ]; do
    [ -d /config/usb_gadget/g1/functions ] && break
    sleep 1
    i=$((i + 1))
done
echo "configfs after ${i}s"

i=0
while [ $i -lt 60 ]; do
    [ -d /vendor_dlkm/lib/modules ] && break
    sleep 1
    i=$((i + 1))
done
echo "vendor_dlkm after ${i}s"

if [ -e /dev/mtp_usb ] || [ -e /dev/usb-ffs/mtp/ep0 ]; then
    echo "mtp node already present, nothing to do"
    exit 0
fi

for dir in /vendor_dlkm/lib/modules /system_dlkm/lib/modules \
           /vendor/lib/modules /odm_dlkm/lib/modules; do
    for ko in "$dir"/*mtp*.ko "$dir"/*MTP*.ko "$dir"/f_fs.ko; do
        [ -f "$ko" ] || continue
        echo "insmod $ko"
        insmod "$ko" 2>>/tmp/start_mtp.err
    done
done

sleep 1

if [ -e /dev/mtp_usb ] || [ -e /dev/usb-ffs/mtp/ep0 ]; then
    echo "mtp function registered, node present"
else
    echo "no mtp gadget function in this kernel, mtp stays unavailable"
    echo "adb pull still works"
fi

# the stock ramdisk rc creates these, keep them so the naming matches if the
# function did register
mkdir /config/usb_gadget/g1/functions/mtp.gs0 2>/dev/null
mkdir /config/usb_gadget/g1/functions/ptp.gs1 2>/dev/null

exit 0