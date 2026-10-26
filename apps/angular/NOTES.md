# bümbap · Angular

Angular 22 standalone components, zoneless, with signals for all state; built
with the Angular CLI. The engine comes in as the `bumbap-engine` package (the
compiled Haxe engine and its `.d.ts`), Tone.js from npm, the stylesheet from
`shared/` through `angular.json`.

Build: `npm install && npx ng build` (the engine must be built first:
`haxe build.hxml` in engine/). Needs Node 22.22 or newer.

## How it is put together

| File | What it does |
|---|---|
| `src/main.ts`, `src/app/app.config.ts` | Makes the machine once, outside Angular; restores a shared pattern; provides it as `MACHINE`; zoneless change detection. |
| `src/app/panel-store.ts` | The panel's state as signals: snapshot, selected part, playhead, held display text. |
| `src/app/panel.ts` | `bm-panel`: loading, address, shortcuts. |
| `src/app/deck.ts` | Display window, the four machine knobs, Play and Clear. |
| `src/app/part-section.ts`, `dial-slot.ts` | Level, Pitch, Length, the 808 group. |
| `src/app/part-buttons.ts` | Pills and M tabs; the LED flash on each hit. |
| `src/app/step-keys.ts`, `key-gestures.ts` | Beats, flip tabs and keys; their gestures. |
| `src/app/knob.ts`, `knob-unit.ts`, `seven-segment.ts` | One knob; a knob with its printed name; the display. |
| `src/app/pointer.ts` | Following one pointer from press to release. |

- **State:** one `signal` set from `machine.subscribe`; every derived value is
  a `computed`. Frozen snapshots compare by identity, so signals are a
  natural fit and no zone.js is needed.
- **DOM contract:** components use attribute selectors (`div[bmKnob]`,
  `svg[bmSevenSegment]`) so Angular adds no wrapper elements of its own and
  the shared stylesheet and tests see the same markup as every other build.
- **Playhead (idiomatic first version):** a signal; the keys whose class
  changes are updated by Angular's fine-grained signal tracking.
- **LED flash on hits:** a one-off animation on the elements, reached with
  `viewChildren`.
- **Shared words:** the display font and every label come from the engine
  (`SevenSegmentFont`, `PanelText`).

## Notes from building it

- First run of the shared suite: 8 of 19 failed; all fixed in one pass.
  - Pill names had trailing whitespace from the template's line break (the
    accessible name became "Kick "); the name now sits on the same line as
    `</button>`.
  - Knobs pressed quickly from the keyboard read a stale value: zoneless
    Angular redraws a moment after a change, so two key presses in a row both
    started from the old number. Each knob now takes a `latest` input that
    reads the value straight from the machine.
- The CLI needs a newer Node (22.22+) than the other builds.
- The production build tries to inline Google Fonts and fails offline;
  `optimization.fonts` is off (the stylesheet loads them itself, as in every
  build).
- TypeScript 6.0: the Angular compiler does not yet run on TypeScript 7.
- The most ceremony of the builds (decorators, providers, `angular.json`),
  but signals made the state code as short as Vue's.

## Who did what

Written by Claude (AI) from the prototype, to Tom's spec and code rules
(functions of at most 15 lines, DRY, names that tell the story). To review:
Tom.

## Versions

Angular 22.2 · TypeScript 6.0 · Node 24 · Tone.js 15.1.22
