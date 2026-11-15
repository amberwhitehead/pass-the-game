"""Shared block-building helpers for the platform props (stone courses, boxes, prisms, gears).
Run inside Blender. Frames: see frame(): +X tangent (game angle increasing), +Y outward, +Z up."""
import math

import bmesh
from mathutils import Matrix, Vector

import bl

pal = bl.pal
TAU = 2 * math.pi
PI = math.pi

def P(r, a, z=0.0):
    return Vector((r * math.cos(a), -r * math.sin(a), z))


def frame(a, r, z=0.0, yaw=0.0):
    """Local frame at game angle a, radius r: +X = tangent (a increasing), +Y = outward, +Z = up."""
    return Matrix.Translation(P(r, a, z)) @ Matrix.Rotation(-a - PI / 2 + yaw, 4, "Z")


def add_bm(b, bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mp = {v: b.bm.verts.new(v.co) for v in bm.verts}
    for f in bm.faces:
        nf = b.bm.faces.new([mp[v] for v in f.verts])
        nf.material_index = f.material_index
    bm.free()


FACE_IDX = {"bottom": (0, 1, 2, 3), "top": (4, 5, 6, 7), "y-": (0, 1, 5, 4),
            "x+": (1, 2, 6, 5), "y+": (2, 3, 7, 6), "x-": (3, 0, 4, 7)}


def solid(b, corners, cell, bevel=0.0, faces=None, hollow=False):
    """Hexahedron from 8 corners (bottom 4 then top 4, same order). bevel chamfers the top edges."""
    bm = bmesh.new()
    vs = [bm.verts.new(c) for c in corners]
    base = pal.idx(cell)
    top = None
    for name, ix in FACE_IDX.items():
        if hollow and name == "bottom":
            continue                         # hidden underside: saves triangles
        f = bm.faces.new([vs[i] for i in ix])
        f.material_index = pal.idx(faces[name]) if faces and name in faces else base
        if name == "top":
            top = f
    if bevel > 0:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.bevel(bm, geom=list(top.edges), offset=bevel, segments=1, affect="EDGES",
                        clamp_overlap=True)
        for f in bm.faces:
            if f.material_index == 0 and base != 0:
                f.material_index = base
    add_bm(b, bm)


def lbox(b, cell, M, c, s, top=(1, 1), bevel=0.0, faces=None, rot=0.0, R=None):
    """Box in frame M: centre c, size s, top face scaled by `top`, yaw `rot` degrees, extra rotation R."""
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    loc = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
           (-hx * top[0], -hy * top[1], hz), (hx * top[0], -hy * top[1], hz),
           (hx * top[0], hy * top[1], hz), (-hx * top[0], hy * top[1], hz)]
    Rm = Matrix.Rotation(math.radians(rot), 4, "Z") if rot else Matrix.Identity(4)
    if R is not None:
        Rm = Rm @ R
    T = M @ Matrix.Translation(c) @ Rm
    solid(b, [T @ Vector(p) for p in loc], cell, bevel, faces)


def rod(b, cell, M, p0, p1, w, h=None, roll=0.0, w1=None, h1=None):
    """Bar from local point p0 to p1 with cross-section w x h (optionally tapering to w1 x h1)."""
    h = w if h is None else h
    w1 = w if w1 is None else w1
    h1 = h if h1 is None else h1
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((0, 1, 0))
    u = d.cross(up).normalized()
    v = d.cross(u).normalized()
    if roll:
        Rr = Matrix.Rotation(math.radians(roll), 3, d)
        u, v = Rr @ u, Rr @ v
    sq = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    cs = [M @ (p0 + u * (sx * w / 2) + v * (sy * h / 2)) for sx, sy in sq]
    cs += [M @ (p1 + u * (sx * w1 / 2) + v * (sy * h1 / 2)) for sx, sy in sq]
    solid(b, cs, cell)


def prism(b, cell, M, sides, r0, r1, z0, z1, off=0.0, cells=None, caps=None, c=(0, 0)):
    """n-gon frustum along local Z (radius r0 at z0, r1 at z1). cells: per-side colours."""
    bm = bmesh.new()
    n = sides

    def ring(r, z):
        return [bm.verts.new(M @ Vector((c[0] + r * math.cos(off + k * TAU / n),
                                         c[1] + r * math.sin(off + k * TAU / n), z))) for k in range(n)]
    bot, top = ring(r0, z0), ring(r1, z1)
    base = pal.idx(cell)
    fb = bm.faces.new(bot[::-1]); ft = bm.faces.new(top)
    fb.material_index = pal.idx(caps[0]) if caps else base
    ft.material_index = pal.idx(caps[1]) if caps else base
    for k in range(n):
        f = bm.faces.new([bot[k], bot[(k + 1) % n], top[(k + 1) % n], top[k]])
        f.material_index = pal.idx(cells[k % len(cells)]) if cells else base
    add_bm(b, bm)


