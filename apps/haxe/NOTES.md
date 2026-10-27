# bümbap · Haxe

Plain DOM code in Haxe 4.3, compiled together with the engine's own Haxe
source. No framework, no Haxe libraries.

Build: `haxe build.hxml` (needs `npm install` in engine/ once, for Tone.js).

## How it is put together

| File | What it does |
|---|---|
| `src/Main.hx` | Makes the machine, restores a shared pattern, starts the panel. |
| `src/panel/Panel.hx` | Draws each snapshot; the knob table; transport; part selection; shortcuts. |
| `src/panel/StepKeys.hx` | The 16 keys and flip tabs: drawing, playhead, tap / drag / arrow gestures. |
| `src/panel/PartButtons.hx` | The 8 part pills and their M tabs; the LED flash on each hit. |
| `src/panel/Knob.hx` | One knob: drag, wheel, keys, double-click reset; points at its value. |
| `src/panel/SevenSegment.hx` | The LED display (drawn from the engine's `SevenSegmentFont`), resting and briefly-shown text. |
| `src/panel/Dom.hx`, `Pointer.hx` | Element helpers; following one pointer from press to release. |
| `index.html` | The static markup of the DOM contract; the code fills in pills and keys. |

- **State:** the panel subscribes to the machine and redraws attributes and
  classes on every snapshot. The markup is built once; nothing is ever
  re-created.
- **Playhead:** straight to the DOM. The machine's `onStep` moves one class
  from one key to the next and flashes the pills; the snapshot path is never
  involved.
- **Shared words:** the display font and every label and display text come
  from the engine (`SevenSegmentFont`, `PanelText`), as in every build.
- **Types:** the engine's `MachineState`, `TrackState`, `StepSettings` and
  `Range` are the same Haxe types the engine itself uses, so a renamed field
  in the engine breaks this build at compile time, not in the browser.

## Notes from building it

- First version passed all 19 shared tests at its first run.
- The compiler caught two mistakes before anything ran: an array mixing
  strings and numbers (the arrow-key table, now a typed record) and passing a
  plain string where the DOM wanted a node (`append(led, name)`, now a text
  node).
- The code is a straight port of the prototype's JavaScript, so it was the
  quickest of the builds to write; the extra work is in types (a `KnobSpec`,
  a `KeyGesture`) that JavaScript did not need written down.
- Haxe writes one readable, unminified ES2015 file. The other builds are
  minified by their own tooling, so this build now minifies too (esbuild, as
  the last step of build.hxml); without it, start-up would not be a fair
  comparison.
- **Measuring found a cost the frameworks hide.** The first version rewrote
  the status line and the 808 knob names on every snapshot, even when nothing
  had changed. Writing the same text still replaces the text node, so the
  browser redid the page's layout on every drag move: about 18 ms per move
  on the slowed "phone", against about 12 ms for Vue and Angular. React, Vue
  and Angular skip unchanged text for you; plain DOM code has to do it
  itself. A three-line `Dom.setText`, which writes only when the text differs,
  brought it down to about 10.5 ms, the cheapest of the builds (see RESULTS.md). The
  first-version numbers are kept in `tests/measure/results/*-first-version.json`.

## Who did what

Written by Claude (AI) from the prototype, to Tom's spec and code rules
(functions of at most 15 lines, DRY, names that tell the story). To review:
Tom.

## Versions

Haxe 4.3.7 · Tone.js 15.1.22

## Version 2: the sequence

- 97 lines: the buttons and the three tools as static markup in `index.html` (19 lines), a
  `PatternButtons` class that draws them from each snapshot and passes taps to the engine's
  `PatternPad`, and one helper.
- The helper is `Dom.setAttribute`, which skips writes that change nothing: the lesson from version 1's
  `setText`, applied before measuring this time rather than after.
- The most lines of the four, because its markup is written out in the page; the frameworks write theirs
  in templates that loop. It passed the shared tests on its first build, apart from the one engine bug
  they found (a shared link asked for `CP0000.wav`), fixed in the engine for every build at once.
