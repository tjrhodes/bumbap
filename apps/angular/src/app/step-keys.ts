// The sixteen brass keys of the selected part, in four beats, each with a flip tab above it.
// Tap a key to switch its step; drag it up or down for its level, sideways for its nudge.
import { Component, inject } from "@angular/core";
import { DrumMachine, PanelText, type StepState } from "bumbap-engine";
import { KeyGestures } from "./key-gestures";
import { PanelStore } from "./panel-store";

const STEPS_PER_BEAT = 4;

@Component({
	selector: "section[bmStepKeys]",
	host: { class: "dm-steps", "aria-label": "Steps" },
	template: `
		<div class="dm-steps-head">
			<h2 class="dm-print dm-rule">Steps</h2>
			<button id="copy-steps" type="button" class="dm-tool" aria-label="Copy these steps" (click)="store.machine.copySteps(store.selectedPart())">Copy</button>
			<button id="paste-steps" type="button" class="dm-tool" aria-label="Paste the copied steps" [disabled]="!store.state().stepsCopied"
				(click)="store.machine.pasteSteps(store.selectedPart())">Paste</button>
		</div>
		<div id="keys" class="dm-keys">
			@for (beat of beats; track beat) {
				<div class="dm-beat" [attr.data-beat]="beat + 1">
					@for (index of stepsOf(beat); track index) {
						@let step = store.selectedTrack().steps[index];
						<button class="dm-tab dm-flip" [attr.aria-pressed]="isReversed(step)" [attr.aria-label]="text.flipLabel(store.selectedTrack().name, index)"
							(click)="store.machine.toggleStepReverse(store.selectedPart(), index)"><span class="dm-flip-icon"></span></button>
						<button class="dm-key" [class.is-current]="index === store.playhead()" [class.is-reversed]="isReversed(step)"
							[style.--level]="step.velocity / 100" [style.--nudge]="step.nudge / furthestNudge" [attr.aria-pressed]="step.on"
							[attr.aria-label]="text.stepLabel(store.selectedTrack().name, index, step)"
							(pointerdown)="gestures.start($event, index)" (click)="gestures.click(index)" (keydown)="gestures.arrow($event, index)">
							<span class="dm-key-fill"></span><span class="dm-key-led"></span><span class="dm-key-number">{{ index + 1 }}</span>
						</button>
					}
				</div>
			}
		</div>
	`
})
export class StepKeys {
	protected readonly store = inject(PanelStore);
	protected readonly gestures = new KeyGestures(this.store);
	protected readonly text = PanelText;
	protected readonly beats = [0, 1, 2, 3];
	protected readonly furthestNudge = DrumMachine.limits.nudge.max;

	protected stepsOf(beat: number): number[] {
		return Array.from({ length: STEPS_PER_BEAT }, (_, offset) => beat * STEPS_PER_BEAT + offset);
	}

	protected isReversed(step: StepState): boolean {
		return step.on && step.reversed;
	}
}
