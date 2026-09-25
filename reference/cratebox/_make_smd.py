# Engine box, already scaled by 0.75, same axes as the ammo crate:
# X front/back, Y the long sides, Z up from the floor to the body rim.
ex0, ey0, ez0 = -13.4775, -28.9425, 0.0
ex1, ey1, ez1 = 19.0125, 30.1125, 27.0675

# Studiomdl turns SMD axes before writing the model: engineX = -smdY, engineY = smdX.
def smd(ex, ey, ez):
	return (ey, -ex, ez)

def smd_n(nx, ny, nz):
	return (ny, -nx, nz)

corners = {
	"000": (ex0, ey0, ez0),
	"100": (ex1, ey0, ez0),
	"010": (ex0, ey1, ez0),
	"110": (ex1, ey1, ez0),
	"001": (ex0, ey0, ez1),
	"101": (ex1, ey0, ez1),
	"011": (ex0, ey1, ez1),
	"111": (ex1, ey1, ez1),
}

# Outward faces in engine space. Winding stays outward: the axis change has det +1.
faces = [
	((1, 0, 0), ("100", "110", "111", "101")),
	((-1, 0, 0), ("000", "001", "011", "010")),
	((0, 1, 0), ("010", "011", "111", "110")),
	((0, -1, 0), ("000", "100", "101", "001")),
	((0, 0, 1), ("001", "101", "111", "011")),
	((0, 0, -1), ("000", "010", "110", "100")),
]

lines = [
	"version 1",
	"nodes",
	"0 \"root\" -1",
	"end",
	"skeleton",
	"time 0",
	"0 0.000000 0.000000 0.000000 0.000000 0.000000 0.000000",
	"end",
	"triangles",
]
for normal, quad in faces:
	a, b, c, d = (corners[k] for k in quad)
	sn = smd_n(*normal)
	for tri in ((a, b, c), (a, c, d)):
		lines.append("debugwhite")
		for v in tri:
			p = smd(*v)
			lines.append(
				"0 %.6f %.6f %.6f %.6f %.6f %.6f 0.000000 0.000000"
				% (p[0], p[1], p[2], sn[0], sn[1], sn[2])
			)
lines.append("end")
path = r"C:\Users\Egor\Desktop\Relapse\reference\cratebox\box.smd"
with open(path, "w", newline="\n") as f:
	f.write("\n".join(lines) + "\n")
print("wrote", path)
