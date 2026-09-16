import math

def seed_rand(seed):
    s = int(seed % 2147483647)
    if s <= 0:
        s += 2147483646
    def rnd():
        nonlocal s
        s = (s * 48271) % 2147483647
        return s / 2147483647
    return rnd

ARMS = [
    dict(outX=0, outY=1), dict(outX=1, outY=1), dict(outX=1, outY=0), dict(outX=1, outY=-1),
    dict(outX=0, outY=-1), dict(outX=-1, outY=-1), dict(outX=-1, outY=0), dict(outX=-1, outY=1),
]
MIN_TURN, MAX_TURN, MIN_SEP, CORE_R, HALF = 42, 118, 0.68, 0.92, 30
NSLOTS = 15

def dist2(ax, ay, bx, by):
    return (ax - bx) ** 2 + (ay - by) ** 2
def angle_diff(a, b):
    return (math.degrees(a) - math.degrees(b) + 180) % 360 - 180
def in_sector(x, y, arm, half):
    if x == 0 and y == 0:
        return False
    return abs(angle_diff(math.atan2(y, x), math.atan2(arm["outY"], arm["outX"]))) <= half
def arm_dot(x, y, arm):
    ox, oy = arm["outX"], arm["outY"]
    return (x * ox + y * oy) / math.hypot(ox, oy)
def near(ax, ay, bx, by):
    return dist2(ax, ay, bx, by) < 1e-8
def orient(ax, ay, bx, by, cx, cy):
    return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
def segs_cross(ax, ay, bx, by, cx, cy, dx, dy):
    if near(ax, ay, cx, cy) or near(ax, ay, dx, dy) or near(bx, by, cx, cy) or near(bx, by, dx, dy):
        return False
    o1 = orient(ax, ay, bx, by, cx, cy)
    o2 = orient(ax, ay, bx, by, dx, dy)
    o3 = orient(cx, cy, dx, dy, ax, ay)
    o4 = orient(cx, cy, dx, dy, bx, by)
    return ((o1 > 0 and o2 < 0) or (o1 < 0 and o2 > 0)) and ((o3 > 0 and o4 < 0) or (o3 < 0 and o4 > 0))
