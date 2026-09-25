import struct

mdl_path = r"C:\Users\Egor\Desktop\Relapse\gamemodes\zombiesurvival\content\models\ammo\fas2\ammocrate.mdl"
vvd_path = r"C:\Users\Egor\Desktop\Relapse\gamemodes\zombiesurvival\content\models\ammo\fas2\ammocrate.vvd"
mdl = open(mdl_path, "rb").read()
vvd = open(vvd_path, "rb").read()

def s(off, n=64):
    raw = mdl[off:off + n]
    z = raw.find(b"\x00")
    return raw[:z].decode("latin1", "replace") if z >= 0 else ""

# studiohdr
numbones, boneindex = struct.unpack_from("<ii", mdl, 156)
print("bones", numbones, "at", boneindex)
# bone stride 216 in v48/v49? check name
for i in range(numbones):
    b = boneindex + i * 216
    name_off = struct.unpack_from("<i", mdl, b)[0]
    parent = struct.unpack_from("<i", mdl, b + 4)[0]
    pos = struct.unpack_from("<fff", mdl, b + 20)  # maybe
    # surfaceprop / name
    print(i, "parent", parent, "nameoff", name_off, s(b + name_off) if name_off > -1000 else "?")

b0 = boneindex
print("bone0 floats from 8:")
for off in range(8, 80, 4):
    f = struct.unpack_from("<f", mdl, b0 + off)[0]
    i = struct.unpack_from("<i", mdl, b0 + off)[0]
    print(off, "f", round(f, 4), "i", i)
print("--- vvd", len(vvd), vvd[:4])
id, ver, checksum = struct.unpack_from("<iii", vvd, 0)
numLODs = struct.unpack_from("<i", vvd, 12)[0]
numLOD = struct.unpack_from("<8i", vvd, 16)
numFixups, fixupStart, vertexStart, tangentStart = struct.unpack_from("<iiii", vvd, 48)
print("ver", ver, "lods", numLODs, "counts", numLOD, "fixups", numFixups, "vstart", vertexStart)

# try 48-byte vertices
n = numLOD[0]
base = vertexStart
per = {i: [1e9, 1e9, 1e9, -1e9, -1e9, -1e9, 0] for i in range(numbones)}
for i in range(n):
    o = base + i * 48
    bone = vvd[o + 12]
    x, y, z = struct.unpack_from("<fff", vvd, o + 16)
    b = per[bone]
    b[0] = min(b[0], x)
    b[1] = min(b[1], y)
    b[2] = min(b[2], z)
    b[3] = max(b[3], x)
    b[4] = max(b[4], y)
    b[5] = max(b[5], z)
    b[6] += 1
# histogram of root Y (model -X front/back) and root X (model Y sides)
from collections import Counter
hy, hx, hz = Counter(), Counter(), Counter()
for i in range(n):
    o = base + i * 48
    if vvd[o + 12] != 0:
        continue
    x, y, z = struct.unpack_from("<fff", vvd, o + 16)
    hy[round(y, 1)] += 1
    hx[round(x, 1)] += 1
    hz[round(z, 1)] += 1
print("root Y extremes (model X = -Y)")
for k in sorted(hy):
    if k < -20 or k > 14:
        print(" y", k, "modelX", round(-k, 2), "n", hy[k])
print("root X extremes (model Y = X)")
for k in sorted(hx):
    if k < -34 or k > 36:
        print(" x", k, "modelY", round(k, 2), "n", hx[k])
print("root Z top")
for k in sorted(hz):
    if k > 32:
        print(" z", k, "n", hz[k])
names = ["Root", "leftlock", "rightlock", "clasp", "lid", "topscissor", "bottomscissor"]
for i, b in per.items():
    if b[6] == 0:
        continue
    print(names[i], "n", b[6], "min", [round(v, 2) for v in b[:3]], "max", [round(v, 2) for v in b[3:6]])
