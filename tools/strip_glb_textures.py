#!/usr/bin/env python3
"""Quita las texturas de un GLB (deja malla, esqueleto, skin y animaciones).

Las texturas pesadas (2048^2) se sustituyen por una textura de color de 1024^2 y mascaras
generadas aparte (tools/make_player_textures.py); el material se asigna en Godot.

Uso: python3 tools/strip_glb_textures.py entrada.glb salida.glb [--no-anims]
  --no-anims  tambien elimina las animaciones (y los datos de fotogramas clave)
"""
import json
import struct
import sys


def read_glb(path):
    data = open(path, "rb").read()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF", "no es un GLB"
    off = 12
    gltf, binchunk = None, b""
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


def write_glb(path, gltf, binchunk):
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    binchunk += b"\x00" * ((4 - len(binchunk) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binchunk)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(binchunk), b"BIN\x00") + binchunk)


def prune_animations(gltf):
    """Elimina animaciones y los accessors/bufferViews que solo ellas usaban."""
    gltf.pop("animations", None)
    used = set()
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            used.update(prim.get("attributes", {}).values())
            if "indices" in prim:
                used.add(prim["indices"])
            for tgt in prim.get("targets", []):
                used.update(tgt.values())
    for sk in gltf.get("skins", []):
        if "inverseBindMatrices" in sk:
            used.add(sk["inverseBindMatrices"])
    remap_acc = {}
    new_acc = []
    for i, acc in enumerate(gltf.get("accessors", [])):
        if i in used:
            remap_acc[i] = len(new_acc)
            new_acc.append(acc)
    gltf["accessors"] = new_acc
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            prim["attributes"] = {k: remap_acc[v] for k, v in prim["attributes"].items()}
            if "indices" in prim:
                prim["indices"] = remap_acc[prim["indices"]]
            for tgt in prim.get("targets", []):
                for k in list(tgt):
                    tgt[k] = remap_acc[tgt[k]]
    for sk in gltf.get("skins", []):
        if "inverseBindMatrices" in sk:
            sk["inverseBindMatrices"] = remap_acc[sk["inverseBindMatrices"]]
    # bufferViews sin accessors: se descartan en strip() (ver keep_views).
    return {acc.get("bufferView") for acc in new_acc if "bufferView" in acc}


def strip(src, dst, no_anims=False):
    gltf, binchunk = read_glb(src)
    image_views = {img["bufferView"] for img in gltf.get("images", []) if "bufferView" in img}
    if no_anims:
        keep = prune_animations(gltf)
        image_views |= {i for i in range(len(gltf["bufferViews"])) if i not in keep}
    # Reconstruye el BIN sin las vistas de imagen, conservando alineacion de 4 bytes.
    new_bin = bytearray()
    remap = {}
    new_views = []
    for i, bv in enumerate(gltf["bufferViews"]):
        if i in image_views:
            continue
        start = bv.get("byteOffset", 0)
        raw = binchunk[start:start + bv["byteLength"]]
        pad = (4 - len(new_bin) % 4) % 4
        new_bin += b"\x00" * pad
        nbv = dict(bv)
        nbv["byteOffset"] = len(new_bin)
        new_bin += raw
        remap[i] = len(new_views)
        new_views.append(nbv)
    gltf["bufferViews"] = new_views
    for acc in gltf.get("accessors", []):
        if "bufferView" in acc:
            acc["bufferView"] = remap[acc["bufferView"]]
    for sk in gltf.get("skins", []):
        if "inverseBindMatrices" in sk:
            pass  # indice de accessor: no cambia
    for key in ("images", "textures", "samplers"):
        gltf.pop(key, None)
    for mat in gltf.get("materials", []):
        pbr = mat.get("pbrMetallicRoughness", {})
        pbr.pop("baseColorTexture", None)
        pbr.pop("metallicRoughnessTexture", None)
        pbr["metallicFactor"] = 0.0
        pbr["roughnessFactor"] = 0.8
        mat["pbrMetallicRoughness"] = pbr
        mat.pop("normalTexture", None)
        mat.pop("occlusionTexture", None)
        mat.pop("emissiveTexture", None)
    gltf["buffers"] = [{"byteLength": len(new_bin)}]
    write_glb(dst, gltf, bytes(new_bin))
    print(f"{src} -> {dst}: {len(new_bin)} bytes de BIN, imagenes eliminadas")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    strip(sys.argv[1], sys.argv[2], "--no-anims" in sys.argv)
