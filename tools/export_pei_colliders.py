"""Export colliders for PEI objects and trees from the core AssetBundle prefabs.

Writes data/maps/PEI/colliders.json:
  { "objects": { "<Asset>.glb": { "mesh_faces": [...], "boxes": [...], "capsules": [...] } },
    "trees":   { ... } }
Coordinates are prefab-local with the prefab root transform skipped, matching the
visual GLB export.
"""
import UnityPy, numpy as np, os, json, math, uuid
from UnityPy.helpers.MeshHelper import MeshHandler

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAB = r"E:\Temp\CAB-13bab8a01683773dc7e9ece82d58bc7a"
GAME = r"E:\Steam\steamapps\common\Unturned"
MAP_DIR = os.path.join(PROJECT, "data", "maps", "PEI")


def vec(v): return (float(v.x), float(v.y), float(v.z))
def quat(q): return (float(q.x), float(q.y), float(q.z), float(q.w))


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


def main():
    env = UnityPy.load(CAB)
    ab = next(o.read() for o in env.objects if o.type.name == "AssetBundle")
    container = {p.lower(): info.asset for p, info in ab.m_Container}

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

    def extract(root):
        faces = []
        boxes = []
        capsules = []

        def walk(t, parent, is_root=False):
            go = t.m_GameObject.deref_parse_as_object()
            world = parent if is_root else parent @ mat_trs(vec(t.m_LocalPosition), quat(t.m_LocalRotation), vec(t.m_LocalScale))
            for mc in comps(go, "MeshCollider"):
                try:
                    mesh = mc.m_Mesh.deref_parse_as_object()
                    if mesh is None:
                        continue
                    handler = MeshHandler(mesh); handler.process()
                    verts = np.array(handler.m_Vertices, dtype=np.float64)
                    if not len(verts):
                        continue
                    v4 = np.c_[verts, np.ones(len(verts))]
                    w = (world @ v4.T).T[:, :3]
                    for tri in handler.get_triangles():
                        arr = np.array(tri, dtype=np.int64).reshape(-1, 3)
                        for a, b, c in arr:
                            faces.append([*w[a].tolist(), *w[b].tolist(), *w[c].tolist()])
                except Exception:
                    pass
            for bc in comps(go, "BoxCollider"):
                try:
                    center = np.array([float(bc.m_Center.x), float(bc.m_Center.y), float(bc.m_Center.z)])
                    origin = (world @ np.array([center[0], center[1], center[2], 1.0]))[:3]
                    rot = world[:3, :3]
                    # rotation+scale via quaternion-free approach: store basis columns
                    boxes.append({
                        "origin": origin.tolist(),
                        "basis": [rot[0, 0], rot[0, 1], rot[0, 2],
                                  rot[1, 0], rot[1, 1], rot[1, 2],
                                  rot[2, 0], rot[2, 1], rot[2, 2]],
                        "size": [float(bc.m_Size.x), float(bc.m_Size.y), float(bc.m_Size.z)],
                    })
                except Exception:
                    pass
            for cc in comps(go, "CapsuleCollider"):
                try:
                    center = np.array([float(cc.m_Center.x), float(cc.m_Center.y), float(cc.m_Center.z)])
                    origin = (world @ np.array([center[0], center[1], center[2], 1.0]))[:3]
                    rot = world[:3, :3]
                    capsules.append({
                        "origin": origin.tolist(),
                        "basis": [rot[0, 0], rot[0, 1], rot[0, 2],
                                  rot[1, 0], rot[1, 1], rot[1, 2],
                                  rot[2, 0], rot[2, 1], rot[2, 2]],
                        "radius": float(cc.m_Radius),
                        "height": float(cc.m_Height),
                        "direction": int(cc.m_Direction),
                    })
                except Exception:
                    pass
            for ch in t.m_Children:
                walk(ch.deref_parse_as_object(), world)

        walk(get_transform(root), np.eye(4), True)
        return {"mesh_faces": faces, "boxes": boxes, "capsules": capsules}

    objects = {}
    trees = {}

    data = json.load(open(os.path.join(MAP_DIR, "objects.json"), encoding="utf-8"))
    for guid in sorted({o["guid"] for o in data["objects"]}):
        asset = data["assets"].get(guid)
        if not asset:
            continue
        rel = os.path.relpath(os.path.dirname(asset["path"]), os.path.join(GAME, "Bundles", "Objects"))
        pptr = container.get("assets/coremasterbundle/objects/" + rel.replace("\\", "/").lower() + "/object.prefab")
        if pptr is None:
            continue
        root = pptr.deref_parse_as_object()
        result = extract(root)
        if result["mesh_faces"] or result["boxes"] or result["capsules"]:
            objects[asset["name"] + ".glb"] = result
        if len(objects) % 40 == 0:
            print("objects", len(objects))

    # trees
    tree_assets = {}
    for root, dirs, files in os.walk(os.path.join(GAME, "Bundles", "Trees")):
        for fn in files:
            if not fn.endswith(".dat") or fn in ("English.dat", "Schinese.dat"):
                continue
            path = os.path.join(root, fn)
            txt = open(path, encoding="utf-8-sig", errors="ignore").read()
            guid = None
            for line in txt.splitlines():
                if line.startswith("GUID "):
                    guid = line.split(None, 1)[1].strip().lower(); break
            if guid:
                tree_assets[guid] = {"name": os.path.splitext(fn)[0], "rel": os.path.relpath(os.path.dirname(path), os.path.join(GAME, "Bundles", "Trees"))}
    b = open(os.path.join(GAME, "Maps", "PEI", "Terrain", "Trees.dat"), "rb").read()
    count = int.from_bytes(b[1:3], "little")
    off = 7
    used_tree_guids = set()
    for _ in range(count):
        raw = b[off:off+16]; off += 16
        used_tree_guids.add(uuid.UUID(bytes_le=raw).hex)
        off += 12 + 12 + 12 + 3
    for guid in sorted(used_tree_guids):
        asset = tree_assets.get(guid)
        if not asset:
            continue
        pptr = container.get("assets/coremasterbundle/trees/" + asset["rel"].replace("\\", "/").lower() + "/resource.prefab")
        if pptr is None:
            continue
        root = pptr.deref_parse_as_object()
        result = extract(root)
        if result["mesh_faces"] or result["boxes"] or result["capsules"]:
            trees[asset["name"] + ".glb"] = result

    out = {"objects": objects, "trees": trees}
    json.dump(out, open(os.path.join(MAP_DIR, "colliders.json"), "w", encoding="utf-8"))
    print("colliders objects", len(objects), "trees", len(trees),
          "faces", sum(len(v["mesh_faces"]) for v in objects.values()) + sum(len(v["mesh_faces"]) for v in trees.values()))


if __name__ == "__main__":
    main()
