"""Builds the one-file bümbap prototype page: template + shared stylesheet + compiled engine + app.js + embedded samples.

Run after `haxe build.hxml` in engine/:  python3 prototype/build.py
It writes prototype/drum-preview.html, which opens straight from disk
(Tone.js comes from jsDelivr, the samples are embedded as base64).
"""

import base64
import json
from pathlib import Path

HERE = Path(__file__).parent
REPO = HERE.parent


def embedded_samples():
    """{"kick.wav": "<base64>", …} for every sample in the repo."""
    files = sorted((REPO / "samples").glob("*.wav"))
    return {file.name: base64.b64encode(file.read_bytes()).decode() for file in files}


def main():
    page = (HERE / "template.html").read_text()
    engine = (REPO / "engine/dist/drum-engine.haxe.js").read_text()
    app = (HERE / "app.js").read_text()
    style = (REPO / "shared/bumbap.css").read_text()
    page = page.replace("__STYLE__", style).replace("__ENGINE__", engine)
    page = page.replace("__SAMPLES__", json.dumps(embedded_samples())).replace("__APP__", app)
    (HERE / "drum-preview.html").write_text(page)
    print(f"drum-preview.html: {len(page) // 1024} KB")


main()
