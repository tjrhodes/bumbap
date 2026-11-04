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

	/**
	 * How to read this knob's very latest value from the machine, for a gesture that comes before the next
	 * redraw.
	 */
	protected readonly latest = () => this.read()(this.store.machine.getState());

	/**
	 * The knob was turned: set the value on the machine, then show it on the display ("S 66") if this knob has
	 * a display letter. The value shown is read back from the machine, so it is the one the machine really
	 * took.
	 */
	protected onTurn(value: number) {
		this.set()(value);
		const letter = PanelText.KNOB_LETTERS[this.knobId()];
		if (letter) this.store.showBriefly(PanelText.labelled(letter, this.read()(this.store.machine.getState())));
	}
}
