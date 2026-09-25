"""List sequences of GMod shared player animation models."""
import struct
import sys

DIR = r"D:\steam\steamapps\common\GarrysMod\garrysmod\garrysmod_dir.vpk"
data = open(DIR, "rb").read()
sig, ver = struct.unpack_from("<II", data, 0)
tree_size = struct.unpack_from("<I", data, 8)[0]
header = 28 if ver == 2 else 12
end = header + tree_size


def read_str(buf, i):
    j = buf.find(b"\x00", i)
    return buf[i:j].decode("latin1"), j + 1


entries = {}
p = header
while p < end:
    ext, p = read_str(data, p)
    if ext == "":
        break
    while True:
        path, p = read_str(data, p)
        if path == "":
            break
        while True:
            name, p = read_str(data, p)
            if name == "":
                break
            crc, preload, archive, offset, length = struct.unpack_from("<IHHII", data, p)
            p += 16
            pre = data[p:p + preload]
            p += preload
            p += 2  # terminator
            full = (path + "/" if path else "") + name + "." + ext
            entries[full] = (archive, offset, length, pre)


def load(full):
    archive, offset, length, pre = entries[full]
    if archive == 0x7FFF:
        body = data[end + offset:end + offset + length]
    else:
        arc = DIR.replace("_dir.vpk", "_%03d.vpk" % archive)
        with open(arc, "rb") as f:
            f.seek(offset)
            body = f.read(length)
    return pre + body


def list_seqs(full):
    mdl = load(full)
    numseq, seqindex = struct.unpack_from("<ii", mdl, 188)
    out = []
    for i in range(numseq):
        base = seqindex + i * 212
        lbl, act, flags, activity = struct.unpack_from("<iiii", mdl, base + 4)
        label, _ = read_str(mdl, base + lbl)
        actname, _ = read_str(mdl, base + act)
        out.append((label, actname, activity))
    return out


targets = [k for k in entries if k.startswith("models/") and k.endswith(".mdl") and ("anm" in k or "player/" in k)]
targets = [k for k in targets if "/" not in k[len("models/"):] or k.count("/") == 1]
print("candidates", len(targets))
for k in sorted(targets):
    if "anm" in k or k in ("models/player.mdl",):
        print(k)

def seq_detail(full, want):
    mdl = load(full)
    numseq, seqindex = struct.unpack_from("<ii", mdl, 188)
    numanim, animindex = struct.unpack_from("<ii", mdl, 180)
    for i in range(numseq):
        base = seqindex + i * 212
        lbl = struct.unpack_from("<i", mdl, base + 4)[0]
        label, _ = read_str(mdl, base + lbl)
        if label != want:
            continue
        flags = struct.unpack_from("<i", mdl, base + 12)[0]
        numblends, animindexindex = struct.unpack_from("<ii", mdl, base + 56)
        g0, g1 = struct.unpack_from("<ii", mdl, base + 68)
        fadein, fadeout = struct.unpack_from("<ff", mdl, base + 104)
        anim0 = struct.unpack_from("<h", mdl, base + animindexindex)[0]
        abase = animindex + anim0 * 100
        nameidx = struct.unpack_from("<i", mdl, abase + 4)[0]
        aname, _ = read_str(mdl, abase + nameidx)
        fps, aflags, numframes, nummove, moveidx = struct.unpack_from("<fiiii", mdl, abase + 8)
        print(f"{full} {label}: flags={flags:#x} blends={numblends} group={g0}x{g1} anim={aname} fps={fps} frames={numframes} moves={nummove} fadein={fadein} fadeout={fadeout} aflags={aflags:#x}")
        for m in range(nummove):
            mb = abase + moveidx + m * 44
            endframe, motionflags, v0, v1, angle = struct.unpack_from("<iifff", mdl, mb)
            vec = struct.unpack_from("<fff", mdl, mb + 20)
            pos = struct.unpack_from("<fff", mdl, mb + 32)
            print("   move", endframe, hex(motionflags), v0, v1, angle, vec, pos)


for full in ("models/m_anm.mdl", "models/f_anm.mdl"):
    for w in ("zombie_climb_start", "zombie_climb_loop", "zombie_climb_end", "idle_all_01", "swim_idle_all"):
        seq_detail(full, w)
