#!/usr/bin/env python3
"""Synthesizes EarlyOtter's original alarm tones. Standard library only.

Usage: ./synth.py [tone ...]    (renders all tones when none are named)
Writes straight into the app's AlarmSounds folder. Every tone is built from
sine math as 44.1 kHz mono 16-bit WAV, under AlarmKit's 30-second limit.
Output is deterministic, so re-rendering an unchanged tone produces the same file.
"""
import array, math, pathlib, random, sys, wave

OUT_DIR = pathlib.Path(__file__).resolve().parents[2] / "EarlyOtter/Resources/AlarmSounds"
RATE = 44_100
TAU = 2 * math.pi


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# MARK: Instruments. Each returns a list of samples for one note.

def marimba(f, dur=1.2):
    """A wooden bar: a fundamental plus the bright, fast-fading overtones of a mallet hit."""
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        out.append(math.sin(TAU * f * t) * math.exp(-t * 5)
                   + 0.30 * math.sin(TAU * 3.9 * f * t) * math.exp(-t * 16)
                   + 0.08 * math.sin(TAU * 9.2 * f * t) * math.exp(-t * 60))
    return out


def kalimba(f, dur=1.6):
    """A thumb piano: a plucked tine with one inharmonic overtone."""
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        attack = min(1.0, t * 400)
        out.append(attack * (math.sin(TAU * f * t) * math.exp(-t * 3.5)
                             + 0.35 * math.sin(TAU * 5.4 * f * t) * math.exp(-t * 22)))
    return out


def organ(freqs, dur, attack=1.5, release=1.5):
    """A pipe-organ chord: drawbar harmonics with a slow swell, lightly chorused."""
    drawbars = ((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.25), (6, 0.1), (8, 0.08))
    out, n = [], int(dur * RATE)
    voices = [f * d for f in freqs for d in (0.999, 1.001)]
    for i in range(n):
        t = i / RATE
        s = sum(w * math.sin(TAU * h * f * t) for f in voices for h, w in drawbars if h * f < 12_000)
        out.append(s * min(1.0, t / attack) * min(1.0, (n - i) / (release * RATE)) / len(voices))
    return out


def celesta(f, dur=1.4):
    """A soft, glassy keyboard note for the arpeggio."""
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        out.append(min(1.0, t * 300) * (math.sin(TAU * f * t) * math.exp(-t * 3)
                                         + 0.25 * math.sin(TAU * 2 * f * t) * math.exp(-t * 6)
                                         + 0.08 * math.sin(TAU * 4 * f * t) * math.exp(-t * 12)))
    return out


def tick(dur=0.03):
    """A clock tick: a short, bright resonant click."""
    rng = random.Random(1)
    out, low = [], 0.0
    for i in range(int(dur * RATE)):
        t = i / RATE
        low += 0.5 * (rng.uniform(-1, 1) - low)
        out.append((0.85 * math.sin(TAU * 2600 * t) + 0.15 * low) * math.exp(-t * 180))
    return out


def pad(freqs, dur, rng, attack=2.0):
    """Soft chord: detuned band-limited saws through a one-pole low-pass.
    `rng` sets each voice's starting phase."""
    out, low = [], 0.0
    voices = [(f * d, rng.random() * TAU) for f in freqs for d in (0.997, 1.003)]
    for i in range(int(dur * RATE)):
        t = i / RATE
        s = sum(sum(math.sin(k * (TAU * f * t + p)) / k for k in range(1, 7)) for f, p in voices)
        low += 0.05 * (s - low)
        swell = min(1.0, t / attack) * min(1.0, (dur - t) / 1.0)
        out.append(low * swell / len(voices))
    return out


def beep(f, dur=0.09):
    """Classic digital alarm beep: an odd-harmonic square wave with tiny fades."""
    out, n = [], int(dur * RATE)
    for i in range(n):
        t = i / RATE
        edge = min(1.0, i / 90, (n - i) / 90)
        out.append(edge * sum(math.sin(TAU * k * f * t) / k for k in (1, 3, 5)))
    return out


# MARK: Mixing

