// The eight pattern buttons (v2), drawn from the snapshot: in the chain, half lit; playing or shown, fully lit;
// waiting for the end of the bar, blinking; empty, a dim number. Their gestures go to the engine's PatternPad.
import { Component, inject } from "@angular/core";
import { PanelText, PatternPad } from "bumbap-engine";
import { PanelStore } from "./panel-store";

@Component({
	selector: "div[bmPatternButtons]",
	host: {
		class: "dm-patterns", role: "group", "aria-label": "Patterns",
		// a finger dragged onto another button is lifted there, so lifting is heard from the whole window
		"(window:pointerup)": "release($event)",
		"(window:pointercancel)": "cancel($event)"
	},
	template: `
		<span class="dm-print dm-dials-label">Pattern</span>
		<div class="dm-pattern-row">
			@for (index of patterns; track index) {
				<button type="button" class="dm-pattern" [attr.data-pattern]="index"
					[class.is-used]="store.state().patternHasSteps[index]" [class.is-next]="store.state().nextPattern === index"
					[attr.aria-pressed]="store.state().chain.includes(index)" [attr.aria-current]="store.state().pattern === index"
					[attr.aria-label]="label(index)" (pointerdown)="pad.press($event.pointerId, index)" (click)="pad.click(index, $event.shiftKey)">{{ index + 1 }}</button>
			}
		</div>
		<p class="dm-print dm-pattern-hint">
			<span class="for-mouse">Shift-click to chain · drag to copy</span><span class="for-touch">Hold and tap to chain · drag to copy</span>
		</p>
	`
})
export class PatternButtons {
	protected readonly store = inject(PanelStore);
	protected readonly pad = new PatternPad(this.store.machine);
	protected readonly patterns = [0, 1, 2, 3, 4, 5, 6, 7];
	protected readonly label = (index: number) => PanelText.patternLabel(this.store.state(), index);

	protected release(event: PointerEvent) {
		this.pad.release(event.pointerId, PatternPad.patternAt(event.clientX, event.clientY));
	}

	protected cancel(event: PointerEvent) {
		this.pad.release(event.pointerId, PatternPad.NONE);
	}
}
