"""Export PEI object prefabs with UVs, materials and textures.

Requires the decompressed core.masterbundle serialized files. Decode textures from
the .resS stream; write PNGs once under assets/unturned/pei_objects/textures and
reference them from GLB files.

Outputs:
  assets/unturned/pei_objects/<asset>.glb
  assets/unturned/pei_objects/textures/*.png
  data/maps/PEI/object_placements.json
"""
import UnityPy, numpy as np, os, json, struct, hashlib, math
from UnityPy.helpers.MeshHelper import MeshHandler

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAB = r"E:\Temp\CAB-13bab8a01683773dc7e9ece82d58bc7a"
GAME = r"E:\Steam\steamapps\common\Unturned"
OUT_DIR = os.path.join(PROJECT, "assets", "unturned", "pei_objects")
TEX_DIR = os.path.join(OUT_DIR, "textures")
MAP_DIR = os.path.join(PROJECT, "data", "maps", "PEI")


def vec(v): return (float(v.x), float(v.y), float(v.z))
def quat(q): return (float(q.x), float(q.y), float(q.z), float(q.w))


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw*bx + ax*bw + ay*bz - az*by,
            aw*by - ax*bz + ay*bw + az*bx,
            aw*bz + ax*by - ay*bx + az*bw,
            aw*bw - ax*bx - ay*by - az*bz)


def euler_to_quat(rx, ry, rz):
    hx, hy, hz = math.radians(rx)*0.5, math.radians(ry)*0.5, math.radians(rz)*0.5
    return qmul(qmul((0.0, math.sin(hy), 0.0, math.cos(hy)),
                     (math.sin(hx), 0.0, 0.0, math.cos(hx))),
                (0.0, 0.0, math.sin(hz), math.cos(hz)))


def mat_trs(pos, rot, scale):
    x, y, z, w = rot
    xx, yy, zz = x*x, y*y, z*z
    xy, xz, yz = x*y, x*z, y*z
    wx, wy, wz = w*x, w*y, w*z
    R = np.array([[1-2*(yy+zz), 2*(xy-wz), 2*(xz+wy)],
                  [2*(xy+wz), 1-2*(xx+zz), 2*(yz-wx)],
                  [2*(xz-wy), 2*(yz+wx), 1-2*(xx+yy)]], dtype=np.float64)
    M = np.eye(4)
    M[:3, :3] = R @ np.diag(scale)
    M[:3, 3] = pos
    return M


def pad4(b, fill=b"\x00"): return b + fill*((4-len(b) % 4) % 4)


