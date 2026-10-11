# Playable interior art continuation

Worktree `/workspace/ashline-polish`, branch `codex/weapon-polish`.
Game commit: `476fcd817c65387719421cdebba36deed89a38d0`.
Prior work: GRAPHICS_HANDOFF.md, FOUNDRY_HANDOFF.md, MOTION_HANDOFF.md.

## Implemented

Six new CC0 Poly Haven props are processed and shipped as kit GLBs:
worn_chair, worn_bookshelf, cassette_player, bench_vice, worn_sofa, coffee_table.
LICENSES.md links each original resource. SOURCES_POLYHAVEN.json records authors,
downloaded-file SHA-256 hashes and licenses. Raw sources remain re-downloadable
through tools/fetch_polyhaven.py; tools/build_kit.py processes each listed prop.
These are real textured meshes, not procedural furniture boxes. Runtime chair
scale .80 brings its original 1.26 m back height to a normal 1.01 m.

Apartment: furnished first-floor sitting area with sofa/table, bookshelf on the
internal partition, chairs by existing desks, personal cassette player and stock
box. Initial bookshelf placement blocked a window: it was moved to the solid
partition after viewing the game. Windows and stair entrance remain accessible.

Market: stocked back wall, counter chair, cassette player, boxes and hardware;
lower painted wall bands, skirting and surface conduit break the repeated plaster.
Initial paint segments ended mid-wall: replaced with a continuous back-wall band.
Partition paint deliberately omits doorway spans. Original shop notices are shaded
Label3D lettering on matte physical panels, not screen-space UI.

Foundry: two detailed metal desk workbenches with textured vises and hardware,
tool cart, safety notice and extinguisher. North door remains clear. Wood/soft
furniture uses wood impact tags rather than the generic metal fallback.

Floor tile tint and wood tint were adjusted after actual screenshots showed
washed-out floors. New furniture has AABB collision/cover hulls from kit metadata.
Small bench-top items are visual details. Final navigation contains 7,534 points.
No new modes, weapons or expansion maps were added.

## Verification

188 local assertions passed without runtime errors: functional 49, motion 23,
anchors 46, spatial audio 34, actual Fighter routes 36. The existing route suite
now covers 18 paths, adding shop passage both ways, upstairs bookshelf/stair access,
chair/desk access, bench traversal both ways and sofa/table access both ways.
All 18 routes completed without stuck recovery. This does not prove every possible
combat/separation path is clear.

Both Linux and Windows exports completed without errors. Local Linux binary ran
two full 6v6 TDM matches (seed 824): 40:35, then 37:40, 999 total shots, 42 headshots.
Two isolated recoveries occurred at existing stair/alley locations, not the added
furniture; see native-tdm.json. The wider recovery issue is still unfinished.

Five final source views were rendered and viewed at 1280x720, Forward+ preset 1
on software Vulkan llvmpipe with Dummy audio. No listening test or gaming GPU
performance measurement; Windows exported but not executed here. Before/after
views 0..2 use identical poses; views 3..4 are additional final-only inspection.
Raw images and logs are in docs/verification/interiors-polish.

Source capture: `godot --path . --script tests/capture_interiors.gd -- --tag=next
--graphics=1`. Optional `--view=4` captures only the sitting area. It requires a
working X display. Use tests/xorg.conf for software Vulkan captures. Native player
can load the same external capture script via `--script /absolute/path/to/script`;
game scenes/models still load from the embedded PCK. It is a QA aid, not a shipped
dependency. Capture paths resolve relative to the native executable's resource root.

Local builds: build/interior-native/ASHLINE.x86_64 and
build/interior-native/windows/ASHLINE.exe. Launch normally to reach Play/menu.
Local export templates: XDG_DATA_HOME=/workspace/ashline/.runtime/data.
Run bot smoke with `--headless --audio-driver Dummy -- --bot-test --seed=825
--matches=1`. Check logs for ERROR/SCRIPT ERROR even when exit status is zero.

## Vehicle research / remaining work

No new car model is shipped. Sketchfab's CC-BY game-ready Destroyed Car 03 by
kryik1023 (efc4dfe2c7284a64bc9281eb4f61d402) is a candidate, but official downloads
require a Sketchfab token unavailable in this environment. No auth bypass was used.
The OpenGameArt CC0 generic car by creomoto was downloaded for evaluation; its
preview was too crude for this target and the source was removed, not integrated.
Poly Haven's currently available vehicle kit only offers covered_car.

Next priorities: detailed licensed vehicles, richer room-specific clutter/damage,
first-person sleeve/metal highlights, character animation review, HUD contrast,
and the known bot recovery corners. The requested COD4/modern quality bar has
not been reached; do not describe this as finished AAA art.

CI run 38120763305 will be recorded after clean-import export verification.
