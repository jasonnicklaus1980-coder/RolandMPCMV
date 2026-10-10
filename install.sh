#!/bin/sh
# MV-8000 0.3.1 installer (experimental). Layout and safety steps follow the JV-880 MPC plugin installer.
# Run on the device as root:  sh install.sh [-y]
# Stops MPC, copies the plugin + skin, backs up MPC.settings, adds the plugin to MPC's plugin list, starts MPC again.
# Safe to run again (upgrades in place; Samples you added are kept).
set -e
cd "$(dirname "$0")"
R="${MV_TEST_ROOT:-}"   # test hook only (tests/test_install.sh); empty on a real device
NAME='MV-8000'; SO='roland_mv.so'; SO_PATH="/sdcard/vst/$SO"; SKIN='mvlib - VST - MV-8000'
YES=0; [ "$1" = "-y" ] && YES=1
die() { echo "error: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root"
case "$(uname -m)" in armv7*) ;; *) die "this build is for 32-bit ARM MPC OS devices (Gen1); this one is $(uname -m)" ;; esac
SETTINGS=$(ls "$R"/media/az01-internal/Settings/*/MPC.settings 2>/dev/null | head -n 1)
[ -n "$SETTINGS" ] || die "MPC.settings not found (not an MPC OS device?)"
command -v systemctl >/dev/null || die "systemctl not found"
command -v awk >/dev/null || die "awk not found"
[ -f "payload/vst/$SO" ] || die "payload/vst/$SO missing (build the ARM plugin first)"
[ -d "$(dirname "$R$SO_PATH")" ] || [ -d "$R/sdcard" ] || die "/sdcard not found"
sha256sum -c SHA256SUMS >/dev/null 2>&1 || die "files damaged (SHA256SUMS mismatch): copy the folder again"
grep -q '/sdcard/Synths' "$SETTINGS" || echo "warning: /sdcard/Synths isn't in MPC's SynthContentLocations; the skin may not show"

echo "Installing $NAME 0.3.1 (experimental drum and chromatic sample instrument, not a full MV-8000 emulator):"
echo "  $SO_PATH, /sdcard/Synths/$SKIN, and an entry in $SETTINGS"
if [ $YES = 0 ]; then
    printf "MPC will be stopped and restarted. Save your project first. Continue? [y/N] "
    read -r ok; case "$ok" in y|Y|yes) ;; *) echo "cancelled"; exit 1 ;; esac
fi

systemctl stop acvs
trap 'systemctl start acvs' EXIT
i=0; while pidof MPC >/dev/null && [ $i -lt 30 ]; do sleep 1; i=$((i + 1)); done
pidof MPC >/dev/null && die "MPC did not stop"

DEST="$R/sdcard/Synths/$SKIN"
mkdir -p "$R/sdcard/vst" "$DEST/Samples"
cp "payload/vst/$SO" "$R$SO_PATH.new" && mv "$R$SO_PATH.new" "$R$SO_PATH"
rm -rf "$DEST/Plugin Skins"
cp -a "payload/Synths/$SKIN/Plugin Skins" "$DEST/Plugin Skins"
cp -f "payload/Synths/$SKIN/version.xml" "$DEST/version.xml"
# shipped samples: only add files that aren't there yet, so your own pads are never overwritten
for f in "payload/Synths/$SKIN/Samples"/*; do
    [ -e "$f" ] || continue
    b=$(basename "$f"); [ -e "$DEST/Samples/$b" ] || cp -a "$f" "$DEST/Samples/$b"
done

BAK="$SETTINGS.bak-$(echo "$SO" | sed 's/\.so$//')-$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS" "$BAK"
awk -v mode=add -v file="$SO_PATH" -v entryfile=plugin.xml -f plugin_list.awk "$SETTINGS" > "$SETTINGS.new"
n=$(grep -c "file=\"$SO_PATH\"" "$SETTINGS.new" || true)
[ "$n" = 1 ] || { rm -f "$SETTINGS.new"; die "settings edit failed (entry count $n); MPC.settings unchanged"; }
if command -v python3 >/dev/null; then
    python3 -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$SETTINGS.new" 2>/dev/null ||
        { rm -f "$SETTINGS.new"; die "edited settings aren't valid XML; MPC.settings unchanged"; }
fi
mv "$SETTINGS.new" "$SETTINGS"
sync

echo "Done. Settings backup: $BAK"
echo "Starting MPC. Add '$NAME' to a track from the plugin browser (Instrument plugins)."
