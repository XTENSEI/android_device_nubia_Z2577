#!/sbin/sh
# start_rndis.sh - add RNDIS networking to the USB gadget.
#
# MTP cannot work on this kernel (no ffs_mtp anywhere), so this is the file
# transfer path: the phone gets usb0 on 192.168.42.129/24 and the PC takes a
# matching address, then adb over TCP works over the same cable. ffs.adb stays
# linked, so the running USB adb session survives.
#
# Start it by hand from a USB adb session:
#     adb shell /system/bin/start_rndis.sh
# or:  adb shell setprop sys.usb.rndis 1
#
# PC side (no DHCP server exists in the recovery ramdisk):
#     ip addr add 192.168.42.100/24 dev enxXXXX   # linux
#     adb connect 192.168.42.129:5555

LOG=/tmp/start_rndis.log
exec > "$LOG" 2>&1

G=/config/usb_gadget/g1
PHONE_IP=192.168.42.129
PREFIX=24
UDC=$(getprop sys.usb.controller)

echo "start, UDC=${UDC}"

mount -t configfs none /config 2>/dev/null
[ -d "$G/functions" ] || { echo "no configfs gadget, aborting"; exit 0; }

# the rndis function is a vendor module, it is not in TW_LOAD_VENDOR_MODULES
if ! ls "$G/functions" | grep -q '^rndis'; then
    echo "loading sprd_usb_f_rndis.ko"
    insmod /lib/modules/sprd_usb_f_rndis.ko 2>&1
    sleep 1
fi
echo "functions: $(ls "$G/functions" | tr '\n' ' ')"

# the stock rc uses rndis.gs4 but the configfs group is whatever the module
# registered; the mkdir only succeeds if that group exists
FN=""
for n in rndis rndis.gs4; do
    if [ -d "$G/functions/$n" ]; then
        FN=$n
        break
    fi
    if mkdir "$G/functions/$n" 2>/dev/null; then
        FN=$n
        break
    fi
done
[ -z "$FN" ] && { echo "no rndis function group, aborting"; exit 0; }
echo "rndis function is $FN"

# both ends of the link need a MAC, the host one has to match
[ -f "$G/functions/$FN/dev_addr" ] && echo "02:00:00:00:42:01" > "$G/functions/$FN/dev_addr"
[ -f "$G/functions/$FN/host_addr" ] && echo "02:00:00:00:42:02" > "$G/functions/$FN/host_addr"

mkdir -p "$G/configs/b.1"

USED=$(ls "$G/configs/b.1" 2>/dev/null | grep -c '^f[0-9]*$')
if [ "$USED" = "0" ]; then
    # nothing was linked yet, put adb back so the session we run from survives
    ln -s "$G/functions/ffs.adb" "$G/configs/b.1/f1" 2>/dev/null
    echo "relinked ffs.adb as f1"
fi

SLOT=""
i=1
while [ $i -le 11 ]; do
    [ -e "$G/configs/b.1/f$i" ] || { SLOT=$i; break; }
    i=$((i + 1))
done
[ -z "$SLOT" ] && { echo "no free config slot, aborting"; exit 0; }

ln -sf "$G/functions/$FN" "$G/configs/b.1/f$SLOT"
echo "rndis linked as f$SLOT, config now: $(ls "$G/configs/b.1" | tr '\n' ' ')"

# a bound gadget cannot change its function list, unbind and bind again
cat "$G/UDC" > /tmp/rndis_udc_before
echo "UDC was $(cat /tmp/rndis_udc_before)"
printf '' > "$G/UDC" 2>/dev/null
echo "${UDC}" > "$G/UDC" 2>&1 || echo "writing UDC failed"
echo "UDC rebound"

i=0
while [ $i -lt 20 ]; do
    [ -e /sys/class/net/usb0 ] && break
    sleep 1
    i=$((i + 1))
done

if [ -e /sys/class/net/usb0 ]; then
    if ifconfig usb0 "$PHONE_IP" netmask 255.255.255.0 up 2>&1; then
        echo "usb0 configured with ifconfig"
    else
        ip addr add "${PHONE_IP}/${PREFIX}" dev usb0 2>&1
        ip link set usb0 up 2>&1
    fi
    echo "usb0 operstate $(cat /sys/class/net/usb0/operstate)"
    echo "PC: ip addr add 192.168.42.100/${PREFIX} dev <enx|usb0>"
    echo "then: adb connect ${PHONE_IP}:5555"
else
    echo "usb0 never appeared"
fi

exit 0
