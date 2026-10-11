# Foundry map, bot navigation and lighting continuation

Latest district graphics pass: see GRAPHICS_HANDOFF.md.

Worktree: `/workspace/ashline-polish`, branch `codex/weapon-polish`.
Game commits: `1e5d593` and `bf4eebc`. Original worktree and master untouched.
Prior weapon/audio work is described in MOTION_HANDOFF.md.

## Implemented

Navigation samples the full standing fighter hull (1.8 m tall, .32 m radius
including 2 cm clearance), then sweeps that hull along links. Thin centreline
rays previously accepted routes through door jambs. The bot's waypoint arrival
radius is .18 m instead of .48 m, preventing early corner cuts. Floor profiles
respect the .24 m movement step and scale allowed ramp rise with link length.

When the closest navigation point cannot be approached from an actor's actual
position, route entry considers nearby reachable points that have a path to
the destination. This matters beside stairs after combat/separation movement.
If none works, the existing route-recovery fallback remains.

The foundry stair has an accessible bottom landing at z=13.2. The upper landing
remains at z=19. Its appearance is now open steel treads on two inclined stringers;
the former solid triangular stack is gone. Its smooth walking collider is a thin
sloped slab, allowing standing passage beneath the high end. Concrete stairs in
the other buildings retain their authored appearance and wedge colliders.

Outdoor exposure, sun intensity, contrast and saturation were reduced together;
sky ambient was adjusted per graphics preset. Three before/after views were
rendered and viewed, including the foundry interior. This reduces harsh highlights,
but is not a claim of finished art direction or COD4-quality presentation.

## Verification

172 local assertions passed with no runtime errors: 49 functional, 23 weapon
motion, 46 imported model anchors, 34 spatial audio and 20 foundry routes.
`tests/foundry_routes_regression.gd` moves the actual Fighter through ten routes:
door and crate crossings in both directions, stair ascent/descent, two side
approaches and under-stair crossings in both directions. All passed without
stuck recovery. The initial four-case baseline failed both door traversals.

Final source bot tests completed four 6v6 TDM matches:

- Seed 811: 34:40 then 40:31; 1,118 shots, 32 headshots, two recoveries.
- Seed 813: 40:33 then 40:32; 899 shots, 37 headshots, one recovery.

Neither final sample recorded an early spawn death. These are small samples,
not spawn/map balance certification. The previous seed-811 two-match sample had
13 recoveries, including repeated loops at the foundry doorway.

The locally exported Linux executable also completed Domination seed 815,
exit zero, 1:60, 953 shots, no route recoveries. That proves mode completion;
the strongly asymmetric result needs additional objective/balance investigation.

Evidence is in `docs/verification/foundry-polish`: raw viewed screenshots,
bot reports and verification.json with image hashes. Final source was rendered
at 1280x720 using Forward+ on llvmpipe. Dummy audio was used. No gaming GPU
performance, actual audio listening or Windows execution has been verified.

Repeat checks:

```sh
godot --headless --audio-driver Dummy --path . --script tests/foundry_routes_regression.gd
godot --headless --audio-driver Dummy --path . --script tests/functional.gd
godot --headless --audio-driver Dummy --path . -- --bot-test --seed=811 --matches=2
godot --path . --resolution 1280x720 --script tests/capture_foundry.gd -- --graphics=1
```

Graphical capture requires an X display. In this workspace use tests/xorg.conf,
the llvmpipe ICD at `/workspace/ashline/.runtime/vulkan/lvp.json`, and keep Xorg
and Godot under one parent process. Capture outputs go in build/verification.

## Next concrete work

Live ally avoidance can still push bots off an already-cleared route: final
recoveries were near (30.449,.181,13.995), (-6.473,.150,-25.683), and
(-19.999,.181,23.499). Inspect those cases with moving actors before changing
navigation further. Start-path projection alone does not prevent mid-route drift.

Art priorities remain repetitive facades, sparse street cover/dressing, strongly
saturated rusty structural steel, and the overbright sleeve. Continue the existing
licensed asset pipeline; do not revive the older procedural weapon generators.
Do not claim multiplayer/load or GPU performance based on these headless samples.

## Native builds

[Actions run 38114938570](https://github.com/blacksteelman/Ashline/actions/runs/38114938570)
succeeded for game commit `bf4eebc645d57db3da4d84d633f57ae9245c7835`.
All 172 assertions passed there. Its native Linux smoke match ended 40:30,
475 shots and 22 headshots.

- [Windows ZIP](https://github.com/blacksteelman/Ashline/actions/runs/38114938570/artifacts/11693357428)
- [Linux ZIP](https://github.com/blacksteelman/Ashline/actions/runs/38114938570/artifacts/11693372388)
- [Verification logs](https://github.com/blacksteelman/Ashline/actions/runs/38114938570/artifacts/11693467149)

Both ZIPs were fetched through the connected GitHub tool, downloaded into the
workspace and checked with a complete ZIP CRC pass. Hashes are in verification.json.
GitHub links require repository access because this is a private repository.
Windows: extract and run ASHLINE.exe. Linux: extract, `chmod +x ASHLINE.x86_64`,
then `./ASHLINE.x86_64`. Both platforms also exported locally without errors;
Windows runtime remains untested.

The executable extracted from the downloaded Linux ZIP was run locally:
TDM seed 814 completed at 40:29, 441 shots and 14 headshots, exit zero without
runtime errors. Its report is `downloaded-linux-tdm.json` beside the captures.
