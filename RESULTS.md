# bümbap: results

The same drum machine, one shared Haxe engine, four front ends. The tables are version 2 (eight
patterns and a sequence), measured 27 October 2026; version 1, measured the day before, came out
within the same run-to-run noise (its numbers are in the history, at commit a28930d).
How each number is made is in `tests/measure/` (one script per measure); the raw numbers are in
`tests/measure/results/*.json`, and `node measure/tables.mjs` prints the tables below from them.

## In short

- **Size:** the Haxe build ships 4.2 kB of its own on top of the shared engine and Tone.js;
  Vue adds 24 kB, Angular 48 kB, React 66 kB. On every page, Tone.js (81 kB) is most of the weight.
- **Start-up:** Haxe paints the whole panel at 2.0 s on a slow phone; the frameworks take 4.8 to
  5.0 s, because they draw the panel from JavaScript while Haxe's markup is already in the page.
  Play is usable after 3.7–4.3 s in all four builds: downloading the drum kit decides that.
- **Playhead:** every build keeps up easily. On the slowed phone, the extra script per step over
  a bare page with no framework is under 1 ms for Haxe and Vue, 1.6 ms for Angular and 2.5 ms for
  React. React re-runs the render of all sixteen keys each step; Vue and Angular re-check only what
  reads the playhead; Haxe moves one class by hand. Differences under about 0.5 ms are noise.
- **Dragging:** after one fix (below), Haxe is the cheapest build per pointer move on the phone
  (about 11 ms), with Angular, React and Vue between 11.5 and 14 ms.
- **The surprise:** the first Haxe version was the *slowest* to drag (up to 24 ms per move on
  the phone). It rewrote two pieces of text on every change, even when they had not changed,
  and each rewrite made the browser redo the page layout. Frameworks skip unchanged writes for
  you; hand-written DOM code has to do it itself. A three-line helper fixed it.
- **One new feature (version 2):** eight patterns and a sequence cost 53 lines of front-end code in
  Vue, 60 in Angular, 76 in React and 97 in Haxe, and 0.4–0.6 kB in each build; the engine took the
  real work (557 lines, 2.6 kB), once for all four. Details below.
- **Tooling:** Haxe builds in 0.5 s from 7 packages; Angular takes 5.6 s and installs 218.
- **Timing:** sound is scheduled by the shared engine in every build, so it is identical. The
  drawn playhead lands within a frame of the beat about 87 % of the time in every build,
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

| Build | Page scripts kB | Own share kB (less Tone.js 81.0 and engine 10.9) |
| --- | --- | --- |
| Haxe | 96.0 | 4.2 |
| Vue | 115.8 | 24.0 |
| Angular | 139.5 | 47.7 |
| React | 157.3 | 65.5 |

## Start-up (slow 4G phone)

"Play usable" is measured for real: slow 4G, a CPU slowed four times, from asking for the page
until the Play button is enabled (scripts run, kit downloaded and decoded). The rest comes from
Lighthouse's mobile preset.

| Build | Play usable after ms | Lighthouse score | First paint ms | Largest paint ms | Blocking ms | Script boot ms | Page weight kB |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Haxe | 3736 | 91 | 2012 | 2012 | 303 | 832 | 492 |
| React | 4301 | 71 | 2144 | 4767 | 398 | 792 | 555 |
| Vue | 3664 | 74 | 1877 | 4821 | 343 | 842 | 513 |
| Angular | 4195 | 72 | 1915 | 5014 | 347 | 828 | 537 |

- Haxe's high score is mostly its largest paint: its panel is plain markup in the HTML, so it
  appears as soon as the page and stylesheet arrive. A framework build could get the same result
  by rendering on the server or by pre-rendering the page.
- "Blocking" is about when scripts run, not how heavy the framework is. Haxe's plain scripts run
  before the first paint; Vue's single module runs as one long task after it.
- The kit (about 400 kB of WAV files) is most of the page weight and most of the wait before Play.

## Playhead at 200 BPM (30 s, about 400 steps)

| Build | Main thread ms/step | over baseline | Script ms/step | over baseline | Frames dropped (30 s) | Steps within a frame of 75 ms | Worst step error ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Baseline (engine, bare playhead) | 2.4 | 0 | 1.6 | 0 | 1 | 87 % | 26.4 |
| Prototype (plain JS) | 4.8 | 2.4 | 1.7 | 0.1 | 0 | 88 % | 25.5 |
| Haxe | 4.4 | 2.0 | 1.5 | -0.1 | 6 | 87.4 % | 76.7 |
| React | 5.1 | 2.8 | 2.0 | 0.4 | 0 | 88 % | 27.9 |
| Vue | 4.6 | 2.2 | 1.6 | 0.0 | 2 | 87.5 % | 29.2 |
| Angular | 5.1 | 2.7 | 1.9 | 0.2 | 0 | 86.7 % | 26.6 |

