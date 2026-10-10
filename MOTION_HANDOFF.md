# Weapon presentation follow-up

Base: Claude branch `claude/multiplayer-military-fps-6avclq`, commit
`3fbdbf8a4948e3638b87c6cb2a407e6e4e790aae`.
Working branch: `codex/weapon-polish`. Original worktree remains untouched.

## Change

`scripts/fp_set_rig.gd` now solves the existing recoil and mouse-inertia
differential equations analytically. Previously recoil applied position damping
once per rendered frame, outside its substeps; inertia used a frame-sized Euler
step. Both made the weapon's response depend on the display rate. Recoil also
simulated only 0.2 seconds of velocity decay through longer stalls.

The new update consumes elapsed time without that cap. Shot impulses, ADS
alignment, authored animations, models and sound assets remain Claude's.
This fixes the springs for identical input histories; it does not establish
end-to-end mouse latency or hardware performance.

The sniper set has no Head_Cam joint. Previously FPSetRig queried bone -1 every
frame; Godot logged an error and returned the identity pose. Its Arsenal entry
now explicitly chooses the skeleton's origin as its camera anchor, preserving
the existing authored offsets without the invalid lookup. The framing probe
uses the same camera-anchor method as gameplay.

## Verification

`godot --headless --path . --script tests/fp_motion_regression.gd`

23 assertions cover linear/angular recoil and inertia at 15/30/60/144/240 FPS,
six-shot automatic bursts, a two-second stall, paused time, and retained kick.
The tests exercise FPSetRig, which is active for the new weapons. The older
regression_v3 spring test exercises the retired WeaponView implementation.

`tests/fp_anchors_regression.gd`: 41 passing assertions on all five imported
weapon sets, camera/weapon anchors, and idle/fire/reload poses. `functional.gd`:
49 passing assertions. The first functional run passed but emitted bone-index
errors; after the camera fix the same test passed with no ERROR entries.

Runtime logs and captures for this worktree belong in `build/verification/`
and `build/screenshots-v8/`; these directories are ignored by Git.

Environment: Godot 4.6.3, software Vulkan/llvmpipe, Dummy audio. No conclusions
about gaming-GPU FPS or listening quality can be drawn here. A cold headless
import crashed at the font importer; the graphical editor import was used next.

Next: inspect moving weapon footage at real frame rates, especially turning
while ADS, firing into ADS and recovering after sprint. Continue from Claude's
asset pipeline, not the older procedural weapon/character generators.
