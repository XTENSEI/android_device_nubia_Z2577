#!/sbin/sh
LOG=/tmp/prepdecrypt.log
exec > "$LOG" 2>&1

echo "=== prepdecrypt: services started by init, checking trusty ==="
TRUSTY_COUNT=$(ls /dev/trusty-ipc* 2>/dev/null | wc -l)
echo "trusty-ipc nodes: $TRUSTY_COUNT"

for i in $(seq 1 15); do
    TRUSTY_COUNT=$(ls /dev/trusty-ipc* 2>/dev/null | wc -l)
    if [ "$TRUSTY_COUNT" -gt 0 ]; then
        echo "trusty ready after ${i}s"
        break
    fi
    sleep 1
done

echo "crypto.ready property: $(getprop crypto.ready)"
echo "=== prepdecrypt: done ==="
