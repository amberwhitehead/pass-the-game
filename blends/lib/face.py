"""Shared face for rigged characters: head, nose, ears, mouth, chin, eyes, brows,
plus the standard shape keys (blink, mouth_open). Head centre HZ=1.67 m."""

HZ = 1.67


def add_face(P, skin, skin_shade, brow, width=0.205, jaw=(0.9, 0.88), nose=(0.03, 0.03, 0.05)):
    P(skin, (0.0, 0.0, HZ), (width, 0.225, 0.255), bottom=jaw, bevel=0.012)                        # head
    P(skin, (0.0, -0.118, HZ - 0.03), nose, bevel=0.003)
    P(skin_shade, (0.101 + (width - 0.205) / 2, 0.0, HZ - 0.005), (0.016, 0.03, 0.05), mirror=True)  # ears
    P("mouth", (0.0, -0.1085, HZ - 0.075), (0.05, 0.006, 0.010), tag="mouth")
    P("mouth_dark", (0.0, -0.1088, HZ - 0.075), (0.036, 0.004, 0.0004), tag="mouth_in")            # interior, hidden until open
    P(skin_shade, (0.0, -0.1085, HZ - 0.095), (0.07, 0.006, 0.014), tag="chin")                    # chin shadow
    for sx in (0.045, -0.045):
        P("eye", (sx, -0.1095, HZ + 0.012), (0.022, 0.006, 0.018), tag="eye")
        if brow:
            P(brow, (sx, -0.1105, HZ + 0.04), (0.052, 0.008, 0.012))


def add_shapes(b):
    V = lambda co, x, y, z: type(co)((x, y, z))
    b.shape("blink", eye=lambda co, c: V(co, co.x, co.y, c.z - 0.003 + (co.z - c.z) * 0.3))
    b.shape("mouth_open",
            mouth=lambda co, c: V(co, co.x, co.y, co.z - 0.02 if co.z < c.z else co.z),                 # lower lip drops
            mouth_in=lambda co, c: V(co, co.x, co.y - 0.002, co.z - 0.018 if co.z < c.z else co.z + 0.002),
            chin=lambda co, c: V(co, co.x, co.y, co.z - 0.014))
