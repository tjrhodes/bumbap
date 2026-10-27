# bümbap: one spec, five front ends

bümbap is a small step sequencer for drum samples, built five times on one shared
engine: **Haxe → vanilla JS, React, Vue, Angular** (and optionally plain
TypeScript as a no-framework baseline). The point is the comparison, so
everything that is not the UI layer is shared and identical.

## 1. What the user can do

The panel is modelled on a small hardware groovebox (Tom's Korg volca beats
was the reference for shapes and style), in the Norwegian rock palette. One
part's sixteen steps are shown at a time; a part selector chooses which.

| Feature | Detail |
|---|---|
| Parts | Kick, Snare, Clap, Closed hat, Open hat, Low tom, High tom, Rim. Fixed, one sample each. Eight pills select the part being edited; each pill's LED flashes when its part plays, brighter for harder hits. Keys 1–8 select too. |
| Steps | 16 brass keys (one bar of sixteenths), grouped in four beats. Tap a key to switch its step on (velocity 85, on the grid, forwards) or off. |
| Step level | Drag a key up or down: velocity 1–100. The key fills from the bottom to its level and its LED brightens. 85 plays at the part's level; every 8 points is 3 dB, so 100 is an accent (+5.6 dB), 45 is −15 dB and 1 is −31.5 dB. |
| Step nudge | Drag a key sideways: up to ±16 ticks (a beat is 384 ticks), i.e. ±1/24 of a beat, about ±25 ms at 100 BPM. The key moves by a hair (3 px at most) and its LED a little further. A drag picks its axis from the first clear movement and keeps it. Dragging an empty key switches it on. |
| Step flip | A small tab above each key plays that step's sample backwards (tab lit, key number printed back to front). Flipping an empty key switches it on, reversed. A reversed hit fills its own step and ends exactly as the next step starts: only the last step-length of the reversed sample plays, faded in over 12 ms where it cuts in; a sample shorter than the step starts later instead. The step length follows tempo and swing; a nudge moves the whole hit. The engine trims each sample's silent tail before reversing it. |
| Display | Four-digit seven-segment display. Shows the tempo; while something is changed it shows that value for 1.2 s: S swing, d drive, r reverb, L level, P pitch, E length, u step velocity, n step nudge; an 808 knob shows the recording's setting digits (e.g. 2550). "LoAd" while loading, "Err" if the samples fail. |
| Machine knobs | Tempo 60–200 BPM (100). Swing 50–75 % (50; MPC-style, 66 is a triplet shuffle). Drive 0–100 (0). Reverb 0–100 (0). Drag up/right, scroll, arrow keys, Home/End; double-click resets. |
| Part knobs | For the selected part: Level 0–100 (80); Pitch ±12 semitones (0; a playback rate, so higher is also shorter, like a sampler); Length 5–100 % (100; how much of the sound is heard before it has faded out). A framed "808" group holds the part's real 808 knobs, which choose between the set's recordings: Kick Tone + Decay, Snare Tone + Snappy, Open hat Decay, Low/High tom Tuning; five detents each (the set's 00, 25, 50, 75, 10); clap, closed hat and rim have none, so the slots sit dimmed. A new recording loads the first time it is chosen; the part plays its old one until then. |
| Buttons | Play/Stop (LED), Clear (empties every step; tempo, swing, effects and part settings stay). An M tab above each part button mutes that part without selecting it. Space toggles play when focus is not on a control. |
| Drive | Warm valve-style overdrive on the whole kit: asymmetric tanh soft clip (even harmonics), a low-pass that closes as drive rises, and a trim so the knob changes character more than loudness. |
| Reverb | A 2.2 s room on the whole kit, after the drive; 100 % is as loud as the dry kit. |
| Safety | A soft clipper at the end of the chain: the output never passes full scale, however many accents land together. |
| Share | The whole pattern, including every step's level and nudge, lives in the URL hash. The share button (top right) copies that link, or offers it through the share sheet on a touch screen; in a frame on a page of the same site (the Lab page), the link is to that page. |
| Start | With no code in the URL, a starter beat with accents and ghost notes is loaded. |
| Loading | Panel usable at once; Play is disabled until the samples are decoded. |

Out of scope: more bars, pattern chaining, recording, sample upload, MIDI.
Five small finished builds beat five big unfinished ones.

## 2. The shared parts (identical in every build)

1. **Engine** (`engine/`, Haxe): pattern model, timing (swing and nudge),
   loudness, sample playback and the master chain (drive, reverb, safety
   clipper) through Tone.js, URL code. Every front end talks to it only
   through the API in section 3. No front end touches Tone.js directly.
   The engine also carries the panel's words (`PanelText`) and the LED
   display's font (`SevenSegmentFont`), so no build re-types them.
2. **Samples** (`samples/`): the same 68 recordings (every variant of the eight parts), from Michael Fischer's free
   TR-808 sample set (see `samples/CREDITS.md`; `samples/prepare.py` makes them).
3. **Stylesheet** (`shared/bumbap.css`): one CSS file, written once.
4. **DOM contract** (section 4): every build renders the same structure and
   class names, so the one stylesheet and the one test suite work on all.
5. **Test suite** (`tests/`, Playwright): one suite run against every build
   in CI. A build is done when the suite passes.

## 3. Engine API

The engine is published as an ES module with TypeScript definitions
(`engine/dist/drum-engine.js`, `engine/drum-engine.d.ts`). The Haxe front
end compiles the engine source in directly.

```ts
import * as Tone from "tone";
import { DrumMachine } from "bumbap-engine";

const machine = new DrumMachine({ tone: Tone, samplesUrl: "/samples/" });

machine.getState();          // MachineState: an immutable snapshot
machine.subscribe(fn);       // fn(state) after every change; returns unsubscribe
machine.onStep(fn);          // fn(step) on the frame each step sounds; -1 on stop

machine.load();              // Promise: downloads and decodes the samples
machine.togglePlay();        // Promise (play must follow a user gesture)
machine.play(); machine.stop();
machine.toggleStep(track, step);
machine.setStepVelocity(track, step, velocity);   // switches the step on if off
machine.setStepNudge(track, step, ticks);         // switches the step on if off
machine.toggleStepReverse(track, step);           // backwards ↔ forwards; switches the step on if off
machine.setTempo(bpm); machine.setSwing(percent);
machine.setDrive(percent); machine.setReverb(percent);
machine.setVolume(track, percent); machine.toggleMute(track);
machine.setPitch(track, semitones); machine.setLength(track, percent);
machine.setDial(track, dial, position);           // an 808 knob, 0–4: picks another recording
machine.clear();
machine.loadCode(code);      // true if the URL code was valid and applied
machine.dispose();           // stops and releases the clock and the audio graph

DrumMachine.limits           // { steps, ticksPerBeat, tempo, swing, volume, velocity, nudge, drive, reverb, pitch, length, dial }
```

`MachineState` is `{ status, playing, tempo, swing, drive, reverb, code,
tracks[] }`, each track `{ id, name, volume, muted, pitch, length, dials[],
dialNames[], sample, steps[] }` (`sample` is the chosen recording, e.g. "BD2550"), each step
`{ on, velocity, nudge, reversed }`. A new snapshot object is made on every change and
the same object is returned until the next one, so it works as-is with
React's `useSyncExternalStore`, Vue's `shallowRef` and Angular signals.
Values handed in are clamped and rounded by the engine, so a UI can pass raw
drag maths straight through.

**Two channels on purpose.** Pattern edits come through `subscribe`; the
playhead comes through `onStep`, up to ~13 times a second at 200 BPM. How each
framework handles that second stream (re-render the keys, update one
reactive value, or touch the DOM directly) is the most interesting part of
the comparison. The knob and the key gestures are the other: each build
writes them as its framework's idea of a reusable component.

## 4. DOM contract

Draft, taken from the prototype (`prototype/`, published as "Bümbap"); it is final once the
UI is signed off.

```html
<main class="dm">
  <div class="dm-panel">
    <header class="dm-head">
      <span class="dm-wordmark">bümbap</span><span class="dm-print">16 step · 8 part · Haxe engine</span>
      <span class="dm-print dm-share-note" aria-live="polite">Link copied</span>   <!-- empty when nothing to say -->
      <button class="dm-share" type="button" aria-label="Share this beat"><svg class="dm-share-icon">…</svg></button>
    </header>
    <section class="dm-deck" aria-label="Controls">
      <div class="dm-window">
        <svg class="dm-display" aria-hidden="true">…4 digits × 7 .dm-seg, lit ones .is-lit…</svg>
        <p class="dm-print dm-status" role="status">Ready</p>
      </div>
      <div class="dm-unit dm-tempo">                    <!-- also dm-swing, dm-drive, dm-reverb, dm-level -->
        <span class="dm-print">Tempo</span>
        <div class="dm-knob" role="slider" tabindex="0" aria-label="Tempo, beats per minute"
             aria-valuemin="60" aria-valuemax="200" aria-valuenow="100" style="--turn: -42deg">
          <span class="dm-knob-cap"></span>
        </div>
      </div>
      <div class="dm-unit dm-play-unit">                <!-- also dm-clear-unit -->
        <span class="dm-print"><span class="dm-led is-on"></span>Play</span>
        <button class="dm-rubber dm-rubber-play" aria-pressed="true" aria-label="Stop"><span class="dm-icon"></span></button>
      </div>
    </section>
    <section class="dm-part" aria-label="Part">
      <h2 class="dm-print dm-rule">Part</h2>
      <div class="dm-strip">
        <div class="dm-unit">…Level knob…</div> <div class="dm-unit">…Pitch…</div> <div class="dm-unit">…Length…</div>
        <div class="dm-dials">
          <span class="dm-print dm-dials-label">808</span>
          <div class="dm-unit"><span class="dm-print">Tone</span><div class="dm-knob dm-knob-808" role="slider" …></div></div>
          <!-- two slots; a part without that knob: .dm-unit.is-unused, label "—", aria-disabled -->
        </div>
      </div>
      <div class="dm-pills" role="group" aria-label="Part">
        <div class="dm-pill-wrap">
          <button class="dm-tab dm-mute" aria-pressed="false" aria-label="Mute Kick">M</button>
          <button class="dm-pill" aria-pressed="true"><span class="dm-led"><span class="dm-led-glow"></span></span>Kick</button>
        </div>
        <!-- …8 parts; a muted part's pill also gets .is-muted -->
      </div>
    </section>
    <section class="dm-steps" aria-label="Steps">
      <h2 class="dm-print dm-rule">Steps</h2>
      <div class="dm-keys">
        <div class="dm-beat" data-beat="1">
          <button class="dm-tab dm-flip" aria-pressed="false" aria-label="Play Kick step 1 backwards"><span class="dm-flip-icon"></span></button>
          <button class="dm-key" aria-pressed="true" aria-label="Kick step 1, level 100, nudge 0"
                  style="--level: 1; --nudge: 0">
            <span class="dm-key-fill"></span><span class="dm-key-led"></span><span class="dm-key-number">1</span>
          </button>
          <!-- …a flip and a key per step, 4 steps per beat, 4 beats; the playing key also
               gets .is-current, a reversed one .is-reversed -->
        </div>
      </div>
    </section>
  </div>
</main>
```

Accessibility comes with the contract: real buttons with `aria-pressed`,
knobs as labelled sliders with keyboard control, arrow keys on a focused key
for level and nudge, a live status line. Tests find elements by role and
label, never by framework internals.

## 5. Fair-comparison rules

- Each build uses its framework's own recommended tooling and idioms
  (Vite for React and Vue, the Angular CLI for Angular, the Haxe compiler
  for Haxe). No cross-framework helper libraries, no state libraries.
- First version of each: the idiomatic way to draw the playhead. If a
  faster variant is added, it is a separate, labelled measurement.
- Latest stable versions at build time; exact versions recorded in the results.
- Same code standards everywhere: functions of at most 15 lines, DRY,
  names that tell the story, comments that explain the why.
- Each build keeps a `NOTES.md`: time spent, what was easy, what fought
  back, and what was AI-assisted versus written or reviewed by hand.

## 6. What gets measured

| Measure | How |
|---|---|
| Bundle size | App code alone, and total with Tone.js; minified and gzipped. Tone.js is the same in all, so the app share is the honest number. |
| Start-up | Lighthouse (mobile preset): score, first and largest paint, total blocking time; and time until Play is usable on slow 4G with a slowed CPU. |
| Playhead cost | 200 BPM for 30 s: main-thread and script ms per step (from Chrome's performance counters) and dropped frames, on desktop and on a phone-sized window with the CPU slowed four times; compared with a bare baseline (engine, no UI). |
| Timing | Audio is scheduled by the engine in all builds, so sound timing should be identical; the playhead measure records how evenly the lit key moves (share of steps within one frame of the beat, worst error). |
| Gesture cost | Main-thread and script time per pointer move while dragging a knob and a key, 400 moves each changing the value (each move re-renders through the snapshot path). |
| Code | Lines of UI code (excluding shared CSS and engine), number of files, build time, install size. |
| Developer experience | From the `NOTES.md` files: setup time, friction, debugging, type-safety catches. |

## 7. On the Lab page

The playable sampler with a switch between the builds (each in its own
iframe; the pattern travels across in the URL), the results table, and a
short write-up of what was learned. Source in one public GitHub repo.

## 8. Folder layout

```
bumbap/
  SPEC.md            this file
  engine/            shared Haxe engine (src/, test/, dist/)
  samples/           the TR-808 recordings and the script that makes them
  prototype/         the panel prototype in plain JavaScript: the UI reference
  shared/            bumbap.css
  apps/haxe/  apps/react/  apps/vue/  apps/angular/  (apps/typescript/)
  tests/             one Playwright suite for every app
```
