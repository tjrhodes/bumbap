// Key gestures: a tap switches a step; a drag up/down sets its level, sideways its nudge;
// arrow keys on a focused key do the same in small steps.
import { DrumMachine, PanelText, type StepState } from "bumbap-engine";
import type { PanelTools } from "./panel";
import { trackPointer } from "./pointer";

/** Less movement than this is still a tap. */
const DRAG_THRESHOLD_PX = 6;
/** Dragging this far up sweeps the whole velocity range. */
const LEVEL_TRAVEL_PX = 140;
/** So the full ±16 ticks is about a key's width either way. */
const NUDGE_PX_PER_TICK = 3;

type Axis = "level" | "nudge";
const ARROWS: Record<string, [Axis, number]> = { ArrowUp: ["level", 5], ArrowDown: ["level", -5], ArrowRight: ["nudge", 1], ArrowLeft: ["nudge", -1] };

/** The gestures of one set of keys; `wasDrag` stops the click that ends a drag from switching the step. */
export function keyGestures(tools: PanelTools) {
	const wasDrag = { current: false };
	return {
		start: (event: PointerEvent, index: number) => startDrag(tools, event, index, wasDrag),
		click: (index: number) => {
			if (!wasDrag.current) tools.machine.toggleStep(tools.selectedPart.value, index);
			wasDrag.current = false;
		},
		arrow: (event: KeyboardEvent, index: number) => onArrow(tools, event, index)
	};
}

function selectedStep(tools: PanelTools, index: number): StepState {
	return tools.machine.getState().tracks[tools.selectedPart.value].steps[index];
}

/** Sets a step's level or nudge and shows it for a moment ("u100", "n -3"). */
function adjust(tools: PanelTools, index: number, axis: Axis, value: number) {
	const part = tools.selectedPart.value;
	if (axis === "level") tools.machine.setStepVelocity(part, index, value);
	else tools.machine.setStepNudge(part, index, value);
	const step = selectedStep(tools, index);
	tools.showBriefly(PanelText.labelled(PanelText.STEP_LETTERS[axis], axis === "level" ? step.velocity : step.nudge));
}

/** The first clear movement picks the axis, and the drag keeps it, so a level drag never nudges by accident. */
function startDrag(tools: PanelTools, down: PointerEvent, index: number, wasDrag: { current: boolean }) {
	wasDrag.current = false;
	const from = selectedStep(tools, index);
	let axis: Axis | null = null;
	trackPointer(down.currentTarget as Element, down, (move) => {
		const rise = down.clientY - move.clientY;
		const across = move.clientX - down.clientX;
		axis ??= chooseAxis(rise, across);
		if (!axis) return;
		wasDrag.current = true; // this press is a drag, so its click must not switch the step
		adjust(tools, index, axis, axis === "level" ? from.velocity + rise * levelPerPixel() : from.nudge + across / NUDGE_PX_PER_TICK);
	});
}

function chooseAxis(rise: number, across: number): Axis | null {
	if (Math.max(Math.abs(rise), Math.abs(across)) < DRAG_THRESHOLD_PX) return null;
	return Math.abs(rise) >= Math.abs(across) ? "level" : "nudge";
}

function levelPerPixel(): number {
	const { velocity } = DrumMachine.limits;
	return (velocity.max - velocity.min) / LEVEL_TRAVEL_PX;
}

/** On a focused key: up and down change its level by 5, left and right its nudge by a tick. */
function onArrow(tools: PanelTools, event: KeyboardEvent, index: number) {
	const arrow = ARROWS[event.key];
	if (!arrow) return;
	event.preventDefault();
	const [axis, change] = arrow;
	const step = selectedStep(tools, index);
	adjust(tools, index, axis, (axis === "level" ? step.velocity : step.nudge) + change);
}
