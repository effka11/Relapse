"""Удалить bsp карты из кэша клиента GMod. Сервер и стол не трогает."""
import os
import re
import sys

ROOT = r"D:\steam\steamapps\common\GarrysMod\garrysmod"
FOLDERS = (
    os.path.join(ROOT, "download", "maps"),
    os.path.join(ROOT, "maps"),
)


def main():
    if len(sys.argv) != 2 or not sys.argv[1].strip():
        print("нужно имя карты")
        return 1
    name = sys.argv[1].strip()
    if name.lower().endswith(".bsp"):
        name = name[:-4]
    name = name.lower()
    if not re.fullmatch(r"[a-z0-9_]+", name):
        print("имя: строчные буквы, цифры, _")
        return 1
    for folder in FOLDERS:
        path = os.path.join(folder, name + ".bsp")
        if os.path.isfile(path):
            os.remove(path)
            print("удалён", path)
        else:
            print("нет", path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
