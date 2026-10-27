# bümbap · Vue

Vue 3.5 with `<script setup lang="ts">` single-file components, built with
Vite. The engine comes in as the `bumbap-engine` package (the compiled Haxe
engine and its `.d.ts`), Tone.js from npm, the stylesheet imported from
`shared/`.

Build: `npm install && npm run build` (the engine must be built first:
`haxe build.hxml` in engine/).

## How it is put together

| File | What it does |
|---|---|
| `src/main.ts` | Makes the machine once, outside Vue; restores a shared pattern; mounts the panel with it as a prop. |
| `src/panel.ts` | The panel's tools, provided once and injected below: machine, state, selected part, held display text; the playhead ref. |
| `src/components/BumbapPanel.vue` | Provides the tools; display text; loading, address, shortcuts. |
| `src/components/DeckSection.vue` | Display window, the four machine knobs, Play and Clear. |
| `src/components/PartSection.vue`, `DialSlot.vue` | Level, Pitch, Length, the 808 group. |
| `src/components/PartButtons.vue` | Pills and M tabs; the LED flash on each hit. |
| `src/components/StepKeys.vue` | Beats, flip tabs and keys. |
| `src/components/KnobControl.vue`, `KnobUnit.vue`, `SevenSegment.vue` | One knob; a knob with its printed name; the display. |
| `src/knob.ts`, `keyGestures.ts`, `pointer.ts` | Knob gestures; key gestures; pointer tracking. |

- **State:** a `shallowRef` set from `machine.subscribe`. Snapshots are
  frozen and replaced whole, so Vue needs no deep reactivity at all; the
  shallow ref is the whole adapter.
- **Playhead (idiomatic first version):** the step being heard is a `ref`.
  Vue tracks which keys read it, so each step re-renders the keys whose
  class actually changes, not the whole grid.
- **LED flash on hits:** a one-off animation, played on the element through
  function refs (indexed by part, since refs gathered by `v-for` alone do not
  promise the list's order).
- **Wheel on knobs:** `@wheel.prevent` stops the page scrolling as a knob
  turns; Vue adds the listener as non-passive when `.prevent` is used.
- **Shared words:** the display font and every label come from the engine
  (`SevenSegmentFont`, `PanelText`).

## Notes from building it

- First build passed all 19 shared tests at its first run.
- `vue-tsc` (Vue's type-checker) does not run on TypeScript 7, the new
  native compiler: it needs the JavaScript TypeScript package, so this build
  pins TypeScript 6.0 while the React build uses 7.0.
- The least code of the framework builds: templates carry the markup
  directly, and the gestures are plain functions shared by the components.
- Long attribute lists in templates are not functions, so the 15-line rule
  bites less here than in React's JSX; scripts are held to it all the same.

## Who did what

Written by Claude (AI) from the prototype, to Tom's spec and code rules
(functions of at most 15 lines, DRY, names that tell the story). To review:
Tom.

## Versions

Vue 3.5 · Vite 8.3 · vue-tsc 3.3 · TypeScript 6.0 · Tone.js 15.1.22

## Version 2: the sequence

- 53 lines, the fewest again: one single-file component, with the tools and the buttons as two `v-for`s
  in the template and the window listeners in `onMounted` / `onUnmounted`.
- Passed the shared tests on its first build.