def extrude(b, cell, M, pts, y0, y1, cap_cell=None):
    """Profile in the local XZ plane (list of (x, z)) extruded along local Y from y0 to y1."""
    bm = bmesh.new()
    a = [bm.verts.new(M @ Vector((x, y0, z))) for x, z in pts]
    c = [bm.verts.new(M @ Vector((x, y1, z))) for x, z in pts]
    base = pal.idx(cell)
    n = len(pts)
    fa = bm.faces.new(a[::-1]); fc = bm.faces.new(c)
    fa.material_index = fc.material_index = pal.idx(cap_cell) if cap_cell else base
    for k in range(n):
        f = bm.faces.new([a[k], a[(k + 1) % n], c[(k + 1) % n], c[k]])
        f.material_index = base
    add_bm(b, bm)


def trap(b, cell, M, x0, x1, w0, w1, z0, z1):
    """Trapezoid plate in plan: from x0 (width w0) to x1 (width w1), z0..z1."""
    cs = [(x0, -w0 / 2, z0), (x1, -w1 / 2, z0), (x1, w1 / 2, z0), (x0, w0 / 2, z0),
          (x0, -w0 / 2, z1), (x1, -w1 / 2, z1), (x1, w1 / 2, z1), (x0, w0 / 2, z1)]
    solid(b, [M @ Vector(p) for p in cs], cell)


def gear(b, M, c, N, pitch, mod, thick, cell, phase=0.0, y=0.0):
    """Spur gear in the local XZ plane centred at c=(x, z); teeth are trapezoids."""
    step = TAU / N
    rr, rt = pitch - 1.0 * mod, pitch + 0.9 * mod
    pts = []
    for i in range(N):
        t = phase + i * step
        for dt, r in ((-0.36, rr), (-0.17, rt), (0.17, rt), (0.36, rr)):
            ang = t + dt * step
            pts.append((c[0] + r * math.cos(ang), c[1] + r * math.sin(ang)))
    extrude(b, cell, M, pts, y - thick / 2, y + thick / 2)


# ---------------------------------------------------------------- stone courses
def pick(rng, weights):
    tot = sum(w for _, w in weights)
    x = rng.uniform(0, tot)
    for n, w in weights:
        x -= w
        if x <= 0:
            return n
    return weights[0][0]


def spans(rng, start, windows, target, jitter=0.2):
    """Cover [start, start+TAU) with blocks and windows [(a0, a1), ...]: [(a0, a1, 'blk'|'win')]."""
    ws = []
    for w0, w1 in windows:
        s = start + ((w0 - start) % TAU)
        ws.append((s, s + (w1 - w0)))
    ws.sort()
    out, cur = [], start

    def gap(a, c):
        L = c - a
        if L < 0.012:
            return
        n = max(1, round(L / target))
        e = [a + L * (i / n + (rng.uniform(-jitter, jitter) / n if 0 < i < n else 0)) for i in range(n + 1)]
        out.extend((e[i], e[i + 1], "blk") for i in range(n))
    for s, e in ws:
        gap(cur, s)
        out.append((s, e, "win"))
        cur = e
    gap(cur, start + TAU)
    return out


def pblock(b, rng, cell, r0, r1, a0, a1, z0, z1, r0t=None, r1t=None, gap=0.006, jit=0.01,
           jz=0.008, bevel=0.012, faces=None, hollow=False):
    """A polar block (wedge with chord faces); rough-cut by jittering its corners."""
    r0t = r0 if r0t is None else r0t
    r1t = r1 if r1t is None else r1t
    bump = rng.uniform(-jit * 2, jit * 2)
    z0 += gap / 2
    z1 -= gap / 2

    def pt(r, a, z, side, k):
        g = gap / max(r, 0.5)
        a = a + g if side == 0 else a - g
        v = P(r, a, z)
        s = 1.0 if z == z1 else 0.3
        v += Vector((rng.uniform(-jit, jit), rng.uniform(-jit, jit), rng.uniform(-jz, jz) * s))
        return v
    cs = [pt(r0, a0, z0, 0, 0), pt(r1 + bump, a0, z0, 0, 1), pt(r1 + bump, a1, z0, 1, 2), pt(r0, a1, z0, 1, 3),
          pt(r0t, a0, z1, 0, 4), pt(r1t + bump, a0, z1, 0, 5), pt(r1t + bump, a1, z1, 1, 6), pt(r0t, a1, z1, 1, 7)]
    solid(b, cs, cell, bevel, faces, hollow)


def cylinder(b, cell, r, z0, z1, n=32):
    prism(b, cell, Matrix.Identity(4), n, r, r, z0, z1)


