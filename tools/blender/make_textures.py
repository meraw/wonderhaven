import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit

TAU = 2.0 * math.pi


class Graph:
    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.out = self.nt.nodes.new("ShaderNodeOutputMaterial")
        self.emit = self.nt.nodes.new("ShaderNodeEmission")
        self.nt.links.new(self.emit.outputs[0], self.out.inputs["Surface"])
        tc = self.nt.nodes.new("ShaderNodeTexCoord")
        sep = self.nt.nodes.new("ShaderNodeSeparateXYZ")
        self.nt.links.new(tc.outputs["UV"], sep.inputs[0])
        self.u, self.v = sep.outputs[0], sep.outputs[1]

    def link(self, sock, target):
        if isinstance(sock, (int, float)):
            target.default_value = sock
        else:
            self.nt.links.new(sock, target)

    def m(self, op, a, b=0.0, clamp=False):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        self.link(a, n.inputs[0])
        self.link(b, n.inputs[1])
        return n.outputs[0]

    def add(self, *xs):
        acc = xs[0]
        for x in xs[1:]:
            acc = self.m("ADD", acc, x)
        return acc

    def mul(self, a, b):
        return self.m("MULTIPLY", a, b)

    def lerp(self, a, b, t):
        return self.add(a, self.mul(self.m("SUBTRACT", b, a), t))

    def smooth(self, x, lo, hi):
        n = self.nt.nodes.new("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        self.link(x, n.inputs["Value"])
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        return n.outputs["Result"]

    def fract(self, x):
        return self.m("FRACT", x)

    def torus(self, nu, nv):
        ru, rv = nu / TAU, nv / TAU
        au, av = self.mul(self.u, TAU), self.mul(self.v, TAU)
        comb = self.nt.nodes.new("ShaderNodeCombineXYZ")
        self.link(self.mul(self.m("COSINE", au), ru), comb.inputs[0])
        self.link(self.mul(self.m("SINE", au), ru), comb.inputs[1])
        self.link(self.mul(self.m("COSINE", av), rv), comb.inputs[2])
        return comb.outputs[0], self.mul(self.m("SINE", av), rv)

    def noise(self, nu, nv=None, detail=4.0, rough=0.55, distortion=0.0, seed=0.0):
        vec, w = self.torus(nu, nu if nv is None else nv)
        n = self.nt.nodes.new("ShaderNodeTexNoise")
        n.noise_dimensions = "4D"
        self.link(vec, n.inputs["Vector"])
        self.link(self.add(w, seed * 17.31), n.inputs["W"])
        n.inputs["Scale"].default_value = 1.0
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = distortion
        return n.outputs["Fac"]

    def voronoi(self, nu, feature="F1", randomness=1.0, output="Distance", seed=0.0):
        vec, w = self.torus(nu, nu)
        n = self.nt.nodes.new("ShaderNodeTexVoronoi")
        n.voronoi_dimensions = "4D"
        n.feature = feature
        self.link(vec, n.inputs["Vector"])
        self.link(self.add(w, seed * 11.7), n.inputs["W"])
        n.inputs["Scale"].default_value = 1.0
        n.inputs["Randomness"].default_value = randomness
        return n.outputs[output]

    def rgb(self, r, g, b):
        comb = self.nt.nodes.new("ShaderNodeCombineColor")
        self.link(r, comb.inputs[0])
        self.link(g, comb.inputs[1])
        self.link(b, comb.inputs[2])
        return comb.outputs[0]


def plaster(g):
    blobs = g.m("SUBTRACT", 1.0, g.smooth(g.voronoi(26, "SMOOTH_F1"), 0.0, 0.55))
    h = g.add(g.mul(g.noise(40, detail=6), 0.55), g.mul(blobs, 0.35), g.mul(g.noise(220, detail=2), 0.12))
    blotch = g.m("SUBTRACT", g.noise(3, detail=6, rough=0.62, seed=2), 0.5)
    alb = g.add(0.82, g.mul(blotch, 0.6), g.mul(g.m("SUBTRACT", h, 0.5), 0.3))
    rough = g.add(0.86, g.mul(g.m("SUBTRACT", g.noise(60, seed=3), 0.5), 0.12))
    return alb, h, rough, 4.0


def stone(g):
    pit = g.m("SUBTRACT", 1.0, g.smooth(g.voronoi(70, seed=4), 0.0, 0.16))
    big = g.noise(10, detail=10, rough=0.7)
    h = g.m("SUBTRACT", g.add(g.mul(big, 0.8), g.mul(g.noise(90, detail=3), 0.2)), g.mul(pit, 0.45))
    alb = g.add(0.84, g.mul(g.m("SUBTRACT", g.noise(5, detail=5, seed=5), 0.5), 0.4), g.mul(pit, -0.3),
                g.mul(g.m("SUBTRACT", big, 0.5), 0.2))
    rough = g.add(0.84, g.mul(pit, 0.1))
    return alb, h, rough, 5.0


def paving(g):
    edge = g.voronoi(7, "DISTANCE_TO_EDGE", randomness=0.85, seed=6)
    cell = g.voronoi(7, "F1", randomness=0.85, output="Color", seed=6)
    sepc = g.nt.nodes.new("ShaderNodeSeparateColor")
    g.link(cell, sepc.inputs[0])
    grout = g.m("SUBTRACT", 1.0, g.smooth(edge, 0.006, 0.02))
    surf = g.noise(45, detail=8, rough=0.6, seed=7)
    h = g.mul(g.m("SUBTRACT", 1.0, grout), g.add(0.55, g.mul(surf, 0.25), g.mul(g.smooth(edge, 0.0, 0.18), 0.2)))
    val = g.mul(g.add(0.3, g.mul(sepc.outputs[0], 0.24)), g.add(0.72, g.mul(surf, 0.5), g.mul(g.noise(14, detail=6, seed=21), 0.2)))
    stone_col = g.rgb(g.mul(val, 1.04), val, g.mul(val, 0.93))
    mix = g.nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    g.link(grout, mix.inputs["Factor"])
    g.link(stone_col, mix.inputs["A"])
    mix.inputs["B"].default_value = (0.24, 0.23, 0.21, 1.0)
    rough = g.lerp(g.add(0.68, g.mul(surf, 0.18)), 0.95, grout)
    return mix.outputs["Result"], h, rough, 3.5


def wood(g):
    fv = g.fract(g.mul(g.v, 5.0))
    gap = g.mul(g.smooth(fv, 0.0, 0.035), g.m("SUBTRACT", 1.0, g.smooth(fv, 0.965, 1.0)))
    grain = g.noise(2, 70, detail=5, rough=0.6, seed=8)
    chips = g.smooth(g.noise(9, detail=7, rough=0.65, seed=9), 0.6, 0.63)
    paint = g.add(0.84, g.mul(g.m("SUBTRACT", grain, 0.5), 0.1))
    bare = g.add(0.66, g.mul(g.m("SUBTRACT", grain, 0.5), 0.3))
    alb = g.mul(g.lerp(paint, bare, chips), g.add(0.55, g.mul(gap, 0.45)))
    h = g.mul(gap, g.add(0.72, g.mul(grain, 0.12), g.mul(chips, -0.1)))
    rough = g.lerp(0.62, 0.86, chips)
    return alb, h, rough, 6.0


def clay(g):
    speck = g.smooth(g.noise(200, detail=1, seed=10), 0.72, 0.78)
    h = g.add(g.mul(g.noise(30, detail=8, seed=11), 0.55), g.mul(g.noise(130, detail=2), 0.3), g.mul(speck, -0.15))
    alb = g.add(0.8, g.mul(g.m("SUBTRACT", g.noise(5, detail=3, seed=12), 0.5), 0.22), g.mul(speck, -0.18))
    return alb, h, 0.82, 3.0


def knit(g):
    x = g.fract(g.mul(g.u, 28.0))
    lean = g.mul(g.m("ABSOLUTE", g.m("SUBTRACT", x, 0.5)), 1.4)
    phase = g.fract(g.add(g.mul(g.v, 38.0), lean))
    ridge = g.m("SUBTRACT", 1.0, g.mul(g.m("ABSOLUTE", g.m("SUBTRACT", phase, 0.5)), 2.0))
    column = g.m("SUBTRACT", 1.0, g.m("POWER", g.mul(g.m("ABSOLUTE", g.m("SUBTRACT", x, 0.5)), 2.0), 6.0))
    fuzz = g.noise(320, detail=2, seed=13)
    h = g.add(g.mul(g.smooth(ridge, 0.0, 1.0), g.mul(column, 0.8)), g.mul(fuzz, 0.15))
    alb = g.add(0.66, g.mul(h, 0.26), g.mul(g.m("SUBTRACT", g.noise(6, seed=14), 0.5), 0.06))
    return alb, h, 0.96, 4.0


def denim(g):
    t = g.fract(g.add(g.mul(g.u, 48.0), g.mul(g.v, 48.0)))
    ridge = g.m("SUBTRACT", 1.0, g.mul(g.m("ABSOLUTE", g.m("SUBTRACT", t, 0.5)), 2.0))
    slub = g.noise(3, 90, detail=3, seed=15)
    h = g.add(g.mul(ridge, 0.7), g.mul(slub, 0.3))
    alb = g.add(0.55, g.mul(ridge, 0.22), g.mul(g.m("SUBTRACT", slub, 0.5), 0.3))
    return alb, h, 0.9, 6.0


def leather(g):
    edge = g.voronoi(22, "DISTANCE_TO_EDGE", seed=16)
    crease = g.smooth(edge, 0.0, 0.035)
    grain = g.noise(160, detail=3, seed=17)
    h = g.add(g.mul(crease, 0.35), g.mul(grain, 0.65))
    alb = g.add(0.74, g.mul(h, 0.1), g.mul(g.m("SUBTRACT", g.noise(8, detail=3, seed=18), 0.5), 0.18))
    rough = g.add(0.5, g.mul(g.m("SUBTRACT", 1.0, crease), 0.25))
    return alb, h, rough, 2.5


def wool(g):
    curls = g.m("SUBTRACT", 1.0, g.smooth(g.voronoi(46, "SMOOTH_F1", seed=19), 0.0, 0.45))
    swirl = g.noise(110, detail=5, distortion=3.0, seed=20)
    h = g.add(g.mul(curls, 0.7), g.mul(swirl, 0.3))
    alb = g.add(0.66, g.mul(h, 0.3))
    return alb, h, 0.95, 7.0


MATERIALS = {"plaster": plaster, "stone": stone, "paving": paving, "wood": wood, "clay": clay,
             "knit": knit, "denim": denim, "leather": leather, "wool": wool}


def setup_scene(size):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.cycles.use_denoising = False
    scene.cycles.pixel_filter_type = "BOX"
    scene.cycles.filter_width = 0.01
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Raw"
    scene.view_settings.look = "None"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_depth = "16"
    scene.render.image_settings.color_mode = "RGB"
    bpy.ops.mesh.primitive_plane_add(size=2.0)
    plane = bpy.context.active_object
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, 0, 2)
    scene.camera = cam
    return plane


