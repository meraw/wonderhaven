"""Shared helpers for Wonderhaven's Blender model scripts.

Run a model script inside Blender, headless:
    blender -b --factory-startup -P tools/blender/langhe_lane.py -- --out godot/assets/models/lab [--blend <dir>]
--blend also saves each model's .blend file (not kept in the repository: the scripts are the source).

Conventions the game relies on (see scripts/world/model_kit.gd and docs/MODELS.md):
  - metres, Blender Z up (glTF export turns it into Godot's Y up); a model's origin is the middle of its footprint
    on the ground, and its front faces Blender -Y, which becomes Godot +Z;
  - materials are named wh_<kind>_<rrggbb> (kind: plaster, stone, brick, wood, roof, iron, glass, metal, paint,
    leaf, flower): the game swaps each for its own material of that kind and colour, so a model shares the
    village's look, wind, rain and snow;
  - the colour attribute "Col" (exported as COLOR_0) multiplies that colour: baked ambient occlusion, per-piece
    colour variation, damp at the foot of the walls.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector, noise
from mathutils.bvhtree import BVHTree


# ---- Command line and scene ---------------------------------------------------------------------------------------
def args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out, i = {}, 0
    while i < len(argv):
        if argv[i].startswith("--"):
            key = argv[i][2:]
            if i + 1 < len(argv) and not argv[i + 1].startswith("--"):
                out[key] = argv[i + 1]; i += 2
            else:
                out[key] = "1"; i += 1
        else:
            i += 1
    return out


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def material(kind: str, hexcol: str) -> bpy.types.Material:
    """The wh_<kind>_<hex> material: base colour times the "Col" attribute (so Blender shows what the game shows)."""
    name = f"wh_{kind}_{hexcol.lstrip('#').lower()}"
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    r, g, b = (srgb_to_linear(c) for c in hex_rgb(hexcol))
    rgb = nt.nodes.new("ShaderNodeRGB"); rgb.outputs[0].default_value = (r, g, b, 1.0)
    attr = nt.nodes.new("ShaderNodeVertexColor"); attr.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(rgb.outputs[0], mix.inputs["A"]); nt.links.new(attr.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0 if kind not in ("glass", "metal") else 0.35
    return m


# ---- A mesh built from pieces -------------------------------------------------------------------------------------
class Builder:
    """Collects pieces (boxes, cylinders, prisms, tiles) into one bmesh. Every piece gets its own id, so it can carry
    its own colour variation (a tint) through bevels and joins."""

    def __init__(self, name: str, seed: int = 1):
        self.name = name
        self.bm = bmesh.new()
        self.elem = self.bm.faces.layers.int.new("elem")
        self.mats: list = []
        self.tints: dict = {0: (1.0, 1.0, 1.0)}
        self.kinds: dict = {}
        self.rng = random.Random(seed)
        self.next_id = 1

    def _mat_index(self, kind: str, hexcol: str) -> int:
        m = material(kind, hexcol)
        if m not in self.mats:
            self.mats.append(m)
        self.kinds[self.mats.index(m)] = kind
        return self.mats.index(m)

    def _claim(self, faces, kind: str, hexcol: str, tint, smooth: bool = False) -> int:
        idx = self._mat_index(kind, hexcol)
        eid = self.next_id; self.next_id += 1
        self.tints[eid] = tint if tint is not None else (1.0, 1.0, 1.0)
        for f in faces:
            f.material_index = idx
            f[self.elem] = eid
            f.smooth = smooth
        return eid

    def mark(self):
        """How many vertices there are now: pass it to turn() to move what was built since."""
        self.bm.verts.ensure_lookup_table()
        return len(self.bm.verts)

    def turn(self, since: int, angle: float):
        """Turns everything built since mark() about the vertical axis through the origin."""
        self.bm.verts.ensure_lookup_table()
        rot = Matrix.Rotation(angle, 3, "Z")
        for v in self.bm.verts[since:]:
            v.co = rot @ v.co

    def vary(self, amount: float = 0.06, warm: float = 0.0) -> tuple:
        """A random tint around white: value +-amount, a little warmer or cooler by `warm`."""
        v = 1.0 + self.rng.uniform(-amount, amount)
        w = self.rng.uniform(-warm, warm)
        return (v * (1 + w), v, v * (1 - w))

    def box(self, center, size, kind: str, hexcol: str, rot=(0, 0, 0), tint=None, dice: float = 0.0):
        """A box `size` (x, y, z) centred on `center`, turned by Euler `rot` (radians). `dice`: cut its faces into a grid
        no coarser than that many metres, for walls that bake ambient occlusion and lean a little."""
        mat = Matrix.Translation(Vector(center)) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1.0))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mat)
        if dice <= 0:
            return self._claim({f for v in res["verts"] for f in v.link_faces}, kind, hexcol, tint)
        # Diced: every face not yet claimed by a piece belongs to this box (each piece claims its faces at once).
        rmat = Euler(rot).to_matrix()
        for axis, length in zip((Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))), size):
            cuts = max(0, math.ceil(length / dice) - 1)
            if cuts == 0:
                continue
            ax = rmat @ axis
            mine = [f for f in self.bm.faces if f[self.elem] == 0]
            edges = {e for f in mine for e in f.edges
                     if abs((e.verts[1].co - e.verts[0].co).normalized().dot(ax)) > 0.99}
            bmesh.ops.subdivide_edges(self.bm, edges=list(edges), cuts=cuts, use_grid_fill=True)
        return self._claim([f for f in self.bm.faces if f[self.elem] == 0], kind, hexcol, tint)

    def cylinder(self, center, radius, depth, kind, hexcol, rot=(0, 0, 0), segments=10, radius2=None, tint=None):
        """A cylinder (or cone, with radius2) along its local Z."""
        mat = Matrix.Translation(Vector(center)) @ Euler(rot).to_matrix().to_4x4()
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                                    radius2=radius if radius2 is None else radius2, depth=depth, matrix=mat)
        faces = {f for v in res["verts"] for f in v.link_faces}
        eid = self._claim(faces, kind, hexcol, tint)
        for f in faces:                      # round sides, flat caps
            f.smooth = len(f.verts) == 4
        return eid

    def blob(self, center, radius, kind, hexcol, squash=1.0, jitter=0.25, tint=None, subdiv=1):
        """A lumpy ball: leaves, flowers, a bush."""
        mat = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((radius, radius, radius * squash, 1.0))
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0, matrix=mat)
        for v in res["verts"]:
            off = (v.co - Vector(center))
            v.co += off * self.rng.uniform(-jitter, jitter)
        faces = {f for v in res["verts"] for f in v.link_faces}
        return self._claim(faces, kind, hexcol, tint, smooth=True)

    def prism(self, profile, x0, x1, kind, hexcol, tint=None):
        """A prism along X from x0 to x1 with a convex (y, z) `profile`, e.g. a gable's triangle."""
        a = [self.bm.verts.new((x0, y, z)) for y, z in profile]
        b = [self.bm.verts.new((x1, y, z)) for y, z in profile]
        faces = [self.bm.faces.new(list(reversed(a))), self.bm.faces.new(b)]
        n = len(profile)
        for i in range(n):
            j = (i + 1) % n
            faces.append(self.bm.faces.new((a[i], a[j], b[j], b[i])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return self._claim(faces, kind, hexcol, tint)

    def tile(self, frame: Matrix, width, length, kind, hexcol, convex: bool, taper=0.12, segments=4, tint=None):
        """One curved roof tile (a coppo) in `frame`: local X across the roof, Y down the slope, Z out of it. Caps arch
        up (convex), pans dip down; a lip at the lower end gives it thickness."""
        verts_rows = []
        for yi, y in enumerate((0.0, length)):
            r = width / 2.0 * (1.0 + (taper if yi == 1 else 0.0))
            row = []
            for s in range(segments + 1):
                a = math.pi * s / segments
                x = -math.cos(a) * r
                z = math.sin(a) * r * (0.8 if convex else -0.55) + (0.0 if convex else r * 0.55)
                row.append(self.bm.verts.new(frame @ Vector((x, y, z))))
            verts_rows.append(row)
        faces = []
        top, bot = verts_rows
        for s in range(segments):
            faces.append(self.bm.faces.new((top[s], bot[s], bot[s + 1], top[s + 1])))
        lip = [self.bm.verts.new(v.co - (frame.to_3x3() @ Vector((0, 0, 0.035)))) for v in bot]
        for s in range(segments):
            faces.append(self.bm.faces.new((bot[s], lip[s], lip[s + 1], bot[s + 1])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        if convex is False:   # recalc can flip an open strip: keep the pan's top facing out of the roof
            n = frame.to_3x3() @ Vector((0, 0, 1))
            for f in faces[:segments]:
                f.normal_update()
                if f.normal.dot(n) < 0:
                    f.normal_flip()
        eid = self._claim(faces, kind, hexcol, tint)
        for f in faces[:segments]:           # the curved top is smooth; the lip stays a crisp edge
            f.smooth = True
        return eid

    def lean(self, amount: float, center=(0, 0, 0), seed: int = 0):
        """Hand-built walls are never quite true: shift vertices sideways by a little, more the higher they are."""
        rng = random.Random(seed)
        lx, ly = rng.uniform(-amount, amount), rng.uniform(-amount, amount)
        for v in self.bm.verts:
            h = max(0.0, v.co.z)
            v.co.x += lx * h / 5.0 + noise.noise(v.co * 0.7) * amount * 0.3
            v.co.y += ly * h / 5.0

    def finish(self, bevel: float = 0.0, segments: int = 2, angle: float = 35.0) -> bpy.types.Object:
        """Writes the bmesh to an object, with rounded edges (`bevel` metres) applied."""
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob["tints"] = {str(k): list(v) for k, v in self.tints.items()}
        ob["kinds"] = {str(k): v for k, v in self.kinds.items()}
        if bevel > 0:
            mod = ob.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel; mod.segments = segments; mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(angle); mod.harden_normals = True
            mod.miter_outer = "MITER_ARC"
            apply_modifiers(ob)
        return ob


def apply_modifiers(ob: bpy.types.Object) -> None:
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


def text(body: str, size: float, kind: str, hexcol: str, loc, rot=(math.pi / 2, 0, 0), depth: float = 0.004,
         align: str = "CENTER", font_path: str = "") -> bpy.types.Object:
    """Lettering as a thin mesh: a shop sign, a painted advert, a house number."""
    cu = bpy.data.curves.new("text", type="FONT")
    cu.body = body; cu.size = size; cu.extrude = depth; cu.align_x = align; cu.align_y = "CENTER"
    if font_path and os.path.exists(font_path):
        cu.font = bpy.data.fonts.load(font_path)
    ob = bpy.data.objects.new("text", cu)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc; ob.rotation_euler = rot
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    me.materials.clear(); me.materials.append(material(kind, hexcol))
    mob = bpy.data.objects.new("text", me)
    bpy.context.scene.collection.objects.link(mob)
    mob.location = loc; mob.rotation_euler = rot
    mob["tints"] = {"0": [1.0, 1.0, 1.0]}
    mob["kinds"] = {"0": kind}
    return mob


# ---- Colour: ambient occlusion and variation, baked into "Col" ----------------------------------------------------
def _hemisphere(n: int) -> list:
    """`n` directions over the +Z hemisphere, cosine-weighted (Fibonacci spiral)."""
    dirs = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n):
        r = math.sqrt((i + 0.5) / n)
        a = i * golden
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1.0 - r * r)))))
    return dirs


