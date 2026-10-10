# Roland MV / MC Sample Instrument — source release 0.3.1

A VST2 instrument prototype organized using the supplied JV-880 MPC plugin's legacy VST2/ARM32 conventions. The approved Roland MV-8000 visual reference and layout spec are in `skin/`.

## Implemented in this revision
- VST2 ABI entry points and stereo output.
- 16 sample-pad MIDI mapping: notes 36–51 trigger pads 1–16 in Drum mode.
- Added Drum/Synth mode parameter and VST program selection for `.MV0` files under `Samples/Patches/`.
- Patch browser scans nested category folders, loads the selected patch on program change, and supports all sample records found in a patch.
- Synth mode maps MIDI notes to the nearest decoded sample root key, transposes from that root key, and uses conservative sample-name velocity-layer hints when tags like MP/FF immediately precede root-note digits; this is still not full Roland key-zone/partial emulation.
- Basic RIFF/WAVE reader for uncompressed 16-bit PCM mono/stereo WAV files.
- Samples are loaded during plugin open, not in the audio callback, from:
  `/sdcard/Synths/mvlib - VST - MV-8000/Samples/pad01.wav` through `pad16.wav`, or patch files under `Samples/Patches/`.
- MIDI notes 36–51 trigger pads 1–16; notes outside that range are ignored.
- Linear interpolation during sample-rate conversion.
- Included minimal VST2 host test that opens the plugin, sends note 36, processes stereo audio, and asserts non-zero output.
- WAV preparation utility: `tools/prepare_wav_pads.py SOURCE_DIR OUTPUT_DIR`.
- Experimental MVFF `.MV0` sample reader for the observed `PRM`/`WAVE` layout.
- Versioned VST2 program-chunk state persistence for all 16 pads, master level, cutoff, resonance, and selected-pad state; malformed chunks are rejected. MVFF sample loading respects valid per-sample end-frame indices, and velocity selection recognizes the single-letter P/F factory naming convention as a heuristic.

## Not implemented / not verified
- Full native MV-8000/MV-8800 project loading is **not implemented**: project/song sequences, track arrangement, patterns, mixer/effect routing, and project-level settings are not parsed. The factory-patch archive is not a full project backup.
- `.MV0` sample extraction remains experimental: PCM interpretation is inferred from observed files and the sample rate is assumed to be 44.1 kHz. The patch PRM synthesis parameters are not decoded.
- MC-909 support remains deferred.
- A generated MPC skin (`payload/Synths/mvlib - VST - MV-8000/Plugin Skins/`, see docs/SKIN.md) now exists in the JV-880 skin format, but is untested on a device. `skin/` still holds the original concept art.
- No ARM32 MPC X binary has been produced in this environment. `make host-test` builds an x86-64 host smoke-test shared object only.
- `install.sh` / `uninstall.sh` follow the JV-880 package design (SHA256 check, wait for MPC to stop, settings backup + validated edit, upgrade in place). They are tested against a fake device filesystem (`make test-install`) but have **never been run on a real MPC**; see INSTALL.md.

## Build/test
Host smoke build:
```sh
make host-smoke test-params test-state test-decode test-skin test-install
file build/roland_mv_host_test.so
```

Target build requires a matching ARMv7 hard-float toolchain:
```sh
make CXX=arm-linux-gnueabihf-g++
file payload/vst/roland_mv.so
```
The second command is only expected to work when that cross compiler and target runtime are installed.

## Prepare WAV samples
```sh
python3 tools/prepare_wav_pads.py ./my_wavs ./Samples
```
Copy `Samples/padNN.wav` to `/sdcard/Synths/mvlib - VST - MV-8000/Samples/` on the MPC. WAVs must be PCM, 16-bit, mono or stereo. The first 16 supported files are assigned alphabetically to pads 1–16.

## MVFF fixture inspection
Extract `MA_Dirt&GrimeKit.MV0` from the supplied ZIP, then run:
```sh
python3 tools/mv_inspect.py /path/to/MA_Dirt\&GrimeKit.MV0
```
This confirms the `MVFF` signature and reports heuristic candidate chunks; it does not decode them.

## Safety
Do not install on the MPC until the ARM binary, VST ABI, host registration, GUI/skin, sample playback, and device behavior have been verified on the actual target. Save projects and back up `MPC.settings` before any eventual installation.

