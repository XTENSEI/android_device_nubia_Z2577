#!/sbin/sh
# start_storage_proxies.sh - start the TEE ss proxies after /data and prodnv
# are mounted. Started earlier they open shadow files and verify fails.

LOG=/tmp/start_storage_proxies.log
exec > "$LOG" 2>&1

# init mount rejects noatime on ext4, mount prodnv here instead
i=0
while [ $i -lt 30 ] && ! grep -q ' /mnt/vendor ' /proc/mounts; do
    mkdir -p /mnt/vendor
    mount -t ext4 /dev/block/by-name/prodnv /mnt/vendor 2>/dev/null
    sleep 1
    i=$((i + 1))
done

if ! grep -q ' /mnt/vendor ' /proc/mounts; then
    echo "prodnv mount failed after ${i}s"
fi

# TWRP mounts /data during startup
i=0
while [ $i -lt 120 ]; do
    grep -q ' /data ' /proc/mounts && break
    sleep 1
    i=$((i + 1))
done

if ! grep -q ' /data ' /proc/mounts; then
    echo "/data not mounted after ${i}s, aborting"
    exit 1
fi

mkdir -p /data/vendor/sprd_ss /mnt/vendor/productinfo/sprd_ss
chown system:system /data/vendor/sprd_ss /mnt/vendor/productinfo/sprd_ss
chmod 0770 /data/vendor/sprd_ss /mnt/vendor/productinfo/sprd_ss

# stock order: rpmb first, a ns-first connect wedges the ss server
setprop ctl.start vendor.rpmbproxy
sleep 2
setprop ctl.start vendor.nsproxy
sleep 2
setprop ctl.start vendor.prodproxy

echo "storage proxies started"
setprop twrp.storage.ready 1
