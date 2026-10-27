// The bümbap panel: the machine's state and the selected part, shared with every component below.
import { useCallback, useEffect, useState } from "react";
import { PanelText, type DrumMachine } from "bumbap-engine";
import { PanelContext } from "../context";
import { useAddress, useHeldText, useMachineState } from "../hooks";
import { Deck } from "./Deck";
import { PartSection } from "./PartSection";
import { ShareButton } from "./ShareButton";
import { StepKeys } from "./StepKeys";

export function Panel({ machine }: { machine: DrumMachine }) {
	const state = useMachineState(machine);
	const [selectedPart, selectPart] = useState(0);
	const [displayText, showBriefly] = useHeldText(PanelText.resting(state));
	useEffect(() => void machine.load(), [machine]);
	useAddress(state.code);
	useShortcuts(machine, selectPart);
	return (
		<PanelContext.Provider value={{ machine, state, selectedPart, selectPart, showBriefly }}>
			<main className="dm"><div className="dm-panel">
				<header className="dm-head"><span className="dm-wordmark">bümbap</span><span className="dm-print">16 step · 8 part · Haxe engine</span><ShareButton /></header>
				<Deck displayText={displayText} /><PartSection /><StepKeys />
			</div></main>
		</PanelContext.Provider>
	);
}

/** Space plays and stops unless a focused control already uses it; keys 1–8 pick a part. */
function useShortcuts(machine: DrumMachine, selectPart: (index: number) => void) {
	const onKey = useCallback((event: KeyboardEvent) => {
		const part = Number(event.key);
		if (event.key !== " " && part >= 1 && part <= machine.getState().tracks.length) return selectPart(part - 1);
		const spaceAlreadyUsed = (event.target as Element).closest("button, [role='slider']");
		if (event.key !== " " || spaceAlreadyUsed) return;
		event.preventDefault();
		machine.togglePlay();
	}, [machine, selectPart]);
	useEffect(() => {
		document.addEventListener("keydown", onKey);
		return () => document.removeEventListener("keydown", onKey);
	}, [onKey]);
}