| Build | Main thread ms/step | over baseline | Script ms/step | over baseline | Frames dropped (30 s) | Steps within a frame of 75 ms | Worst step error ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Baseline (engine, bare playhead) | 8.1 | 0 | 6.1 | 0 | 2 | 87.2 % | 30 |
| Prototype (plain JS) | 17.3 | 9.1 | 6.2 | 0.0 | 5 | 86.2 % | 56.3 |
| Haxe | 17.8 | 9.7 | 6.7 | 0.6 | 1 | 88.2 % | 28.6 |
| React | 21.6 | 13.5 | 8.6 | 2.5 | 0 | 84 % | 33.3 |
| Vue | 18.6 | 10.5 | 6.5 | 0.3 | 0 | 87.2 % | 30.8 |
| Angular | 21.1 | 12.9 | 7.7 | 1.6 | 1 | 84.8 % | 28.9 |

- Every build's per-step cost is small next to the 75 ms between steps, even on the slowed phone.
- The main-thread time over the baseline is mostly the shared panel's styles and paint, the same
  in every build. The script column shows what the frameworks themselves add.
- The "idiomatic first version" rule (SPEC.md §5) is why React re-renders all sixteen keys each
  step. A version that updates the key from a ref would be a separate, labelled measurement.
- Frame drops are a handful in 1,800 frames in every build, the baseline included, so they are
  noise on this machine rather than a difference between builds. The same goes for "worst step
  error": it is one late frame in a 30-second run (Haxe's 77 ms on desktop was a single hiccup).

## Dragging (400 pointer moves, each changing the value)

| Build | Knob: main thread ms/move | Knob: script ms/move | Key: main thread ms/move | Key: script ms/move |
| --- | --- | --- | --- | --- |
| Prototype (plain JS) | 5.8 | 0.9 | 7.2 | 0.9 |
| Haxe | 3.3 | 0.7 | 3.5 | 0.6 |
| React | 3.8 | 1.2 | 4.4 | 1.2 |
| Vue | 4.0 | 0.3 | 4.0 | 0.2 |
| Angular | 3.8 | 1.1 | 4.0 | 1.0 |

| Build | Knob: main thread ms/move | Knob: script ms/move | Key: main thread ms/move | Key: script ms/move |
| --- | --- | --- | --- | --- |
| Prototype (plain JS) | 20.8 | 3.0 | 30.5 | 3.3 |
| Haxe | 11.2 | 2.9 | 10.7 | 1.9 |
| React | 12.4 | 4.8 | 13.4 | 4.2 |
| Vue | 12.8 | 1.1 | 13.9 | 0.7 |
| Angular | 11.5 | 3.3 | 12.0 | 2.4 |

- Vue does the least script per move: it patches only the attributes that changed. Haxe redraws
  every attribute of the panel on each change, which is simple and still cheap, but costs more
  script than Vue's fine-grained updates.
- First version of Haxe, before the fix: knob 4.4 / key 5.8 ms on desktop, 18.6 / 23.7 ms on the
  phone. The fix (`Dom.setText`: only write text that differs) took the phone figures down to
  10.5 ms. Those numbers are kept in `results/*-first-version.json`.

## Version 2: what one feature cost

Version 2 added eight patterns, a sequence to play them in, and Select, Copy and Clear tools to every
build (SPEC.md §1). `node measure/feature-cost.mjs` compares each front end with version 1 (git's own
line counts) and the code each one ships (`size.json`, before and after).

| Build | Front-end lines added / removed | Files touched | Own code added kB |
| --- | --- | --- | --- |
| Haxe | +97 / −0 | 4 | +0.4 |
| React | +76 / −1 | 2 | +0.4 |
| Vue | +53 / −1 | 2 | +0.5 |
| Angular | +60 / −2 | 2 | +0.6 |

Shared by all four, written once: the engine (+557 lines, +2.6 kB shipped), its unit tests (+421), the
browser tests every build runs (+138) and the stylesheet (+47).

- The engine did the real work: the sequence, the switch at the end of the bar, what each tool does
  with a tap, links that carry all eight patterns (and still open version 1's), and even the buttons'
  gestures (`PatternPad`). So each front end only draws the buttons and passes on their taps.
- Vue needed the fewest lines again. Haxe needed the most because its markup is written out in its
  HTML page, where the frameworks loop in a template, and because it added `Dom.setAttribute`, which
  skips unchanged writes (version 1's lesson, applied before measuring this time).
- Nothing broke in any framework. The shared browser tests found one bug, in the engine (a shared
  link asked for `CP0000.wav`, a clap recording that does not exist), so one fix mended all four.
- Speed did not change beyond the noise: the playhead, drag and start-up tables are version 2's.

## Code, build and install

| Build | UI code lines | UI files | Clean build s | Installed MB | Packages installed |
| --- | --- | --- | --- | --- | --- |
| Haxe | 670 | 11 | 0.5 | 41.3 | 7 |
| React | 567 | 17 | 1.1 | 103 | 32 |
| Vue | 447 | 17 | 3.5 | 97.2 | 53 |
| Angular | 525 | 18 | 5.6 | 233 | 218 |

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
