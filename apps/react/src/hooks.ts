// The panel's hooks: the machine's state, the display's held text, the playhead.
import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from "react";
import type { DrumMachine, MachineState } from "bumbap-engine";

/** How long a changed value stays on the display before the resting text returns. */
const HOLD_MS = 1200;

/** The machine's current snapshot; a new one re-renders, the same one does not. */
export function useMachineState(machine: DrumMachine): MachineState {
	const subscribe = useCallback((listener: () => void) => machine.subscribe(listener), [machine]);
	const snapshot = useCallback(() => machine.getState(), [machine]);
	return useSyncExternalStore(subscribe, snapshot);
}

/** The display's text: the resting text, unless something was shown briefly in the last moment. */
export function useHeldText(resting: string): [string, (text: string) => void] {
	const [held, setHeld] = useState<string | null>(null);
	const timer = useRef<number | undefined>(undefined);
	const showBriefly = useCallback((text: string) => {
		setHeld(text);
		window.clearTimeout(timer.current);
		timer.current = window.setTimeout(() => setHeld(null), HOLD_MS);
	}, []);
	useEffect(() => () => window.clearTimeout(timer.current), []);
	return [held ?? resting, showBriefly];
}

/** The step being heard (-1 when stopped), as React state: each step re-renders whoever uses it. */
export function usePlayhead(machine: DrumMachine): number {
	const [step, setStep] = useState(-1);
	useEffect(() => machine.onStep(setStep), [machine]);
	return step;
}

/** Remembers the pattern in the address; some frames refuse, and then it simply is not remembered there. */
export function useAddress(code: string) {
	useEffect(() => {
		try { history.replaceState(null, "", `#${code}`); } catch { /* nothing is lost */ }
	}, [code]);
}
