# bümbap: results

The same drum machine, one shared Haxe engine, four front ends. Measured 26 October 2026.
How each number is made is in `tests/measure/` (one script per measure); the raw numbers are in
`tests/measure/results/*.json`, and `node measure/tables.mjs` prints the tables below from them.

## In short

- **Size:** the Haxe build ships 3.8 kB of its own on top of the shared engine and Tone.js;
  Vue adds 23 kB, Angular 47 kB, React 65 kB. On every page, Tone.js (81 kB) is most of the weight.
- **Start-up:** Haxe paints the whole panel at 1.9 s on a slow phone; the frameworks take about
  4.7 s, because they draw the panel from JavaScript while Haxe's markup is already in the page.
  Play is usable after 3.6–4.3 s in all four builds: downloading the drum kit decides that.
- **Playhead:** every build keeps up easily. On the slowed phone, the extra script per step over
  a bare page with no framework is about 0 ms for Haxe, 0.7 ms for Vue, 1.5 ms for Angular and
  2.5 ms for React. React re-runs the render of all sixteen keys each step; Vue and Angular
  re-check only what reads the playhead; Haxe moves one class by hand.
- **Dragging:** after one fix (below), Haxe is the cheapest build per pointer move on the phone
  (10.5 ms), with Angular, Vue and React between 11.7 and 14.5 ms.
- **The surprise:** the first Haxe version was the *slowest* to drag (up to 24 ms per move on
  the phone). It rewrote two pieces of text on every change, even when they had not changed,
  and each rewrite made the browser redo the page layout. Frameworks skip unchanged writes for
  you; hand-written DOM code has to do it itself. A three-line helper fixed it.
- **Tooling:** Haxe builds in 0.4 s from 7 packages; Angular takes 5.7 s and installs 218.
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

| Build | Page scripts kB | Own share kB (less Tone.js 81.0 and engine 8.3) |
| --- | --- | --- |
| Haxe | 93.0 | 3.8 |
| Vue | 112.8 | 23.5 |
| Angular | 136.3 | 47.1 |
| React | 154.3 | 65.1 |

## Start-up (slow 4G phone)

"Play usable" is measured for real: slow 4G, a CPU slowed four times, from asking for the page
until the Play button is enabled (scripts run, kit downloaded and decoded). The rest comes from
Lighthouse's mobile preset.

| Build | Play usable after ms | Lighthouse score | First paint ms | Largest paint ms | Blocking ms | Script boot ms | Page weight kB |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Haxe | 3786 | 91 | 1894 | 1894 | 335 | 790 | 487 |
| React | 4326 | 71 | 2025 | 4674 | 436 | 817 | 550 |
| Vue | 3599 | 74 | 1884 | 4811 | 319 | 851 | 508 |
| Angular | 3958 | 75 | 1880 | 4796 | 313 | 798 | 532 |

- Haxe's high score is mostly its largest paint: its panel is plain markup in the HTML, so it
  appears as soon as the page and stylesheet arrive. A framework build could get the same result
  by rendering on the server or by pre-rendering the page.
- "Blocking" is about when scripts run, not how heavy the framework is. Haxe's plain scripts run
  before the first paint; Vue's single module runs as one long task after it.
- The kit (about 400 kB of WAV files) is most of the page weight and most of the wait before Play.

## Playhead at 200 BPM (30 s, about 400 steps)

| Build | Main thread ms/step | over baseline | Script ms/step | over baseline | Frames dropped (30 s) | Steps within a frame of 75 ms | Worst step error ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Baseline (engine, bare playhead) | 2.3 | 0 | 1.6 | 0 | 0 | 86 % | 29.1 |
| Prototype (plain JS) | 4.3 | 2.0 | 1.5 | 0.0 | 0 | 85.7 % | 29.7 |
| Haxe | 4.2 | 1.9 | 1.6 | 0.0 | 3 | 86.7 % | 74.8 |
| React | 5.0 | 2.7 | 2.0 | 0.4 | 1 | 86.2 % | 41.6 |
| Vue | 4.7 | 2.4 | 1.6 | 0.1 | 4 | 85.2 % | 41.5 |
| Angular | 5.2 | 2.9 | 1.8 | 0.2 | 0 | 85.7 % | 26.7 |

