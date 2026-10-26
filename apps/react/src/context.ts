// What every part of the panel needs: the machine, which part is selected, and the display.
import { createContext, useContext } from "react";
import type { DrumMachine, MachineState, TrackState } from "bumbap-engine";

export interface PanelTools {
	machine: DrumMachine;
	state: MachineState;
	selectedPart: number;
	selectPart: (index: number) => void;
	/** Shows a value on the display for a moment, e.g. "S 66". */
	showBriefly: (text: string) => void;
}

export const PanelContext = createContext<PanelTools | null>(null);

export function usePanel(): PanelTools {
	const tools = useContext(PanelContext);
	if (!tools) throw new Error("usePanel must be used inside <Panel>");
	return tools;
}

export function selectedTrack(tools: PanelTools): TrackState {
	return tools.state.tracks[tools.selectedPart];
}
