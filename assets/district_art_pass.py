"""Reproducible conversion of selected CC0 industrial models for the west workshop."""
import bpy
from pathlib import Path
P=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(P/'thirdparty/industrial/industrial_selected.blend'))
# One library shares materials/textures across all six authored placements.
# Cap source image dimensions for the compact native alpha.
used={m for o in bpy.data.objects if o.type=='MESH' for m in o.data.materials if m}
images={n.image for m in used for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image}
for image in images:
 w,h=image.size
 if max(w,h)>1024:image.scale(round(w*1024/max(w,h)),round(h*1024/max(w,h)))
bpy.ops.export_scene.gltf(filepath=str(P/'district_props.glb'),export_format='GLB',export_apply=True)
print('Selected industrial library exported')
