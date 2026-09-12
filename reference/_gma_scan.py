path = r"D:\steam\steamapps\workshop\content\4000\2459720887\gmpublisher.gma"
needles = [
    b"SetMaxClientSpeed",
    b"SetWalkSpeed",
    b"SetRunSpeed",
    b"SprintDisable",
    b"SetMaxSpeed",
    b"SetupMove",
    b"PlayerSpeed",
]
with open(path, "rb") as f:
    data = f.read()
print("size", len(data))
for n in needles:
    idxs = []
    start = 0
    while True:
        i = data.find(n, start)
        if i < 0:
            break
        idxs.append(i)
        start = i + 1
        if len(idxs) >= 12:
            break
    print(n.decode("latin1"), "hits", len(idxs))
    for i in idxs[:4]:
        snippet = data[max(0, i - 60) : i + 100]
        s = "".join(chr(b) if 32 <= b < 127 else "." for b in snippet)
        print(" ", s)
        print()