def bake_colors(ob: bpy.types.Object, ao_dist: float = 1.4, ao_strength: float = 0.6, rays: int = 14,
                ground: bool = True, damp_height: float = 0.0, mottle: float = 0.05, occluders: list = ()) -> None:
    """Fills the "Col" attribute of `ob` (world space, modifiers applied): ambient occlusion from rays against itself,
    `occluders` and the ground, times each piece's tint, plaster mottling and damp at the foot of the walls."""
    me = ob.data
    mw = ob.matrix_world
    verts = [mw @ v.co for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    for oc in occluders:
        base = len(verts)
        verts += [oc.matrix_world @ v.co for v in oc.data.vertices]
        polys += [tuple(base + i for i in p.vertices) for p in oc.data.polygons]
    if ground:
        base = len(verts); s = 60.0
        verts += [Vector((-s, -s, -0.001)), Vector((s, -s, -0.001)), Vector((s, s, -0.001)), Vector((-s, s, -0.001))]
        polys.append((base, base + 1, base + 2, base + 3))
    bvh = BVHTree.FromPolygons(verts, polys)
    hemi = _hemisphere(rays)
    nmat = mw.to_3x3().inverted().transposed()
    ao = []
    for v in me.vertices:
        p = mw @ v.co
        n = (nmat @ v.normal).normalized()
        t = n.orthogonal().normalized(); b = n.cross(t)
        occl = 0.0
        origin = p + n * 0.012
        for d in hemi:
            ray = t * d.x + b * d.y + n * d.z
            hit = bvh.ray_cast(origin, ray, ao_dist)
            if hit[0] is not None:
                occl += 1.0 - (hit[3] / ao_dist) ** 0.5
        ao.append(1.0 - ao_strength * occl / len(hemi))
    tints = {int(k): v for k, v in ob.get("tints", {}).items()}
    kinds = {int(k): v for k, v in ob.get("kinds", {}).items()}
    elem = me.attributes.get("elem")
    col = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for poly in me.polygons:
        tint = tints.get(elem.data[poly.index].value if elem else 0, (1.0, 1.0, 1.0))
        kind = kinds.get(poly.material_index, "")
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            p = verts[vi]
            k = ao[vi]
            if kind == "plaster":
                k *= 1.0 + mottle * noise.noise(p * 0.55) + mottle * 0.5 * noise.noise(p * 2.1)
                if damp_height > 0 and p.z < damp_height:
                    k *= 0.84 + 0.16 * (p.z / damp_height) ** 0.7
            col.data[li].color = (tint[0] * k, tint[1] * k, tint[2] * k, 1.0)
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = me.color_attributes.find("Col")


def join(objs: list, name: str) -> bpy.types.Object:
    """Joins objects into the first one (materials and "Col" kept)."""
    objs = [o for o in objs if o is not None]
    for o in objs:
        if o.data.color_attributes.get("Col") is None:
            bake_colors(o, ao_strength=0.0, ground=False)
    ctx = {"active_object": objs[0], "selected_editable_objects": objs, "selected_objects": objs}
    with bpy.context.temp_override(**ctx):
        bpy.ops.object.join()
    objs[0].name = name; objs[0].data.name = name
    return objs[0]


def save_blend(path: str) -> None:
    """Keeps the Blender file too (--blend <dir>), so an artist can open the model and carry on by hand."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(path))
    print(f"saved {path}")


def export_glb(objs: list, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for a in list(o.data.attributes):
            if a.name == "elem":
                o.data.attributes.remove(a)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_vertex_color="ACTIVE", export_yup=True, export_materials="EXPORT")
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs if o.type == "MESH")
    print(f"exported {path}: {tris} triangles, {os.path.getsize(path) // 1024} KB")