| Build | Main thread ms/step | over baseline | Script ms/step | over baseline | Frames dropped (30 s) | Steps within a frame of 75 ms | Worst step error ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Baseline (engine, bare playhead) | 8.2 | 0 | 6.1 | 0 | 7 | 85.4 % | 50.9 |
| Prototype (plain JS) | 17.0 | 8.8 | 6.2 | 0.1 | 2 | 87 % | 43.4 |
| Haxe | 16.0 | 7.8 | 6.0 | 0.0 | 3 | 87 % | 27.8 |
| React | 21.4 | 13.2 | 8.6 | 2.5 | 1 | 86 % | 34.5 |
| Vue | 19.1 | 10.9 | 6.8 | 0.7 | 9 | 87.7 % | 136 |
| Angular | 20.1 | 11.9 | 7.5 | 1.5 | 1 | 86.2 % | 49.1 |

- Every build's per-step cost is small next to the 75 ms between steps, even on the slowed phone.
- The main-thread time over the baseline is mostly the shared panel's styles and paint, the same
  in every build. The script column shows what the frameworks themselves add.
- The "idiomatic first version" rule (SPEC.md §5) is why React re-renders all sixteen keys each
  step. A version that updates the key from a ref would be a separate, labelled measurement.
- Frame drops are a handful in 1,800 frames in every build, the baseline included, so they are
  noise on this machine rather than a difference between builds. The same goes for "worst step
  error": it is one late frame in a 30-second run (Vue's 136 ms on the phone was a single hiccup).

## Dragging (400 pointer moves, each changing the value)

| Build | Knob: main thread ms/move | Knob: script ms/move | Key: main thread ms/move | Key: script ms/move |
| --- | --- | --- | --- | --- |
| Prototype (plain JS) | 3.2 | 0.7 | 3.5 | 0.6 |
| Haxe | 3.1 | 0.6 | 3.7 | 0.6 |
| React | 3.6 | 1.1 | 4.0 | 1.0 |
| Vue | 3.6 | 0.3 | 3.9 | 0.2 |
| Angular | 3.2 | 0.9 | 3.6 | 0.9 |

| Build | Knob: main thread ms/move | Knob: script ms/move | Key: main thread ms/move | Key: script ms/move |
| --- | --- | --- | --- | --- |
| Prototype (plain JS) | 10.2 | 2.7 | 11.5 | 2.1 |
| Haxe | 10.5 | 2.5 | 10.5 | 1.8 |
| React | 13.2 | 4.7 | 14.1 | 4.1 |
| Vue | 12.2 | 1.0 | 14.3 | 0.7 |
| Angular | 11.7 | 3.5 | 14.5 | 3.1 |

- Vue does the least script per move: it patches only the attributes that changed. Haxe redraws
  every attribute of the panel on each change, which is simple and still cheap, but costs more
  script than Vue's fine-grained updates.
- First version of Haxe, before the fix: knob 4.4 / key 5.8 ms on desktop, 18.6 / 23.7 ms on the
  phone. The fix (`Dom.setText`: only write text that differs) took the phone figures down to
  10.5 ms. Those numbers are kept in `results/*-first-version.json`.

## Code, build and install

| Build | UI code lines | UI files | Clean build s | Installed MB | Packages installed |
| --- | --- | --- | --- | --- | --- |
| Haxe | 568 | 9 | 0.4 | 41.3 | 7 |
| React | 486 | 15 | 1.1 | 74.7 | 30 |
| Vue | 382 | 15 | 3.5 | 97.2 | 53 |
| Angular | 440 | 15 | 5.7 | 211 | 218 |

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
