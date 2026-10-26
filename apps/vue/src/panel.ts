// What every part of the panel needs, provided once by BumbapPanel and injected below it.
import { inject, onUnmounted, provide, ref, shallowRef, type InjectionKey, type Ref, type ShallowRef } from "vue";
import type { DrumMachine, MachineState, TrackState } from "bumbap-engine";

/** How long a changed value stays on the display before the resting text returns. */
const HOLD_MS = 1200;

export interface PanelTools {
	machine: DrumMachine;
	/** The machine's latest snapshot; snapshots are frozen, so a shallow ref is all it needs. */
	state: ShallowRef<MachineState>;
	selectedPart: Ref<number>;
	/** Text shown on the display for a moment, e.g. "S 66"; null when resting. */
	heldText: Ref<string | null>;
	showBriefly: (text: string) => void;
}

const PANEL: InjectionKey<PanelTools> = Symbol("bümbap panel");

/** Called once, by the panel: follows the machine's snapshots and provides the tools to every component. */
export function providePanel(machine: DrumMachine): PanelTools {
	const state = shallowRef(machine.getState());
	onUnmounted(machine.subscribe((next) => (state.value = next)));
	const heldText = ref<string | null>(null);
	const tools = { machine, state, selectedPart: ref(0), heldText, showBriefly: holdFor(heldText) };
	provide(PANEL, tools);
	return tools;
}

export function usePanel(): PanelTools {
	const tools = inject(PANEL);
	if (!tools) throw new Error("usePanel must be used inside the bümbap panel");
	return tools;
}

export function selectedTrack(tools: PanelTools): TrackState {
	return tools.state.value.tracks[tools.selectedPart.value];
}

/** Shows a text, then lets the resting text back after a moment; a newer text restarts the wait. */
function holdFor(heldText: Ref<string | null>): (text: string) => void {
	let timer: number | undefined;
	return (text) => {
		heldText.value = text;
		window.clearTimeout(timer);
		timer = window.setTimeout(() => (heldText.value = null), HOLD_MS);
	};
}

/** The step being heard (-1 when stopped), as a reactive ref: keys that depend on it update. */
export function usePlayhead(machine: DrumMachine): Ref<number> {
	const step = ref(-1);
	onUnmounted(machine.onStep((next) => (step.value = next)));
	return step;
}
