# MV-8000 0.3.1 (experimental)

A sample instrument for the MPC's built-in plugin host with a native MPC screen skin (Pad and Mixer pages, Q-Links follow the page).
It plays up to 16 pads from `Samples/padNN.wav` or a Roland MV drum kit saved as `Samples/kit.MV0`. It is **not** a full MV-8000 emulator and has
not been verified on a device. Back up first and use at your own risk.

## Requirements
- A first-generation MPC OS standalone (32-bit ARM: Force, MPC Live / Live II, One, X, Key 61). The installer refuses anything else.
- Root shell (SSH) access, which stock MPC OS does not offer; you need a modded unit.

## Install (scripted)
1. Unzip, then copy the whole folder to the device, e.g. `scp -r MV-8000-0.3.1 root@<device-ip>:/tmp/`
2. `ssh root@<device-ip> sh /tmp/MV-8000-0.3.1/install.sh` (add `-y` to skip the prompt)

The installer verifies `SHA256SUMS`, **stops MPC** (save your project first), waits until it has exited, backs up `MPC.settings`, copies the
plugin to `/sdcard/vst/` and the skin to `/sdcard/Synths/mvlib - VST - MV-8000/`, adds the plugin to MPC's plugin list, validates the edited
settings file, and starts MPC again. Running it again upgrades in place; Samples you added are never overwritten.
Then add **MV-8000** to a track from the plugin browser (Instrument plugins).

## Uninstall
`sh uninstall.sh` removes the plugin, the skin and the plugin-list entry (after a backup). Files in `Samples/` are kept.

## Install by hand
1. Copy `payload/vst/roland_mv.so` to `/sdcard/vst/roland_mv.so` and `payload/Synths/mvlib - VST - MV-8000/` to `/sdcard/Synths/mvlib - VST - MV-8000/`.
2. `systemctl stop acvs`, back up `MPC.settings` (Force: `/media/az01-internal/Settings/MPC/MPC.settings`).
3. Add the line from `plugin.xml` inside `<VALUE name="pluginList-arm"><KNOWNPLUGINS>` (create the value before `</PROPERTIES>` if missing).
4. `systemctl start acvs`. If MPC shows default settings, restore your backup.

## Files
See `SHA256SUMS`. Layout and installer safety steps are modelled on the JV-880 MPC plugin package.
