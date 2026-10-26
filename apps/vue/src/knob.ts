// A rotary knob's gestures: drag up or right to turn it up, scroll, or use the arrow keys;
// double-click (double-tap) resets it. The engine's Range rounds and clamps whatever they work out.
import type { Range } from "bumbap-engine";
import { trackPointer } from "./pointer";

/** Dragging this far turns a knob from its minimum to its maximum. */
const TRAVEL_PX = 160;
/** From seven o'clock round to five o'clock. */
const SWEEP_DEGREES = 270;
const KEY_STEPS: Record<string, number> = { ArrowUp: 1, ArrowRight: 1, ArrowDown: -1, ArrowLeft: -1, PageUp: 10, PageDown: -10 };

export type Turn = (value: number) => void;

/** Where the knob points, as the CSS custom property the stylesheet turns the cap by. */
export function turnStyle(value: number, range: Range): Record<string, string> {
	const share = (value - range.min) / (range.max - range.min);
	return { "--turn": `${share * SWEEP_DEGREES - SWEEP_DEGREES / 2}deg` };
}

/** Turns by how far the pointer has moved since it went down; up and right both mean more. */
export function followDrag(down: PointerEvent, startValue: number, range: Range, turnTo: Turn) {
	const unitsPerPixel = (range.max - range.min) / TRAVEL_PX;
	trackPointer(down.currentTarget as Element, down, (move) =>
		turnTo(startValue + (down.clientY - move.clientY + move.clientX - down.clientX) * unitsPerPixel));
}

export function onKnobKey(event: KeyboardEvent, value: number, range: Range, turnTo: Turn) {
	if (event.key === "Home") turnTo(range.min);
	else if (event.key === "End") turnTo(range.max);
	else if (event.key in KEY_STEPS) turnTo(value + KEY_STEPS[event.key]);
	else return;
	event.preventDefault();
}
