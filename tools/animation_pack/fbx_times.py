import struct, zlib, sys, json, os, glob
TICKS = 46186158000.0

def read_node(b, off, ver):
    if ver >= 7500:
        end, nprops, plen, nlen = struct.unpack_from("<QQQB", b, off); hdr = 25
    else:
        end, nprops, plen, nlen = struct.unpack_from("<IIIB", b, off); hdr = 13
    if end == 0: return None, off + hdr
    name = b[off + hdr: off + hdr + nlen].decode("latin1")
    p = off + hdr + nlen
    props = []
    for _ in range(nprops):
        t = chr(b[p]); p += 1
        if t in "YCIFDL":
            sz = {"Y": 2, "C": 1, "I": 4, "F": 4, "D": 8, "L": 8}[t]
            fmt = {"Y": "<h", "C": "<B", "I": "<i", "F": "<f", "D": "<d", "L": "<q"}[t]
            props.append((t, struct.unpack_from(fmt, b, p)[0])); p += sz
        elif t in "fdlib":
            n, enc, clen = struct.unpack_from("<III", b, p); p += 12
            raw = b[p:p + clen]; p += clen
            if enc == 1: raw = zlib.decompress(raw)
            esz = {"f": 4, "d": 8, "l": 8, "i": 4, "b": 1}[t]
            fmt = {"f": "f", "d": "d", "l": "q", "i": "i", "b": "B"}[t]
            props.append((t, struct.unpack("<%d%s" % (n, fmt), raw[:n * esz])))
        elif t in "SR":
            n = struct.unpack_from("<I", b, p)[0]; p += 4
            props.append((t, b[p:p + n])); p += n
        else:
            raise ValueError(t)
    children = []
    while p < end:
        c, p2 = read_node(b, p, ver)
        if c is None: p = p2; break
        children.append(c); p = p2
    return (name, props, children), end

def walk(node, out):
    name, props, ch = node
    if name == "AnimationCurve":
        times = None
        for c in ch:
            if c[0] == "KeyTime": times = c[1][0][1]
        if times: out.append(times)
    for c in ch: walk(c, out)

def curves(path):
    b = open(path, "rb").read()
    ver = struct.unpack_from("<I", b, 23)[0]
    off = 27
    out = []
    while True:
        n, off2 = read_node(b, off, ver)
        if n is None: break
        walk(n, out); off = off2
    return out

if __name__ == "__main__":
    root = sys.argv[1]
    res = {}
    for f in sorted(glob.glob(root + "/animaciones/*/*.fbx")):
        cs = curves(f)
        if not cs: res[os.path.relpath(f, root + "/animaciones")] = None; continue
        t0 = min(c[0] for c in cs); t1 = max(c[-1] for c in cs)
        res[os.path.relpath(f, root + "/animaciones")] = {"curves": len(cs), "t0": t0 / TICKS, "t1": t1 / TICKS, "max_keys": max(len(c) for c in cs), "min_keys": min(len(c) for c in cs)}
    json.dump(res, open(sys.argv[2], "w"))
    print(len(res), "FBX leidos")
