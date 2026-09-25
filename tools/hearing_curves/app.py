# Local editor for hearing curves. Run from the "Кривые слуха" task.
# Catalog comes from the Lua the server actually loads, plus player footsteps
# the engine plays, plus workshop audio those scripts point at.

import argparse
import json
import re
import struct
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CURVES_PATH = HERE / "curves.json"
CATALOG_CACHE = HERE / "cache" / "catalog.json"
CATALOG_VERSION = 3
HEARING_LUA = ROOT / "gamemodes" / "zombiesurvival" / "gamemode" / "sh_relapse_hearing.lua"
WORKSHOP = Path(r"D:\steam\steamapps\workshop\content\4000")
SOURCE = Path(r"D:\steam\steamapps\common\GarrysMod\sourceengine")
GMOD = Path(r"D:\steam\steamapps\common\GarrysMod\garrysmod")
SERVER = Path(r"D:\Relapse\server\garrysmod")

METRE = 39.37
AUDIO_EXT = (".wav", ".ogg", ".mp3")

SCAN_ROOTS = [
    ROOT / "gamemodes" / "zombiesurvival",
    ROOT / "addons",
]

VPK_DIRS = [
    SOURCE / "hl2_sound_misc_dir.vpk",
    SOURCE / "hl2_sound_vo_english_dir.vpk",
    SOURCE / "hl2_misc_dir.vpk",
    SOURCE / "content_hl2_dir.vpk",
    SOURCE / "content_cstrike_dir.vpk",
    GMOD / "garrysmod_dir.vpk",
]

LOOSE_SOUND = [
    GMOD / "sound",
    SERVER / "sound",
]

SURFACES = [
    ("metalgrate", "металлическая решётка"),
    ("chainlink", "сетка"),
    ("ceilingtile", "потолочная плитка"),
    ("concrete", "бетон"),
    ("metal", "металл"),
    ("gravel", "гравий"),
    ("grass", "трава"),
    ("ladder", "лестница"),
    ("carpet", "ковёр"),
    ("plastic", "пластик"),
    ("rubber", "резина"),
    ("glass", "стекло"),
    ("flesh", "плоть"),
    ("slosh", "лужа"),
    ("snow", "снег"),
    ("dirt", "земля"),
    ("duct", "труба"),
    ("sand", "песок"),
    ("tile", "плитка"),
    ("wood", "дерево"),
    ("mud", "грязь"),
    ("wade", "вода по колено"),
]

ACTIONS = [
    ("fire.first", "первый выстрел"),
    ("fire_first", "первый выстрел"),
    ("disconnector", "щелчок спуска"),
    ("dryfire", "осечка"),
    ("fire.s", "выстрел с глушителем"),
    ("_sup_", "выстрел с глушителем"),
    ("suppress", "выстрел с глушителем"),
    ("silenc", "выстрел с глушителем"),
    (".fire", "выстрел"),
    ("_fire", "выстрел"),
    ("reload", "перезарядка"),
    ("mag_out", "магазин наружу"),
    ("magout", "магазин наружу"),
    ("clipout", "магазин наружу"),
    ("mag_in", "магазин внутрь"),
    ("magin", "магазин внутрь"),
    ("clipin", "магазин внутрь"),
    ("rechamber", "передёргивание затвора"),
    ("ads_up", "прицел поднять"),
    ("ads_down", "прицел опустить"),
    ("snap_closed", "защёлка закрыта"),
    ("snap_open", "защёлка открыта"),
    ("hybrid_scope", "гибридный прицел"),
    ("inspect", "осмотр оружия"),
    ("atmo_pistol.inside", "атмосфера выстрела в помещении"),
    ("atmo_pistol.outside", "атмосфера выстрела снаружи"),
    ("atmo_pistol_mag", "атмосфера магазина"),
    ("atmo_", "атмосфера выстрела"),
    ("holster", "убрать оружие"),
    ("melee_hitworld", "удар по миру"),
    ("hitworld", "удар по миру"),
    ("melee_hit", "удар"),
    ("_hit", "удар"),
    ("swing", "замах"),
    ("pump", "помпа"),
    ("insert", "вставить патрон"),
    ("bolt", "затвор"),
    ("raise", "достать оружие"),
    ("draw", "достать оружие"),
    ("breathe", "дыхание"),
    ("footstep", "шаг"),
    ("/foot", "шаг"),
    ("pain", "боль"),
    ("death", "смерть"),
    ("explode", "взрыв"),
    ("explosion", "взрыв"),
    ("jump", "прыжок"),
    ("land", "приземление"),
    ("taunt", "насмешка"),
    ("alert", "тревога"),
    ("idle", "ожидание"),
]

