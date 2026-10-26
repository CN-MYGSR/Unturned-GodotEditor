"""Export the object prefabs used by PEI from Unturned's core.masterbundle to GLB.

Input: decompressed core masterbundle serialized files (CAB-main) produced from
Bundles/core.masterbundle, and data/maps/PEI/objects.json (parsed Objects.dat).
Output: assets/unturned/pei_objects/<Asset>.glb and object_placements.json.

Only LOD0 renderers are exported. Materials are baked into vertex colors.
"""
import UnityPy, numpy as np, os, json, struct, sys, hashlib, math

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAB = r"E:\Temp\CAB-main"
GAME = r"E:\Steam\steamapps\common\Unturned"
OUT_DIR = os.path.join(PROJECT, "assets", "unturned", "pei_objects")
MAP_DIR = os.path.join(PROJECT, "data", "maps", "PEI")


def cstr(v):
    return f"{v.x},{v.y},{v.z}"


def vec(v):
    return (float(v.x), float(v.y), float(v.z))


def quat(q):
    return (float(q.x), float(q.y), float(q.z), float(q.w))


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def euler_to_quat(rx, ry, rz):
    hx, hy, hz = math.radians(rx) * 0.5, math.radians(ry) * 0.5, math.radians(rz) * 0.5
    qx = (math.sin(hx), 0.0, 0.0, math.cos(hx))
    qy = (0.0, math.sin(hy), 0.0, math.cos(hy))
    qz = (0.0, 0.0, math.sin(hz), math.cos(hz))
    return qmul(qmul(qy, qx), qz)


def mat_trs(pos, rot, scale):
    x, y, z, w = rot
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    R = np.array([
        [1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy)],
        [2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx)],
        [2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy)],
    ], dtype=np.float64)
    M = np.eye(4)
    M[:3, :3] = R @ np.diag(scale)
    M[:3, 3] = pos
    return M


def pad4(b, fill=b"\x00"):
    return b + fill * ((4 - len(b) % 4) % 4)


