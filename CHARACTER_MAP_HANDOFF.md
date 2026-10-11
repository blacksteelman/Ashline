# ASHLINE — character, weapon assembly and map recovery

User direction: leave Claude's audio alone and improve the rest. This is a concrete defect repair pass, not a claim that models, animation or graphics meet COD4 quality. The user rejected the earlier quality claims. Preserve that feedback.

Worktree: `/workspace/ashline-polish`, branch `codex/weapon-polish`. Gameplay commits: `2206367`, `a8cc188` and `eaee5f6`. Exact Claude reference remains separate in `codex/claude-baseline`; do not revert the whole game and lose navigation/network/combat fixes.

## Changed

- Reload AnimationTree filter includes BOTH shoulder/arm chains and their descendants (fingers), together with Weapon. Previously the tilted reload gun retained an idle right arm.
- Sprint presentation eases in/out; authoritative actors use the actual sprint flag, remote actors infer sprint from speed (snapshots do not carry that flag). Reload/crouch cannot select sprint. Respawn resets presentation blends.
- Removed spare first-person reload magazines from the baked AK and MPA30 third-person meshes. Confirmed they were weighted to `Pmag2_063` / `Pmag_2_062`, source nodes Object_99 / Object_96, not the installed magazine. Baking script now omits them too. Installed magazines remain.
- ACR's authored Pmag surface is a separate MagazineRig. It extracts, disappears while stowed, and seats in time with the existing hand clip. This applies to ACR; AK/SMG installed magazine geometry is still combined with the receiver. Do not claim all third-person reloads are now complete.
- Road/repair asphalt has reduced normal strength, darker albedo and a dry roughness floor, rather than chalky bright specular relief. Other surfaces retain their previous settings. Actual before/after game captures were viewed.
- Restored Claude's original recordings/routing/pitch/overlap behavior in the working game, not just the reference branch. No near/far crossfade or added indoor compression. Audio test exercises actual playback dispatcher under Dummy. Audio was NOT listened to here.
- Bots now detect net horizontal progress over 0.25 s. Stair-side bobbing/rebound no longer counts as advancing. One early replan keeps the same 3D destination; random recovery remains the final fallback. Bots brake within 0.6 m of waypoints to avoid overshooting the tight arrival radius; accelerated 4x stepping is also tested. A reproduction first plans a valid stair route, then displaces the Fighter below its side. Before fix: fail. After fix: reaches upper floor without random recovery.

## Verified locally

Godot 4.6.3, native Linux export, llvmpipe software Vulkan, Dummy audio. No Windows runtime or representative gaming-GPU performance check.

- functional: 49; FP motion: 23; FP anchors: 46; audio dispatcher: 38; actual character graph/magazine lifecycle: 18; map routes/displacement/accelerated stepping: 39. Total 213 checks, zero failures in final passing logs.
- `build/character-native/ASHLINE.x86_64` is the local playable export. Final exported run: two matches, scores 40:38 and 27:40, 1007 shots, 36 headshots, six random recovery events. Stair-side displacement repro passes without recovery; the remaining full-match recoveries are unresolved, see native-bot.json. Final native frame was viewed.
- Deterministic in-map captures use real Fighter + CharacterMotion + GripIK, not raw source clips. `tests/capture_character_motion.gd -- --graphics=1 --tag=review --weapon=0` captures idle/sprint/reload/aim. Requires Xorg/Vulkan. Local gun is hidden in this third-person inspection. This is a pose review, not a human gameplay/gunfeel assessment.
- CI for final gameplay revision: https://github.com/blacksteelman/Ashline/actions/runs/38129341065 . Do not claim it passed until checking the run; artifacts from 38128506082 are the previous commit and omit the stair recovery fix.

Evidence: [docs/verification/character-map-recovery](docs/verification/character-map-recovery), including actual frames, raw passing logs, final native report and build hashes. The CI was still importing assets at recording; Windows artifact download has not been verified for this gameplay revision.

## Continue with actual art work

The modern storefronts remain repetitive, roofs/interiors need authored destruction and distinct composition, covered cars are poor silhouettes, and sleeves/operators still need model/material/rig review. Do not substitute small HUD or material adjustments for the requested overall art quality. Work on one readable battle area, then judge it in the exported game.

Reload inspection is still needed across all weapons and BOTH teams at multiple phases. AK/SMG need proper detachable magazine geometry; pistol and bolt rifle need their own third-person handling rather than the generic rifle stance/2-second reload. Any animation reauthoring must preserve locomotion, muzzle attachment and runtime IK.

Use the existing CC BY assets legally and retain LICENSES.md/attribution when modifying or replacing them. Avoid replacing detailed weapons/operators with procedural stand-ins.

Run meaningful checks after new changes:

```sh
for suite in functional fp_motion_regression fp_anchors_regression audio_distance_regression character_motion_regression foundry_routes_regression; do
  godot --headless --audio-driver Dummy --path . --script tests/$suite.gd || exit 1
done
XDG_DATA_HOME=/workspace/ashline/.runtime/data godot --headless --path . --export-release "Linux PC" build/character-native/ASHLINE.x86_64
build/character-native/ASHLINE.x86_64 --headless -- --bot-test --seed=829 --matches=2
```

Inspect logs for SCRIPT ERROR / ERROR even with exit 0. Regression evidence includes an intentionally failing before-fix control; it is not a passing-suite log.

The intermediate a8cc188 native run exposed waypoint oscillation (37 recovery events across two matches). eaee5f6 adds braking into tight waypoints; its source replay completed two matches with five recovery events. Do not imply zero recoveries across full matches. Use the final native report, not the intermediate run, for release evidence.

The paused street-art stash `a8f221120ae9b1f3221c9a2b24a3631667713cd8` still contains an unimplemented build_street_architecture call. Do not apply blindly. Display numbers through :141 used. Keep local build/.gdignore so export/import does not process hundreds of review screenshots. Export templates are in /workspace/ashline/.runtime/data.
