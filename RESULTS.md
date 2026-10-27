# bümbap: results

The same drum machine, one shared Haxe engine, four front ends. The tables are version 2 (eight
patterns and a sequence), measured 27 October 2026; version 1, measured the day before, came out
within the same run-to-run noise (its numbers are in the history, at commit a28930d).
How each number is made is in `tests/measure/` (one script per measure); the raw numbers are in
`tests/measure/results/*.json`, and `node measure/tables.mjs` prints the tables below from them.

## In short

- **Size:** the Haxe build ships 4.1 kB of its own on top of the shared engine and Tone.js;
  Vue adds 24 kB, Angular 48 kB, React 66 kB. On every page, Tone.js (81 kB) is most of the weight.
- **Start-up:** Haxe paints the whole panel at 1.9 s on a slow phone; the frameworks take 4.7 to
  4.9 s, because they draw the panel from JavaScript while Haxe's markup is already in the page.
  Play is usable after 3.9–4.3 s in all four builds: downloading the drum kit decides that.
- **Playhead:** every build keeps up easily. On the slowed phone, the extra script per step over
  a bare page with no framework is under 1 ms for Haxe and Vue, 1.3 ms for Angular and about 2 ms
  for React.
  React re-runs the render of all sixteen keys each step; Vue and Angular re-check only what reads
  the playhead; Haxe moves one class by hand.
- **Dragging:** after one fix (below), Haxe, Angular and Vue all do 10.5 to 12 ms of work per pointer
  move on the phone, within noise of each other (each run reorders them); React does a little more.
- **Noise:** runs on a shared cloud machine vary by about ±0.5 ms per step and ±1 ms per move, so
  smaller differences say nothing about the frameworks.
- **The surprise:** the first Haxe version was the *slowest* to drag (up to 24 ms per move on
  the phone). It rewrote two pieces of text on every change, even when they had not changed,
  and each rewrite made the browser redo the page layout. Frameworks skip unchanged writes for
  you; hand-written DOM code has to do it itself. A three-line helper fixed it.
- **New features (version 2):** the sequence, its tools, Copy/Paste and Download cost 66 lines of
  front-end code in Vue, 75 in Angular, 105 in React and 114 in Haxe, and under 1 kB in each build;
  the engine took the real work (883 lines, 4.3 kB), once for all four. Details below.
- **Tooling:** Haxe builds in 0.5 s from 7 packages; Angular takes 5.5 s and installs 218.
- **Timing:** sound is scheduled by the shared engine in every build, so it is identical. The
  drawn playhead lands within a frame of the beat about 86 % of the time in every build,
  including the bare baseline: that spread comes from frame timing, not from the frameworks.

## How it was measured

