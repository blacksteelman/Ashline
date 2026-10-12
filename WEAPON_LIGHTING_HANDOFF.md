# First-person weapon lighting

Gameplay revision: `a4d01e943de6d190a6f9a7e595d8500df303f5b0`, branch `codex/weapon-polish`.

## Change

A camera-relative OmniLight supplies a restrained cool bounce to imported first-person weapons and arms. It preserves existing PBR textures, normals, roughness, scene lighting and optic emission. Its position is above/right of the camera to produce a readable highlight on dark receivers and sights. No audio, weapon balance or animation clips changed.

Meshes retain their world-light layer and additionally receive render layer 20. The bounce only affects layer 20, has no shadows, and explicitly uses `BAKE_DISABLED`: GI ignores light cull masks, so allowing it into SDFGI would leak into the map. Bots and world geometry retain their normal layers. The light is owned by the local player's camera and is freed with it.

`tests/viewmodel_lighting_regression.gd` checks isolation, GI exclusion, shadow cost and both light layers for all five actual first-person assets (16 checks). It is included in CI alongside existing regression suites. `tests/capture_weapon_materials.gd` now supports `--compare-bounce` and a seventh sniper view. This captures the same settled pose with/without the bounce, rather than relying only on first-frame screenshots.

## Verification in this session

- Source functional suite: 49 checks passed.
- New source isolation suite: 16 checks passed.
- Real source OpenGL Compatibility screenshots at 640×360: initial before, weak first trial, tuned result. The tuned result improves the optic/upper rail highlight; the weapon's side remains dark. These are software-rendered first frames, not proof of warmed-up rendering or hardware performance.
- Forward+ Quality on software Vulkan timed out after 180 seconds without saving a frame. It reached map navigation creation, and its log is retained. Do not claim this renderer/preset passed visual inspection.
- Settled OpenGL captures: six on/off pairs covering all five weapons, including indoor/outdoor assault rifle. All 12 images were inspected. The full batch hit its 300-second limit after view 4; focused SMG and sniper reruns completed their pairs with exit 0. Receiver sides and environment shadows remain very dark; some original materials remain too glossy.
- Forward+ Performance also timed out at 180 seconds without a capture. Do not equate this with a measured GPU performance failure; only software rendering is available here.
- CI run https://github.com/blacksteelman/Ashline/actions/runs/38271481205 succeeded: nine suites / 429 checks, both exports, native asset calibration, bot smoke and release publication.
- Published release https://github.com/blacksteelman/Ashline/releases/tag/dev-a4d01e9 : Windows 490,404,120 bytes, Linux 480,232,204 bytes. CI verified ZIP CRC and uploaded byte sizes/digests before publishing. Release metadata and full CI log are retained. These ZIPs were not independently downloaded in this session: gh began returning HTTP 401; the GitHub connector successfully confirmed completion and publication. Git transport still worked.
- Local exports refreshed under `build/hands-linux` and `build/hands-windows`, with regenerated BUILD_INFO for a4d01e9. They now supersede the old hand-alignment exports in those directories; old released bytes remain under `build/release-download-98e84ad`. Both clean exports exited 0. An initial export could not save editor settings outside the sandbox; rerunning with XDG_CONFIG_HOME inside the workspace removed those errors.
- Local native Linux asset calibration passed for all five weapons; two seed-808 bot matches completed (1148 shots, 35 headshots, zero stuck recoveries). Native OpenGL launch saved `native.png`, inspected, exit 0. Windows was exported but not run.

Evidence: `docs/verification/weapon-lighting/`. Repeat a settled pair with `godot --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 640x360 --script tests/capture_weapon_materials.gd -- --tag=review --compare-bounce --view=4`. View indices: 0 indoor assault, 1 outdoor assault, 2 marksman, 3 pistol, 4 SMG-class AK asset, 5 HUD stress, 6 sniper.

## Continue

Inspect actual Forward+ gameplay on a GPU. Check the bounce during ADS, sprint and reload and in bright outdoor light; reduce/tune specular if coated metal looks too glossy. Finger poses, forearm deformation and inconsistent weapon styling between the five sets remain unresolved. This pass does not establish COD4 visual quality. Preserve Claude's audio.

## Follow-up pass: the blue sniper accessory is gone

The sniper set (ccransh CC-BY) hangs a blue gun-oil can with a Portuguese "P-F-1 / PLATINUM FILTER" label on the barrel in front of the receiver. It read as a blue box hanging off the muzzle in every first-person and third-person frame. `FPSetRig.strip_foreign_part()` now drops it at load time: an island of the `Rifle` surface counts as the can when a third of its vertices sample a clearly blue texel and its centre is forward of the receiver, and only its triangles leave the index buffer, so the glTF skin bindings stay valid. Barrel, sling and buttstock (which samples the same label inside its UV shell) survive; `tests/weapon_trim_regression.gd` guards all of that, including the untouched other four weapons and the third-person bake. The bake was refreshed: `assets/viewmodels/world_fp_sniper.res`.

