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

`tests/fp_anchors_regression.gd`: 46 passing assertions on all five imported
weapon sets, camera/weapon anchors, idle/fire/reload poses, and ADS alignment. `functional.gd`:
49 passing assertions. The first functional run passed but emitted bone-index
errors; after the camera fix the same test passed with no ERROR entries.

Sniper hip framing now uses eye offset (-.04,.27,.12), rotation (3,-2,0), FOV 62.
This removes the cut-off sleeve in the lower-left corner. ADS settings are
unchanged; the sight-line assertions check its alignment after hip framing.
The fp_frame capture tool now disables animation crossfading for a frozen pose
and exits with code 2 for a missing clip instead of hanging on a null animation.

Viewed three actual 1280x720 Forward+ match captures and sniper before/after,
reload and Walk poses. Images are committed in `docs/verification/weapon-polish`.
The sniper has no Run clip; FPSetRig uses Walk as its sprint fallback.
Bot seed 810 completed a 6v6 TDM at 40:30, 376 shots, 17 headshots, five route
recoveries and five early spawn deaths. This is not a map-balance certification.

Runtime logs and captures for this worktree belong in `build/verification/`
and `build/screenshots-v8/`; these directories are ignored by Git.

Environment: Godot 4.6.3, software Vulkan/llvmpipe, Dummy audio. No conclusions
about gaming-GPU FPS or listening quality can be drawn here. A cold headless
import crashed at the font importer; the graphical editor import was used next.
After the fonts were cached, a headless import completed successfully.

Visual limitations: sleeve highlights and some road/concrete areas are overly
bright; the environment still needs art direction and varied cover. No claim
that COD4-quality presentation has been reached.

Next: inspect moving weapon footage at real frame rates, especially turning
while ADS, firing into ADS and recovering after sprint. Continue from Claude's
asset pipeline, not the older procedural weapon/character generators.

## Spatial gunfire follow-up

Nearby enemy shots now use mono close-recording variants. Between 10 and 50 m,
the game blends close/far recordings with constant-power gains; farther shots
use the existing distant recording. Both layers share pitch and emitter position.
Selection uses the current viewport camera, including spectator views.
Interior local fire now sends through the Weapons compressor; spatial interior
fire has its own WorldInterior reverb bus feeding World.

Rebuild positional close recordings without downloading the source library:
`python3 tools/build_sounds.py --world-near-only`. This uses the included processed
stereo WAVs and writes source/output hashes. Full source-library processing also
generates the positional variants. Credits remain CC0 in LICENSES.md.

`tests/audio_distance_regression.gd`: 34 passing assertions for power/continuity,
near/far choice, mono resources, actual playback voices, shared pitch, current
listener distance and physical roof-based audio routing. Dummy output was used;
subjective audio quality still needs listening on a PC.

The native build workflow now also builds codex/weapon-polish and runs all four
regression suites. It fails on logged runtime errors even if an older test exits
zero. Documentation screenshots are excluded from native exports.

Final local regression total: 152 passing assertions (49 gameplay, 23 motion,
46 model anchors, 34 spatial audio). Gameplay was repeated after the audio
changes with no logged runtime errors.