- Headless Chromium (Playwright) on a cloud Linux machine, one build at a time.
- **Desktop:** a 1280×800 window at full speed. **Phone:** a 390×844 window with the CPU slowed
  four times (Chrome's setting for a mid-range phone). This is a stand-in, not a real Android phone.
- Each measure runs three times (start-up five), and the middle run is kept.
- "Main thread" is all the work Chrome's main thread did: script, style, layout, paint and
  everything else. "Script" is the JavaScript alone.
- The **baseline** is the same engine, Tone.js and kit with the least possible UI: sixteen bare
  keys, one class moved per step, no styles. What a build costs above it is its panel plus its framework.
- The **prototype** is the plain-JavaScript reference the builds were made from.
- The server gzips like a real host, and every build is minified. Haxe's output is minified with
  esbuild as the last step of its build; the other builds are minified by their own tooling.
- Google Fonts is blocked in every build: the measuring machine cannot reach it, and it would cost
  the same in every build.

## Size (minified and gzipped scripts)

| Build | Page scripts kB | Own share kB (less Tone.js 81.0 and engine 12.6) |
| --- | --- | --- |
| Haxe | 97.7 | 4.1 |
| Vue | 117.7 | 24.1 |
| Angular | 141.7 | 48.1 |
| React | 159.2 | 65.6 |

## Start-up (slow 4G phone)

"Play usable" is measured for real: slow 4G, a CPU slowed four times, from asking for the page
until the Play button is enabled (scripts run, kit downloaded and decoded). The rest comes from
Lighthouse's mobile preset.

| Build | Play usable after ms | Lighthouse score | First paint ms | Largest paint ms | Blocking ms | Script boot ms | Page weight kB |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Haxe | 3938 | 91 | 1927 | 1927 | 310 | 679 | 494 |
| React | 4299 | 72 | 2036 | 4674 | 403 | 790 | 557 |
| Vue | 4063 | 73 | 1801 | 4896 | 345 | 814 | 515 |
| Angular | 4151 | 75 | 1808 | 4869 | 307 | 727 | 539 |

- Haxe's high score is mostly its largest paint: its panel is plain markup in the HTML, so it
  appears as soon as the page and stylesheet arrive. A framework build could get the same result
  by rendering on the server or by pre-rendering the page.
- "Blocking" is about when scripts run, not how heavy the framework is. Haxe's plain scripts run
  before the first paint; Vue's single module runs as one long task after it.
- The kit (about 400 kB of WAV files) is most of the page weight and most of the wait before Play.

## Playhead at 200 BPM (30 s, about 400 steps)

| Build | Main thread ms/step | over baseline | Script ms/step | over baseline | Frames dropped (30 s) | Steps within a frame of 75 ms | Worst step error ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Baseline (engine, bare playhead) | 2.0 | 0 | 1.4 | 0 | 1 | 85.7 % | 32.7 |
| Prototype (plain JS) | 4.2 | 2.2 | 1.5 | 0.1 | 2 | 85.7 % | 41.8 |
| Haxe | 4.1 | 2.1 | 1.5 | 0.1 | 0 | 86.2 % | 25.9 |
| React | 5.1 | 3.1 | 2.0 | 0.6 | 3 | 85.4 % | 41.5 |
| Vue | 4.6 | 2.6 | 1.5 | 0.1 | 3 | 87.9 % | 41.7 |
| Angular | 4.8 | 2.8 | 1.7 | 0.3 | 2 | 86.2 % | 75.5 |

| Build | Main thread ms/step | over baseline | Script ms/step | over baseline | Frames dropped (30 s) | Steps within a frame of 75 ms | Worst step error ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Baseline (engine, bare playhead) | 7.8 | 0 | 5.9 | 0 | 0 | 87 % | 37.5 |
| Prototype (plain JS) | 17.8 | 9.9 | 6.2 | 0.3 | 0 | 86.2 % | 27.7 |
| Haxe | 17.7 | 9.9 | 6.4 | 0.5 | 4 | 87.9 % | 74 |
| React | 19.7 | 11.9 | 7.8 | 1.9 | 0 | 84.2 % | 35 |
| Vue | 18.1 | 10.2 | 6.1 | 0.1 | 1 | 86 % | 27.8 |
| Angular | 20.1 | 12.2 | 7.2 | 1.3 | 0 | 84.8 % | 30.3 |

- Every build's per-step cost is small next to the 75 ms between steps, even on the slowed phone.
- The main-thread time over the baseline is mostly the shared panel's styles and paint, the same
  in every build. The script column shows what the frameworks themselves add.
- The "idiomatic first version" rule (SPEC.md §5) is why React re-renders all sixteen keys each
  step. A version that updates the key from a ref would be a separate, labelled measurement.
- Frame drops are a handful in 1,800 frames in every build, the baseline included, so they are
  noise on this machine rather than a difference between builds. The same goes for "worst step
  error": it is one late frame in a 30-second run.

## Dragging (400 pointer moves, each changing the value)

| Build | Knob: main thread ms/move | Knob: script ms/move | Key: main thread ms/move | Key: script ms/move |
| --- | --- | --- | --- | --- |
| Prototype (plain JS) | 5.6 | 0.8 | 7.2 | 0.8 |
| Haxe | 3.1 | 0.6 | 3.4 | 0.6 |
| React | 4.2 | 1.3 | 4.4 | 1.2 |
| Vue | 3.7 | 0.3 | 4.2 | 0.2 |
| Angular | 3.4 | 1.0 | 4.0 | 1.0 |

| Build | Knob: main thread ms/move | Knob: script ms/move | Key: main thread ms/move | Key: script ms/move |
| --- | --- | --- | --- | --- |
| Prototype (plain JS) | 23.5 | 3.5 | 31.0 | 3.6 |
| Haxe | 10.9 | 2.6 | 10.3 | 1.9 |
| React | 12.9 | 4.6 | 13.3 | 4.1 |
| Vue | 11.0 | 0.8 | 12.3 | 0.6 |
| Angular | 10.8 | 3.2 | 11.2 | 2.2 |

- Vue does the least script per move: it patches only the attributes that changed. Haxe redraws
  every attribute of the panel on each change, which is simple and still cheap, but costs more
  script than Vue's fine-grained updates.
- First version of Haxe, before the fix: knob 4.4 / key 5.8 ms on desktop, 18.6 / 23.7 ms on the
  phone. The fix (`Dom.setText`: only write text that differs) took the phone figures down to
  10.5 ms. Those numbers are kept in `results/*-first-version.json`.

## Version 2: what the new features cost

Version 2 added eight patterns, a sequence to play them in with Select, Copy and Clear tools, Copy and
Paste for a part's steps, and a Download button that renders the sequence into a loop-ready WAV, to
every build (SPEC.md §1). `node measure/feature-cost.mjs` compares each front end with version 1 (git's own
line counts) and the code each one ships (`size.json`, before and after).

| Build | Front-end lines added / removed | Files touched | Own code added kB |
| --- | --- | --- | --- |
| Haxe | +114 / −1 | 4 | +0.3 |
| React | +105 / −4 | 4 | +0.5 |
| Vue | +66 / −4 | 4 | +0.6 |
| Angular | +75 / −5 | 4 | +1 |

Shared by all four, written once: the engine (+883 lines, +4.3 kB shipped), its unit tests (+546), the
browser tests every build runs (+177) and the stylesheet (+65).

- The engine did the real work: the sequence, the switch at the end of the bar, what each tool does
  with a tap, links that carry all eight patterns (and still open version 1's), the offline render and
  the WAV file (`Bounce`, `WavFile`, `LoopFile`), and even the buttons' gestures (`PatternPad`). So each front end only draws the buttons and passes on their taps.
- Vue needed the fewest lines again. Haxe needed the most because its markup is written out in its
  HTML page, where the frameworks loop in a template, and because it added `Dom.setAttribute`, which
  skips unchanged writes (version 1's lesson, applied before measuring this time).
- Nothing broke in any framework. The shared browser tests found one bug, in the engine (a shared
  link asked for `CP0000.wav`, a clap recording that does not exist), so one fix mended all four.
- Version 2 also lets any pattern be edited while the sequence plays (the sound follows the pattern
  playing). Speed did not change beyond the noise: the playhead, drag and start-up tables are version 2's.

## Code, build and install

| Build | UI code lines | UI files | Clean build s | Installed MB | Packages installed |
| --- | --- | --- | --- | --- | --- |
| Haxe | 685 | 11 | 0.5 | 41.3 | 7 |
| React | 589 | 17 | 1 | 103 | 32 |
| Vue | 457 | 17 | 3.3 | 97.2 | 53 |
| Angular | 537 | 18 | 5.5 | 233 | 218 |

- **UI code lines** count lines with code in them (not blank, not only a comment) in each app's
  own source and page. The shared engine and stylesheet are not counted.
- Haxe has the most lines: plain DOM code builds and updates the panel by hand, and the types
  that JavaScript leaves unwritten (`KnobSpec`, `KeyGesture`) are written down.
- **Clean build** is the middle of three builds from nothing. It includes type-checking: React's
  TypeScript 7 (the new native compiler) is fast; Vue's checker needs TypeScript 6.
- **Installed** is the app's `node_modules`. For Haxe that is the engine's (Tone.js and esbuild),
  plus the Haxe compiler itself (44 MB, not in the table). Every framework build also needs the
  engine built, so it needs Haxe too.

## What it was like to build each one

From each app's `NOTES.md`:

- **Haxe:** the quickest to write, as a port of the prototype. Because it compiles together with
  the engine's own source, a renamed engine field breaks the UI build, not the page in the
  browser; the compiler caught two mistakes before anything ran. Plain DOM code leaves the
  performance details to you: the text-rewrite cost above.
- **React:** `useSyncExternalStore` fits the engine's frozen snapshots with no glue code. React's
  own wheel events can't stop the page scrolling, so each knob adds a listener of its own. JSX
  grows quickly, so the 15-line rule split it into many small components.
- **Vue:** the least code. `shallowRef` is the whole adapter to the engine. Lists of refs don't
  keep their order, so function refs are needed. Its type-checker doesn't run on TypeScript 7 yet.
- **Angular:** the most ceremony and the biggest install, but signals make the state code as
  short as Vue's. It was the only build to fail tests on its first run (8 of 19): template
  whitespace in the part names, and knobs reading a stale value between quick key presses
  without zone.js. Its CLI needs Node 22.22 or newer.
