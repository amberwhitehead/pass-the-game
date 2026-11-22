import bpy
bpy.ops.wm.open_mainfile(filepath="C:/Users/Admin/dev/pass-the-game/blends/props/observatory_platform.blend")
for ob in bpy.data.objects:
    if ob.type == "MESH":
        me = ob.data
        uv_layers = me.uv_layers
        print(ob.name, "uv_layers:", len(uv_layers), "verts:", len(me.vertices), "polys:", len(me.polygons))
        if uv_layers and len(uv_layers[0].data) > 0:
            print("   first uv:", uv_layers[0].data[0].uv)
EOF