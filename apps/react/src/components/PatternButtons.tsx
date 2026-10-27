// The eight pattern buttons (v2), drawn from the snapshot: in the chain, half lit; playing or shown, fully lit;
// waiting for the end of the bar, blinking; empty, a dim number. Their gestures go to the engine's PatternPad.
import { useEffect, useMemo } from "react";
import { PanelText, PatternPad, type MachineState } from "bumbap-engine";
import { usePanel } from "../context";

const PATTERNS = [0, 1, 2, 3, 4, 5, 6, 7];

export function PatternButtons() {
	const { machine, state } = usePanel();
	const pad = useMemo(() => new PatternPad(machine), [machine]);
	useReleaseAnywhere(pad);
	return (
		<div className="dm-patterns" role="group" aria-label="Patterns">
			<span className="dm-print dm-dials-label">Pattern</span>
			<div className="dm-pattern-row">
				{PATTERNS.map((index) => <PatternButton key={index} index={index} state={state} pad={pad} />)}
			</div>
			<PatternHint />
		</div>
	);
}

/** How to chain and copy; the stylesheet shows the mouse or the touch version. */
function PatternHint() {
	return (
		<p className="dm-print dm-pattern-hint">
			<span className="for-mouse">Shift-click to chain · drag to copy</span><span className="for-touch">Hold and tap to chain · drag to copy</span>
		</p>
	);
}

function PatternButton({ index, state, pad }: { index: number; state: MachineState; pad: PatternPad }) {
	const classes = ["dm-pattern", state.patternHasSteps[index] && "is-used", state.nextPattern === index && "is-next"];
	return (
		<button type="button" className={classes.filter(Boolean).join(" ")} data-pattern={index}
			aria-pressed={state.chain.includes(index)} aria-current={state.pattern === index} aria-label={PanelText.patternLabel(state, index)}
			onPointerDown={(event) => pad.press(event.pointerId, index)} onClick={(event) => pad.click(index, event.shiftKey)}>
			{index + 1}
		</button>
	);
}

/** A finger dragged onto another button is lifted there, so lifting is heard from the whole window. */
function useReleaseAnywhere(pad: PatternPad) {
	useEffect(() => {
		const release = (event: PointerEvent) => pad.release(event.pointerId, PatternPad.patternAt(event.clientX, event.clientY));
		const cancel = (event: PointerEvent) => pad.release(event.pointerId, PatternPad.NONE);
		window.addEventListener("pointerup", release);
		window.addEventListener("pointercancel", cancel);
		return () => {
			window.removeEventListener("pointerup", release);
			window.removeEventListener("pointercancel", cancel);
		};
	}, [pad]);
}