What is left is UV bleed, not the can: 341 of the barrel's triangles sit over the label patch of the shared atlas, so isolated barrel triangles still sample blue. Removing them would thin the barrel. Do not describe that as the can still being there.

Two things this pass measured rather than changed. First, the sniper has no first-person viewmodel in ADS by design: `fighter.gd` hides the gun once `Arsenal.scoped()` and `view.aim_blend > .98`, and `hud.gd` draws `scope_overlay()` instead. A HUD-free ADS capture of that weapon looks like an empty street, and that is not a broken viewmodel - `docs/verification/weapon-trim/scope-overlay-ads.png` shows the real scoped view. Second, the palms and fingers do reach the weapon: engine-baked skinned vertices put the closest palm vertex 0.2-4.4 mm and the closest fingertip 0.2-0.9 mm from the weapon surface on all five sets. Finger shape is still a pose question, not a contact one.

Evidence and numbers: `docs/verification/weapon-trim/`. Repeated local run on Windows (Godot 4.6.3, RX 9070 XT): ten suites / 448 checks, 0 failures; a real `main.tscn` match with input, damage and HUD captured; bot smoke `--bot-test --seed=801 --matches=1` finished with 520 shots, 18 headshots, success. `tests/functional.gd` now pins `settings.mode` and `settings.classes` before `start_match()`, because saved user preferences (domination, edited loadouts) used to fail four of its checks on any machine where the game had been played. The export templates are not installed here, so no playable export was produced in this session.

For graphical runs here, use Xorg with a `/tmp` logfile and set XDG_DATA_HOME, XDG_CACHE_HOME and MESA_SHADER_CACHE_DIR inside the workspace. `tools` are not required to modify user settings: CLI `--graphics=0` selects Performance for a diagnostic launch. Default remains Quality/Forward+.

## Building and running the PC build on Windows

The export templates must be installed before any export works: download `Godot_v4.6.3-stable_export_templates.tpz` from the Godot release, extract it, and copy its `templates/*` into `%APPDATA%\Godot\export_templates\4.6.3.stable\`. Then:

```powershell
godot --headless --path . --export-release "Windows PC" build/windows/ASHLINE.exe
build\windows\ASHLINE.exe --headless --audio-driver Dummy --user-data-dir build/verify-userdata -- --bot-test --seed=801 --matches=1
build\windows\ASHLINE.exe --resolution 1280x720 --user-data-dir build/verify-userdata -- --showcase
```

`--user-data-dir` keeps the run away from the player's saved settings, which otherwise decide the mode and the class loadouts. A native launch must print `Vulkan ... Forward+ - Using Device #0` and `NAV_READY`. `--verify-assets` runs inside the shipped binary and checks what the editor cannot: every texture, fx, shader, font and script the game `load()`s, all 26 sound streams (loaded the way the game loads them, and the ambient loop is started through the AudioServer), the three camouflage maps, every first-person weapon set and both soldier models. It prints `EXPORTED_ASSETS PASS` or the failing paths, and CI fails the build without that line.

Three export defects were found this way, all of them invisible in the editor:

- `assets/smoke.png` was excluded from both presets, so the shipped build threw `No loader found for resource` on every impact and had no impact or explosion smoke.
- `assets/textures/camo_emr_albedo.jpg` and `camo_mm14_albedo.jpg` were excluded too; `FirstPersonRig.camo_texture()` loads them by name, so two of the three camouflage patterns were simply absent from builds (`camo_ocp_albedo.jpg` happened to be missing from the exclude list).
- The first version of the check itself was wrong: `FileAccess.file_exists()` on a `.wav` cannot succeed in a build, because the importer turns the wav into a `.sample` resource. It now `load()`s the streams the way the game does.

`tests/runtime_assets_regression.gd` keeps the editor side of the same list, so an exporter exclude is caught before an export is even attempted.

Recorded in this session on Windows 11 / Godot 4.6.3 / RX 9070 XT: the exported `ASHLINE.exe` (538.5 MB, Vulkan/Forward+) completed a headless bot match with the same numbers as the editor run (520 shots, 18 headshots, 31:40) and opened its window in showcase mode with no loader errors. With `--verbose` the one-shot verification process reports one leaked `AudioStreamPlaybackWAV` at exit; it holds no `FAIL` line and is written down in `docs/verification/native-build/verification.json` rather than hidden.
