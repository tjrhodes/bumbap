// The deck: the display and the whole machine's controls (tempo, swing, drive, reverb, play, clear, download).
import { Component, inject } from "@angular/core";
import { DrumMachine, LoopFile, PanelText, type MachineState } from "bumbap-engine";
import { KnobUnit } from "./knob-unit";
import { PanelStore } from "./panel-store";
import { SevenSegment } from "./seven-segment";

@Component({
	selector: "section[bmDeck]",
	imports: [KnobUnit, SevenSegment],
	host: { class: "dm-deck", "aria-label": "Controls" },
	template: `
		<div class="dm-window">
			<svg bmSevenSegment [text]="store.displayText()"></svg>
			<p id="status" class="dm-print dm-status" role="status">{{ status() }}</p>
		</div>
		<div bmKnobUnit knobId="tempo" name="Tempo" label="Tempo, beats per minute" unitClass="dm-tempo" [range]="limits.tempo" [read]="tempo" [set]="setTempo"></div>
		<div bmKnobUnit knobId="swing" name="Swing" label="Swing, percent" unitClass="dm-swing" [range]="limits.swing" [read]="swing" [set]="setSwing"></div>
		<div bmKnobUnit knobId="drive" name="Drive" label="Drive, percent" unitClass="dm-drive" [range]="limits.drive" [read]="drive" [set]="setDrive"></div>
		<div bmKnobUnit knobId="reverb" name="Reverb" label="Reverb, percent" unitClass="dm-reverb" [range]="limits.reverb" [read]="reverb" [set]="setReverb"></div>
		<div class="dm-unit dm-play-unit">
			<span class="dm-print"><span id="play-led" class="dm-led" [class.is-on]="store.state().playing"></span>Play</span>
			<button id="play" class="dm-rubber dm-rubber-play" [attr.aria-pressed]="store.state().playing" [attr.aria-label]="store.state().playing ? 'Stop' : 'Play'"
				[disabled]="store.state().status !== 'ready'" (click)="machine.togglePlay()"><span class="dm-icon"></span></button>
		</div>
		<div class="dm-unit dm-clear-unit">
			<span class="dm-print">Clear</span>
			<button id="clear" class="dm-rubber" aria-label="Clear every step" (click)="machine.clear()"></button>
		</div>
		<div class="dm-unit dm-save-unit">
			<span class="dm-print">Download</span>
			<button id="save" class="dm-rubber" type="button" [attr.aria-label]="downloadLabel"
				[disabled]="store.state().status !== 'ready' || store.state().exporting" (click)="download()"><svg class="dm-download-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/></svg></button>
		</div>
	`
})
export class Deck {
	protected readonly store = inject(PanelStore);
	protected readonly machine = this.store.machine;
	protected readonly limits = DrumMachine.limits;
	protected readonly status = () => PanelText.status(this.store.state());
	protected readonly downloadLabel = LoopFile.LABEL;
	protected readonly download = () => LoopFile.download(this.machine);
	protected readonly tempo = (state: MachineState) => state.tempo;
	protected readonly swing = (state: MachineState) => state.swing;
	protected readonly drive = (state: MachineState) => state.drive;
	protected readonly reverb = (state: MachineState) => state.reverb;
	protected readonly setTempo = (value: number) => this.machine.setTempo(value);
	protected readonly setSwing = (value: number) => this.machine.setSwing(value);
	protected readonly setDrive = (value: number) => this.machine.setDrive(value);
	protected readonly setReverb = (value: number) => this.machine.setReverb(value);
}
