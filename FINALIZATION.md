# Roland MV MPC Plugin — 0.3.1 source handoff

## Included in this handoff
- VST2 source for Drum/Synth modes and patch-program selection.
- Experimental MVFF `.MV0` PCM sample reader. It preserves sample names, slots, root-note metadata, stereo flag, and applies valid in-range end-frame trims.
- Nearest-root-key chromatic playback with conservative velocity-layer hints based on the factory sample naming conventions.
- Factory patch staging tool: `python3 tools/prepare_factory_patches.py MV-8000_Factory_Patches.zip Samples/Patches`.
- Skin assets, install/uninstall scripts, CI ARMv7 build workflow, and host-side tests.

## Validation performed for this source revision
- Host VST2 entry/open/MIDI/stereo audio smoke test: PASS.
- Parameter behavior tests: PASS.
- State chunk save/restore and invalid-chunk rejection: PASS.
- Synth-mode MIDI note audio test: PASS.
- MVFF synthetic decode test: PASS.
- Skin schema and Q-Link consistency test: PASS.
- Installer simulation (install/upgrade/uninstall and safety refusals): PASS.
- Factory patch staging test: PASS.
- 16 included WAV sample structural validation: PASS.
- Additional manual smoke test using a real factory patch (`BS _CompJBass @.MV0`): drum-note playback PASS; synth note 60 playback PASS.

## Limitations that remain
- The MPC X ARMv7 hard-float shared object was **not built in this workspace** because the ARM cross-compiler could not be installed here. The included GitHub Actions workflow is configured to build and verify it.
- No physical MPC X/Hakai device test was performed.
- This is not a bit-accurate MV-8000 synthesizer. The proprietary patch parameter/partial-zone tables and effects engine are not decoded. Synth key/velocity selection is a useful approximation based on sample root keys and naming hints. Drum mode uses the first 16 sample records rather than the original kit PRM's pad-to-sample assignments.
- The sample rate is assumed to be 44.1 kHz because the fields decoded so far do not establish the original rate.

Do not install a host x86-64 `.so` on the MPC X. Build the ARMv7 target with the included workflow, inspect the artifact, back up the MPC settings, and test on-device before relying on it in a session.
