# Weapon hand alignment — 2026-10-12

Branch `codex/weapon-polish`; final gameplay/release revision `98e84ad85433d410d78bc44baebb272d8882723f`.

## Changes

- World weapon instances expose the existing per-weapon grip/support finger and thumb directions from CFG metadata. GripIK derives each soldier hand's anatomical frame from rest-pose finger and thumb bones, then blends wrist orientation toward the weapon frame during holding. Free reload motion retains its authored pose; rig scale is preserved.
- Carried magazines follow the full wrist transform, including rotation. Their contact offset rotates consistently; seating/completion restores the identity transform. Finger direction during carrying is calibrated toward the actual magazine center, with the thumb along its side.
- Settling the test scene exposed an older contact bug: measurements before deferred BoneAttachment updates hid 1–6 cm of rifle reach error. Wrist contact now sits behind the near magazine edge, with palm space and a lower wrist to reduce receiver overlap. Bones are not stretched.
- Character regression waits for actual attachment updates and verifies idle finger directions, magazine rotation, fingers pointing into the carried magazine, hand scale, contact and respawn. 128 checks pass.
- Crucial export fix: Godot's all-resources export omitted the raw world weapon CFGs. Ready builds therefore silently used default muzzle/grip values. Both PC export presets now explicitly include `assets/viewmodels/world_*.cfg`.
- `--verify-assets` validates CFG data and actual Art.world_weapon metadata inside the native executable before any map/menu is created. CI runs it before the bot match, covering all five weapons. Original first-person assets, audio recordings and balance were retained.

## Verification and delivery

CI passed: https://github.com/blacksteelman/Ashline/actions/runs/38234168627 . Eight suites total 413 checks (49 functional, 23 FP motion, 46 anchors, 60 actions, 38 audio, 128 character motion, 40 routes, 29 ragdoll), both native exports, native calibration verification, native bot smoke match and verified release publication. Intermediate run 38232851210 was cancelled during further visual corrections and produced no published build.

Release: https://github.com/blacksteelman/Ashline/releases/tag/dev-98e84ad . Windows ZIP 490,402,670 bytes; Linux ZIP 480,229,988 bytes. Both downloaded locally; ZIP CRC, archive SHA-256 and every BUILD_INFO payload hash verified. Extracted Linux calibration check passed for all five weapons. Windows was cross-exported and its bytes verified, not run on Windows. Repository is private; download requires repository access.

Local source suites: 206 checks (functional 49, character 128, ragdoll 29). Local pre-publication native export completed two seed-806 matches: 1141 shots, 35 headshots, zero stuck recoveries. This pre-publication run preceded the CFG inclusion fix; the CI match and downloaded executable calibration checks cover the final export. Downloaded final published binary additionally completed two seed-807 matches: 1033 shots, 32 headshots, zero recoveries, successful completion. The new CLI verification also passed locally for all five exported weapon calibrations. Native graphical verification is recorded below.

Evidence: `docs/verification/hand-alignment/`, including actual game renders, CI log/result, download hashes and native asset verification. Source captures: `tests/capture_hand_alignment.gd -- --tag=checked`, Vulkan llvmpipe/Dummy audio at 960×540, actual map. Capture frames include idle, carrying (30%) and seating (65%) for all five weapons. Last source display `:163`; native graphical run uses `:164`.

## Continue and limits

Finger curl is still shared across weapons; individual service finger poses and pistol support grip need manual adjustment. The sniper's bright blue improvised muzzle accessory remains a visible asset issue, as do inconsistent weapon styling, character clothing/materials and first-person forearm deformation. This pass improves third-person contact and prevents lost calibration in builds; it does not establish COD4 art quality. Preserve Claude audio.

Next: tune actual finger bones per weapon and magazine, inspect both teams and moving/aimed reloads, then improve coherent weapon finishes/models. Do not remove the native CFG smoke check. To publish another PC build: push a commit and manually dispatch `build.yml` on `codex/weapon-polish`; manual runs use Releases and avoid the full Actions artifact quota.

Current native exports under `build/hands-linux` and `build/hands-windows` have been refreshed from the verified published ZIPs and contain exact release manifests. Superseded generated copies `magazine-unpack`, `magazine-linux`, `magazine-windows`, and `release-download-44a9226` were removed for disk space; their published releases/evidence and source assets remain. Pre-existing untracked generated UIDs/reports were left untouched.

Native launch environment: this workspace now restricts writes outside `/workspace` and `/tmp`. A first headless run failed while opening default user logs; rerunning with `XDG_DATA_HOME=/workspace/ashline-polish/build/runtime-hands-verification` succeeded. For graphical runs also set XDG_CACHE_HOME/MESA_SHADER_CACHE_DIR inside the build directory and point Xorg logs to `/tmp`. This is a workspace permission issue; preserve the failed log as evidence. Native software-Vulkan graphical attempt timed out after 180 seconds before producing a frame. Source graphical captures were successful under Vulkan llvmpipe; the initial OpenGL timed capture also timed out. Verbose startup confirmed actual loading of map and character resources. A subsequent OpenGL Compatibility run requesting only the first frame (`--capture=.01`, 640×360) succeeded, saved `native-game.png`, and exited 0. The actual frame was inspected: map, first-person gun and HUD render; the gun is excessively dark in this fallback view. No FPS/performance claim is established by a single software-rendered frame. Do not claim a successful native Forward+ visual run. Next graphical priority: check default Forward+ first-person weapon readability on a working graphical runtime, tune viewmodel lighting if similarly dark, and investigate cold startup/render cost rather than hiding the timed-out attempts.
