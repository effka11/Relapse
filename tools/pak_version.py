"""Версия пака (lump 40) = 1 у bsp на столе, рядом с VMF. Сервер не трогает."""
import os
import re
import struct
import sys

DESKTOP = r"C:\Users\Egor\Desktop"
LUMP40_VERSION = 8 + 40 * 16 + 8


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
    path = os.path.join(DESKTOP, name + ".bsp")
    if not os.path.isfile(path):
        print("нет", path)
        return 1
    data = bytearray(open(path, "rb").read())
    if len(data) < LUMP40_VERSION + 4 or data[:4] != b"VBSP":
        print("это не bsp", path)
        return 1
    old = struct.unpack_from("<i", data, LUMP40_VERSION)[0]
    struct.pack_into("<i", data, LUMP40_VERSION, 1)
    open(path, "wb").write(data)
    print(path)
    print("версия пака", old, "-> 1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
