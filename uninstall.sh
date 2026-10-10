#!/bin/sh
# MV-8000 uninstaller. Run on the device as root:  sh uninstall.sh [-y]
# Stops MPC, removes the plugin, its skin and its MPC.settings entry (after a backup), starts MPC again.
# Files in Samples/ are kept.
set -e
cd "$(dirname "$0")"
R="${MV_TEST_ROOT:-}"   # test hook only
NAME='MV-8000'; SO='roland_mv.so'; SO_PATH="/sdcard/vst/$SO"; SKIN='mvlib - VST - MV-8000'
YES=0; [ "$1" = "-y" ] && YES=1
die() { echo "error: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root"
SETTINGS=$(ls "$R"/media/az01-internal/Settings/*/MPC.settings 2>/dev/null | head -n 1)
[ -n "$SETTINGS" ] || die "MPC.settings not found"
if [ $YES = 0 ]; then
    printf "Remove %s? MPC will be stopped and restarted. Save your project first. [y/N] " "$NAME"
    read -r ok; case "$ok" in y|Y|yes) ;; *) echo "cancelled"; exit 1 ;; esac
fi

systemctl stop acvs
trap 'systemctl start acvs' EXIT
i=0; while pidof MPC >/dev/null && [ $i -lt 30 ]; do sleep 1; i=$((i + 1)); done
pidof MPC >/dev/null && die "MPC did not stop"

BAK="$SETTINGS.bak-$(echo "$SO" | sed 's/\.so$//')-$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS" "$BAK"
awk -v mode=remove -v file="$SO_PATH" -f plugin_list.awk "$SETTINGS" > "$SETTINGS.new"
n=$(grep -c "file=\"$SO_PATH\"" "$SETTINGS.new" || true)
[ "$n" = 0 ] || { rm -f "$SETTINGS.new"; die "settings edit failed; MPC.settings unchanged"; }
if command -v python3 >/dev/null; then
    python3 -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$SETTINGS.new" 2>/dev/null ||
        { rm -f "$SETTINGS.new"; die "edited settings aren't valid XML; MPC.settings unchanged"; }
fi
mv "$SETTINGS.new" "$SETTINGS"

DEST="$R/sdcard/Synths/$SKIN"
rm -f "$R$SO_PATH"
rm -rf "$DEST/Plugin Skins" "$DEST/version.xml"
rmdir "$DEST/Samples" 2>/dev/null || true
rmdir "$DEST" 2>/dev/null || true
sync
echo "Removed $NAME. Settings backup: $BAK"
[ -d "$DEST" ] && echo "Kept $DEST/Samples (remove it by hand if you don't need it)."
exit 0
