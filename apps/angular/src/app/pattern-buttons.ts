// The sequence (v2): eight pattern buttons and the Select, Copy and Clear tools beside the title. In the sequence,
// half lit; playing, fully lit; on the keys, a ring; taking over at the end of the bar, blinking; empty, a dim number; with Select
// on, each button's places in the sequence. Taps go to the engine's PatternPad, shared by every build.
import { Component, computed, inject } from "@angular/core";
import { PanelText, PatternPad } from "bumbap-engine";
import { PanelStore } from "./panel-store";

@Component({
	selector: "div[bmPatternButtons]",
	host: {
		class: "dm-patterns", role: "group", "aria-label": "Sequence",
		// a finger dragged onto another button is lifted there, so lifting is heard from the whole window
		"(window:pointerup)": "release($event)",
		"(window:pointercancel)": "cancel($event)"
	},
	template: `
		<div class="dm-sequence-head">
			<span class="dm-print dm-sequence-title">Sequence</span>
			@for (tool of tools; track tool.tool) {
				<button type="button" class="dm-tool" [attr.data-tool]="tool.tool" [attr.aria-pressed]="store.state().tool === tool.tool"
					[attr.aria-label]="tool.label" (click)="store.machine.toggleTool(tool.tool)">{{ tool.name }}</button>
			}
		</div>
		<div class="dm-pattern-row">
			@for (index of patterns; track index) {
				<button type="button" class="dm-pattern" [attr.data-pattern]="index" [class.is-used]="store.state().patternHasSteps[index]"
					[class.is-playing]="store.state().playingPattern === index" [class.is-next]="store.state().nextPattern === index" [class.is-copy-source]="store.state().copyFrom === index"
					[attr.aria-pressed]="store.state().sequence.includes(index)" [attr.aria-current]="store.state().pattern === index"
					[attr.aria-label]="label(index)" (pointerdown)="pad.press($event.pointerId, index)" (click)="pad.click(index, $event.shiftKey)"
					><span class="dm-pattern-number">{{ index + 1 }}</span><span class="dm-pattern-places">{{ places(index) }}</span></button>
			}
		</div>
		<p class="dm-print dm-pattern-hint"><span class="for-mouse">{{ hints()[0] }}</span><span class="for-touch">{{ hints()[1] }}</span></p>
	`
})
export class PatternButtons {
	protected readonly store = inject(PanelStore);
	protected readonly pad = new PatternPad(this.store.machine);
	protected readonly patterns = [0, 1, 2, 3, 4, 5, 6, 7];
	protected readonly tools = [
		{ tool: "select", name: "Select", label: "Select the sequence" },
		{ tool: "copy", name: "Copy", label: "Copy a pattern" },
		{ tool: "clear", name: "Clear", label: "Clear a pattern" }
	] as const;
	protected readonly label = (index: number) => PanelText.patternLabel(this.store.state(), index);
	protected readonly places = (index: number) => PanelText.sequencePlaces(this.store.state(), index);
	protected readonly hints = computed(() => PanelText.sequenceHints(this.store.state()));

	protected release(event: PointerEvent) {
		this.pad.release(event.pointerId, PatternPad.patternAt(event.clientX, event.clientY));
	}

	protected cancel(event: PointerEvent) {
		this.pad.release(event.pointerId, PatternPad.NONE);
	}
}
