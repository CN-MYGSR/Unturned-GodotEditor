"""Export PEI trees from Trees.dat + Bundles/Trees prefabs to GLB (textured)."""
import UnityPy, numpy as np, os, json, struct, hashlib, math, uuid
from UnityPy.helpers.MeshHelper import MeshHandler

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAB = r"E:\Temp\CAB-13bab8a01683773dc7e9ece82d58bc7a"
GAME = r"E:\Steam\steamapps\common\Unturned"
OUT_DIR = os.path.join(PROJECT, "assets", "unturned", "pei_trees")
TEX_DIR = os.path.join(OUT_DIR, "textures")
MAP_DIR = os.path.join(PROJECT, "data", "maps", "PEI")


def vec(v): return (float(v.x), float(v.y), float(v.z))
def quat(q): return (float(q.x), float(q.y), float(q.z), float(q.w))


def qmul(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
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
    M = np.eye(4); M[:3, :3] = R @ np.diag(scale); M[:3, 3] = pos
    return M


def pad4(b, fill=b"\x00"): return b + fill*((4-len(b) % 4) % 4)


def main():
    os.makedirs(TEX_DIR, exist_ok=True)
    env = UnityPy.load(CAB)
    ab = next(o.read() for o in env.objects if o.type.name == "AssetBundle")
    container = {p.lower(): info.asset for p, info in ab.m_Container}

    # tree assets
    assets = {}
    for root, dirs, files in os.walk(os.path.join(GAME, "Bundles", "Trees")):
        for fn in files:
            if not fn.endswith(".dat") or fn in ("English.dat", "Schinese.dat"):
                continue
            path = os.path.join(root, fn)
            txt = open(path, encoding="utf-8-sig", errors="ignore").read()
            guid = None
            for line in txt.splitlines():
                if line.startswith("GUID "):
                    guid = line.split(None, 1)[1].strip().lower()
                    break
            if guid:
                rel = os.path.relpath(os.path.dirname(path), os.path.join(GAME, "Bundles", "Trees"))
                assets[guid] = {"name": os.path.splitext(fn)[0], "rel": rel}

    b = open(os.path.join(GAME, "Maps", "PEI", "Terrain", "Trees.dat"), "rb").read()
    count = struct.unpack_from("<H", b, 1)[0]
    records = []
    off = 7
    for i in range(count):
        raw = b[off:off+16]; off += 16
        guid = uuid.UUID(bytes_le=raw).hex
        px, py, pz = struct.unpack_from("<fff", b, off); off += 12
        rx, ry, rz = struct.unpack_from("<fff", b, off); off += 12
        sx, sy, sz = struct.unpack_from("<fff", b, off); off += 12
        off += 3
        records.append({"guid": guid, "x": px, "y": py, "z": pz, "rx": rx, "ry": ry, "rz": rz, "sx": sx, "sy": sy, "sz": sz})
    print("tree records", len(records), "off", off, "file", len(b))

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

    texture_cache = {}

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
    for guid, asset in assets.items():
        prefix = "assets/coremasterbundle/trees/" + asset["rel"].replace("\\", "/").lower() + "/resource.prefab"
        pptr = container.get(prefix)
        if pptr is None:
            continue
        root = pptr.deref_parse_as_object()
        renderers = []

        def traverse(t, parent, is_root=False):
            go = t.m_GameObject.deref_parse_as_object()
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
                p = getattr(lr, "renderer", None) or getattr(lr, "m_Renderer", None)
                if p:
                    ids.add(p.path_id)
            renderers = [(mr, w) for mr, w in renderers if mr.object_reader.path_id in ids]
        if not renderers:
            continue

        prims = []
        for mr, world in renderers:
            go = mr.m_GameObject.deref_parse_as_object()
            mfs = comps(go, "MeshFilter")
            if not mfs:
                continue
            mesh = mfs[0].m_Mesh.deref_parse_as_object()
            try:
                h = MeshHandler(mesh); h.process()
                verts = np.array(h.m_Vertices, dtype=np.float32)
                norms = np.array(h.m_Normals, dtype=np.float32) if h.m_Normals else np.zeros_like(verts)
                uvs = np.array(h.m_UV0, dtype=np.float32) if h.m_UV0 else np.zeros((len(verts), 2), dtype=np.float32)
                tris = h.get_triangles()
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
                color = (0.5, 0.5, 0.5, 1.0)
                tex_uri = None
                if mat is not None:
                    for k, v in mat.m_SavedProperties.m_Colors:
                        nm = k if isinstance(k, str) else k.name
                        if nm == "_Color":
                            color = (float(v.r), float(v.g), float(v.b), float(v.a)); break
                    for k, v in mat.m_SavedProperties.m_TexEnvs:
                        nm = k if isinstance(k, str) else k.name
                        if nm == "_MainTex" and v.m_Texture:
                            try:
                                tex = v.m_Texture.deref_parse_as_object()
                                if tex: tex_uri = save_texture(tex)
                            except Exception: pass
                            break
                v4 = np.c_[verts, np.ones(len(verts))]
                w = (world @ v4.T).T[:, :3]
                nmx = np.linalg.inv(world[:3, :3]).T
                wn = (nmx @ norms.T).T
                prims.append({"P": w.astype(np.float32), "N": wn.astype(np.float32), "T": uvs, "I": tri.reshape(-1, 3), "color": color, "tex": tex_uri})

        if not prims:
            continue
        bin_parts, views, accessors, materials, images, textures = [], [], [], [], [], []
        mat_to_index = {}

        def add_view(data, target):
            off = sum(len(x) for x in bin_parts)
            bin_parts.append(pad4(data)); views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
            return len(views)-1

        def add_acc(view, comp, typ, count, mn=None, mx=None):
            a = {"bufferView": view, "componentType": comp, "count": count, "type": typ}
            if mn is not None: a["min"] = mn; a["max"] = mx
            accessors.append(a); return len(accessors)-1

        primitives = []
        for prim in prims:
            P, N, T, I = prim["P"], prim["N"], prim["T"], prim["I"].reshape(-1).astype(np.uint32)
            lens = np.linalg.norm(N, axis=1); lens[lens == 0] = 1; N = N/lens[:, None]
            ap = add_acc(add_view(P.tobytes(), 34962), 5126, "VEC3", len(P), P.min(0).tolist(), P.max(0).tolist())
            an = add_acc(add_view(N.tobytes(), 34962), 5126, "VEC3", len(N))
            at = add_acc(add_view(T.astype(np.float32).tobytes(), 34962), 5126, "VEC2", len(T))
            ai = add_acc(add_view(I.tobytes(), 34963), 5125, "SCALAR", len(I))
            key = (prim["tex"], prim["color"])
            if key not in mat_to_index:
                mi = len(materials)
                mat = {"name": f"mat_{mi}", "pbrMetallicRoughness": {"baseColorFactor": list(prim["color"]), "metallicFactor": 0.0, "roughnessFactor": 0.9}, "doubleSided": True}
                if prim["tex"]:
                    images.append({"uri": prim["tex"]}); textures.append({"source": len(images)-1, "sampler": 0})
                    mat["pbrMetallicRoughness"]["baseColorTexture"] = {"index": len(textures)-1}
                    mat["alphaMode"] = "MASK"; mat["alphaCutoff"] = 0.5
                materials.append(mat); mat_to_index[key] = mi
            primitives.append({"attributes": {"POSITION": ap, "NORMAL": an, "TEXCOORD_0": at}, "indices": ai, "material": mat_to_index[key]})
        gltf = {"asset": {"version": "2.0", "generator": "UnturnedGodot PEI tree exporter"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": asset["name"]}], "meshes": [{"name": asset["name"], "primitives": primitives}], "materials": materials, "images": images, "textures": textures, "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}], "buffers": [{"byteLength": sum(len(x) for x in bin_parts)}], "bufferViews": views, "accessors": accessors}
        js = pad4(json.dumps(gltf, separators=(",", ":")).encode(), b" "); binb = b"".join(bin_parts)
        glb = b"glTF"+struct.pack("<II", 2, 12+8+len(js)+8+len(binb))+struct.pack("<I", len(js))+b"JSON"+js+struct.pack("<I", len(binb))+b"BIN\x00"+binb
        glb_name = asset["name"].replace("/", "_") + ".glb"
        open(os.path.join(OUT_DIR, glb_name), "wb").write(glb)
        exported[guid] = glb_name

    for rec in records:
        asset = assets.get(rec["guid"])
        if not asset or rec["guid"] not in exported:
            continue
        q = euler_to_quat(rec["rx"], rec["ry"], rec["rz"])
        placements.append({"asset": exported[rec["guid"]], "x": rec["x"], "y": rec["y"], "z": rec["z"],
                           "qx": q[0], "qy": q[1], "qz": q[2], "qw": q[3],
                           "sx": rec["sx"], "sy": rec["sy"], "sz": rec["sz"]})
    json.dump({"assets": exported, "placements": placements}, open(os.path.join(MAP_DIR, "tree_placements.json"), "w", encoding="utf-8"))
    print("trees exported", len(exported), "placements", len(placements), "textures", len(texture_cache))


if __name__ == "__main__":
    main()

