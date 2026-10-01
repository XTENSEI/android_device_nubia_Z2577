#!/sbin/sh
# start_tsupplicant.sh - start the TEE TA supplier
#
# The TEE pulls gatekeeper.elf through vendor.tsupplicant; stock runs it as a
# class core service, which recovery never starts. TWRP never mounts odm and
# nothing else mounts it here, so do it up front instead of waiting.

LOG=/tmp/start_tsupplicant.log
exec > "$LOG" 2>&1

TA=/odm/firmware/gatekeeper.elf

if [ ! -e "$TA" ]; then
    mount -t erofs -o ro /dev/block/by-name/odm /odm 2>/dev/null ||
        mount -o ro /dev/block/by-name/odm /odm 2>/dev/null
    if [ -e "$TA" ]; then
        echo "odm mounted by script"
    else
        echo "$TA still missing, aborting"
        exit 1
    fi
fi

setprop vendor.sprd.tsupplicant.enabled 1
sleep 2
setprop twrp.tsupplicant.ready 1
echo "supplier started"
