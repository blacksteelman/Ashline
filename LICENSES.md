Game code, generated models, map layout, sky shader and the remaining generated textures/audio were created for this project. No assets from Call of Duty or other commercial games are included.

Godot engine is distributed under MIT: https://godotengine.org/license/
DejaVu Sans and DejaVu Sans Mono fonts: DejaVu/Bitstream Vera license; see FONT-LICENSE.txt.

Third-party CC0 resources added in 0.4:

- ambientCG / Lennart Demes: Bricks097, Asphalt023S, Concrete034, Plaster007, Metal055A (color, OpenGL normal, roughness and AO maps). https://docs.ambientcg.com/license/
- The Free Firearm Sound Library: Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney. https://opengameart.org/content/the-free-firearm-sound-library

License: CC0 1.0 Universal, https://creativecommons.org/publicdomain/zero/1.0/
Pinned files, source links, hashes, source mirror commit and modifications are recorded in assets/thirdparty/SOURCES.json. Local vendor inputs are included for offline rebuilding.

The 0.5 biped skeleton, skin weights, keyframed clips, material derivations and character presentation code were authored specifically for ASHLINE. (0.8 replaces these characters; see below.)

Third-party CC0 models added in 0.7:

- nisu / 3DModelsCC0: M4A1 rifle geometry and PBR maps, adapted for AR-41. https://opengameart.org/content/m4a1-assault-rifle
- para / MakeHuman team: rigged FPS arm mesh. https://opengameart.org/content/fps-arms-rigged-only
- rubberduck, PBR adaptation by a52: Industrial Asset Pack; six equipment/pipe/vent/chimney meshes and associated PBR maps. https://opengameart.org/content/pbr-industrial-asset-pack

All three source pages explicitly designate the assets CC0. Weapon geometry and arm mesh in 0.7 derive from these licensed models; the earlier blanket description of generated models does not apply to them. No Call of Duty models, textures, maps, animations or recordings are used. The arm reload animation, material modifications, placement and integration code are authored for ASHLINE.

Third-party resources added in 0.8 (see tools/fetch_polyhaven.py, tools/fetch_ambientcg.py, tools/build_soldiers.py for the exact asset lists):

- Poly Haven (CC0, https://polyhaven.com/license): HDRI kloofendal_38d_partly_cloudy_puresky; urban/industrial props and the modular facade set listed in tools/fetch_polyhaven.py; Mosin-Nagant rifle and service pistol models used for the sniper rifle and P38 viewmodels.
- ambientCG / Lennart Demes (CC0): the PBR material sets listed in tools/fetch_ambientcg.py.
- MakeHuman / MPFB2 (CC0 base mesh, skins and cmu_mb rig): soldier bodies. https://static.makehumancommunity.org/
- MakeHuman community clothing assets:
  - elvs_male_shirt_untucked_bd1 by Elvaerwyn — CC BY (shirt, recoloured with project camouflage)
  - mindfront_tactical_vest_male and mindfront_helmet_kz45 by Mindfront (Sweden) — CC BY 4.0 (plate carrier, helmet; recoloured, decimated)
  - mrgreaterthan_m1_helmet by MrGreaterThan — CC0
  - gredal_gas_mask — CC0
  - cortu_cargo_pants by Cortu — CC0
  - toigo_ankle_boots_male, toigo_gloves_short by MRT (MargaretToigo) — CC0
  CC BY licence text: https://creativecommons.org/licenses/by/4.0/
- Motion capture: CMU Graphics Lab Motion Capture Database (http://mocap.cs.cmu.edu), BVH conversion by Bruce Hahne (cgspeed). The database is free for use, including commercial products. Clips 09_06, 16_46, 143_32, 143_39 are retargeted in tools/build_soldiers.py; the upper body, idle, crouch, jump, reload and death motions are authored procedurally for ASHLINE.
- Camouflage patterns (tools/camo.py) are generated procedurally for ASHLINE; no third-party camouflage artwork is copied.
