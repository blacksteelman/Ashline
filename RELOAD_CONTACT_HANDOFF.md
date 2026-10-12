# Reload hand contact — 2026-10-11

Branch `codex/weapon-polish`, reload commit `8de2f06205ed881b63c68e47b915090bef2a7671`, final gameplay/build revision `4421b5f3117328626732c63c0779a545d0ab72f6`.

Third-person ACR reload previously animated the magazine independently of the left wrist, using a generic magazine location that does not match this weapon. GripIK now uses the actual detached magazine bounds for its wrist contact. The wrist reaches that contact during extraction and insertion, releases towards the authored pouch position during the swap, and returns to the support grip. The carried magazine is positioned from the solved wrist, after aim/arm processing. Completion, weapon changes and respawn clear handling state.

The subsequent native match revealed a separate movement fault: ally-separation normalization discarded the route's braking magnitude when input exceeded sqrt(.1). At four-times bot simulation speed this produced repeated oscillation 19.5 cm from a waypoint. Fighter now preserves input magnitude while changing heading. The regression fails before the fix and passes after it; all 40 actual route tests pass. Seed 803, two matches: the observed recovery count fell from 24 before to 1 in the source run after (one scenario, not a general performance claim).

Scope: ACR already has a separable magazine mesh. Other world weapons still need their own detachable magazines and service poses. This change does not improve mesh resolution or author new finger animations; carried-magazine orientation remains aligned to the weapon. Do not claim the whole animation/model target is achieved.

Verification: 295 checks across the existing eight suites, including 22 character-motion checks. New checks measure actual hand-to-magazine contact at extraction/insertion (<5 mm) and carry (<1 mm), visibility at the pouch, seating and respawn. Actual Vulkan/llvmpipe frames inspected: extract, carry, insert and seated. Dummy audio; no subjective audio or gaming-GPU performance assessment.

Raw logs and actual frames: `docs/verification/reload-contact/`.

Local builds: `build/service-linux/ASHLINE.x86_64`, `build/service-windows/ASHLINE.exe`. Linux runs here; Windows is cross-exported and not runtime-tested.

CI completed successfully: https://github.com/blacksteelman/Ashline/actions/runs/38158301046

- Windows: https://github.com/blacksteelman/Ashline/actions/runs/38158301046/artifacts/11709682715
- Linux: https://github.com/blacksteelman/Ashline/actions/runs/38158301046/artifacts/11709567809

Download/CRC/revision/payload hash verification of both published artifacts is in `docs/verification/reload-contact/ci-artifacts.json`.

To capture: start Xorg using `tests/xorg.conf`; use `VK_ICD_FILENAMES=/workspace/ashline/.runtime/vulkan/lvp.json`, then Godot with `--script tests/capture_character_motion.gd -- --tag=service-final --weapon=0 --service`. Last display `:158`; use `:159` next. Source captures use the actual Fighter, CharacterMotion, GripIK and world weapon in the live map, with time advanced deterministically. Export templates: `XDG_DATA_HOME=/workspace/ashline/.runtime/data`.

Next: create distinct movable magazines for other world weapons from their source bone weights; author their matching hand/finger poses. Review first-person forearm deformation and the ACR empty reload (currently the fast clip, without a dedicated charging action). Preserve the restored Claude sound recordings and processing. Continue from `WEAPON_ACTIONS_HANDOFF.md` for first-person clock/ADS details.

World magazine audit: AK has one combined surface; sniper has Rifle/Other; SMG combines its magazine with the main surface. Split by source skin weights when rebaking; material-name splitting alone cannot support these safely. Raw bounds recorded in world-magazine-surfaces.log.

Final native Linux build: seed 803, two matches completed, 959 shots, 31 headshots, 1 recoveries. Both final ZIPs passed CRC and payload SHA-256 checks; an extracted Linux executable booted.

A second actual graphical pass sampled 21 normalized reload phases at 640x360, inspected in sequence-contact-sheet.jpg. Probe source is archived as capture_reload_sequence.gd.txt; copy to build/ to execute. This verifies poses and continuity at sampled phases, not subjective animation quality at full-speed human play.
