// A rotary knob: a slider in a round body. Drag up or right to turn it up, scroll, or use the arrow
// keys; double-click (double-tap) resets it. The engine's Range rounds and clamps whatever a gesture works out.
import { Component, computed, input, output } from "@angular/core";
import type { Range } from "bumbap-engine";
import { trackPointer } from "./pointer";

/** Dragging this far turns a knob from its minimum to its maximum. */
const TRAVEL_PX = 160;
/** From seven o'clock round to five o'clock. */
const SWEEP_DEGREES = 270;
const KEY_STEPS: Record<string, number> = { ArrowUp: 1, ArrowRight: 1, ArrowDown: -1, ArrowLeft: -1, PageUp: 10, PageDown: -10 };

@Component({
	selector: "div[bmKnob]",
	template: `<span class="dm-knob-cap"></span>`,
	host: {
		class: "dm-knob", role: "slider", "[class]": "variant()", "[attr.id]": "knobId()", "[attr.tabindex]": "disabled() ? -1 : 0",
		"[attr.aria-label]": "label()", "[attr.aria-disabled]": "disabled()", "[attr.aria-valuemin]": "range().min",
		"[attr.aria-valuemax]": "range().max", "[attr.aria-valuenow]": "value()", "[style.--turn]": "angle()",
		"(pointerdown)": "drag($event)", "(keydown)": "key($event)", "(wheel)": "scroll($event)", "(dblclick)": "turnTo(range().initial)"
	}
})
export class Knob {
	readonly knobId = input.required<string>();
	readonly label = input.required<string>();
	readonly range = input.required<Range>();
	readonly value = input.required<number>();
	/**
	 * The very latest value, read from the machine. Zoneless Angular redraws a moment after an
	 * event, so a quick second key press would otherwise start from the value drawn before the first.
	 */
	readonly latest = input<() => number>();
	/** "dm-knob-808" for the detented 808 knobs. */
	readonly variant = input("");
	readonly disabled = input(false);
	readonly turn = output<number>();

	protected readonly angle = computed(() => {
		const share = (this.value() - this.range().min) / (this.range().max - this.range().min);
		return `${share * SWEEP_DEGREES - SWEEP_DEGREES / 2}deg`;
	});

	private current(): number {
		return this.latest()?.() ?? this.value();
	}

	protected turnTo(next: number) {
		this.turn.emit(this.range().clamp(next));
	}

	/** Turns by how far the pointer has moved since it went down; up and right both mean more. */
	protected drag(down: PointerEvent) {
		const [startValue, range] = [this.current(), this.range()];
		const unitsPerPixel = (range.max - range.min) / TRAVEL_PX;
		trackPointer(down.currentTarget as Element, down, (move) =>
			this.turnTo(startValue + (down.clientY - move.clientY + move.clientX - down.clientX) * unitsPerPixel));
	}

	protected key(event: KeyboardEvent) {
		if (event.key === "Home") this.turnTo(this.range().min);
		else if (event.key === "End") this.turnTo(this.range().max);
		else if (event.key in KEY_STEPS) this.turnTo(this.current() + KEY_STEPS[event.key]);
		else return;
		event.preventDefault();
	}

	/** Stops the page scrolling while the knob turns. */
	protected scroll(event: WheelEvent) {
		event.preventDefault();
		this.turnTo(this.current() - Math.sign(event.deltaY));
	}
}
