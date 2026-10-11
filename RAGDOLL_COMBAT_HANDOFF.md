# Ragdoll and combat readability — 2026-10-11

Working tree `/workspace/ashline-polish`, branch `codex/weapon-polish`.
Gameplay commit `47b1fec51eb5abd04f38471faee37e5768ce5f39`.
User still rejects the overall models/animations/shooting quality. This is a concrete improvement, not completion of the COD4 quality goal. Keep Claude's restored sound implementation.

## Implemented

- Thirteen physical corpse segments drive the existing soldier skin through a SkeletonModifier3D. Ten pin joints and two limited knee hinges. Current pose/movement and incoming hit direction initiate the fall; headshots apply additional head impulse.
- Weapon mesh drops separately, with its actual mesh bounds supplying a collision box. Original world weapon is hidden until respawn.
- AnimationTree and GripIK stop competing with death physics. Offline and snapshot-driven respawns remove all corpse bodies, restore hand constraints and first-person camera.
- Directional chest flinch replaces random whole-model tilt. The real Weapon bone recoils during shots; grip locks blend out during reload handling.
- Bots now flash from their world-weapon muzzle instead of a point ahead of the eye.
- Short incoming-damage bearing arc; collision-aware corpse-following death camera; first-person camera returns on respawn.

## Validation and evidence

`docs/verification/ragdoll-combat/` contains raw 1280×720 runtime screenshots, seven suite logs, actual native bot results, capture logs and hashes.

230 checks passed: functional 49, FP motion 23, FP anchors 46, audio 38, character motion 18, routes 39, ragdoll 17. Ragdoll test simulates ten seconds, checks stability, pose following, dropped gun, local death camera, directional damage, offline/network respawn cleanup.

Native Linux executable: `build/ragdoll-native/ASHLINE.x86_64` (~451 MiB).
Two headless native TDM matches: 40:33 and 32:40, 951 shots, 20 headshots, 4 route recoveries. Cosmetic corpse physics is disabled in these headless matches; it is exercised separately by the physics regression and actual graphical captures.

Actual graphical captures inspected: idle/firing/flinch/fall/settled/respawn, overhead corpse, incoming-damage HUD, local death camera, first-person respawn, native executable showcase. Software Vulkan llvmpipe, Dummy audio. No listening, Windows runtime, or gaming-GPU performance claim.

First ConeTwist joint implementation passed a short headless test but exploded in the graphical standing-pose test (bodies above 30 m). It was replaced and retested; final physical corpse and weapon remain on the floor. Never treat compilation/short simulation alone as ragdoll validation.

CI run for gameplay commit: https://github.com/blacksteelman/Ashline/actions/runs/38130745591
At handoff creation: in progress. Do not label its Windows artifact ready until successful.

## Continue here

1. Improve authored per-weapon first-person reload/handling animation. Current generic third-person reload, wrist orientation and magazine interaction remain visibly limited. Do not just add camera shake.
2. Improve soldier deformation/weights and angular constraints at shoulders/hips/elbows. Stable pin joints allow excessive twisting; knee hinges are limited. Exercise crouch, sprint, stairs and wall deaths and inspect actual renders, not just the standing-floor case.
3. Upgrade the actual model/material/environment quality. The native image remains visibly below the requested visual target; this task did not replace meshes or rebuild the map.
4. Play real human input and network sessions. Automated source/native matches validate mechanics, not subjective gunfeel. Dedicated server stays authoritative; corpses remain cosmetic and client-local.

## Reproduce

Run all seven suites with Godot 4.6.3, Dummy audio:

```bash
for suite in functional fp_motion_regression fp_anchors_regression audio_distance_regression character_motion_regression foundry_routes_regression ragdoll_regression; do
  godot --headless --audio-driver Dummy --path . --script tests/${suite}.gd
done
```

Graphical probes require an X display and Vulkan. Use `tests/xorg.conf`; llvmpipe ICD is `/workspace/ashline/.runtime/vulkan/lvp.json`. Last display used `:148`; allocate `:149` next. Start Xorg and Godot inside the same Python subprocess lifetime and terminate Xorg in `finally`.

```bash
godot --path . --audio-driver Dummy --resolution 1280x720 --script tests/capture_ragdoll.gd -- --graphics=1
godot --path . --audio-driver Dummy --resolution 1280x720 --script tests/capture_combat_readability.gd -- --graphics=1
XDG_DATA_HOME=/workspace/ashline/.runtime/data godot --headless --path . --export-release 'Linux PC' build/ragdoll-native/ASHLINE.x86_64
build/ragdoll-native/ASHLINE.x86_64 --headless --audio-driver Dummy -- --bot-test --seed=801 --matches=2
```

Keep `build/.gdignore` and `docs/.gdignore`; avoid reimporting screenshots. Export excludes tests/docs/build. Do not use release binaries with `--script`; probes run from source. Preserve the separate Claude baseline worktree.
