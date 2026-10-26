"""Runs the smoke page in headless Chromium and checks the engine end to end:
samples load, Play makes sound, the playhead counts 0–15 at an even pace,
Stop clears it, and nothing throws.

Usage (from the repo root, after `npm install` in engine/ and `haxe build.hxml`):
    python3 engine/smoke/run.py
Needs Python Playwright with Chromium.
"""

import functools
import http.server
import statistics
import sys
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

REPO_ROOT = Path(__file__).resolve().parents[2]
PORT = 8765
STEP_MS_AT_100_BPM = 60_000 / 100 / 4  # one sixteenth note
CHROMIUM_FLAGS = ["--autoplay-policy=no-user-gesture-required"]
# Headless Chromium on a busy machine now and then drops a frame or two
# (~33 ms). That moves the drawing only; the sound is scheduled ahead on
# the audio clock. Real frame-drop figures come from a phone (SPEC.md §6).
LATE_TOLERANCE_MS = 40


def serve_repo():
    """A quiet static server for the repo root, on a background thread."""
    handler = functools.partial(QuietHandler, directory=str(REPO_ROOT))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def play_two_bars(page):
    """Loads the page, waits for the samples, adds drive, reverb, a nudge, a reversed snare, pitch, length and an 808 knob, plays a little over two bars, stops."""
    page.goto(f"http://127.0.0.1:{PORT}/engine/smoke/")
    page.wait_for_function("window.smokeReport && window.smokeReport.loaded", timeout=10_000)
    page.evaluate("machine.setDrive(60); machine.setReverb(40); machine.setStepNudge(1, 4, -6); machine.toggleStepReverse(1, 12); machine.setPitch(0, -3); machine.setLength(3, 40); machine.setDial(0, 1, 4)")
    page.click("#play")
    page.wait_for_timeout(5_200)
    page.click("#play")
    page.wait_for_timeout(300)
    return page.evaluate("window.smokeReport")


def check(report):
    """Each check is a line of plain English and whether it held."""
    steps = report["steps"]
    gaps = [b - a for a, b in zip(report["drawnAtMs"], report["drawnAtMs"][1:-1])]
    return [
        ("no errors on the page", not report["errors"]),
        ("playhead counts 0 to 15 and round again", steps[:32] == list(range(16)) * 2),
        ("stop clears the playhead (-1)", steps[-1] == -1),
        (f"steps drawn ~{STEP_MS_AT_100_BPM:.0f} ms apart (median {statistics.median(gaps):.1f})",
         abs(statistics.median(gaps) - STEP_MS_AT_100_BPM) < 5),
        (f"no step drawn noticeably late (worst gap {max(gaps):.1f} ms)",
         max(gaps) < STEP_MS_AT_100_BPM + LATE_TOLERANCE_MS),
        (f"sound reached the output (peak {report['peakDb']:.1f} dB)", report["peakDb"] > -30),
    ]


def main():
    server = serve_repo()
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(args=CHROMIUM_FLAGS)
        results = check(play_two_bars(browser.new_page()))
        browser.close()
    server.shutdown()
    for description, held in results:
        print(("✓ " if held else "✗ ") + description)
    sys.exit(0 if all(held for _, held in results) else 1)


if __name__ == "__main__":
    main()
