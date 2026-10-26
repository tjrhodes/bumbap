// One of the selected part's 808 knobs; a part without one there leaves the slot dimmed, unnamed and still.
import { Component, computed, inject, input } from "@angular/core";
import { DrumMachine, PanelText } from "bumbap-engine";
import { Knob } from "./knob";
import { PanelStore } from "./panel-store";

@Component({
	selector: "div[bmDialSlot]",
	imports: [Knob],
	host: { class: "dm-unit", "[class.is-unused]": "!name()" },
	template: `
		<span class="dm-print">{{ name() ?? "—" }}</span>
		<div bmKnob [knobId]="'dial-' + slot()" variant="dm-knob-808" [label]="label()" [range]="range"
			[value]="position()" [latest]="latest" [disabled]="!name()" (turn)="turn($event)"></div>
	`
})
export class DialSlot {
	private readonly store = inject(PanelStore);
	readonly slot = input.required<number>();
	protected readonly range = DrumMachine.limits.dial;
	protected readonly name = computed(() => this.store.selectedTrack().dialNames[this.slot()]);
	protected readonly label = computed(() => PanelText.dialLabel(this.store.selectedTrack(), this.slot()));
	protected readonly position = computed(() => this.store.selectedTrack().dials[this.slot()] ?? this.range.initial);

	protected readonly latest = () => this.store.machine.getState().tracks[this.store.selectedPart()].dials[this.slot()] ?? this.range.initial;

	/** Picks another recording, and shows its 808 setting (e.g. "2510") while the knob turns. */
	protected turn(position: number) {
		if (!this.name()) return;
		this.store.machine.setDial(this.store.selectedPart(), this.slot(), position);
		this.store.showBriefly(PanelText.dialSetting(this.store.machine.getState().tracks[this.store.selectedPart()]));
	}
}
