# bümbap · React

React 19 with TypeScript, built with Vite. The engine comes in as the
`bumbap-engine` package (the compiled Haxe engine and its `.d.ts`), Tone.js
from npm, the stylesheet imported from `shared/`.

Build: `npm install && npm run build` (the engine must be built first:
`haxe build.hxml` in engine/).

## How it is put together

| File | What it does |
|---|---|
| `src/main.tsx` | Makes the machine once, outside React; restores a shared pattern; renders the panel. |
| `src/components/Panel.tsx` | Machine state, the selected part and the display, shared through a context; loading, address, shortcuts. |
| `src/components/Deck.tsx` | Display window, the four machine knobs, Play and Clear. |
| `src/components/PartSection.tsx` | Level, Pitch, Length, the 808 group, the part buttons. |
| `src/components/PartButtons.tsx` | Pills and M tabs; the LED flash on each hit. |
| `src/components/StepKeys.tsx` | Beats, flip tabs and keys. |
| `src/components/Knob.tsx`, `KnobUnit.tsx`, `SevenSegment.tsx` | One knob; a knob with its printed name; the display. |
| `src/hooks.ts`, `keyGestures.ts`, `pointer.ts`, `context.ts` | Machine state, held display text, playhead, address; key gestures; pointer tracking; the panel context. |

- **State:** `useSyncExternalStore(machine.subscribe, machine.getState)`. The
  engine hands out a new frozen snapshot per change and the same object
  otherwise, which is exactly what that hook wants, so no adapter was needed.
- **Playhead (idiomatic first version):** the step being heard is React state
  (`usePlayhead`), so every step re-renders the sixteen keys and their tabs,
  up to ~13 times a second. This is the cost the comparison measures; a
  faster variant (touching the DOM from a ref) would be a separate,
  labelled measurement.
- **LED flash on hits:** a one-off animation, played on the element through
  refs rather than held in state.
- **Wheel on knobs:** React's own wheel events are passive, so a page scroll
  cannot be stopped from them; each knob adds its own non-passive listener
  in an effect.
- **Shared words:** the display font and every label come from the engine
  (`SevenSegmentFont`, `PanelText`).

## Notes from building it

- First build passed all 19 shared tests at its first run.
- TypeScript 7 refused the side-effect import of the stylesheet until Vite's
  client types were referenced (`src/vite-env.d.ts`).
- The 15-line rule shaped the components: JSX grows fast, so the deck, the
  part section and the keys are split into small named components
  (`DisplayWindow`, `PlayButton`, `PartKnobs`, `DialSlot`, `StepColumn`, …).
- The engine's `.d.ts` was missing `Range.clamp`, which the knobs use; it is
  now declared. A hand-written `.d.ts` can drift; this was its first test by
  a real consumer.

## Who did what

Written by Claude (AI) from the prototype, to Tom's spec and code rules
(functions of at most 15 lines, DRY, names that tell the story). To review:
Tom.

## Versions

React 19.3 · Vite 8.3 · TypeScript 7.0 · Tone.js 15.1.22

## Version 2: the sequence

- 76 lines in one new file, `PatternButtons.tsx` (the group, its title row with the tools, the buttons and
  the hint, as four small components), plus its place in `PartSection`.
- `useMemo` keeps one `PatternPad` per machine; the window's pointer-up and cancel listeners need a
  `useEffect` with its own clean-up, the most ceremony of the four for that part.
- The first version broke the fifteen-line rule (16 lines of JSX), so the hint became its own component.
