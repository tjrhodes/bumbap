#!/usr/bin/env python3
"""Copy the four built front ends, the kit and the measured results into a website.

    python3 tools/export-to-site.py <site folder>

The site's Lab page (tomrhodes.it) plays each build in a frame and draws its charts from the results.
Everything goes where the builds already expect it, so no build needs changing:

    <site>/src/lab/bumbap/apps/<build>/dist/…   each build (served at /assets/lab/bumbap/…)
    <site>/src/lab/bumbap/samples/*.wav          the kit, found by every build at ../../../samples/
    <site>/content/bumbap_results/*.json         the measurements, read by the site's build

One change is made on the way: the builds load their fonts from Google Fonts, which a site in the EU
should not do without asking (it hands the visitor's address to Google). The exported pages load the
same faces from the site's own font files instead (FONTS_CSS below).
"""
import pathlib, re, shutil, sys

REPO = pathlib.Path(__file__).resolve().parent.parent
BUILDS = ("haxe", "react", "vue", "angular")
GOOGLE_FONTS = re.compile(r'\s*<link[^>]+fonts\.(googleapis|gstatic)\.com[^>]*>')
SITE_FONTS = '\n\t<link rel="stylesheet" href="../../../fonts.css">'

# The faces the panel uses, from the site's self-hosted Fira files. The site has no condensed 700, so
# the wordmark's 700 uses the 600 file (the browser would otherwise fake a bold).
FONT_FILES = [("Fira Sans Condensed", 500, "fira-sans-condensed-latin-500-normal"),
              ("Fira Sans Condensed", 600, "fira-sans-condensed-latin-600-normal"),
              ("Fira Sans Condensed", 700, "fira-sans-condensed-latin-600-normal"),
              ("Fira Sans", 400, "fira-sans-latin-400-normal"),
              ("Fira Sans", 500, "fira-sans-latin-500-normal")]


def fonts_css():
    """@font-face rules pointing at the site's /assets/fonts/ files."""
    face = '@font-face {{ font-family: "{0}"; font-weight: {1}; font-display: swap; src: url("/assets/fonts/{2}.woff2") format("woff2"); }}'
    return "/* bümbap on tomrhodes.it: the panel's fonts, from the site's own files */\n" + "\n".join(face.format(*f) for f in FONT_FILES) + "\n"


def copy_build(build, lab):
    """One build's dist folder, with its page's font link swapped for the site's fonts."""
    target = lab / "apps" / build / "dist"
    shutil.copytree(REPO / "apps" / build / "dist", target)
    page = target / "index.html"
    page.write_text(GOOGLE_FONTS.sub("", page.read_text(encoding="utf-8")).replace("</head>", SITE_FONTS + "\n</head>", 1), encoding="utf-8")


def copy_kit_and_results(lab, site):
    """The kit and its credits, then the measurement results the site's charts are drawn from."""
    (lab / "samples").mkdir(parents=True)
    for sound in [*(REPO / "samples").glob("*.wav"), REPO / "samples" / "CREDITS.md"]:
        shutil.copy(sound, lab / "samples" / sound.name)
    results = site / "content" / "bumbap_results"
    shutil.rmtree(results, ignore_errors=True)
    shutil.copytree(REPO / "tests" / "measure" / "results", results)


def main(site):
    """Replace what an earlier export left, then copy everything in."""
    lab = site / "src" / "lab" / "bumbap"
    shutil.rmtree(lab, ignore_errors=True)
    for build in BUILDS:
        copy_build(build, lab)
    (lab / "fonts.css").write_text(fonts_css(), encoding="utf-8")
    copy_kit_and_results(lab, site)
    print(f"exported {len(BUILDS)} builds, the kit and the results into {site}")


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]).resolve())
