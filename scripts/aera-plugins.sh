#!/bin/bash
#
# Fetch every AERA plugin package so they can be side-loaded from storage.
#   scripts/aera-plugins.sh [dest]
#
# Copy the .aerap files to the external SD or internal storage and install them
# from the plugin manager. Useful because recovery on this device has no WLAN,
# so the registry cannot be reached from inside AERA.
#
set -euo pipefail

OUT="${1:-./aera-plugins}"

REPOS="
mirror
settings-backup
browser
media
app-backup-vault
recorder
gallery
telegram
retroarch
streams
doom
sysinfo
storage-benchmark
font-inter
font-manrope
font-space-grotesk
font-atkinson-hyperlegible-next
font-ibm-plex-sans
font-jetbrains-mono
"

mkdir -p "$OUT"
ok=0
skip=0
for r in $REPOS; do
    if gh release download -R "AERA-Plugins/$r" --pattern '*.aerap' --clobber -D "$OUT" 2>/dev/null; then
        echo "ok   $r"
        ok=$((ok + 1))
    else
        echo "skip $r"
        skip=$((skip + 1))
    fi
done

echo
echo "$ok packages in $OUT, $skip skipped"
du -sh "$OUT"