def write_glb(path, name, P, N, C, I):
    bin_parts = []
    views = []
    accessors = []

    def add_view(data, target):
        off = sum(len(x) for x in bin_parts)
        bin_parts.append(pad4(data))
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        return len(views) - 1

    def add_accessor(view, comp, typ, count, mn=None, mx=None):
        acc = {"bufferView": view, "componentType": comp, "count": count, "type": typ}
        if mn is not None:
            acc["min"] = mn
            acc["max"] = mx
        accessors.append(acc)
        return len(accessors) - 1

    ap = add_accessor(add_view(P.tobytes(), 34962), 5126, "VEC3", len(P), P.min(0).tolist(), P.max(0).tolist())
    an = add_accessor(add_view(N.tobytes(), 34962), 5126, "VEC3", len(N))
    ac = add_accessor(add_view(C.tobytes(), 34962), 5126, "VEC4", len(C))
    ai = add_accessor(add_view(I.tobytes(), 34963), 5125, "SCALAR", len(I))
    gltf = {
        "asset": {"version": "2.0", "generator": "UnturnedGodot PEI object exporter"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [{
            "attributes": {"POSITION": ap, "NORMAL": an, "COLOR_0": ac},
            "indices": ai, "material": 0,
        }]}],
        "materials": [{"name": "pei_object", "pbrMetallicRoughness": {
            "baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.9,
        }}],
        "buffers": [{"byteLength": sum(len(x) for x in bin_parts)}],
        "bufferViews": views,
        "accessors": accessors,
    }
    js = pad4(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
    binb = b"".join(bin_parts)
    glb = (b"glTF" + struct.pack("<II", 2, 12 + 8 + len(js) + 8 + len(binb))
           + struct.pack("<I", len(js)) + b"JSON" + js
           + struct.pack("<I", len(binb)) + b"BIN\x00" + binb)
    with open(path, "wb") as f:
        f.write(glb)
    return len(glb)


def palette_for(name, path):
    lower = (name + " " + path).lower()
    if any(k in lower for k in ("fence", "wood", "plank", "lumber")):
        base = (0.45, 0.32, 0.20)
    elif any(k in lower for k in ("metal", "steel", "pipe", "rail", "car", "truck")):
        base = (0.45, 0.47, 0.50)
    elif any(k in lower for k in ("boulder", "rock", "stone", "cliff")):
        base = (0.42, 0.41, 0.38)
    elif any(k in lower for k in ("crop", "grass", "tree", "foliage", "bush", "plant")):
        base = (0.25, 0.45, 0.18)
    elif any(k in lower for k in ("building", "house", "wall", "roof", "shop", "office", "school")):
        base = (0.62, 0.56, 0.46)
    elif any(k in lower for k in ("concrete", "block", "brick")):
        base = (0.55, 0.54, 0.50)
    else:
        base = (0.52, 0.52, 0.52)
    h = int(hashlib.md5(name.encode("utf-8")).hexdigest()[:4], 16) / 65535.0
    return tuple(max(0.06, min(0.92, c * (0.82 + 0.36 * h))) for c in base)


def main():
    env = UnityPy.load(CAB)
    ab = next(o.read() for o in env.objects if o.type.name == "AssetBundle")
    container = {}
    for entry in ab.m_Container:
        path, info = entry
        container[path.lower()] = info.asset

    with open(os.path.join(MAP_DIR, "objects.json"), "r", encoding="utf-8") as f:
        data = json.load(f)
    assets = data["assets"]
    used = sorted({o["guid"] for o in data["objects"]})

    os.makedirs(OUT_DIR, exist_ok=True)
    exported = {}
    placements = []

    def get_transform(go):
        for comp in go.m_Component:
            pptr = comp[1] if isinstance(comp, tuple) else comp.component
            obj = pptr.deref()
            if obj and obj.type.name == "Transform":
                return pptr.deref_parse_as_object()
        return None

    def comps(go, typename):
        out = []
        for comp in go.m_Component:
            pptr = comp[1] if isinstance(comp, tuple) else comp.component
            obj = pptr.deref()
            if obj and obj.type.name == typename:
                out.append(pptr.deref_parse_as_object())
        return out

    for index, guid in enumerate(used):
        asset = assets.get(guid)
        if not asset:
            continue
        rel = os.path.relpath(os.path.dirname(asset["path"]), os.path.join(GAME, "Bundles", "Objects"))
        prefix = ("assets/coremasterbundle/objects/" + rel.replace("\\", "/").lower() + "/object.prefab")
        pptr = container.get(prefix)
        if pptr is None:
            continue
        root = pptr.deref_parse_as_object()
        renderers = []

        def traverse(transform, parent):
            go = transform.m_GameObject.deref_parse_as_object()
            world = parent @ mat_trs(vec(transform.m_LocalPosition), quat(transform.m_LocalRotation), vec(transform.m_LocalScale))
            for mr in comps(go, "MeshRenderer"):
                renderers.append((mr, world))
            for child in transform.m_Children:
                traverse(child.deref_parse_as_object(), world)

        traverse(get_transform(root), np.eye(4))
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

        P, N, C, I = [], [], [], []
        base = 0
        for mr, world in renderers:
            go = mr.m_GameObject.deref_parse_as_object()
            mfs = comps(go, "MeshFilter")
            if not mfs:
                continue
            mesh = mfs[0].m_Mesh.deref_parse_as_object()
            handler = __import__("UnityPy.helpers.MeshHelper", fromlist=["MeshHandler"]).MeshHandler(mesh)
            handler.process()
            verts = np.array(handler.m_Vertices, dtype=np.float32)
            norms = np.array(handler.m_Normals, dtype=np.float32) if handler.m_Normals else np.zeros_like(verts)
            tris = handler.get_triangles()
            mats = []
            for mat_ptr in mr.m_Materials:
                try:
                    mats.append(mat_ptr.deref_parse_as_object())
                except Exception:
                    mats.append(None)
            fallback = palette_for(asset["name"], asset["path"])
            for sub_index, tri in enumerate(tris):
                tri = np.array(tri, dtype=np.int64)
                if not len(tri):
                    continue
                mat = mats[sub_index] if sub_index < len(mats) else (mats[0] if mats else None)
                color = fallback
                if mat is not None:
                    for key, value in mat.m_SavedProperties.m_Colors:
                        key_name = key if isinstance(key, str) else key.name
                        if key_name == "_Color":
                            rgb = (float(value.r), float(value.g), float(value.b))
                            if max(rgb) > 0.93 and min(rgb) > 0.9:
                                color = fallback
                            else:
                                color = rgb
                            break
                v4 = np.c_[verts, np.ones(len(verts))]
                w = (world @ v4.T).T[:, :3]
                nmat = np.linalg.inv(world[:3, :3]).T
                wn = (nmat @ norms.T).T
                idx = tri.reshape(-1, 3).copy()
                P.append(w.astype(np.float32))
                N.append(wn.astype(np.float32))
                C.append(np.tile(np.array([*color, 1.0], dtype=np.float32), (len(w), 1)))
                I.append(idx + base)
                base += len(w)
        if not P:
            continue
        P = np.concatenate(P)
        N = np.concatenate(N)
        C = np.concatenate(C)
        I = np.concatenate(I).astype(np.uint32)
        I = I[: len(I) // 3 * 3]
        lengths = np.linalg.norm(N, axis=1)
        lengths[lengths == 0] = 1
        N = N / lengths[:, None]
        safe_name = asset["name"].replace("/", "_").replace("\\", "_")
        glb_name = safe_name + ".glb"
        path = os.path.join(OUT_DIR, glb_name)
        size = write_glb(path, safe_name, P, N, C, I)
        exported[guid] = glb_name
        for obj in data["objects"]:
            if obj["guid"] == guid:
                q = euler_to_quat(obj["rx"], obj["ry"], obj["rz"])
                placements.append({
                    "asset": glb_name,
                    "kind": asset["type"],
                    "x": obj["x"], "y": obj["y"], "z": obj["z"],
                    "qx": q[0], "qy": q[1], "qz": q[2], "qw": q[3],
                    "sx": obj["sx"], "sy": obj["sy"], "sz": obj["sz"],
                })
        if index % 25 == 0:
            print(f"[{index}/{len(used)}] {safe_name}: {len(P)} verts {size} bytes")

    with open(os.path.join(MAP_DIR, "object_placements.json"), "w", encoding="utf-8") as f:
        json.dump({"assets": exported, "placements": placements}, f)
    print("exported", len(exported), "assets,", len(placements), "placements")


if __name__ == "__main__":
    main()

