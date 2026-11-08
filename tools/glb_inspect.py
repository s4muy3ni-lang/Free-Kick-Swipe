#!/usr/bin/env python3
"""Inspector de GLB sin dependencias externas (solo stdlib + numpy opcional).

Uso: python3 tools/glb_inspect.py modelo.glb [--json]

Informa: triangulos reales, vertices, mallas, materiales, texturas (tamano en
bytes y dimensiones), skins/huesos, animaciones y bounding box.
"""
import json
import struct
import sys


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("no es un GLB valido")
    off = 12
    gltf = None
    binchunk = b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<I4s", data, off)
        off += 8
        chunk = data[off:off + clen]
        off += clen
        if ctype == b"JSON":
            gltf = json.loads(chunk.decode("utf-8"))
        elif ctype == b"BIN\x00":
            binchunk = chunk
    return gltf, binchunk


def image_size(gltf, binchunk, img):
    """Devuelve (ancho, alto, bytes) leyendo la cabecera PNG/JPEG/WebP."""
    if "bufferView" not in img:
        return None, None, None
    bv = gltf["bufferViews"][img["bufferView"]]
    raw = binchunk[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
    w = h = None
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        w, h = struct.unpack(">II", raw[16:24])
    elif raw[:2] == b"\xff\xd8":
        i = 2
        while i < len(raw):
            if raw[i] != 0xFF:
                i += 1
                continue
            marker = raw[i + 1]
            if marker in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", raw[i + 5:i + 9])
                break
            seglen = struct.unpack(">H", raw[i + 2:i + 4])[0]
            i += 2 + seglen
    elif raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        if raw[12:16] == b"VP8 ":
            w, h = struct.unpack("<HH", raw[26:30])
            w &= 0x3FFF
            h &= 0x3FFF
        elif raw[12:16] == b"VP8L":
            b = struct.unpack("<I", raw[21:25])[0]
            w = (b & 0x3FFF) + 1
            h = ((b >> 14) & 0x3FFF) + 1
    return w, h, len(raw)


def inspect(path):
    gltf, binchunk = read_glb(path)
    acc = gltf.get("accessors", [])
    report = {"file": path, "meshes": [], "total_triangles": 0, "total_vertices": 0}
    for mi, mesh in enumerate(gltf.get("meshes", [])):
        for pi, prim in enumerate(mesh.get("primitives", [])):
            mode = prim.get("mode", 4)
            vcount = acc[prim["attributes"]["POSITION"]]["count"]
            if "indices" in prim:
                icount = acc[prim["indices"]]["count"]
            else:
                icount = vcount
            tris = icount // 3 if mode == 4 else 0
            report["meshes"].append({
                "mesh": mesh.get("name", f"mesh{mi}"), "primitive": pi,
                "vertices": vcount, "triangles": tris,
                "attributes": sorted(prim["attributes"].keys()),
                "material": prim.get("material"),
                "morph_targets": len(prim.get("targets", [])),
            })
            report["total_triangles"] += tris
            report["total_vertices"] += vcount
    report["materials"] = [m.get("name", "") for m in gltf.get("materials", [])]
    imgs = []
    for img in gltf.get("images", []):
        w, h, n = image_size(gltf, binchunk, img)
        imgs.append({"name": img.get("name", ""), "mime": img.get("mimeType"),
                     "width": w, "height": h, "bytes": n})
    report["images"] = imgs
    skins = gltf.get("skins", [])
    report["skins"] = []
    for sk in skins:
        names = [gltf["nodes"][j].get("name", f"node{j}") for j in sk.get("joints", [])]
        report["skins"].append({"joint_count": len(names), "joints": names})
    anims = []
    for a in gltf.get("animations", []):
        dur = 0.0
        for s in a.get("samplers", []):
            ac = acc[s["input"]]
            if "max" in ac:
                dur = max(dur, ac["max"][0])
        anims.append({"name": a.get("name", ""), "channels": len(a.get("channels", [])), "duration_s": round(dur, 3)})
    report["animations"] = anims
    pos_acc = [acc[p["attributes"]["POSITION"]] for m in gltf.get("meshes", []) for p in m["primitives"]]
    if pos_acc and all("min" in a and "max" in a for a in pos_acc):
        mn = [min(a["min"][i] for a in pos_acc) for i in range(3)]
        mx = [max(a["max"][i] for a in pos_acc) for i in range(3)]
        report["bbox_min"] = mn
        report["bbox_max"] = mx
        report["size"] = [round(mx[i] - mn[i], 3) for i in range(3)]
    return report


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    r = inspect(sys.argv[1])
    if "--json" in sys.argv:
        print(json.dumps(r, indent=2))
    else:
        print(f"Archivo: {r['file']}")
        print(f"Triangulos totales: {r['total_triangles']}  Vertices: {r['total_vertices']}")
        for m in r["meshes"]:
            print(f"  malla {m['mesh']} prim{m['primitive']}: {m['triangles']} tris, {m['vertices']} verts, attrs={m['attributes']}, morphs={m['morph_targets']}")
        print(f"Materiales: {r['materials']}")
        for i in r["images"]:
            print(f"  imagen {i['name']}: {i['width']}x{i['height']} {i['mime']} {i['bytes']} bytes")
        for s in r["skins"]:
            print(f"Skin: {s['joint_count']} huesos")
        print(f"Animaciones: {len(r['animations'])}")
        for a in r["animations"]:
            print(f"  {a['name']}: {a['duration_s']}s, {a['channels']} canales")
        if "size" in r:
            print(f"BBox size (m): {r['size']}")