class Track:
    def __init__(self, seconds):
        self.samples = [0.0] * int(seconds * RATE)

    def add(self, note, at, gain=1.0):
        start = int(at * RATE)
        for i, s in enumerate(note[: len(self.samples) - start]):
            self.samples[start + i] += s * gain

    def reverb(self, mix=0.25, size=1.0, decay=0.80):
        """Schroeder reverb: four parallel combs into two all-passes.
        Raise `size` and `decay` for a larger, longer hall."""
        dry = self.samples
        wet = [0.0] * len(dry)
        for n, base in enumerate((1557, 1617, 1491, 1422)):
            delay, feedback = int(base * size), decay - 0.01 * n
            buf = [0.0] * delay
            for i, x in enumerate(dry):
                y = buf[i % delay]
                buf[i % delay] = x + y * feedback
                wet[i] += y
        for delay in (225, 556):
            buf = [0.0] * delay
            for i, x in enumerate(wet):
                y = buf[i % delay]
                buf[i % delay] = x + y * 0.5
                wet[i] = y - 0.5 * x
        self.samples = [d + mix * w / 4 for d, w in zip(dry, wet)]
        return self

    def swell(self, start=0.35, full_at=14.0):
        """Starts quiet and reaches full volume by `full_at` seconds."""
        for i in range(len(self.samples)):
            self.samples[i] *= start + (1 - start) * min(1.0, i / (full_at * RATE))
        return self

    def write(self, path):
        peak = max(abs(s) for s in self.samples) or 1.0
        scale = 0.89 / peak  # about -1 dBFS
        fade = int(0.05 * RATE)
        n = len(self.samples)
        pcm = array.array("h", (
            int(32767 * s * scale * min(1.0, (n - i) / fade))
            for i, s in enumerate(self.samples)))
        with wave.open(str(path), "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(pcm.tobytes())


def pattern(track, instrument, notes, beat, gain=1.0, start=0.0):
    """Places notes one beat apart; None is a rest."""
    for n, midi in enumerate(notes):
        if midi is not None:
            track.add(instrument(hz(midi)), start + n * beat, gain)


# MARK: Tones

def sunrise():
    """A marimba arpeggio climbing through C major pentatonic, louder each bar."""
    t = Track(24)
    bars = [[60, 64, 67, 72], [62, 67, 69, 74], [64, 69, 72, 76], [67, 72, 76, 79]]
    beat = 0.3
    for rep in range(5):
        for b, bar in enumerate(bars):
            pattern(t, marimba, bar, beat, gain=0.6, start=rep * 4.8 + b * 1.2)
    return t.reverb(0.3).swell(0.3, 15)


def starlight():
    """A slow cinematic build in A minor, in the spirit of an interstellar score.

    A clock ticks from the first beat. The organ enters softly, a celesta
    arpeggio starts turning in bar 3, bass and a high line join in bar 5,
    and the last two bars open into a full A-major chord (a Picardy third)
    that rings out before the file loops.
    """
    bpm = 72
    beat = 60 / bpm
    bar = 4 * beat
    progression = [  # (bass, chord) as MIDI notes
        (45, [57, 60, 64]), (45, [57, 60, 64, 71]), (41, [57, 60, 65]), (41, [57, 60, 65, 72]),
        (48, [55, 60, 64]), (43, [55, 59, 62]), (45, [57, 60, 64]), (45, [57, 61, 64, 69]),
    ]
    t = Track(len(progression) * bar + 2.5)

    for n, (bass, chord) in enumerate(progression):
        start = n * bar
        final = n == len(progression) - 1
        grandeur = 0.35 + 0.65 * n / (len(progression) - 1)
        t.add(organ([hz(m) for m in chord], bar + (2.5 if final else 0.6), attack=1.2 if n else 2.5),
              start, 0.55 * grandeur)
        if n >= 2:  # arpeggio: chord tones walking up and back, two octaves up
            walk = [m + 12 for m in chord[:3]] + [chord[0] + 24] + [m + 12 for m in reversed(chord[1:3])]
            for k in range(8):
                t.add(celesta(hz(walk[k % len(walk)])), start + k * beat / 2, 0.22 * grandeur)
        if n >= 4:  # bass and organ pedal
            t.add(organ([hz(bass - 12), hz(bass)], bar + 0.6, attack=0.8), start, 0.45 * grandeur)
        if n >= 5:  # a high line answering the arpeggio
            t.add(celesta(hz(chord[-1] + 24), 2.5), start + beat, 0.18)
            t.add(celesta(hz(chord[0] + 24), 2.5), start + 3 * beat, 0.15)

    t.reverb(0.4, size=1.6, decay=0.86)
    for b in range(len(progression) * 4):  # the clock never stops; kept dry so it stays crisp
        t.add(tick(), b * beat, 0.12 if b % 4 else 0.2)
    return t


def otter():
    """A playful xylophone tune with a bounce."""
    t = Track(24)
    tune = [72, 76, 79, 76, 81, 79, 76, None, 74, 77, 81, 77, 84, 81, 79, None]
    for rep in range(6):
        pattern(t, marimba, tune, 0.25, gain=0.6, start=rep * 4)
        t.add(marimba(hz(48), 2), rep * 4, 0.5)
        t.add(marimba(hz(55), 2), rep * 4 + 2, 0.5)
    return t.reverb(0.2).swell(0.4, 12)


def tide():
    """Warm swelling chords with a kalimba melody drifting on top."""
    rng = random.Random(3)
    t = Track(26)
    chords = [[48, 55, 64], [45, 52, 60], [41, 48, 57], [43, 50, 59]]
    for c, chord in enumerate(chords * 2):
        t.add(pad([hz(m) for m in chord], 3.6, rng, attack=1.2), c * 3.2, 0.9)
    melody = [72, None, 76, 79, None, 76, 74, None]
    for rep in range(6):
        pattern(t, kalimba, melody, 0.5, gain=0.7, start=1.6 + rep * 4)
    return t.reverb(0.3).swell(0.3, 16)


def classic():
    """The familiar four-beep digital alarm."""
    t = Track(16)
    for group in range(16):
        for b in range(4):
            t.add(beep(hz(95)), group * 1.0 + b * 0.13, 0.6)
    return t


TONES = {
    "Sunrise": sunrise,
    "Starlight": starlight,
    "Otter": otter,
    "Tide": tide,
    "Classic": classic,
}


if __name__ == "__main__":
    for name in sys.argv[1:] or TONES:
        path = OUT_DIR / f"Alarm{name}.wav"  # must match AlarmSoundOption.resourceName
        TONES[name]().write(path)
        print("wrote", path)