def seg_dist2(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    len2 = vx * vx + vy * vy
    if len2 < 1e-8:
        return dist2(px, py, ax, ay)
    t = max(0, min(1, ((px - ax) * vx + (py - ay) * vy) / len2))
    return dist2(px, py, ax + vx * t, ay + vy * t)

class G:
    def __init__(self, ti, arm, rnd, alln, segs):
        self.ti = ti
        self.arm = arm
        self.rnd = rnd
        self.alln = alln
        self.segs = segs
        self.nodes = []
        self.child = {}
        self.lean = 1 if rnd() < 0.5 else -1
        self.center = math.atan2(arm["outY"], arm["outX"])
        self.half = HALF
    def too_close(self, x, y, skip):
        if dist2(x, y, 0, 0) < CORE_R * CORE_R:
            return True
        for n in self.alln:
            if n is not skip and dist2(x, y, n["x"], n["y"]) < MIN_SEP * MIN_SEP:
                return True
        return False
    def blocked(self, ax, ay, bx, by, skip):
        for e in self.segs:
            if segs_cross(ax, ay, bx, by, *e):
                return True
        lim = 0.32 * 0.32
        for n in self.alln:
            if n is not skip and seg_dist2(n["x"], n["y"], ax, ay, bx, by) < lim:
                return True
        return False
    def add(self, x, y, parent, ang):
        n = dict(slot=len(self.nodes), x=x, y=y, parent=parent, ang=ang)
        self.nodes.append(n)
        self.alln.append(n)
        if parent is not None:
            self.child[id(parent)] = self.child.get(id(parent), 0) + 1
            self.segs.append((parent["x"], parent["y"], x, y))
        else:
            self.segs.append((0, 0, x, y))
        return n
    def score(self, parent, x, y, ang):
        out = arm_dot(x, y, self.arm)
        pout = arm_dot(parent["x"], parent["y"], self.arm)
        s = self.rnd() * 3.2
        s += 4.5 if out > pout else -4
        turn = abs(angle_diff(ang, parent["ang"]))
        if turn < 50:
            s -= 1.5
        elif turn > 95:
            s += 0.8
        s -= abs(angle_diff(math.atan2(y, x), self.center)) * 0.04
        return s
    def try_from(self, parent, ignore=False):
        if not ignore and self.child.get(id(parent), 0) >= 3:
            return None
        cands = []
        for k in range(1, 23):
            sign = self.lean
            if k % 2 == 0:
                sign = -self.lean
            if self.rnd() < 0.22:
                sign = -sign
            turn = math.radians(MIN_TURN + self.rnd() * (MAX_TURN - MIN_TURN))
            ang = parent["ang"] + sign * turn
            ln = 0.92 + self.rnd() * 0.62
            x = parent["x"] + math.cos(ang) * ln
            y = parent["y"] + math.sin(ang) * ln
            if in_sector(x, y, self.arm, self.half) and not self.too_close(x, y, parent) and not self.blocked(parent["x"], parent["y"], x, y, parent):
                cands.append((self.score(parent, x, y, ang), x, y, ang))
        if not cands:
            return None
        cands.sort(reverse=True)
        pick = cands[0]
        if len(cands) >= 2 and self.rnd() < 0.6:
            pick = cands[int(self.rnd() * min(4, len(cands)))]
        return self.add(pick[1], pick[2], parent, pick[3])
    def pick(self):
        roll = self.rnd()
        if roll < 0.38:
            return self.nodes[-1]
        if roll < 0.76:
            return self.nodes[int(self.rnd() * len(self.nodes))]
        best, bn = None, None
        for n in self.nodes:
            c = self.child.get(id(n), 0)
            if c < 3 and (bn is None or c < bn):
                best, bn = n, c
        return best or self.nodes[-1]
    def gate(self):
        jitter = (self.rnd() - 0.5) * 0.16
        ang = self.center + jitter
        rad = 1.12 + self.rnd() * 0.22
        x, y = math.cos(ang) * rad, math.sin(ang) * rad
        if self.too_close(x, y, None):
            x, y = math.cos(self.center) * 1.2, math.sin(self.center) * 1.2
        self.add(x, y, None, ang)
    def step(self, ignore=False):
        if len(self.nodes) >= NSLOTS:
            return False
        if self.try_from(self.pick(), ignore):
            return True
        for n in reversed(self.nodes):
            if self.try_from(n, ignore):
                return True
        return False
    def widen(self):
        self.half = min(40, self.half + 5)

alln = []
segs = []
gs = []
for i, arm in enumerate(ARMS, 1):
    g = G(i, arm, seed_rand(41117 + i * 13063), alln, segs)
    g.gate()
    gs.append(g)

def grow_round(ignore):
    order = sorted(gs, key=lambda g: (len(g.nodes), g.ti))
    moved = False
    for g in order:
        if g.step(ignore):
            moved = True
        elif len(g.nodes) < NSLOTS:
            g.widen()
            if g.step(ignore):
                moved = True
    return moved

moved = True
guard = 0
while moved and guard < 80:
    moved = grow_round(False)
    guard += 1
moved = True
guard = 0
while moved and guard < 80:
    moved = grow_round(True)
    guard += 1

col = 0
xs = 0
for i, g in enumerate(gs, 1):
    c = 0
    for n in g.nodes:
        if n["parent"] is None:
            continue
        if abs(angle_diff(n["ang"], n["parent"]["ang"])) < MIN_TURN - 1:
            c += 1
            col += 1
    print(f"tree {i}: n={len(g.nodes)} collinear={c} half={g.half}")
for i, e in enumerate(segs):
    for f in segs[i + 1:]:
        if segs_cross(*e, *f):
            xs += 1
print("nodes", len(alln), "segs", len(segs), "xcross", xs, "smallturn", col)
