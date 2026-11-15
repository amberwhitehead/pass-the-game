"""Blender helpers for palette-textured blocky characters. Run inside Blender (bpy).

Conventions: metres, Z up, origin at the feet, character FRONT faces -Y in Blender
(which becomes +Z in glTF/Godot, the way npc.gd expects).
Wearer's left is +X, wearer's right is -X.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # blends/
sys.path.insert(0, os.path.join(ROOT, "palette"))
import palette as pal  # noqa: E402


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.ranges = []   # (bone, tag, first_vert, last_vert+1, centre) for every part

    def part(self, cell, center, size, top=(1, 1), bottom=(1, 1), bevel=0.0,
             rot=(0, 0, 0), faces=None, mirror=False, bone=None, tag=None):
        """Add a (tapered) box. cell: palette name. size: (x, y, z) metres.
        top/bottom: (x, y) scale of the top / bottom face (taper). bevel: chamfer width.
        rot: degrees XYZ about the box centre. faces: {'front'|'back'|'top'|'bottom'|'left'|'right': cell}
        overrides a whole side (sides are in character terms; front = -Y).
        mirror=True also adds an X-mirrored copy (for limbs).
        bone: skeleton bone name; default is chosen from where the part sits (see auto_bone).
        tag: label so a shape key can move this part (e.g. 'mouth', 'eye')."""
        for sign in ((1, -1) if mirror else (1,)):
            self._part(cell, center, size, top, bottom, bevel, rot, faces, sign, bone, tag)

    def _part(self, cell, center, size, top, bottom, bevel, rot, faces, sign, bone, tag):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            s = top if v.co.z > 0 else bottom
            v.co = Vector((v.co.x * size[0] * s[0], v.co.y * size[1] * s[1], v.co.z * size[2]))
        if any(rot):
            e = Euler([math.radians(a) for a in rot], "XYZ")
            for v in bm.verts:
                v.co = e.to_matrix() @ v.co
        for v in bm.verts:
            v.co += Vector(center)
            if sign < 0:
                v.co.x = -v.co.x
        if sign < 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
        # classify sides before bevel (bevel adds faces, which inherit nothing useful)
        base = pal.idx(cell)
        for f in bm.faces:
            f.material_index = base
        if faces:
            names = {"front": (0, -1, 0), "back": (0, 1, 0), "top": (0, 0, 1),
                     "bottom": (0, 0, -1), "left": (1, 0, 0), "right": (-1, 0, 0)}
            for side, c in faces.items():
                n = Vector(names[side])
                if sign < 0 and side in ("left", "right"):
                    n.x = -n.x
                for f in bm.faces:
                    if f.normal.dot(n) > 0.9:
                        f.material_index = pal.idx(c)
        if bevel > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1,
                            affect="EDGES", clamp_overlap=True)
            for f in bm.faces:  # bevel faces: take colour of the neighbouring big face
                if f.material_index == 0 and base != 0:
                    f.material_index = base
        me = bpy.data.meshes.new("tmp")
        bm.to_mesh(me)
        bm.free()
        c = Vector((center[0] * sign, center[1], center[2]))
        first = len(self.bm.verts)
        self.bm.from_mesh(me)
        self.ranges.append((bone or auto_bone(c), tag, first, len(self.bm.verts), c))
        bpy.data.meshes.remove(me)

    def shape(self, name, **tag_fns):
        """Define a shape key. Each keyword is a tag -> fn(co, centre) returning the moved vertex."""
        self.shapes = getattr(self, "shapes", [])
        self.shapes.append((name, tag_fns))

    def finish(self, name, rig=False, joints=None):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            u, v = pal.cell_uv(f.material_index)
            for loop in f.loops:
                loop[uv].uv = (u, v)
            f.material_index = 0
            f.smooth = False
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("body" if rig else name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.data.materials.append(make_material())
        if rig:
            import rig as rigmod
            rigmod.attach(self, ob, joints)
        return ob


def auto_bone(c):
    """Convention for every character: pick a bone from a part's centre (metres, feet at z=0).
    Skeleton: torso, head, upper/lower_arm.L/R, upper/lower_leg.L/R, foot.L/R (L = +X)."""
    side = ".L" if c.x > 0 else ".R"
    ax = abs(c.x)
    if ax >= 0.2:
        return ("upper_arm" if c.z >= 1.18 else "lower_arm") + side
    if c.z >= 1.535:
        return "head"
    if ax >= 0.04 and c.z < 0.93:
        if c.z < 0.12:
            return "foot" + side
        return ("upper_leg" if c.z >= 0.49 else "lower_leg") + side
    return "torso"


def make_material():
    mat = bpy.data.materials.new("palette")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def img(fname, colorspace):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(os.path.join(ROOT, "palette", fname), check_existing=True)
        n.image.colorspace_settings.name = colorspace
        n.interpolation = "Closest"
        return n

    a = img("palette_albedo.png", "sRGB")
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    mr = img("palette_mr.png", "Non-Color")
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(mr.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    e = img("palette_emit.png", "sRGB")
    nt.links.new(e.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    return mat


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def mute_animation_tracks(ob):
    """Leave the saved .blend in rest pose: all NLA tracks muted (unmute/solo one to preview it)."""
    arm = ob.parent
    datablocks = [arm.animation_data] if arm and arm.animation_data else []
    if ob.data.shape_keys and ob.data.shape_keys.animation_data:
        datablocks.append(ob.data.shape_keys.animation_data)
    for ad in datablocks:
        for t in ad.nla_tracks:
            t.mute = True
    if arm:  # the exporter leaves its last sampled frame on the bones: clear it
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
    if ob.data.shape_keys:
        for kb in ob.data.shape_keys.key_blocks:
            kb.value = 0.0


def export(ob, blend_path, glb_path):
    os.makedirs(os.path.dirname(glb_path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    rigged = ob.parent is not None and ob.parent.type == "ARMATURE"
    if rigged:
        ob.parent.select_set(True)
    extra = dict(export_animations=True, export_animation_mode="NLA_TRACKS", export_morph=True,
                 export_skins=True, export_apply=False) if rigged else dict(export_apply=True)
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", use_selection=True,
                              export_yup=True, export_image_format="AUTO",
                              export_cameras=False, export_lights=False, **extra)
    if rigged:
        mute_animation_tracks(ob)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, relative_remap=True)
    print(f"exported {glb_path}  tris={tri_count(ob)}")
