"""The Sindaco as a rigged, animated model: a character experiment (docs/MODELS.md).

    blender -b --factory-startup -P tools/blender/sindaco.py -- --out godot/assets/models/lab

A silhouette of his own (a round belly on short legs, a big head with a white handlebar moustache, the tricolour
sash) instead of the shared chibi body, an armature, and three animations exported with it: idle, walk (a pompous
waddle) and talk (an orator's gesture). Each part follows one bone (rigid skinning), as the game's own chibis do; a
character artist would paint smooth weights at the joints.
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

SUIT, SHIRT, SKIN, HAIR, SHOE = "2d3142", "f2efe8", "f0c8a0", "f2f0ea", "2a2523"
GREEN, WHITE, RED = "2e8b57", "f4f2ea", "c8323a"
FPS = 24

# bone: (head, tail, parent)
BONES = {
    "hips": ((0, 0, 0.30), (0, 0, 0.44), None),
    "spine": ((0, 0, 0.44), (0, 0, 0.66), "hips"),
    "chest": ((0, 0, 0.66), (0, 0, 0.82), "spine"),
    "head": ((0, 0, 0.82), (0, 0, 1.38), "chest"),
    "arm.L": ((0.27, 0, 0.74), (0.33, 0, 0.6), "chest"),
    "forearm.L": ((0.33, 0, 0.6), (0.36, 0, 0.46), "arm.L"),
    "arm.R": ((-0.27, 0, 0.74), (-0.33, 0, 0.6), "chest"),
    "forearm.R": ((-0.33, 0, 0.6), (-0.36, 0, 0.46), "arm.R"),
    "thigh.L": ((0.09, 0, 0.3), (0.09, 0, 0.18), "hips"),
    "shin.L": ((0.09, 0, 0.18), (0.09, 0, 0.04), "thigh.L"),
    "thigh.R": ((-0.09, 0, 0.3), (-0.09, 0, 0.18), "hips"),
    "shin.R": ((-0.09, 0, 0.18), (-0.09, 0, 0.04), "thigh.R"),
}


def part(bone: str, build) -> bpy.types.Object:
    """Builds one rigid part and binds all of it to `bone`."""
    b = kit.Builder(bone + "_part", seed=len(bone))
    build(b)
    ob = b.finish()
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    return ob


def body_parts() -> list:
    parts = []

    def legs(side):
        x = 0.09 * side
        sfx = ".L" if side > 0 else ".R"
        parts.append(part("thigh" + sfx, lambda b: b.cylinder((x, 0, 0.245), 0.07, 0.16, "fabric", SUIT, segments=12)))

        def shin(b):
            b.cylinder((x, 0, 0.12), 0.064, 0.13, "fabric", SUIT, segments=12)
            b.blob((x, -0.035, 0.04), 0.075, "fabric", SHOE, squash=0.6, jitter=0.0, subdiv=2)
            b.blob((x, -0.075, 0.035), 0.06, "fabric", SHOE, squash=0.55, jitter=0.0, subdiv=2)
        parts.append(part("shin" + sfx, shin))

    legs(1); legs(-1)

    def belly(b):
        b.blob((0, 0, 0.52), 0.3, "fabric", SUIT, squash=0.95, jitter=0.0, subdiv=3)
        b.blob((0, -0.18, 0.6), 0.17, "fabric", SHIRT, squash=1.35, jitter=0.0, subdiv=2)   # shirt front
        for i in range(3):                                                                    # buttons
            b.blob((0, -0.295 + i * 0.004, 0.42 + i * 0.09), 0.018, "metal", "c9a24a", jitter=0.0, subdiv=1)
        # the tricolour sash, over the right shoulder to the left hip
        for k, col in enumerate((GREEN, WHITE, RED)):
            b.cylinder((0.0, 0.0, 0.55 + (k - 1) * 0.045), 0.312 - abs(k - 1) * 0.004, 0.045, "fabric", col,
                       rot=(0, math.radians(-38), 0), segments=28)
        b.blob((0.19, -0.2, 0.36), 0.05, "fabric", RED, squash=1.4, jitter=0.0, subdiv=1)  # the knot
    parts.append(part("spine", belly))

    def chest(b):
        b.blob((0, 0.02, 0.78), 0.2, "fabric", SUIT, squash=0.55, jitter=0.0, subdiv=2)       # shoulders
        for s in (-1, 1):                                                                     # lapels
            b.box((s * 0.07, -0.16, 0.74), (0.08, 0.04, 0.16), "fabric", "252937", rot=(0.3, 0, s * 0.35))
    parts.append(part("chest", chest))

    def arms(side):
        sfx = ".L" if side > 0 else ".R"
        parts.append(part("arm" + sfx, lambda b: b.cylinder((0.3 * side, 0, 0.67), 0.058, 0.17, "fabric", SUIT,
                                                         rot=(0, side * math.radians(-22), 0), segments=10)))

        def fore(b):
            b.cylinder((0.345 * side, 0, 0.535), 0.052, 0.15, "fabric", SUIT, rot=(0, side * math.radians(-12), 0), segments=10)
            b.blob((0.36 * side, -0.01, 0.43), 0.055, "skin", SKIN, jitter=0.0, subdiv=2)
        parts.append(part("forearm" + sfx, fore))

    arms(1); arms(-1)

    def head(b):
        b.blob((0, 0, 1.08), 0.3, "skin", SKIN, squash=0.96, jitter=0.0, subdiv=3)
        b.blob((0, -0.29, 1.03), 0.055, "skin", "e9a98c", jitter=0.0, subdiv=2)               # nose
        for s in (-1, 1):
            b.blob((s * 0.11, -0.265, 1.12), 0.035, "eye", "1d1a18", squash=1.3, jitter=0.0, subdiv=2)
            b.blob((s * 0.105 - 0.008, -0.293, 1.135), 0.009, "eye", "ffffff", jitter=0.0, subdiv=1)
            b.box((s * 0.115, -0.262, 1.2), (0.12, 0.05, 0.035), "hair", HAIR, rot=(0.25, 0, s * -0.18))   # brows
            b.blob((s * 0.18, -0.21, 1.02), 0.045, "skin", "f0a49a", squash=0.4, jitter=0.0, subdiv=1)     # blush
            # the handlebar moustache, curling up at the ends
            b.blob((s * 0.075, -0.285, 0.985), 0.06, "hair", HAIR, squash=0.55, jitter=0.0, subdiv=2)
            b.blob((s * 0.15, -0.265, 1.0), 0.042, "hair", HAIR, squash=0.6, jitter=0.0, subdiv=2)
            b.blob((s * 0.2, -0.235, 1.04), 0.03, "hair", HAIR, jitter=0.0, subdiv=2)
            # white hair round the sides and back; the top is bald
            for k in range(4):
                a = math.radians(70 + k * 30)
                b.blob((s * math.sin(a) * 0.28, math.cos(a) * -0.28 + 0.06, 1.1 + (k % 2) * 0.03), 0.09, "hair", HAIR,
                       jitter=0.12, subdiv=2)
            b.blob((s * 0.29, -0.02, 1.07), 0.05, "skin", SKIN, squash=1.2, jitter=0.0, subdiv=1)                  # ears
        b.blob((0, 0.27, 1.12), 0.11, "hair", HAIR, jitter=0.12, subdiv=2)
    parts.append(part("head", head))
    return parts


def armature() -> bpy.types.Object:
    arm = bpy.data.armatures.new("Sindaco_rig")
    ob = bpy.data.objects.new("Sindaco_rig", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (h, t, parent) in BONES.items():
        e = arm.edit_bones.new(name)
        e.head, e.tail = h, t
        e.roll = 0.0
        if parent:
            e.parent = arm.edit_bones[parent]
            e.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def key(ob, bone, frame, rot=None, loc=None):
    pb = ob.pose.bones[bone]
    pb.rotation_mode = "XYZ"
    if rot is not None:
        pb.rotation_euler = [math.radians(a) for a in rot]
        pb.keyframe_insert("rotation_euler", frame=frame)
    if loc is not None:
        pb.location = loc
        pb.keyframe_insert("location", frame=frame)


def action(ob, name, frames, keys):
    """An action from {frame: {bone: (rot, loc)}}; the last frame repeats the first so it loops."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ob.animation_data_create()
    ob.animation_data.action = act
    for pb in ob.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
    for f, bones in keys.items():
        for bone, (rot, loc) in bones.items():
            key(ob, bone, f, rot, loc)
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.easing = "AUTO"
        mod = fc.modifiers.new("CYCLES")
    track = ob.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    ob.animation_data.action = None
    return act


