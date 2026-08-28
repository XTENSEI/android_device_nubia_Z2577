#!/sbin/sh
# prepdecrypt.sh — signal crypto readiness after trusty modules load
#
# The keymint/gatekeeper HALs depend on the trusty IPC kernel modules
# (trusty.ko, trusty-ipc.ko) which TWRP loads via TW_LOAD_VENDOR_BOOT_MODULES.
# We wait for /dev/trusty-ipc* nodes to appear, then signal crypto.ready.

TIMEOUT=30
WAITED=0

# Wait for trusty IPC device nodes (created when trusty-ipc.ko loads)
while [ $WAITED -lt $TIMEOUT ]; do
    if ls /dev/trusty-ipc* 2>/dev/null | grep -q .; then
        break
    fi
    sleep 1
    WAITED=$((WAITED + 1))
done

if [ $WAITED -ge $TIMEOUT ]; then
    # Even without trusty devices, signal ready so vold can attempt
    # a fast fail rather than hanging forever.
    echo "prepdecrypt: trusty devices not found after ${TIMEOUT}s, signaling anyway" > /dev/kmsg
fi

# Signal init to start keymint + gatekeeper services
setprop crypto.ready 1
