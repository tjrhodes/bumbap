// A knob with its name printed above it, as on the hardware. Turning it shows its letter and value ("S 66").
import { Component, inject, input } from "@angular/core";
import { PanelText, type MachineState, type Range } from "bumbap-engine";
import { Knob } from "./knob";
import { PanelStore } from "./panel-store";

@Component({
	selector: "div[bmKnobUnit]",
	imports: [Knob],
	host: { class: "dm-unit", "[class]": "unitClass()" },
	template: `
		<span class="dm-print">{{ name() }}</span>
		<div bmKnob [knobId]="knobId()" [label]="label()" [range]="range()" [value]="read()(store.state())" [latest]="latest" (turn)="onTurn($event)"></div>
	`
})
export class KnobUnit {
	protected readonly store = inject(PanelStore);
	readonly knobId = input.required<string>();
	readonly name = input.required<string>();
	readonly label = input.required<string>();
	readonly range = input.required<Range>();
	readonly read = input.required<(state: MachineState) => number>();
	readonly set = input.required<(value: number) => void>();
	readonly unitClass = input("");

	protected readonly latest = () => this.read()(this.store.machine.getState());

	protected onTurn(value: number) {
		this.set()(value);
		const letter = PanelText.KNOB_LETTERS[this.knobId()];
		if (letter) this.store.showBriefly(PanelText.labelled(letter, this.read()(this.store.machine.getState())));
	}
}