QUOTE_AUDIO = re.compile(r'["\']([^"\']+\.(?:wav|ogg|mp3))["\']', re.I)
PRINT_NAME = re.compile(r'PrintName\s*=\s*"([^"]+)"')
CLASS_NAME = re.compile(r'CLASS\.Name\s*=\s*"([^"]+)"')
SCRIPT_CALL = re.compile(
    r'(?:EmitSound|CreateSound|sound\.Play|Sound)\s*\(\s*(?:[^,\n]{0,80},\s*)?["\']([^"\']+)["\']',
    re.I,
)
CONCAT_RANDOM = re.compile(
    r'["\']([^"\']+)["\']\s*\.\.\s*math(?:_random)?\.random\(\s*(\d+)\s*(?:,\s*(\d+)\s*)?\)\s*\.\.\s*["\']([^"\']+)["\']'
)
FORMAT_RANDOM = re.compile(
    r'string\.format\(\s*["\']([^"\']*%d[^"\']*)["\']\s*,\s*math(?:_random)?\.random\(\s*(\d+)'
)

INDEX = {}
CATALOG = []
IMPORTED = {}
LOCK = threading.Lock()


def norm(path):
    path = path.replace("\\", "/").strip()
    while path[:1] in "^)@#*":
        path = path[1:]
    path = path.lstrip()
    low = path.lower()
    if low.startswith("sound/"):
        path = path[6:]
    return path


