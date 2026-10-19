#!/usr/bin/env python3
"""홍보 영상 배경 음악(코드로 합성, 외부 음원 없음).

장면이 시작하는 시각에 맞춰 분위기를 바꾼다. 장면 번호는 tools/promo_video.gd와 같다.
  잔잔함(패드) · 전투(베이스·북) · 보스(무거운 북·낮은 울림) · 마을(밝은 패드)
  밤(낮은 울림·심장 소리) · 끝(큰 화음이 울리고 사라짐)

사용: promo_music.py <출력.wav> <길이(초)> <장면:시작초,장면:시작초,...>
"""
import array
import math
import random
import sys
import wave

RATE = 44100
BPM = 96.0
BEAT = 60.0 / BPM
BAR = BEAT * 4

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def freq(name: str, octave: int) -> float:
    return 440.0 * 2.0 ** ((NOTE[name] + 12 * (octave + 1) - 69) / 12.0)


# 화음: (뿌리, [구성음 이름])
PROG_MAIN = [("A", ["A", "C", "E"]), ("F", ["F", "A", "C"]), ("C", ["C", "E", "G"]), ("G", ["G", "B", "D"])]
PROG_BOSS = [("A", ["A", "C", "E"]), ("A", ["A", "C", "E"]), ("F", ["F", "A", "C"]), ("E", ["E", "G#", "B"])]
PROG_TOWN = [("F", ["F", "A", "C"]), ("C", ["C", "E", "G"]), ("G", ["G", "B", "D"]), ("A", ["A", "C", "E"])]
PROG_DARK = [("D", ["D", "F", "A"]), ("D", ["D", "F", "A"]), ("A#", ["A#", "D", "F"]), ("A", ["A", "C#", "E"])]


# 장면 번호 → 분위기(tools/promo_video.gd의 장면 순서)
MOODS = {0: "intro", 1: "calm", 2: "action", 3: "calm", 4: "calm", 5: "calm", 6: "action", 7: "action",
         8: "action", 9: "action", 10: "boss", 11: "town", 12: "town", 13: "dark", 14: "end"}
MOOD_SETTINGS = {
    "intro": ({"pad": 0.8, "bass": 0.0, "kick": 0.0, "hat": 0.0, "drone": 0.25}, PROG_MAIN),
    "calm": ({"pad": 1.0, "bass": 0.4, "kick": 0.0, "hat": 0.0, "drone": 0.0}, PROG_MAIN),
    "action": ({"pad": 0.75, "bass": 1.0, "kick": 0.8, "hat": 0.6, "drone": 0.0}, PROG_MAIN),
    "boss": ({"pad": 0.6, "bass": 1.0, "kick": 1.0, "hat": 0.4, "drone": 0.7}, PROG_BOSS),
    "town": ({"pad": 1.0, "bass": 0.55, "kick": 0.25, "hat": 0.45, "drone": 0.0}, PROG_TOWN),
    "dark": ({"pad": 0.3, "bass": 0.0, "kick": 0.55, "hat": 0.0, "drone": 1.0}, PROG_DARK),
    "end": ({"pad": 1.15, "bass": 0.4, "kick": 0.0, "hat": 0.0, "drone": 0.0}, PROG_MAIN),
}


def make_table(harmonics: list[float], size: int = 2048) -> list[float]:
    t = [0.0] * size
    for i in range(size):
        ph = 2.0 * math.pi * i / size
        t[i] = sum(a * math.sin(ph * (k + 1)) for k, a in enumerate(harmonics))
    peak = max(abs(v) for v in t)
    return [v / peak for v in t]


PAD = make_table([1.0, 0.45, 0.22, 0.12, 0.06])
BASS = make_table([1.0, 0.6, 0.3, 0.15])
TSIZE = 2048


def mood_at(t: float, marks: list[tuple[int, float]]) -> int:
    scene = 0
    for s, start in marks:
        if t >= start:
            scene = s
    return scene


