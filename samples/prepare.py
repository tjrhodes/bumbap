"""Makes the kit from Michael Fischer's free TR-808 sample set (Technopolis, 1994).

Usage: python3 samples/prepare.py "/path/to/TR808WAV"
Writes every variant of the eight parts next to this script, e.g. BD2550.wav. Needs numpy.

The set has each 808 sound at several knob positions; the file name says
which: two digits per knob, 00 = fully left, 25, 50, 75, 10 = fully right,
tone/tuning first, then decay/snappy (see TR808.TXT in the set). The engine
picks the file from its own 808 knobs (engine/src/drum/Kit.hx), so every
variant is copied, keeping the set's names.

The samples keep the 808's own levels (every sound was recorded with its
level knob full, peaking around -3 dBFS), so the balance between drums is the
machine's. Only the silent tail is cut, with a short fade so nothing clicks.
"""

import sys
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).parent

# The set's codes for the eight parts: kick, snare, clap, closed hat, open hat, low tom, high tom, rim.
PART_CODES = ["BD", "SD", "CP", "CH", "OH", "LT", "HT", "RS"]

SILENCE_DB = -60      # below this, relative to the sample's peak, counts as silence
FADE_SECONDS = 0.01   # fade over the last 10 ms, so the cut never clicks


def read_wav(path):
    """Mono 16-bit samples as floats from -1 to 1, and the sample rate."""
    with wave.open(str(path)) as file:
        assert file.getnchannels() == 1 and file.getsampwidth() == 2, f"{path}: expected 16-bit mono"
        frames = file.readframes(file.getnframes())
        return np.frombuffer(frames, "<i2").astype(np.float64) / 32768, file.getframerate()


def trim_tail(sound, rate):
    """Cuts the silence after the sound dies away, ending with a short fade-out."""
    threshold = np.abs(sound).max() * 10 ** (SILENCE_DB / 20)
    last_audible = np.nonzero(np.abs(sound) > threshold)[0][-1]
    fade_length = int(rate * FADE_SECONDS)
    trimmed = sound[: min(len(sound), last_audible + fade_length)].copy()
    trimmed[-fade_length:] *= np.linspace(1, 0, fade_length)
    return trimmed


def write_wav(path, sound, rate):
    pcm = np.clip(np.round(sound * 32768), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(rate)
        file.writeframes(pcm.tobytes())


def every_variant(source_folder):
    """Each part's folder holds its variants, named after its code: BD/BD0000.WAV … BD/BD7575.WAV."""
    for code in PART_CODES:
        yield from sorted((Path(source_folder) / code).glob(f"{code}*.WAV"))


def main(source_folder):
    for source in every_variant(source_folder):
        sound, rate = read_wav(source)
        trimmed = trim_tail(sound, rate)
        write_wav(HERE / f"{source.stem}.wav", trimmed, rate)
        print(f"{source.stem:7} {len(trimmed) / rate:.2f} s")


if __name__ == "__main__":
    main(sys.argv[1])