def main():
    os.makedirs(TEX_DIR, exist_ok=True)
    env = UnityPy.load(CAB)
    ab = next(o.read() for o in env.objects if o.type.name == "AssetBundle")
    container = {p.lower(): info.asset for p, info in ab.m_Container}

    with open(os.path.join(MAP_DIR, "objects.json"), encoding="utf-8") as f:
        data = json.load(f)
    assets = data["assets"]
    used = sorted({o["guid"] for o in data["objects"]})

    # preload all tree/object materials? no
    texture_cache = {}  # name -> path

    def get_transform(go):
        for c in go.m_Component:
            pptr = c[1] if isinstance(c, tuple) else c.component
            o = pptr.deref()
            if o and o.type.name == "Transform":
                return pptr.deref_parse_as_object()
        return None

    def comps(go, typename):
        out = []
        for c in go.m_Component:
            pptr = c[1] if isinstance(c, tuple) else c.component
            o = pptr.deref()
            if o and o.type.name == typename:
                out.append(pptr.deref_parse_as_object())
        return out

    def save_texture(tex):
        try:
            img = tex.image
        except Exception:
            return None
        if img is None:
            return None
        name = (tex.m_Name or "texture").replace("/", "_").replace("\\", "_")
        digest = hashlib.md5(img.tobytes()).hexdigest()[:12]
        filename = f"{name}_{digest}.png"
        path = os.path.join(TEX_DIR, filename)
        if filename not in texture_cache:
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGBA" if "A" in img.mode else "RGB")
            img.save(path)
            texture_cache[filename] = True
        return "textures/" + filename

    exported = {}
    placements = []
    stats = {"assets": 0, "prims": 0, "textures": 0}

    for index, guid in enumerate(used):
        asset = assets.get(guid)
        if not asset:
            continue
        rel = os.path.relpath(os.path.dirname(asset["path"]), os.path.join(GAME, "Bundles", "Objects"))
        prefix = "assets/coremasterbundle/objects/" + rel.replace("\\", "/").lower() + "/object.prefab"
        pptr = container.get(prefix)
        if pptr is None:
            continue
        root = pptr.deref_parse_as_object()
        renderers = []

        def traverse(t, parent, is_root=False):
            go = t.m_GameObject.deref_parse_as_object()
            # LevelObject instantiates the prefab with the map placement as the root
            # transform, so the prefab's authored root position/rotation is replaced.
            # Applying it here would double-transform the object.
            world = parent if is_root else parent @ mat_trs(vec(t.m_LocalPosition), quat(t.m_LocalRotation), vec(t.m_LocalScale))
            for mr in comps(go, "MeshRenderer"):
                renderers.append((mr, world))
            for ch in t.m_Children:
                traverse(ch.deref_parse_as_object(), world)

        traverse(get_transform(root), np.eye(4), True)
        lgs = comps(root, "LODGroup")
        if lgs and lgs[0].m_LODs:
            ids = set()
            for lr in lgs[0].m_LODs[0].renderers:
                ptr = getattr(lr, "renderer", None) or getattr(lr, "m_Renderer", None)
                if ptr:
                    ids.add(ptr.path_id)
            renderers = [(mr, w) for mr, w in renderers if mr.object_reader.path_id in ids]
        if not renderers:
            continue

        prims = []  # dict with P,N,T,I,material(name,color,tex,alpha)
        for mr, world in renderers:
            go = mr.m_GameObject.deref_parse_as_object()
            mfs = comps(go, "MeshFilter")
            if not mfs:
                continue
            mesh = mfs[0].m_Mesh.deref_parse_as_object()
            try:
                handler = MeshHandler(mesh); handler.process()
                verts = np.array(handler.m_Vertices, dtype=np.float32)
                norms = np.array(handler.m_Normals, dtype=np.float32) if handler.m_Normals else np.zeros_like(verts)
                uvs = np.array(handler.m_UV0, dtype=np.float32) if handler.m_UV0 else np.zeros((len(verts), 2), dtype=np.float32)
                tris = handler.get_triangles()
            except Exception:
                continue
            mats = []
            for mp in mr.m_Materials:
                try: mats.append(mp.deref_parse_as_object())
                except Exception: mats.append(None)
            for si, tri in enumerate(tris):
                tri = np.array(tri, dtype=np.int64)
                if not len(tri):
                    continue
                mat = mats[si] if si < len(mats) else (mats[0] if mats else None)
                color = (0.8, 0.8, 0.8, 1.0)
                tex_uri = None
                alpha = "OPAQUE"
                if mat is not None:
                    for key, value in mat.m_SavedProperties.m_Colors:
                        nm = key if isinstance(key, str) else key.name
                        if nm == "_Color":
                            color = (float(value.r), float(value.g), float(value.b), float(value.a))
                            break
                    for key, value in mat.m_SavedProperties.m_TexEnvs:
                        nm = key if isinstance(key, str) else key.name
                        if nm != "_MainTex" or not value.m_Texture:
                            continue
                        try:
                            tex = value.m_Texture.deref_parse_as_object()
                            if tex:
                                tex_uri = save_texture(tex)
                                if tex_uri:
                                    alpha = "MASK"
                        except Exception:
                            pass
                        break
                v4 = np.c_[verts, np.ones(len(verts))]
                w = (world @ v4.T).T[:, :3]
                nmat = np.linalg.inv(world[:3, :3]).T
                wn = (nmat @ norms.T).T
                idx = tri.reshape(-1, 3)
                idx = idx[: len(idx)//1]
                prims.append({
                    "P": w.astype(np.float32),
                    "N": wn.astype(np.float32),
                    "T": uvs,
                    "I": idx.astype(np.uint32),
                    "color": color,
                    "tex": tex_uri,
                    "alpha": alpha,
                })

        if not prims:
            continue

        # build glTF
        bin_parts = []
        views = []
        accessors = []
        materials = []
        images = []
        textures = []
        mat_to_index = {}

        def add_view(data, target):
            off = sum(len(x) for x in bin_parts)
            bin_parts.append(pad4(data))
            views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
            return len(views) - 1

        def add_accessor(view, comp, typ, count, mn=None, mx=None):
            a = {"bufferView": view, "componentType": comp, "count": count, "type": typ}
            if mn is not None:
                a["min"] = mn; a["max"] = mx
            accessors.append(a)
            return len(accessors) - 1

        primitives = []
        for prim in prims:
            P = prim["P"]
            N = prim["N"]
            T = prim["T"]
            I = prim["I"]
            I = I[:, :3].reshape(-1).astype(np.uint32)
            lengths = np.linalg.norm(N, axis=1)
            lengths[lengths == 0] = 1
            N = N / lengths[:, None]
            ap = add_accessor(add_view(P.tobytes(), 34962), 5126, "VEC3", len(P), P.min(0).tolist(), P.max(0).tolist())
            an = add_accessor(add_view(N.tobytes(), 34962), 5126, "VEC3", len(N))
            at = add_accessor(add_view(T.astype(np.float32).tobytes(), 34962), 5126, "VEC2", len(T))
            ai = add_accessor(add_view(I.tobytes(), 34963), 5125, "SCALAR", len(I))
            key = (prim["tex"], prim["color"], prim["alpha"])
            if key not in mat_to_index:
                mat_index = len(materials)
                mat = {
                    "name": f"mat_{mat_index}",
                    "pbrMetallicRoughness": {
                        "baseColorFactor": [prim["color"][0], prim["color"][1], prim["color"][2], prim["color"][3]],
                        "metallicFactor": 0.0,
                        "roughnessFactor": 0.9,
                    },
                    "doubleSided": True,
                }
                if prim["tex"]:
                    images.append({"uri": prim["tex"]})
                    textures.append({"source": len(images)-1, "sampler": 0})
                    mat["pbrMetallicRoughness"]["baseColorTexture"] = {"index": len(textures)-1}
                    if prim["alpha"] == "MASK":
                        mat["alphaMode"] = "MASK"
                        mat["alphaCutoff"] = 0.5
                materials.append(mat)
                mat_to_index[key] = mat_index
            primitives.append({
                "attributes": {"POSITION": ap, "NORMAL": an, "TEXCOORD_0": at},
                "indices": ai,
                "material": mat_to_index[key],
            })

        gltf = {
            "asset": {"version": "2.0", "generator": "UnturnedGodot PEI object textured exporter"},
            "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": [{"mesh": 0, "name": asset["name"]}],
            "meshes": [{"name": asset["name"], "primitives": primitives}],
            "materials": materials,
            "images": images,
            "textures": textures,
            "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
            "buffers": [{"byteLength": sum(len(x) for x in bin_parts)}],
            "bufferViews": views,
            "accessors": accessors,
        }
        js = pad4(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
        binb = b"".join(bin_parts)
        glb = (b"glTF" + struct.pack("<II", 2, 12 + 8 + len(js) + 8 + len(binb))
               + struct.pack("<I", len(js)) + b"JSON" + js
               + struct.pack("<I", len(binb)) + b"BIN\x00" + binb)
        safe_name = asset["name"].replace("/", "_").replace("\\", "_")
        glb_name = safe_name + ".glb"
        with open(os.path.join(OUT_DIR, glb_name), "wb") as f:
            f.write(glb)
        exported[guid] = glb_name
        stats["assets"] += 1
        stats["prims"] += len(primitives)
        for obj in data["objects"]:
            if obj["guid"] != guid:
                continue
            q = euler_to_quat(obj["rx"], obj["ry"], obj["rz"])
            placements.append({
                "asset": glb_name,
                "x": obj["x"], "y": obj["y"], "z": obj["z"],
                "qx": q[0], "qy": q[1], "qz": q[2], "qw": q[3],
                "sx": obj["sx"], "sy": obj["sy"], "sz": obj["sz"],
            })
        if index % 20 == 0:
            print(f"[{index}/{len(used)}] {safe_name}: {len(primitives)} prims, {len(glb)} bytes")

    stats["textures"] = len(texture_cache)
    with open(os.path.join(MAP_DIR, "object_placements.json"), "w", encoding="utf-8") as f:
        json.dump({"assets": exported, "placements": placements}, f)
    print("done", stats)


if __name__ == "__main__":
    main()