def render_channel(graph, sock, path):
    graph.link(sock, graph.emit.inputs["Color"])
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[:, :, :3]


def save_jpeg(arr, path):
    h, w, _ = arr.shape
    img = bpy.data.images.new("out", w, h, alpha=False, float_buffer=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(arr, 0.0, 1.0)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "JPEG"
    bpy.context.scene.render.image_settings.quality = 90
    img.save()
    bpy.data.images.remove(img)


def normal_from_height(hgt, strength):
    dx = (np.roll(hgt, -1, axis=1) - np.roll(hgt, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(hgt, -1, axis=0) - np.roll(hgt, 1, axis=0)) * 0.5 * strength
    n = np.stack([-dx, -dy, np.ones_like(hgt)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def main():
    a = kit.args()
    out = a.get("out", "godot/assets/textures/lab/blender")
    size = int(a.get("size", "1024"))
    only = a.get("only", "")
    tmp = os.path.abspath(a.get("tmp", "/tmp/wonderhaven_textures"))
    os.makedirs(out, exist_ok=True)
    os.makedirs(tmp, exist_ok=True)
    kit.reset()
    plane = setup_scene(size)
    for name, build in MATERIALS.items():
        if only and name not in only.split(","):
            continue
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        plane.data.materials.clear()
        plane.data.materials.append(mat)
        g = Graph(mat)
        alb, hgt, rough, strength = build(g)
        albedo = render_channel(g, alb, os.path.join(tmp, name + "_a.png"))
        height = render_channel(g, hgt, os.path.join(tmp, name + "_h.png"))[:, :, 0]
        if isinstance(rough, (int, float)):
            rmap = np.full_like(albedo, rough)
        else:
            rmap = render_channel(g, rough, os.path.join(tmp, name + "_r.png"))
        save_jpeg(albedo, os.path.join(os.path.abspath(out), name + "_albedo.jpg"))
        save_jpeg(normal_from_height(height * size / 256.0, strength), os.path.join(os.path.abspath(out), name + "_normal.jpg"))
        save_jpeg(rmap, os.path.join(os.path.abspath(out), name + "_rough.jpg"))
        print(f"texture {name}: height {height.min():.2f}..{height.max():.2f}, albedo mean {albedo.mean():.2f}")


main()