def animations(rig):
    # walk: one stride a second; a waddle, the belly swinging side to side
    def walk_pose(phase):  # phase 0..1
        s = math.sin(phase * 2 * math.pi)
        c = math.cos(phase * 2 * math.pi)
        bob = abs(math.sin(phase * 2 * math.pi))
        return {
            "thigh.L": ((-28 * s, 0, 0), None), "thigh.R": ((28 * s, 0, 0), None),
            "shin.L": ((max(0.0, 30 * c), 0, 0), None), "shin.R": ((max(0.0, -30 * c), 0, 0), None),
            "arm.L": ((24 * s, 0, 0), None), "arm.R": ((-24 * s, 0, 0), None),
            "forearm.L": ((-12 - 8 * s, 0, 0), None), "forearm.R": ((-12 + 8 * s, 0, 0), None),
            "hips": ((0, 7 * s, 4 * s), (0, 0, 0.025 * bob)),
            "spine": ((4, -5 * s, -3 * s), None),
            "head": ((-4, 3 * s, 2 * s), None),
        }
    action(rig, "walk", 25, {f: walk_pose((f - 1) / 24.0) for f in (1, 4, 7, 10, 13, 16, 19, 22, 25)})

    # idle: breathing, a slow look round, thumbs in the waistcoat
    def idle_pose(phase):
        s = math.sin(phase * 2 * math.pi)
        return {
            "chest": ((-3 * s, 0, 0), None), "spine": ((1.5 * s, 0, 0), None),
            "hips": ((0, 0, 0), (0, 0, 0.006 * s)),
            "head": ((2 * s, 0, 8 * math.sin(phase * math.pi * 2 + 1.0)), None),
            "arm.L": ((-15, 0, 18), None), "arm.R": ((-15, 0, -18), None),
            "forearm.L": ((-60, 0, 0), None), "forearm.R": ((-60, 0, 0), None),
        }
    action(rig, "idle", 49, {f: idle_pose((f - 1) / 48.0) for f in (1, 13, 25, 37, 49)})

    # talk: the orator's raised hand, chin up, chest out
    def talk_pose(phase):
        s = math.sin(phase * 2 * math.pi)
        s2 = math.sin(phase * 4 * math.pi)
        return {
            "chest": ((-6 - 2 * s2, 0, 4 * s), None),
            "head": ((-8 + 5 * s2, 0, -6 * s), None),
            "arm.R": ((-70 - 15 * s, 0, -25), None), "forearm.R": ((-50 + 20 * s2, 0, 0), None),
            "arm.L": ((-15, 0, 18), None), "forearm.L": ((-60, 0, 0), None),
            "hips": ((0, 0, 0), (0, 0, 0.008 * s2)),
        }
    action(rig, "talk", 49, {f: talk_pose((f - 1) / 48.0) for f in (1, 7, 13, 19, 25, 31, 37, 43, 49)})


def main():
    a = kit.args()
    kit.reset()
    bpy.context.scene.render.fps = FPS
    parts = body_parts()
    for p in parts:
        kit.bake_colors(p, occluders=[q for q in parts if q is not p], ao_dist=0.35, ao_strength=0.5, ground=True)
    mesh = kit.join(parts, "Sindaco")
    for poly in mesh.data.polygons:
        poly.use_smooth = True
    rig = armature()
    mesh.parent = rig
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    animations(rig)
    out = os.path.join(a.get("out", "godot/assets/models/lab"), "sindaco.glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    for o in (mesh,):
        if o.data.attributes.get("elem"):
            o.data.attributes.remove(o.data.attributes["elem"])
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True); rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_vertex_color="ACTIVE",
                              export_yup=True, export_skins=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_materials="EXPORT")
    if a.get("blend"):
        kit.save_blend(os.path.join(a["blend"], "sindaco.blend"))
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    print(f"exported {out}: {tris} triangles, {len(rig.data.bones)} bones, "
          f"{len([t for t in rig.animation_data.nla_tracks])} animations, {os.path.getsize(out) // 1024} KB")


main()
