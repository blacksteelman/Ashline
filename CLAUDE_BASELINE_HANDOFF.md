# Claude reference restored for comparison

User rejected the cumulative polish: graphics, sound, animation and models remain
poor, and explicitly prefers Claude's original sound and overall feel. Passing
automated checks is not evidence of pleasant gunfeel or good visual/audio quality.

Reference worktree: `/workspace/ashline-claude-baseline`.
Branch: `codex/claude-baseline`, based exactly on Claude game commit
`3fbdbf8a4948e3638b87c6cb2a407e6e4e790aae` (Weapon sounds and gunfire FX rebuilt).
Remote Claude branch was checked and still points to this commit. No game code,
model, clip, sound, shader or map changes have been applied to this reference.
Only this handoff and verification evidence were added.

Existing successful original CI: https://github.com/blacksteelman/Ashline/actions/runs/38046985616
Windows: https://github.com/blacksteelman/Ashline/actions/runs/38046985616/artifacts/11668940063
Linux: https://github.com/blacksteelman/Ashline/actions/runs/38046985616/artifacts/11668261518
Both exact original ZIPs were downloaded and fully CRC checked. Hashes/file lists
are in docs/verification/claude-reference. Local files are
`build/claude-original/windows.zip` and `build/claude-original/linux.zip`.

Downloaded Linux executable was actually run: native showcase screenshot rendered,
viewed, exit 0; TDM seed 801 completed 34:40, 487 shots, 20 headshots, no runtime
errors. It had 13 bot stuck recoveries, so do not promote a wholesale rollback
as a fix for all gameplay. Prefer the original sound and feel per user feedback,
while retaining separately proven navigation/gameplay fixes when integrating.
Rendering was Forward+ balanced, 1280x720, llvmpipe. Dummy audio: no listening
comparison was possible. Windows ZIP verified but Windows executable not run.

The prior implementation remains intact in `/workspace/ashline-polish`, branch
`codex/weapon-polish`, last completed commit dd7fed2. Its character/viewmodel model
files and authored animation clips are unchanged relative to Claude, but imported
materials, framing, procedural recoil/inertia, lighting and world dressing changed.
Its audio change added mono close/far blending and altered bus routing; this can
change the sound materially despite technically passing the audio regression.

An unfinished street-lighting/material investigation is safely stashed in the
shared repository, stash commit `a8f221120ae9b1f3221c9a2b24a3631667713cd8`, message
`Paused street art investigation before Claude comparison`. It is not applied
in either runnable worktree. That draft calls an unimplemented architecture
function: do not blindly apply it to a playable branch. The completed projects
remain runnable. Its earlier camera probe captures are ignored build output in
the polish worktree, not evidence of a completed street improvement.

Next work: compare against this exact reference, restore preferred audio/weapon
presentation selectively, preserve navigation/collision fixes separately, then
address models/animation/lighting with visibly substantial changes. Small HUD
adjustments, source counts and regression totals are not substitutes for quality.
