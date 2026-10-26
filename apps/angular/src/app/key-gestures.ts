// Key gestures: a tap switches a step; a drag up/down sets its level, sideways its nudge;
// arrow keys on a focused key do the same in small steps.
import { DrumMachine, PanelText } from "bumbap-engine";
import type { PanelStore } from "./panel-store";
import { trackPointer } from "./pointer";

/** Less movement than this is still a tap. */
const DRAG_THRESHOLD_PX = 6;
/** Dragging this far up sweeps the whole velocity range. */
const LEVEL_TRAVEL_PX = 140;
/** So the full ±16 ticks is about a key's width either way. */
const NUDGE_PX_PER_TICK = 3;

type Axis = "level" | "nudge";
const ARROWS: Record<string, [Axis, number]> = { ArrowUp: ["level", 5], ArrowDown: ["level", -5], ArrowRight: ["nudge", 1], ArrowLeft: ["nudge", -1] };

export class KeyGestures {
	/** Stops the click that ends a drag from switching the step. */
	private wasDrag = false;

	constructor(private readonly store: PanelStore) {}

	click(index: number) {
		if (!this.wasDrag) this.store.machine.toggleStep(this.store.selectedPart(), index);
		this.wasDrag = false;
	}

	/** The first clear movement picks the axis, and the drag keeps it, so a level drag never nudges by accident. */
	start(down: PointerEvent, index: number) {
		this.wasDrag = false;
		const from = this.store.latestStep(index);
		let axis: Axis | null = null;
		trackPointer(down.currentTarget as Element, down, (move) => {
			const [rise, across] = [down.clientY - move.clientY, move.clientX - down.clientX];
			axis ??= chooseAxis(rise, across);
			if (!axis) return;
			this.wasDrag = true;
			this.adjust(index, axis, axis === "level" ? from.velocity + rise * levelPerPixel() : from.nudge + across / NUDGE_PX_PER_TICK);
		});
	}

	/** On a focused key: up and down change its level by 5, left and right its nudge by a tick. */
	arrow(event: KeyboardEvent, index: number) {
		const arrow = ARROWS[event.key];
		if (!arrow) return;
		event.preventDefault();
		const [axis, change] = arrow;
		const step = this.store.latestStep(index);
		this.adjust(index, axis, (axis === "level" ? step.velocity : step.nudge) + change);
	}

	/** Sets a step's level or nudge and shows it for a moment ("u100", "n -3"). */
	private adjust(index: number, axis: Axis, value: number) {
		const part = this.store.selectedPart();
		if (axis === "level") this.store.machine.setStepVelocity(part, index, value);
		else this.store.machine.setStepNudge(part, index, value);
		const step = this.store.latestStep(index);
		this.store.showBriefly(PanelText.labelled(PanelText.STEP_LETTERS[axis], axis === "level" ? step.velocity : step.nudge));
	}
}

function chooseAxis(rise: number, across: number): Axis | null {
	if (Math.max(Math.abs(rise), Math.abs(across)) < DRAG_THRESHOLD_PX) return null;
	return Math.abs(rise) >= Math.abs(across) ? "level" : "nudge";
}

function levelPerPixel(): number {
	const { velocity } = DrumMachine.limits;
	return (velocity.max - velocity.min) / LEVEL_TRAVEL_PX;
}
