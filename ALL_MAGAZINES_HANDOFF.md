Latest continuation: [HAND_ALIGNMENT_HANDOFF.md](HAND_ALIGNMENT_HANDOFF.md).

# All weapon magazines and interrupted reloads — 2026-10-12

Branch `codex/weapon-polish`; gameplay/build revision `5658ac2c493ba00c6f92b25aac1d88741f6cb664`.

## Implemented

- Rebuilt AK, sniper, pistol and SMG world meshes from their licensed source first-person rigs. Triangles are classified using the actual `Pmag_*` / `Mag_*` skin bindings, not guessed cuts or material names. Parked spare magazines stay excluded. The bake stores detachable surface IDs and the source triangle count.
- All five weapons now have a separate magazine node using the existing reload hand-contact system. Geometry and materials are retained: original/new triangle counts match for each rebaked model; maximum bounds difference from the prior idle bake is 0.23 mm. Baking now samples a fixed idle pose using manual animation evaluation.
- Art caches immutable receiver/magazine meshes; per-fighter transforms and visibility stay independent. Reloading one instance cannot detach another fighter's magazine.
- If death interrupts carrying a magazine, the dropped weapon and magazine become separate rigid bodies. A seated magazine remains in the receiver. Loose magazine physics is removed with the corpse on respawn.
- First-person source meshes, textures, animations and Claude audio recordings/processing were not altered by this iteration.

## Verified

363 checks: functional 49, FP motion 23, anchors 46, actions 60, audio 38, character motion 78, routes 40, ragdoll 29. New assertions cover actual magazine geometry, triangle preservation, contact for all five weapons, shared-mesh instance isolation, interrupted reload death and respawn cleanup.

Actual graphical inspection: eight in-map frames (carry/seat for AK, sniper, pistol, SMG) plus a physical interrupted-reload death frame. Vulkan llvmpipe, Dummy audio. Source probes: `tests/capture_magazine_service.gd`, `tests/capture_reload_death.gd`. Last display `:162`; use `:163` next.

Final Linux executable: two native bot matches, seed 804, 949 shots, 35 headshots, zero stuck recoveries; successful completion. Native dedicated server/client: 120 snapshots, 30 predicted shots, acknowledged 30, pending 0.

Local packages: `build/packages/ASHLINE-Linux-5658ac2.zip`, `build/packages/ASHLINE-Windows-5658ac2.zip`. Both CRC/payload hashes checked; extracted Linux executable booted. Windows was cross-exported and its executable format checked, not launched on Windows.

CI: https://github.com/blacksteelman/Ashline/actions/runs/38205497493 passed regression checks, both exports and the native bot match, but failed artifact upload because GitHub Actions artifact storage quota was full. No new downloadable artifacts were produced by that run.

Delivery fix: manual workflow dispatch now packages both native exports and publishes a development GitHub Release using the Actions token. Uploaded sizes and SHA-256 digests are verified before the draft becomes public to repository readers; published binaries are never overwritten on retries. Manual builds skip Actions artifact storage. Release build revision `44a9226300a74ee2ac0536b83a84335c6cc897e5` contains the same gameplay as `5658ac2`, plus delivery tooling/documentation. Verification run: https://github.com/blacksteelman/Ashline/actions/runs/38229469101 — gameplay checks, exports and native bot match passed. ZIP upload succeeded, but final verification failed because the original helper addressed the draft through the tag endpoint (404). The helper now locates drafts by release ID through the releases list, with pagination compatible with older gh versions. The same uploaded archives were downloaded locally, their SHA-256/CRC and every manifest payload hash verified, then the release was published using the authenticated CLI. The downloaded Linux executable passed a version boot check. The helper's published-release retry path passed; a new full manual CI run after the draft lookup fix has not been performed.

Download: https://github.com/blacksteelman/Ashline/releases/tag/dev-44a9226 . Windows ZIP 490,398,844 bytes; Linux ZIP 480,226,221 bytes. Repository is private, so readers must sign in with repository access. Evidence: `release-download.json`, `published-release.json`, `release-launch.txt`. Empty draft `dev-5658ac2` was removed after successful replacement. Do not report the CI run as fully green: its final publication step failed and was completed with the verified recovery described above.

Evidence: `docs/verification/all-magazines/`. These are actual game renders and raw test/export/packaging results. Cosmetic ragdolls are disabled in native headless bot matches; their physics is covered separately by the ragdoll suite and graphical capture.

## Continue

The reload still uses generic upper-body timing and existing finger poses; these improvements do not establish COD4-level overall asset/animation quality. The sniper's conspicuous blue muzzle accessory and improvised styling remain a visible art problem. Next priorities: dedicated weapon-specific hand/finger orientation, first-person forearm deformation, a true ACR empty-reload charging action, and coherent military weapon finishes/models. Keep the preferred Claude sounds.

Rebake using Godot 4.6.3 with a graphical display: `--script tests/bake_world_weapons.gd -- --weapons=1,2,3,4`. Backups of pre-split meshes are under `build/magazine-backup/`; geometry preservation log compares against them. Original external-asset attribution remains in `LICENSES.md`.

Disk usage reached the workspace limit while archiving verification. Removed superseded downloaded/extracted build copies (`ci-actions`, `ci-reload`, `package-launch-check`, `service-unpack`) and old local ZIPs for 35dd113/8de2f06; their published GitHub artifacts and committed evidence remain. Keep current build outputs, source assets and export templates. Generated untracked UIDs and bot reports that predated this turn were left untouched.
