#!/sbin/sh
# start_tsupplicant.sh - mount /odm for good, then start the TEE TA supplier.
#
# TWRP mounts /odm to read its props and additional fstab, then unmounts it
# (partitionmanager.cpp Process_Fstab). A TA load in that window fails and the
# gatekeeper service never recovers, so wait for /data (TWRP mounts it after
# the fstab pass) and the ss proxies before mounting /odm again.

LOG=/tmp/start_tsupplicant.log
exec > "$LOG" 2>&1

TA=/odm/firmware/gatekeeper.elf

i=0
while [ $i -lt 120 ]; do
    grep -q ' /data ' /proc/mounts && break
    sleep 1
    i=$((i + 1))
done
echo "/data mounted after ${i}s"

i=0
while [ $i -lt 60 ] && [ "$(getprop twrp.storage.ready)" != "1" ]; do
    sleep 1
    i=$((i + 1))
done
echo "storage ready after ${i}s"

i=0
while [ $i -lt 30 ]; do
    mount -t erofs -o ro /dev/block/by-name/odm /odm 2>/dev/null
    sleep 2
    grep -q ' /odm ' /proc/mounts && [ -r "$TA" ] && break
    i=$((i + 1))
done

if [ ! -r "$TA" ]; then
    echo "$TA not readable after ${i} tries, aborting"
    exit 1
fi
echo "/odm mounted, TA readable"

setprop vendor.sprd.tsupplicant.enabled 1
sleep 2
setprop twrp.tsupplicant.ready 1
