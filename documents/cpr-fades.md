# Фейды из Cubase `.cpr`

`.cpr` — RIFF `NUND`. Кривая и длина клипа лежат в нём числами. Микс в WAV/MP3 кривую уже запёк. Архив дорожки `.smt` / `.xml`, если выделены только темп и размер, содержит BPM и `4/4`, не аудио.

Читать скриптом ниже. Скан байт вокруг `MConstrainedSpline` на новом проекте промахивается: класс кривой бывает `MFramedSpline`, а у схода имени класса второй раз нет.

## Две длины

Секунды = сэмплы / частота. Частота — big-endian double сразу после `Float` у `SampleRate`.

| Поле скрипта | Откуда | Что это |
|---|---|---|
| `file` | big-endian int64 у `AudioFile`, старшие байты нули | весь файл в пуле |
| `event` | big-endian double в первых 64 байтах `MAudioEvent`, не длиннее `file` | клип на таймлайне |

Если `event` короче `file`, хвост обрезан. Сход стоит в конце **события**: старт схода = `event` − длина схода. Хвост файла после события не играет.

## Кривая

У клипа два фейда: `MFadeIn`, `MFadeOut`. `MAutoFadeSetting` — автофейд около 0.01 с, не рисунок. `MLinearInterpolator` далеко от `MFadeOut`, с уровнями `1`, — громкость дорожки, не сход.

Числа — big-endian double. Заход начинается с сэмплов (большое число) и уровня. Точка `(0, 0)` не записана. Сход начинается с уровня `1`, дальше пары сэмплы / уровень до `0`. Прямой сход — уровень `1` и одна длина, конец `0`; вторая копия длины и `0.5` в хвосте — середина той же прямой.

Сэмплы внутри фейда — от его начала, не от начала файла.

## Скрипт

Аргумент — путь к `.cpr`. Печатает частоту, `file`, `event` и оба фейда.

```python
import struct
import sys

data = open(sys.argv[1], "rb").read()

def be_d(at):
    return struct.unpack_from(">d", data, at)[0]

def be_q(at):
    return struct.unpack_from(">q", data, at)[0]

def sane(v):
    return v == v and abs(v) < 1e9

rate_at = data.find(b"Float", data.find(b"SampleRate"))
rate = be_d(rate_at + len(b"Float") + 3)
print("rate", rate)

file_at = data.find(b"AudioFile")
file_len = None
for off in range(file_at, file_at + 48):
    if data[off : off + 3] != b"\x00\x00\x00":
        continue
    samples = be_q(off)
    if rate * 0.5 < samples < rate * 3600:
        file_len = samples
        break
print("file %.6f s" % (file_len / rate))

idx = 0
while True:
    ev = data.find(b"MAudioEvent", idx)
    if ev < 0:
        break
    idx = ev + 1
    for off in range(ev, ev + 64):
        d = be_d(off)
        if sane(d) and rate * 0.5 < d <= file_len + 1:
            print("event %.6f s" % (d / rate))
            break

def is_time(v):
    return 1.5 < v < rate * 3600

def is_level(v):
    return 0 <= v <= 1.001

def curve(marker):
    start = data.find(marker)
    fade_in = marker == b"MFadeIn"
    linear = None
    for slide in range(296):
        at = start + slide
        a, b = be_d(at), be_d(at + 8)
        if not (sane(a) and sane(b)):
            continue
        if fade_in and is_time(a) and is_level(b):
            points = [(0.0, 0.0)]
            off = at
            for _ in range(16):
                t, v = be_d(off), be_d(off + 8)
                if not (sane(t) and sane(v) and is_time(t) and is_level(v)):
                    break
                if t <= points[-1][0]:
                    break
                points.append((t, v))
                off += 16
                if v >= 0.999:
                    break
            if len(points) >= 2 and points[-1][1] >= 0.999:
                return "spline", points
        if not fade_in and is_level(a) and is_time(b):
            points = [(0.0, a)]
            off = at + 8
            for _ in range(16):
                t, v = be_d(off), be_d(off + 8)
                if not (sane(t) and sane(v) and is_time(t) and is_level(v)):
                    break
                if t <= points[-1][0]:
                    break
                points.append((t, v))
                off += 16
                if v <= 0.001:
                    break
            if len(points) >= 2 and points[-1][1] <= 0.001:
                return "spline", points
            if linear is None and a >= 0.999:
                linear = [(0.0, a), (b, 0.0)]
    if linear:
        return "linear", linear
    raise SystemExit("no curve for " + marker.decode())

for marker in (b"MFadeIn", b"MFadeOut"):
    kind, points = curve(marker)
    print(marker.decode(), kind)
    for samples, level in points:
        print("  %.6f s  %.6f" % (samples / rate, level))
```
