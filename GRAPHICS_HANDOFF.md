# District art continuation

Worktree `/workspace/ashline-polish`, branch `codex/weapon-polish`.
Gameplay/art commits `e8fe145`, `f5f2a58`, `f00868f`; previous work in
FOUNDRY_HANDOFF.md and MOTION_HANDOFF.md. Original worktree untouched.

## Changes

The Poly Haven CC0 facade plaster now uses a dedicated shader preserving its
texture/normal detail while reducing the baked orange hue. Four muted district
palettes are cached by mesh and palette; facade MultiMesh cell culling is retained.
Ground damp and restrained vertical streaking supplement the original chips.
Window, brick and trim materials are preserved. This is an art pass, not a claim
of COD4/MW2019 quality.

Original signs distinguish Rowan Supplies, Keln House and Vorda Metalworks.
Facade services include AC units, gutters, fixtures, a raised fire escape and a
delivery canopy. Roof ducts/chimneys break the repeated skyline. Foundry eaves
and external frame members articulate its large blank walls. Existing licensed
kit models are reused; no new third-party assets or licenses were introduced.

Street spans have sagged cables, building edges have shallow masonry fragments,
and road markings use chipped alpha-tested paint. Five irregular asphalt repairs
use the existing ambientCG PBR set. Foundry painted steel is desaturated and
darkened. Background facade texture scale doubled: the atlas covers six storeys,
so its previous nine-metre repeat made the windows implausibly small.

Decorative placement uses a separate seeded RandomNumberGenerator. These additions
have no new collision bodies; the previous navigation graph remains 7,553 points.
Avoid consuming the global layout random stream in decorative helpers.

## Export repair

The initial native smoke run exposed exclusions for newly used assets. Removed
duct_fan, duct_square, fire_escape and their texture exclusions, plus asphalt_patch
texture exclusions, from BOTH presets. An editor scene can look correct while
an export is missing these resources. Check native logs for ERROR/SCRIPT ERROR,
not only exit status: the initial incomplete build finished a match with errors.
The final local native run has no such errors.

## Verification / reproduction

All 172 assertions passed on final source: functional 49, motion 23, anchors 46,
audio 34, routes 20. Both Linux/Windows exports succeeded without errors. Local
Linux seed 822 completed one 6v6 TDM 33:40, 489 shots, 20 headshots, zero route
recoveries. One sample is not map balance certification.

`docs/verification/district-polish` contains raw viewed before/after images at
the same three poses, regression logs, native bot report and image hashes.
Captured through the actual game at 1280x720, Forward+ balanced preset 1,
software Vulkan llvmpipe. Dummy audio, no listening test. Windows was exported,
not run. Gaming GPU frame times have not been measured.

Capture source with `tests/capture_look.gd -- --tag=next --graphics=1` under a
working X display (tests/xorg.conf). It waits 12 frames per pose; balanced preset
uses neither temporal AA nor auto exposure. It writes build/screenshots-v8.
Native executable supports `-- --showcase --capture=1 --graphics=1
--capture-path=/absolute/path.png`. Review real images before declaring art done.

Local builds: build/district-native/ASHLINE.x86_64 and
build/district-native/windows/ASHLINE.exe. Launch normally for the menu; native
smoke: `build/district-native/ASHLINE.x86_64 --headless --audio-driver Dummy --
--bot-test --seed=823 --matches=1`.
Export templates locally require XDG_DATA_HOME=/workspace/ashline/.runtime/data.

## Next art priorities

1. Replace some covered-car repetitions with licensed detailed abandoned vehicles,
   preserving combat cover size and checking model bounds/collision alignment.
   A Poly Haven API catalogue request returned HTTPError in this turn; do not claim
   any new car models were downloaded. Existing fetch/build tools are available.
2. Distinguish room functions with believable interior dressing and authored damage.
   Current interiors and wide crossing still look sparse; preserve sight lines.
3. Review characters, sleeve highlights and third-person animation in close combat.
4. Improve HUD text contrast/typography independently; do not hide art with bloom.
5. Measure on a real GPU and listen to native audio when that environment is available.

The final local Linux executable was also rendered and viewed (native-linux.png).
Native render exited zero with no errors. CI build/evidence details will be appended
after its final verification.