## MVFF (.MV0) experimental sample support
The real `MA_Dirt&GrimeKit.MV0` was parsed and the decoder rewritten around its actual chunk structure: `MVFF` header, `FMT `, kit `PRM ` block, then an `SMPL` chunk holding per-sample `PRM`(0x26)+`WAVE` records. Findings from the real file:
- Payload is signed 16-bit big-endian PCM (kicks are smooth under this reading, noise if byte-swapped).
- **Pads 1-12 of the Dirt & Grime kit are interleaved stereo, pads 13-16 mono.** In that kit the per-sample PRM flag (0x0100) matches: stereo samples show L/R pairs that are identical or nearly so. An earlier build wrongly treated everything as mono.
- Tested on 96 readable MV-8000 factory patches (1,571 samples): all parse structurally, every sample is mono (flag 0), and PRM bytes 32/33 are a constant 0x27 and the MIDI root note. The end-point field is the sample end and is often *smaller* than the sample length, so it says nothing about channel count (an earlier claim here that it did was wrong).
- Header length equals file size minus 8.
- Sample rate is not stored in any field decoded so far; 44.1 kHz is assumed (pad 16 is exactly 4.000 s at 44.1 kHz, which supports but doesn't prove it).
- The kit parameter block (pad levels, tuning, envelopes, assignments) is **not decoded**.

```sh
python3 tools/mvff_decode.py path/to/kit.MV0 output_samples
MV_REAL_KIT=path/to/kit.MV0 make test-decode
```
The plugin also loads `Samples/kit.MV0` directly. The original `.MV0` is third-party content and is not included in this repo. The runtime reader now retains each sample record name/slot/root key and uses root-key-aware selection plus conservative velocity-layer hints for synth mode.

## Validation added in continued build
Run `python3 tools/validate_samples.py` to validate the 16 staged Dirt & Grime WAV files against the experimental extraction manifest. This checks file readability, PCM format, pad count, non-empty audio, sample names, and basic signal statistics. It does **not** prove the guessed PCM byte order or 44.1 kHz rate is correct.

## Current deployment note
Install with `install.sh` from the release folder (see INSTALL.md). It is tested only against a simulated device filesystem, so back up `MPC.settings` and save projects first.

## GitHub Actions test build (MPC X / Hakai 3.8 target)

The repository includes `.github/workflows/build.yml`. After pushing this folder to a GitHub repository, open **Actions → Build and validate → Run workflow** (or push a commit). It runs two jobs:

1. **Host smoke test** — compiles an x86-64 shared object and checks that the VST2 entry-point symbols exist.
2. **ARMv7 hard-float cross-build** — builds `roland_mv.so` using Ubuntu's `arm-linux-gnueabihf` toolchain, checks the ELF architecture and exported symbols, and publishes the `roland-mv-armv7-hakai-test-build` artifact.

Download the ARM artifact from the completed Actions run. The `MV-8000-0.3.1.zip` release folder contains the ARM plugin, installer scripts, `plugin.xml`, the skin, the 16 candidate WAVs and `SHA256SUMS`.

**This is a test build, not a verified Hakai 3.8 release.** CI verifies compilation, architecture metadata, symbols, and WAV file structure only. It cannot confirm MPC plugin registration, native skin support, VST ABI compatibility on the MPC, sound output, or the inferred MVFF sample encoding. The current PNG/layout JSON is a visual specification and is not a working native MPC GUI. Do not run the installer or overwrite MPC settings on your device based on this artifact alone.


## Archive import utility (new)
Use `python3 tools/roland_archive_import.py source.zip output_folder` to scan a Roland archive, copy supported WAVs into numbered pads, experimentally extract matching MVFF `.MV0` samples, preserve original proprietary files, and write `import-report.json`. The importer intentionally does not claim native decoding of MC-909 `.SVD`/`.MCS` files: the supplied SRX-01 archive is a user-memory backup and its proprietary structures still require a validated decoder.


## Factory patch loading (added)
1. Run `python3 tools/prepare_factory_patches.py MV-8000_Factory_Patches.zip Samples/Patches` on a computer. This safely stages `.MV0` files and writes `Samples/Patches/patch-import-report.json`; files with ZIP CRC errors are reported.
2. Copy the resulting `Samples/Patches/` folder to `/sdcard/Synths/mvlib - VST - MV-8000/Samples/Patches/` on the MPC X, preserving category folders.
3. Restart/reload the plugin. The program list is scanned when the plugin opens. Select a patch from the host's VST program list.
4. `Drums` mode triggers MIDI notes 36–51 using the first 16 sample records; `Synth` mode plays chromatically using decoded sample root keys and conservative name-based velocity-layer hints.

The MVFF parser is experimental. Patch PRM settings and exact sample zones are not decoded, and sample rate remains assumed to be 44.1 kHz. Some archive members failed CRC/header checks during cataloging and may not load. The sample endpoint field is now applied as a conservative trim when it falls inside the decoded PCM frame count.

## VST2 state persistence
The plugin now advertises VST2 program chunks and stores/restores its current parameter state, including all per-pad level/pan/tuning/envelope/gate values, master, filter, resonance, and selected pad. Run `make test-state` to verify save/restore and malformed-state rejection. This is **plugin parameter state only**; it does not load or recreate a Roland MV song/project, sample-zone mapping, or native FX graph.

## Factory patch archive catalog
For a supplied MV factory patch ZIP, run:
```sh
python3 tools/catalog_mv0_archive.py /path/to/MV-8000_Factory_Patches.zip build/mv0-catalog.json
```
The output is metadata-only and reports invalid ZIP members rather than silently skipping them. It does not redistribute/extract factory audio. The catalog is useful for decoder validation, not proof of full patch or project compatibility.
