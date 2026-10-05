#!/sbin/sh
# start_rndis.sh - add RNDIS networking to the USB gadget.
#
# MTP cannot work on this kernel (no ffs_mtp anywhere), so this is the file
# transfer path: the phone gets usb0 on 192.168.42.129/24 and the PC takes a
# matching address, then files move over the link.
#
# Start it with:
#     adb shell setprop sys.usb.rndis 1
# or run this script directly; when launched from the adb shell it re-execs
# itself with nohup first, because the UDC unbind below drops USB and adbd
# can kill the shell it spawned.
#
# configfs refuses to link a function while the gadget is bound (EINVAL,
# kernel configfs.c config_usb_cfg_link), so the flow has to be:
# unbind UDC, link rndis.gs4, bind UDC again. ffs.adb stays linked, so the
# USB adb session comes back after the rebind.
#
# PC side (no DHCP server exists in the recovery ramdisk):
#     ip addr add 192.168.42.100/24 dev enxXXXX   # linux
#     adb connect 192.168.42.129:5555

# Detach when we are not an init child: PPID 1 means the rc service started
# us, anything else means a shell that the USB drop may take down with it.
if [ "$PPID" != "1" ] && [ "${RNDIS_DETACHED:-0}" != "1" ]; then
    RNDIS_DETACHED=1
    export RNDIS_DETACHED
    nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

LOG=/tmp/start_rndis.log
exec > "$LOG" 2>&1

G=/config/usb_gadget/g1
PHONE_IP=192.168.42.129
PREFIX=24
UDC=$(getprop sys.usb.controller)

echo "start, UDC=${UDC}"

mount -t configfs none /config 2>/dev/null
[ -d "$G/functions" ] || { echo "no configfs gadget, aborting"; exit 0; }
[ -z "$UDC" ] && UDC=$(cat "$G/UDC")

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

LINKED=""
for f in "$G/configs/b.1"/f*; do
    [ -L "$f" ] || continue
    case "$(readlink "$f")" in
        */"$FN") LINKED="${f##*/}"; break ;;
    esac
done

if [ -n "$LINKED" ]; then
    echo "rndis already linked as $LINKED, skipping the rebind"
else
    # nothing was linked yet? put adb back so the session comes back
    if ! ls "$G/configs/b.1" | grep -q '^f[0-9]*$'; then
        ln -s "$G/functions/ffs.adb" "$G/configs/b.1/f1" 2>/dev/null
        echo "relinked ffs.adb as f1"
    fi

    SLOT=""
    i=1
    while [ $i -le 11 ]; do
        [ -e "$G/configs/b.1/f$i" ] || { SLOT=$i; break; }
        i=$((i + 1))
    done
    if [ -z "$SLOT" ]; then
        echo "no free config slot, nothing to do"
    else
        # an empty write is a no-op, configfs only unbinds on a real value
        echo "unbinding UDC"
        echo none > "$G/UDC"
        echo "UDC now: $(cat "$G/UDC")"

        ln -s "$G/functions/$FN" "$G/configs/b.1/f$SLOT"
        echo "rndis linked as f$SLOT, config now: $(ls "$G/configs/b.1" | tr '\n' ' ')"

        echo "$UDC" > "$G/UDC" || echo "writing UDC failed"
        if [ -z "$(cat "$G/UDC")" ]; then
            # rebind refused, put the adb-only config back so USB returns
            echo "rebind failed, restoring the adb-only config"
            rm -f "$G/configs/b.1/f$SLOT"
            echo "$UDC" > "$G/UDC"
        fi
        echo "UDC rebound: $(cat "$G/UDC")"
    fi
fi

# adbd loses its functionfs endpoints across the rebind; restart it so USB
# adb comes back even when the old session did not survive (ignored when
# this recovery has no adbd service). The TCP port makes the same adbd
# reachable over the link, so the PC can adb connect 192.168.42.129:5555.
setprop service.adb.tcp.port 5555
setprop ctl.restart adbd 2>&1

i=0
while [ $i -lt 20 ]; do
    [ -e /sys/class/net/usb0 ] && break
    sleep 1
    i=$((i + 1))
done

if [ -e /sys/class/net/usb0 ]; then
    # the ramdisk has toybox ifconfig only, there is no ip(8) in recovery
    ifconfig usb0 "$PHONE_IP" netmask 255.255.255.0 up 2>&1
    echo "ifconfig rc=$?"
    echo "usb0 operstate $(cat /sys/class/net/usb0/operstate)"
    ifconfig usb0 2>&1
    echo "PC: ip addr add 192.168.42.100/${PREFIX} dev <enx|usb0>"
    echo "then: adb connect ${PHONE_IP}:5555"
else
    echo "usb0 never appeared"
fi

exit 0
