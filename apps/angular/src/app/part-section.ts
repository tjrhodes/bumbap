// The selected part's own knobs (Level, Pitch, Length, and its 808 knobs), then the part buttons.
import { Component, inject } from "@angular/core";
import { DrumMachine, type MachineState } from "bumbap-engine";
import { DialSlot } from "./dial-slot";
import { KnobUnit } from "./knob-unit";
import { PanelStore } from "./panel-store";
import { PartButtons } from "./part-buttons";

@Component({
	selector: "section[bmPartSection]",
	imports: [DialSlot, KnobUnit, PartButtons],
	host: { class: "dm-part", "aria-label": "Part" },
	template: `
		<h2 class="dm-print dm-rule">Part</h2>
		<div class="dm-strip">
			<div bmKnobUnit knobId="level" name="Level" [label]="name() + ' level'" [range]="limits.volume" [read]="volume" [set]="setVolume"></div>
			<div bmKnobUnit knobId="pitch" name="Pitch" [label]="name() + ' pitch'" [range]="limits.pitch" [read]="pitch" [set]="setPitch"></div>
			<div bmKnobUnit knobId="length" name="Length" [label]="name() + ' length'" [range]="limits.length" [read]="length" [set]="setLength"></div>
			<div class="dm-dials">
				<span class="dm-print dm-dials-label">808</span>
				@for (slot of dialSlots; track slot) { <div bmDialSlot [slot]="slot"></div> }
			</div>
		</div>
		<div bmPartButtons></div>
	`
})
export class PartSection {
	private readonly store = inject(PanelStore);
	private readonly machine = this.store.machine;
	/** The 808 group has room for the most knobs any part has. */
	protected readonly dialSlots = [0, 1];
	protected readonly limits = DrumMachine.limits;
	protected readonly name = () => this.store.selectedTrack().name;
	private readonly part = (state: MachineState) => state.tracks[this.store.selectedPart()];
	protected readonly volume = (state: MachineState) => this.part(state).volume;
	protected readonly pitch = (state: MachineState) => this.part(state).pitch;
	protected readonly length = (state: MachineState) => this.part(state).length;
	protected readonly setVolume = (value: number) => this.machine.setVolume(this.store.selectedPart(), value);
	protected readonly setPitch = (value: number) => this.machine.setPitch(this.store.selectedPart(), value);
	protected readonly setLength = (value: number) => this.machine.setLength(this.store.selectedPart(), value);
}