def main() -> None:
    out_path = sys.argv[1]
    length = float(sys.argv[2])
    marks = []
    for part in sys.argv[3].split(","):
        s, start = part.split(":")
        marks.append((int(s), float(start)))
    marks.sort(key=lambda m: m[1])
    end_start = next((st for s, st in marks if MOODS.get(s) == "end"), length - 5.0)
    rng = random.Random(7)
    n = int(length * RATE)
    left = array.array("h", [0] * n)
    right = array.array("h", [0] * n)
    pad_phase = [0.0] * 8
    bass_phase = 0.0
    kick_phase = 0.0
    # 장면별 세기(부드럽게 바뀐다)
    level = {"pad": 0.0, "bass": 0.0, "kick": 0.0, "hat": 0.0, "drone": 0.0}
    noise = 0.0
    for i in range(n):
        t = i / RATE
        scene = mood_at(t, marks)
        mood = MOODS.get(scene, "calm")
        target, prog = MOOD_SETTINGS[mood]
        for k in level:
            level[k] += (target[k] - level[k]) * (1.0 / (RATE * 0.6))
        bar_t = t / BAR
        chord_root, chord = prog[int(bar_t) % len(prog)]
        if mood == "end":
            chord_root, chord = ("A", ["A", "C", "E"])
        beat_pos = (t / BEAT) % 1.0
        # 패드: 화음 세 음 + 위 옥타브, 조금씩 어긋나 넓게 울린다.
        sl = 0.0
        sr = 0.0
        if level["pad"] > 0.001:
            # 화음이 바뀌는 순간을 부드럽게(마디 첫머리에서 살짝 숨을 쉰다)
            swell = 0.75 + 0.25 * math.sin(math.pi * (bar_t % 1.0))
            for j in range(8):
                note = chord[j % 3]
                octave = 3 if j < 3 else (4 if j < 6 else 5)
                f = freq(note, octave) * (1.0 + (0.0015 if j % 2 else -0.0015))
                pad_phase[j] = (pad_phase[j] + f / RATE) % 1.0
                v = PAD[int(pad_phase[j] * TSIZE)] * (0.11 if j < 6 else 0.05)
                if j % 2:
                    sr += v
                else:
                    sl += v
            sl *= level["pad"] * swell
            sr *= level["pad"] * swell
        # 베이스: 8분음표로 튕기는 뿌리음
        if level["bass"] > 0.001:
            eighth = (t / (BEAT * 0.5)) % 1.0
            env = math.exp(-eighth * 5.0)
            bass_phase = (bass_phase + freq(chord_root, 2) / RATE) % 1.0
            b = BASS[int(bass_phase * TSIZE)] * 0.22 * env * level["bass"]
            sl += b
            sr += b
        # 북: 박마다(보스는 더 세게), 심장 소리는 두 번 친다.
        if level["kick"] > 0.001:
            kt = beat_pos * BEAT
            if mood == "dark":
                kt = (t % 1.1)
                kt = kt if kt < 0.3 else kt - 0.3
            kick_f = 45.0 + 110.0 * math.exp(-kt * 30.0)
            kick_phase = (kick_phase + kick_f / RATE) % 1.0
            k = math.sin(2.0 * math.pi * kick_phase) * math.exp(-kt * 9.0) * 0.5 * level["kick"]
            sl += k
            sr += k
        # 하이햇: 반박마다 짧은 잡음
        if level["hat"] > 0.001:
            ht = ((t / BEAT) + 0.5) % 1.0 * BEAT
            noise = rng.uniform(-1.0, 1.0) - noise * 0.6
            h = noise * math.exp(-ht * 60.0) * 0.07 * level["hat"]
            sl += h * 0.8
            sr += h
        # 낮은 울림(보스·밤)
        if level["drone"] > 0.001:
            df = freq("A" if mood != "dark" else "D", 1)
            d = (math.sin(2.0 * math.pi * df * t) + 0.5 * math.sin(2.0 * math.pi * df * 1.5 * t)) \
                * (0.6 + 0.4 * math.sin(2.0 * math.pi * 0.25 * t)) * 0.13 * level["drone"]
            sl += d
            sr += d
        # 처음과 끝은 부드럽게
        g = min(1.0, t / 1.5) * min(1.0, (length - t) / 2.5)
        if t > end_start:
            g *= 1.0 + 0.25 * min(1.0, (t - end_start) / 1.5)
        sl = math.tanh(sl * g * 1.1)
        sr = math.tanh(sr * g * 1.1)
        left[i] = int(sl * 26000)
        right[i] = int(sr * 26000)
    inter = array.array("h", [0] * (2 * n))
    inter[0::2] = left
    inter[1::2] = right
    with wave.open(out_path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(inter.tobytes())


if __name__ == "__main__":
    main()
