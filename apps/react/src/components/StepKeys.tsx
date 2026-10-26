// The sixteen brass keys of the selected part, in four beats, each with a flip tab above it.
// Tap a key to switch its step; drag it up or down for its level, sideways for its nudge.
import type { CSSProperties } from "react";
import { DrumMachine, PanelText, type StepState } from "bumbap-engine";
import { selectedTrack, usePanel } from "../context";
import { usePlayhead } from "../hooks";
import { useKeyGestures, type KeyGestures } from "../keyGestures";

const STEPS_PER_BEAT = 4;
const BEATS = [0, 1, 2, 3];

export function StepKeys() {
	const tools = usePanel();
	const currentStep = usePlayhead(tools.machine);
	const gestures = useKeyGestures();
	return (
		<section className="dm-steps" aria-label="Steps">
			<h2 className="dm-print dm-rule">Steps</h2>
			<div id="keys" className="dm-keys">
				{BEATS.map((beat) => <Beat key={beat} beat={beat} currentStep={currentStep} gestures={gestures} />)}
			</div>
		</section>
	);
}

function Beat({ beat, currentStep, gestures }: { beat: number; currentStep: number; gestures: KeyGestures }) {
	const indexes = Array.from({ length: STEPS_PER_BEAT }, (_, offset) => beat * STEPS_PER_BEAT + offset);
	return (
		<div className="dm-beat" data-beat={beat + 1}>
			{indexes.map((index) => <StepColumn key={index} index={index} isCurrent={index === currentStep} gestures={gestures} />)}
		</div>
	);
}

/** A flip tab above a key: the tab plays the step backwards. */
function StepColumn({ index, isCurrent, gestures }: { index: number; isCurrent: boolean; gestures: KeyGestures }) {
	const tools = usePanel();
	const track = selectedTrack(tools);
	const step = track.steps[index];
	const reversed = step.on && step.reversed;
	return (
		<>
			<button className="dm-tab dm-flip" aria-pressed={reversed} aria-label={PanelText.flipLabel(track.name, index)}
				onClick={() => tools.machine.toggleStepReverse(tools.selectedPart, index)}><span className="dm-flip-icon" /></button>
			<Key index={index} step={step} trackName={track.name} isCurrent={isCurrent} gestures={gestures} />
		</>
	);
}

/** A key: the level fill at the back, then its LED, then its printed number. */
function Key({ index, step, trackName, isCurrent, gestures }: { index: number; step: StepState; trackName: string; isCurrent: boolean; gestures: KeyGestures }) {
	const classes = ["dm-key", isCurrent && "is-current", step.on && step.reversed && "is-reversed"].filter(Boolean).join(" ");
	const style = { "--level": step.velocity / 100, "--nudge": step.nudge / DrumMachine.limits.nudge.max } as CSSProperties;
	return (
		<button className={classes} style={style} aria-pressed={step.on} aria-label={PanelText.stepLabel(trackName, index, step)}
			onPointerDown={(event) => gestures.start(event, index)} onClick={() => gestures.click(index)} onKeyDown={(event) => gestures.arrow(event, index)}>
			<span className="dm-key-fill" /><span className="dm-key-led" /><span className="dm-key-number">{index + 1}</span>
		</button>
	);
}
