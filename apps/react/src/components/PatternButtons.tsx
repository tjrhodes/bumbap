// The sequence (v2): eight pattern buttons and the Select, Copy and Clear tools beside the title. In the sequence,
// half lit; playing, fully lit; on the keys, a ring; taking over at the end of the bar, blinking; empty, a dim number; with Select
// on, each button's places in the sequence. Taps go to the engine's PatternPad, shared by every build.
import { useEffect, useMemo } from "react";
import { PanelText, PatternPad, type MachineState, type SequenceTool } from "bumbap-engine";
import { usePanel } from "../context";

const PATTERNS = [0, 1, 2, 3, 4, 5, 6, 7];
const TOOLS: { tool: Exclude<SequenceTool, "">; name: string; label: string }[] = [
	{ tool: "select", name: "Select", label: "Select the sequence" },
	{ tool: "copy", name: "Copy", label: "Copy a pattern" },
	{ tool: "clear", name: "Clear", label: "Clear a pattern" }
];

export function PatternButtons() {
	const { machine, state } = usePanel();
	const pad = useMemo(() => new PatternPad(machine), [machine]);
	useReleaseAnywhere(pad);
	return (
		<div className="dm-patterns" role="group" aria-label="Sequence">
			<SequenceHead />
			<div className="dm-pattern-row">
				{PATTERNS.map((index) => <PatternButton key={index} index={index} state={state} pad={pad} />)}
			</div>
			<PatternHint />
		</div>
	);
}

function SequenceHead() {
	const { machine, state } = usePanel();
	return (
		<div className="dm-sequence-head">
			<span className="dm-print dm-sequence-title">Sequence</span>
			{TOOLS.map(({ tool, name, label }) => (
				<button key={tool} type="button" className="dm-tool" data-tool={tool} aria-pressed={state.tool === tool}
					aria-label={label} onClick={() => machine.toggleTool(tool)}>{name}</button>
			))}
		</div>
	);
}

function PatternButton({ index, state, pad }: { index: number; state: MachineState; pad: PatternPad }) {
	const classes = ["dm-pattern", state.patternHasSteps[index] && "is-used", state.playingPattern === index && "is-playing",
		state.nextPattern === index && "is-next", state.copyFrom === index && "is-copy-source"];
	return (
		<button type="button" className={classes.filter(Boolean).join(" ")} data-pattern={index}
			aria-pressed={state.sequence.includes(index)} aria-current={state.pattern === index} aria-label={PanelText.patternLabel(state, index)}
			onPointerDown={(event) => pad.press(event.pointerId, index)} onClick={(event) => pad.click(index, event.shiftKey)}>
			<span className="dm-pattern-number">{index + 1}</span><span className="dm-pattern-places">{PanelText.sequencePlaces(state, index)}</span>
		</button>
	);
}

/** What a tap does now; the stylesheet shows the mouse or the touch version. */
function PatternHint() {
	const [forMouse, forTouch] = PanelText.sequenceHints(usePanel().state);
	return <p className="dm-print dm-pattern-hint"><span className="for-mouse">{forMouse}</span><span className="for-touch">{forTouch}</span></p>;
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
