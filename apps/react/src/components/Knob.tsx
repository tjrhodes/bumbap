// A rotary knob: a slider in a round body. Drag up or right, scroll or use the arrow keys;
// double-click (double-tap) resets it. The engine's Range rounds and clamps whatever a gesture works out.
import { useEffect, useRef, type CSSProperties, type KeyboardEvent, type PointerEvent, type RefObject } from "react";
import type { Range } from "bumbap-engine";
import { trackPointer } from "../pointer";

/** Dragging this far turns a knob from its minimum to its maximum. */
const TRAVEL_PX = 160;
/** From seven o'clock round to five o'clock. */
const SWEEP_DEGREES = 270;
const KEY_STEPS: Record<string, number> = { ArrowUp: 1, ArrowRight: 1, ArrowDown: -1, ArrowLeft: -1, PageUp: 10, PageDown: -10 };

export interface KnobProps {
	id: string;
	label: string;
	range: Range;
	value: number;
	onTurn: (value: number) => void;
	/** "dm-knob-808" for the detented 808 knobs. */
	variant?: string;
	disabled?: boolean;
}

export function Knob({ id, label, range, value, onTurn, variant = "", disabled = false }: KnobProps) {
	const element = useRef<HTMLDivElement>(null);
	const latest = useRef(value);
	latest.current = value;
	const turnTo = (next: number) => onTurn(range.clamp(next));
	useWheel(element, (direction) => turnTo(latest.current - direction));
	return (
		<div ref={element} {...sliderAttributes(id, label, range, value, disabled)} className={`dm-knob ${variant}`.trim()}
			onPointerDown={(event) => followDrag(event, latest.current, range, turnTo)}
			onKeyDown={(event) => onKnobKey(event, latest.current, range, turnTo)} onDoubleClick={() => turnTo(range.initial)}>
			<span className="dm-knob-cap" />
		</div>
	);
}

/** What a screen reader needs to know it is a slider, and where the knob points. */
function sliderAttributes(id: string, label: string, range: Range, value: number, disabled: boolean) {
	const share = (value - range.min) / (range.max - range.min);
	return {
		id, role: "slider", tabIndex: disabled ? -1 : 0, "aria-label": label, "aria-disabled": disabled,
		"aria-valuemin": range.min, "aria-valuemax": range.max, "aria-valuenow": value,
		style: { "--turn": `${share * SWEEP_DEGREES - SWEEP_DEGREES / 2}deg` } as CSSProperties
	};
}

/** Turns by how far the pointer has moved since it went down; up and right both mean more. */
function followDrag(down: PointerEvent, startValue: number, range: Range, turnTo: (value: number) => void) {
	const unitsPerPixel = (range.max - range.min) / TRAVEL_PX;
	trackPointer(down.currentTarget, down.nativeEvent, (move) =>
		turnTo(startValue + (down.clientY - move.clientY + move.clientX - down.clientX) * unitsPerPixel));
}

function onKnobKey(event: KeyboardEvent, value: number, range: Range, turnTo: (value: number) => void) {
	if (event.key === "Home") turnTo(range.min);
	else if (event.key === "End") turnTo(range.max);
	else if (event.key in KEY_STEPS) turnTo(value + KEY_STEPS[event.key]);
	else return;
	event.preventDefault();
}

/** React's own wheel events are passive, so a knob listens itself, to stop the page scrolling as it turns. */
function useWheel(element: RefObject<HTMLDivElement | null>, onScroll: (direction: number) => void) {
	const latestOnScroll = useRef(onScroll);
	latestOnScroll.current = onScroll;
	useEffect(() => {
		const listener = (event: WheelEvent) => {
			event.preventDefault();
			latestOnScroll.current(Math.sign(event.deltaY));
		};
		element.current?.addEventListener("wheel", listener, { passive: false });
		return () => element.current?.removeEventListener("wheel", listener);
	}, [element]);
}