def rel_lua(path):
    try:
        return str(path.relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


GENERIC = {
    "base", "mg_base", "modules", "sounds", "shared", "weapons", "gamemode",
    "entities", "client", "server", "autorun", "common", "att", "attachments",
    "lua", "addons", "vgui", "zombieclasses", "player", "sound", "init",
    "all", "cl", "sv", "customization", "animations",
}

NPC_STEPS = [
    ("fast_zombie", "быстрого зомби"),
    ("poison_zombie", "ядовитого зомби"),
    ("zombie_poison", "ядовитого зомби"),
    ("headcrab", "хедкраба"),
    ("antlion_guard", "стража муравьиных львов"),
    ("antlion", "муравьиного льва"),
    ("barnacle", "барнакла"),
    ("combine_soldier", "комбайна"),
    ("zombie", "зомби"),
]


def load_print_names():
    names = {}
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for lua in root.rglob("*.lua"):
            folder = lua.parent.name
            folder_l = folder.lower()
            parts = [p.lower() for p in lua.parts]
            if "zombieclasses" in parts:
                if folder_l != "zombieclasses":
                    continue
            elif "weapons" in parts:
                after = parts[parts.index("weapons") + 1:]
                if len(after) > 2 or folder_l in ("sounds", "modules"):
                    continue
            else:
                continue
            try:
                text = lua.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            found = PRINT_NAME.search(text) or CLASS_NAME.search(text)
            if not found:
                continue
            label = found.group(1)
            key = lua.stem.lower() if folder_l in ("weapons", "zombieclasses") else folder_l
            if key not in GENERIC:
                names[key] = label
            token = key
            for prefix in ("mg_", "weapon_zs_", "weapon_"):
                if token.startswith(prefix):
                    token = token[len(prefix):]
            if len(token) >= 3 and token not in GENERIC:
                names[token] = label
            skip_codes = GENERIC | {
                "reload", "raise", "drop", "fire", "barrel", "laser", "sight", "scope",
                "mount", "perk", "bolt", "pump", "draw", "idle", "pain", "jump", "land",
                "grip", "stock", "mag", "ads", "first", "last", "empty", "open", "close",
            }
            if lua.stem.lower() not in ("shared", "init", "cl_init") and folder_l not in ("weapons", "zombieclasses"):
                continue
            for code in re.findall(r"(?:iw8|weap|wfoly|vm|pi|ar|sm|lm|sn|sh)_([a-z0-9]{4,})", text, re.I):
                code = code.lower()
                if code in skip_codes or code in names:
                    continue
                names[code] = label
    return names


def resolve_title(names, token):
    if not token:
        return ""
    parts = [p for p in re.split(r"[_\-.]+", token.lower()) if p and p not in GENERIC]
    options = []
    for i in range(len(parts)):
        for j in range(i + 1, len(parts) + 1):
            options.append("_".join(parts[i:j]))
    options.sort(key=len, reverse=True)
    for piece in options:
        if piece in GENERIC or len(piece) < 3:
            continue
        title = names.get(piece)
        if title:
            return title
    return ""


def ids_in(text):
    if not text:
        return []
    return re.findall(r"(?:mg_|weapon_zs_|weapon_|weap_|mw19\.)([a-z0-9_]+)", text, re.I)


def class_titles(names, sources):
    found = []
    for source in sources or []:
        parts = source.replace("\\", "/").split("/")
        token = ""
        if "zombieclasses" in parts:
            i = parts.index("zombieclasses")
            if i + 1 < len(parts):
                token = Path(parts[i + 1]).stem
        elif "weapons" in parts:
            i = parts.index("weapons")
            if i + 1 < len(parts):
                name = parts[i + 1]
                token = Path(name).stem if name.endswith(".lua") else name
        title = resolve_title(names, token)
        if title and title not in found:
            found.append(title)
    return found


def weapon_from(names, path, script, sources):
    stem = ""
    if path and not path.lower().startswith("script:"):
        stem = Path(path).stem
    # The file name is the sound itself. The script name can be a shared alias.
    for token in [stem] + ids_in(path):
        title = resolve_title(names, token)
        if title:
            return title
    if path and not path.lower().startswith("script:"):
        for seg in reversed(path.replace("\\", "/").split("/")):
            title = resolve_title(names, Path(seg).stem)
            if title:
                return title
    for token in ids_in(script):
        title = resolve_title(names, token)
        if title:
            return title
    classes = class_titles(names, sources)
    if len(classes) == 1:
        return classes[0]
    if classes:
        shown = classes[:3]
        text = ", ".join(shown)
        if len(classes) > 3:
            text += "…"
        return text
    return ""


def action_name(blob):
    low = blob.lower()
    for key, label in ACTIONS:
        if key in low:
            return label
    return ""


def variant_name(path):
    m = re.search(r'(?:_|/)?(\d{1,2})\.(?:wav|ogg|mp3)$', path, re.I)
    if not m:
        return ""
    return "вариант " + str(int(m.group(1)))


def surface_name(path):
    low = path.lower()
    if "footsteps/" not in low and "/foot" not in low:
        return ""
    base = Path(low).stem
    base = re.sub(r'\d+$', '', base)
    for key, label in SURFACES:
        if base == key or base.endswith(key):
            return label
    return ""


def file_tag(path, script):
    if path and not path.lower().startswith("script:"):
        return Path(path).name
    if script:
        return script
    return Path(path).name if path else ""


def npc_step_label(path):
    low = path.lower()
    if not low.startswith("npc/"):
        return ""
    for key, label in NPC_STEPS:
        if ("/" + key + "/") in low or low.startswith("npc/" + key):
            return "Шаг " + label
    return ""


def title_for(path, script, sources, names):
    low = (path or "").lower()
    surf = surface_name(path)
    if surf and "player/footsteps/" in low:
        bit = variant_name(path)
        title = "Шаг выжившего — " + surf
        if bit:
            title += ", " + bit
        tag = file_tag(path, script)
        if tag:
            title += " (" + tag + ")"
        return title, "Шаги"
    if "/beats/" in low:
        folder = Path(path).parent.name.lower()
        kind = "Музыка зомби" if "zombie" in folder else "Музыка выжившего"
        return kind + " — трек " + Path(path).stem + " (" + Path(path).name + ")", "Музыка"
    if low.startswith("vo/"):
        return "Голос — " + Path(path).stem + " (" + path + ")", "Голоса"
    stem = Path(path).stem if path and not low.startswith("script:") else ""
    who = weapon_from(names, path, script, sources)
    act = action_name(" ".join(x for x in (stem, script) if x))
    npc = npc_step_label(path)
    class_files = [s for s in (sources or []) if "zombieclasses" in s.replace("\\", "/")]
    if npc and len(class_files) != 1:
        who = npc
        act = ""
    elif not act and ("/foot" in low or "footstep" in low):
        act = "шаг"
    elif surf and not act:
        act = "шаг"
    parts = [p for p in (who, act) if p]
    if not parts:
        parts = [script or (Path(path).stem if path else "звук")]
    title = " — ".join(parts)
    tag = file_tag(path, script)
    if tag and tag not in title:
        title += " (" + tag + ")"
    if act == "шаг" or surf or npc or "/foot" in low or "footstep" in low:
        group = "Шаги"
    elif who and "," not in who and not who.endswith("…"):
        group = who
    elif who:
        group = "Общие"
    elif low.startswith("script:"):
        group = "Скрипты"
    else:
        top = low.split("/")[0] if low else ""
        group = {
            "reloads": "Перезарядка",
            "foley": "Фоли",
            "weapons": "Оружие Source",
            "npc": "NPC",
            "ambient": "Фон",
            "physics": "Физика",
            "player": "Игрок",
            "buttons": "Кнопки",
            "world": "Мир",
            "items": "Предметы",
            "zombiesurvival": "Режим",
        }.get(top, "Прочее")
    return title, group


def detail_for(path, script, sources, engine_note):
    lines = []
    if path:
        lines.append("Файл: " + path)
    if script:
        lines.append("Скрипт: " + script)
    if sources:
        shown = sources[:3]
        extra = len(sources) - len(shown)
        text = "Задан в " + ", ".join(shown)
        if extra > 0:
            text += " и ещё %d" % extra
        lines.append(text)
    if engine_note:
        lines.append(engine_note)
    return "\n".join(lines)


class Entry(object):
    def __init__(self, path, script, source, names):
        self.path = path
        self.script = script or ""
        self.sources = []
        if source:
            self.sources.append(source)
        self.names = names
        self.engine_note = ""
        self.title = ""
        self.group = ""
        self.refresh()

    def add_source(self, source):
        if source and source not in self.sources:
            self.sources.append(source)

    def refresh(self):
        self.title, self.group = title_for(self.path, self.script, self.sources, self.names)

    def to_json(self):
        return {
            "path": self.path,
            "title": self.title,
            "group": self.group,
            "script": self.script,
            "detail": detail_for(self.path, self.script, self.sources, self.engine_note),
        }


def add_entry(bucket, path, script, source, names):
    path = norm(path)
    if not path or any(ch in path for ch in "*?%<>"):
        return
    key = path.lower()
    ent = bucket.get(key)
    if ent is None:
        ent = Entry(path, script, source, names)
        bucket[key] = ent
    else:
        ent.add_source(source)
        if script and not ent.script:
            ent.script = script


def expand_patterns(text):
    found = []
    for m in CONCAT_RANDOM.finditer(text):
        prefix, a, b, suffix = m.group(1), int(m.group(2)), m.group(3), m.group(4)
        if b is None:
            start, end = 1, a
        else:
            start, end = a, int(b)
        if end < start or end - start > 32:
            continue
        for n in range(start, end + 1):
            found.append(prefix + str(n) + suffix)
    for m in FORMAT_RANDOM.finditer(text):
        fmt, n = m.group(1), int(m.group(2))
        if n > 32:
            continue
        for i in range(1, n + 1):
            try:
                found.append(fmt % i)
            except TypeError:
                break
    return found


def scan_lua(names):
    bucket = {}
    scripts = {}
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for lua in root.rglob("*.lua"):
            if "reference" in lua.parts:
                continue
            try:
                text = lua.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            source = rel_lua(lua)
            i = 0
            key = "sound.Add("
            while True:
                j = text.find(key, i)
                if j < 0:
                    break
                k = j + len(key)
                depth = 1
                while k < len(text) and depth:
                    if text[k] == "(":
                        depth += 1
                    elif text[k] == ")":
                        depth -= 1
                    k += 1
                block = text[j:k]
                i = k
                nm = re.search(r'name\s*=\s*"([^"]+)"', block)
                script = nm.group(1) if nm else ""
                for path in QUOTE_AUDIO.findall(block):
                    add_entry(bucket, path, script, source, names)
            for path in QUOTE_AUDIO.findall(text):
                add_entry(bucket, path, "", source, names)
            for path in expand_patterns(text):
                if path.lower().endswith(AUDIO_EXT):
                    add_entry(bucket, path, "", source, names)
            for m in SCRIPT_CALL.finditer(text):
                raw = m.group(1)
                if raw.lower().endswith(AUDIO_EXT):
                    continue
                if re.search(r'\s', raw):
                    continue
                scripts.setdefault(raw, set()).add(source)
    return bucket, scripts


def walk_vpk(dirpath):
    data = dirpath.read_bytes()
    sig, ver, tree_size = struct.unpack_from("<III", data, 0)
    if sig != 0x55AA1234 or ver not in (1, 2):
        return
    p = 28 if ver == 2 else 12
    tree_end = min(len(data), (28 if ver == 2 else 12) + tree_size)
    out = []

    def cstr(at):
        end = data.find(b"\x00", at, tree_end)
        if end < 0:
            return None, tree_end
        return data[at:end].decode("latin1", "replace"), end + 1

    while p < tree_end:
        ext, p = cstr(p)
        if ext is None or ext == "":
            break
        while True:
            folder, p = cstr(p)
            if folder is None or folder == "":
                break
            while True:
                name, p = cstr(p)
                if name is None or name == "":
                    break
                if p + 18 > len(data):
                    return out
                crc, preload, archive, offset, length, term = struct.unpack_from("<IHHIIH", data, p)
                p += 18
                if term != 0xFFFF:
                    return out
                p += preload
                rel = name + "." + ext if folder == " " else folder + "/" + name + "." + ext
                low = rel.lower()
                if low.endswith(AUDIO_EXT) or "game_sounds" in low:
                    out.append((rel, archive, offset, length, dirpath))
    return out


def index_vpk(dirpath):
    if not dirpath.exists():
        return
    for rel, archive, offset, length, _ in walk_vpk(dirpath):
        key = norm(rel).lower()
        INDEX.setdefault(key, ("vpk", str(dirpath), archive, offset, length))


def index_gma(path):
    with path.open("rb") as f:
        if f.read(4) != b"GMAD":
            return
        f.read(1)
        f.read(16)

        def rs():
            buf = bytearray()
            while True:
                c = f.read(1)
                if c in (b"\x00", b""):
                    break
                buf += c
            return buf.decode("utf-8", "replace")

        for _ in range(4):
            rs()
        f.read(4)
        files = []
        while True:
            num = struct.unpack("<I", f.read(4))[0]
            if num == 0:
                break
            name = rs()
            size, _crc = struct.unpack("<QI", f.read(12))
            files.append((name, size))
        base = f.tell()
    cursor = base
    for name, size in files:
        if name.lower().endswith(AUDIO_EXT):
            INDEX.setdefault(norm(name).lower(), ("gma", str(path), cursor, size))
        cursor += size


def workshop_gmas():
    text = (ROOT / "addons" / "zzz_relapse_mw_sykov" / "lua" / "autorun" / "server" / "relapse_mw_workshop.lua").read_text(encoding="utf-8", errors="replace")
    ids = re.findall(r'resource\.AddWorkshop\("(\d+)"\)', text)
    found = []
    for wid in ids:
        folder = WORKSHOP / wid
        if not folder.exists():
            continue
        for gma in folder.glob("*.gma"):
            found.append(gma)
    return found


def read_loose(path):
    rel = norm(path)
    for root in LOOSE_SOUND:
        candidate = root / rel
        if candidate.exists():
            return candidate.read_bytes()
    return None


def read_located(loc):
    kind = loc[0]
    if kind == "vpk":
        _kind, dirpath, archive, offset, length = loc
        dirpath = Path(dirpath)
        if archive == 0x7FFF:
            data = dirpath.read_bytes()
            _sig, ver, tree_size = struct.unpack_from("<III", data, 0)
            start = (28 if ver == 2 else 12) + tree_size + offset
            return data[start:start + length]
        archive_path = Path(str(dirpath).replace("_dir.vpk", "_%03d.vpk" % archive))
        with archive_path.open("rb") as f:
            f.seek(offset)
            return f.read(length)
    if kind == "gma":
        _kind, gma, offset, size = loc
        with open(gma, "rb") as f:
            f.seek(offset)
            return f.read(size)
    return None


def extract_vpk_text(dirpath, archive, offset, length):
    blob = read_located(("vpk", str(dirpath), archive, offset, length))
    if not blob:
        return ""
    return blob.decode("utf-8", errors="replace")


def parse_game_sounds(text):
    waves = {}
    name = None
    depth = 0
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("//"):
            continue
        if depth == 0 and line.startswith('"') and "{" not in line:
            name = line.strip('"')
            waves.setdefault(name, [])
            continue
        opens = line.count("{")
        closes = line.count("}")
        if "wave" in line.lower() and name:
            for found in re.findall(r'"((?:[^"]+\.(?:wav|ogg|mp3)))"', line, re.I):
                waves[name].append(norm(found))
        depth += opens - closes
        if depth <= 0:
            depth = 0
            if closes and "{" not in line:
                name = None
    return waves


def attach_scripts(bucket, scripts, names):
    if not scripts:
        return
    libraries = {}
    for key, loc in list(INDEX.items()):
        if "game_sounds" not in key or not key.endswith(".txt"):
            continue
        if loc[0] != "vpk":
            continue
        text = extract_vpk_text(Path(loc[1]), loc[2], loc[3], loc[4])
        libraries.update(parse_game_sounds(text))
    by_lower = {}
    for key, paths in libraries.items():
        by_lower.setdefault(key.lower(), []).extend(paths)
    known = {}
    for ent in bucket.values():
        if ent.script:
            known.setdefault(ent.script.lower(), []).append(ent)
    for script, sources in scripts.items():
        if "." not in script:
            continue
        owners = known.get(script.lower())
        if owners:
            for ent in owners:
                for source in sources:
                    ent.add_source(source)
            continue
        paths = libraries.get(script) or by_lower.get(script.lower()) or []
        if not paths:
            fake = "script:" + script
            add_entry(bucket, fake, script, next(iter(sources)), names)
            ent = bucket[fake.lower()]
            for source in sources:
                ent.add_source(source)
            ent.engine_note = "Имя скрипта Source. Волна в локальных архивах не нашлась: дорожки нет, параметры сохранить можно."
            continue
        for path in paths:
            add_entry(bucket, path, script, "", names)
            ent = bucket[path.lower()]
            for source in sources:
                ent.add_source(source)


def add_player_footsteps(bucket, names):
    prefix = "player/footsteps/"
    for key in list(INDEX.keys()):
        if not key.startswith(prefix):
            continue
        if key in bucket:
            continue
        original = key
        add_entry(bucket, original, "", "", names)
        ent = bucket[key]
        ent.engine_note = "Этот шаг ставит движок, когда выживший идёт по этой поверхности. В Lua пути нет: поверхность выбирает игра."


def load_lua_curves():
    if not HEARING_LUA.exists():
        return {}
    text = HEARING_LUA.read_text(encoding="utf-8", errors="replace")
    start = text.find("GM.HearingTracks")
    if start < 0:
        return {}
    chunk = text[start:]
    out = {}
    for m in re.finditer(r"(\w+)\s*=\s*\{", chunk):
        if m.group(1) in ("Knots", "Controls", "Peaks", "Radius", "HearingTracks", "HearingFalloff"):
            continue
        body_start = m.end()
        depth = 1
        i = body_start
        while i < len(chunk) and depth:
            if chunk[i] == "{":
                depth += 1
            elif chunk[i] == "}":
                depth -= 1
            i += 1
        body = chunk[body_start:i]
        comment = re.search(r"--\s*(\S+\.(?:wav|ogg|mp3))", body, re.I)
        if not comment:
            continue
        path = norm(comment.group(1))

        def pairs(block_name, nxt):
            a = body.find(block_name)
            if a < 0:
                return []
            b = body.find(nxt, a) if nxt else len(body)
            if b < 0:
                b = len(body)
            return [[float(x), float(y)] for x, y in re.findall(r"\{\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\}", body[a:b])]

        peak_pairs = pairs("Peaks", "")
        radius = None
        rm = re.search(r"Radius\s*=\s*([0-9.]+)\s*\*\s*METRE", body)
        if rm:
            radius = float(rm.group(1))
        else:
            rm = re.search(r"Radius\s*=\s*([0-9.]+)", body)
            if rm:
                radius = float(rm.group(1)) / METRE
        if len(peak_pairs) < 1:
            continue
        out[path.lower()] = {
            "path": path,
            "radius_m": radius,
            "peaks": peak_pairs,
        }
    return out


def load_saved():
    if not CURVES_PATH.exists():
        return {}
    try:
        data = json.loads(CURVES_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def merge_curves(imported, saved):
    merged = {}
    for key, curve in imported.items():
        merged[key] = curve
    for key, curve in saved.items():
        if not isinstance(curve, dict):
            continue
        if curve.get("cleared"):
            merged.pop(key.lower(), None)
            continue
        curve = dict(curve)
        curve["path"] = curve.get("path") or key
        merged[key.lower()] = curve
    return merged


def lua_mtime():
    newest = 0
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for lua in root.rglob("*.lua"):
            try:
                newest = max(newest, int(lua.stat().st_mtime * 1000))
            except OSError:
                continue
    return newest


def load_catalog():
    stamp = lua_mtime()
    if CATALOG_CACHE.exists():
        try:
            data = json.loads(CATALOG_CACHE.read_text(encoding="utf-8"))
            if data.get("version") == CATALOG_VERSION and data.get("lua_mtime") == stamp and data.get("sounds"):
                print("Каталог из кэша, звуков: %d" % len(data["sounds"]), flush=True)
                return data["sounds"]
        except (OSError, ValueError):
            pass
    sounds = build()
    CATALOG_CACHE.parent.mkdir(parents=True, exist_ok=True)
    CATALOG_CACHE.write_text(json.dumps({
        "version": CATALOG_VERSION,
        "lua_mtime": stamp,
        "sounds": sounds,
    }, ensure_ascii=False), encoding="utf-8")
    return sounds


def build():
    print("Имена оружия...", flush=True)
    names = load_print_names()
    print("Индекс архивов...", flush=True)
    for vpk in VPK_DIRS:
        print("  " + vpk.name, flush=True)
        index_vpk(vpk)
    gmas = workshop_gmas()
    print("Моды: %d архивов" % len(gmas), flush=True)
    for gma in gmas:
        index_gma(gma)
    for root in LOOSE_SOUND:
        if not root.exists():
            continue
        for ext in ("*.wav", "*.ogg", "*.mp3"):
            for file in root.rglob(ext):
                rel = str(file.relative_to(root)).replace("\\", "/")
                INDEX.setdefault(rel.lower(), ("loose", str(file)))
    print("Каталог Lua...", flush=True)
    bucket, scripts = scan_lua(names)
    print("Скрипты: %d" % len(scripts), flush=True)
    attach_scripts(bucket, scripts, names)
    add_player_footsteps(bucket, names)
    for ent in bucket.values():
        ent.refresh()
    items = list(bucket.values())
    items.sort(key=lambda e: (e.group.lower(), e.title.lower(), e.path.lower()))
    print("Звуков в списке: %d, файлов в архивах: %d" % (len(items), len(INDEX)), flush=True)
    return [e.to_json() for e in items]


def content_type(path):
    low = path.lower()
    if low.endswith(".ogg"):
        return "audio/ogg"
    if low.endswith(".mp3"):
        return "audio/mpeg"
    return "audio/wav"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def send_json(self, payload, code=200):
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ("/", "/index.html"):
            raw = (HERE / "index.html").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
            return
        if parsed.path == "/api/state":
            saved = load_saved()
            merged = merge_curves(IMPORTED, saved)
            self.send_json({"sounds": CATALOG, "curves": merged, "imported": IMPORTED})
            return
        if parsed.path == "/api/audio":
            qs = parse_qs(parsed.query)
            path = norm((qs.get("path") or [""])[0])
            known = {s["path"].lower() for s in CATALOG if s.get("path")}
            if path.lower() not in known:
                self.send_error(404)
                return
            loc = INDEX.get(path.lower())
            blob = None
            if loc and loc[0] == "loose":
                blob = Path(loc[1]).read_bytes()
            elif loc:
                try:
                    blob = read_located(loc)
                except OSError:
                    blob = None
            if not blob:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", content_type(path))
            self.send_header("Content-Length", str(len(blob)))
            self.end_headers()
            self.wfile.write(blob)
            return
        self.send_error(404)

    def do_POST(self):
        if urlparse(self.path).path != "/api/curves":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length") or "0")
        raw = self.rfile.read(length)
        try:
            data = json.loads(raw.decode("utf-8"))
        except ValueError:
            self.send_error(400)
            return
        if not isinstance(data, dict):
            self.send_error(400)
            return
        CURVES_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        self.send_json({"ok": True})


def main():
    global CATALOG, IMPORTED
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    CATALOG = load_catalog()
    IMPORTED = load_lua_curves()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    url = "http://127.0.0.1:%d/" % args.port
    print("Кривые слуха: " + url)
    if not args.no_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Остановлено.")


if __name__ == "__main__":
    main()
