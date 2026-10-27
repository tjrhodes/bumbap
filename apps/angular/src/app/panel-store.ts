// The panel's state as signals: the machine's snapshot, the selected part, the playhead and the display.
import { computed, DestroyRef, inject, Injectable, InjectionToken, signal } from "@angular/core";
import { PanelText, type DrumMachine, type StepState, type TrackState } from "bumbap-engine";
import { HeldText } from "./held-text";

export const MACHINE = new InjectionToken<DrumMachine>("bümbap machine");

/** How long a changed value stays on the display before the resting text returns. */
const HOLD_MS = 1200;

@Injectable({ providedIn: "root" })
export class PanelStore {
	readonly machine = inject(MACHINE);
	/** The machine's latest snapshot; a new frozen object per change, so a signal can compare by identity. */
	readonly state = signal(this.machine.getState());
	readonly selectedPart = signal(0);
	readonly selectedTrack = computed<TrackState>(() => this.state().tracks[this.selectedPart()]);
	/** The step being heard, -1 when stopped. */
	readonly playhead = signal(-1);
	private readonly heldText = new HeldText(HOLD_MS);
	readonly displayText = computed(() => this.heldText.text() ?? PanelText.resting(this.state()));

	constructor() {
		const stopFollowing = [this.machine.subscribe((next) => this.state.set(next)), this.machine.onStep((step) => this.playhead.set(step))];
		inject(DestroyRef).onDestroy(() => stopFollowing.forEach((stop) => stop()));
	}

	/** Shows a value on the display for a moment, e.g. "S 66"; a newer one restarts the wait. */
	showBriefly(text: string) {
		this.heldText.show(text);
	}

	/** A step of the selected part, read straight from the machine (gestures need the very latest). */
	latestStep(index: number): StepState {
		return this.machine.getState().tracks[this.selectedPart()].steps[index];
	}
}
