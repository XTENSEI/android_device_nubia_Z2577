#!/sbin/sh
# start_tsupplicant.sh - mount odm and start the TEE TA supplier.
# dm-0 may not exist yet when this runs, retry until gatekeeper.elf appears.

LOG=/tmp/start_tsupplicant.log
exec > "$LOG" 2>&1

TA=/odm/firmware/gatekeeper.elf
i=0

while [ ! -e "$TA" ] && [ $i -lt 60 ]; do
    mount -t erofs -o ro /dev/block/by-name/odm /odm 2>/dev/null
    [ -e "$TA" ] && break
    sleep 1
    i=$((i + 1))
done

if [ ! -e "$TA" ]; then
    echo "$TA missing after ${i}s, aborting"
    exit 1
fi

echo "odm ready after ${i}s"
setprop vendor.sprd.tsupplicant.enabled 1
sleep 2
setprop twrp.tsupplicant.ready 1
