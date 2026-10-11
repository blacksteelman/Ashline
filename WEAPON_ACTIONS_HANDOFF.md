# Weapon actions and PC packages — 2026-10-11

Working tree `/workspace/ashline-polish`, branch `codex/weapon-polish`.
Gameplay/packaging commit `35dd113017d735a9748d130932cf956c98ae6f24`.
Previous ragdoll work remains intact; see `RAGDOLL_COMBAT_HANDOFF.md`.

## Actual changes

- AnimationPlayer is advanced explicitly by FPSetRig before camera/sight/muzzle bone queries. Reload seeks to the gameplay timer exactly while animation blends still advance.
- Each shot restarts its actual imported firing clip. Previously replaying the same AnimationPlayer clip resumed its existing position; the pre-change regression has 13 failing checks across five weapons.
- ADS remembers the pre-shot sight alignment instead of canceling authored weapon recoil each frame. Large source recoil (pistol ~17.7 degrees) is bounded to four degrees for visual readability. Camera/gameplay recoil values remain as before.
- Draw clips complete in 0.28 seconds rather than their native ~0.57–0.65 seconds. Sprint can interrupt non-bolt firing recovery; the bolt rifle preserves its mechanical cycle.
- Magazine-out/in sounds use per-weapon measured magazine-track timings. Original Claude recordings, gains, buses and processing remain intact. `tools/measure_reload_cues.gd` reproduces the measurements.
- Newly restarted first-person pose is evaluated before locating muzzle flash and shell ejection.
- `tools/package_builds.py` checks native file types, copies launch instructions, records revision/file hashes, creates ZIPs and verifies CRC. CI also includes this metadata/instructions in its existing platform artifacts.

## Built and checked

Local exported executables:

- `build/actions-windows/ASHLINE.exe` (~483 MiB), Windows x86-64 PE checked; no Windows runtime available here.
- `build/actions-native/ASHLINE.x86_64` (~451 MiB), actual native startup, graphical capture and matches checked.

Ready local ZIPs:

- `build/packages/ASHLINE-Windows-35dd113.zip` — 387,407,292 bytes.
- `build/packages/ASHLINE-Linux-35dd113.zip` — 377,233,223 bytes.
- `build/packages/SHA256SUMS.txt` — archive SHA-256 values.

Both archives passed CRC and every packaged file matches BUILD_INFO.json. Linux executable was extracted from the archive and started with `--headless --version`. No claim that these local paths automatically download on the user's machine.

290 passing checks: functional 49, FP motion 23, anchors 46, actions 60, audio 38, character motion 18, routes 39, ragdoll 17. The new actions suite covers clip restart/clock, normal and empty reloads, cue ordering, bounded ADS motion, draw and sprint transitions.

Actual native bot matches (seed 802): 36:40 and 40:33, 1,096 shots, 38 headshots, 9 route recoveries. Native dedicated-server/client check: 125 snapshots, 30 predicted shots, acknowledged 30, pending 0.

Actual renders inspected: ACR/pistol reload phases, ADS shots/recovery and exported Linux native frame. Software Vulkan llvmpipe, Dummy audio. No listening or gaming-GPU performance claim.

Raw evidence: `docs/verification/weapon-actions/`. The initial all-idle `before-*` probe was invalid because its manual AnimationPlayer blend had not advanced; it is not included as proof. Corrected `baseline-*` poses are retained. Equal normalized reload poses are expected to look similar: this iteration fixes clock/contact synchronization, not imported mesh geometry.

New CI run: https://github.com/blacksteelman/Ashline/actions/runs/38132781333
At initial handoff: importing assets. Fetch final artifact IDs after successful completion and link this exact revision, not the previous ragdoll build.

## Next work

- Improve actual authored poses, wrists/fingers and forearm deformation, plus generic third-person reloads. Imported ACR has only a fast reload clip; empty reload still reuses it, without an independently authored charging action.
- Inspect all weapons through live movement/ADS/reload/crouch and actual human input. Automation does not establish subjective gunfeel.
- Graphics/model/map quality remains below the user's requested COD4 target. This update does not replace meshes or rebuild environments.
- Keep restored Claude sound recordings/processing. Dummy audio cannot establish subjective sound quality.

## Reproduce packaging

```bash
python tools/package_builds.py --linux-dir build/actions-native --windows-dir build/actions-windows --revision 35dd113017d735a9748d130932cf956c98ae6f24
```

Use Godot 4.6.3; export templates require `XDG_DATA_HOME=/workspace/ashline/.runtime/data`. All eight suites appear in `.github/workflows/build.yml`. Source graphical probes: `tests/capture_reload_cycle.gd` and `tests/capture_ads_actions.gd`. Last X display used `:154`; allocate `:155` next. Keep `build/.gdignore` and `docs/.gdignore`. Source probes use scripts; native binaries use `--showcase --capture=1 --capture-path=...`.

Native server stdout is buffered when redirected. Wrap it with `stdbuf -oL -eL` if a harness waits for SERVER_READY; otherwise a live server can incorrectly appear not ready.
