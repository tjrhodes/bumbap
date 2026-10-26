// The deck: the display and the whole machine's controls (tempo, swing, drive, reverb, play, clear).
import { DrumMachine, PanelText } from "bumbap-engine";
import { usePanel } from "../context";
import { KnobUnit } from "./KnobUnit";
import { SevenSegment } from "./SevenSegment";

export function Deck({ displayText }: { displayText: string }) {
	const { machine } = usePanel();
	const { limits } = DrumMachine;
	return (
		<section className="dm-deck" aria-label="Controls">
			<DisplayWindow text={displayText} />
			<KnobUnit id="tempo" name="Tempo" label="Tempo, beats per minute" unitClass="dm-tempo" range={limits.tempo} read={(s) => s.tempo} set={(v) => machine.setTempo(v)} />
			<KnobUnit id="swing" name="Swing" label="Swing, percent" unitClass="dm-swing" range={limits.swing} read={(s) => s.swing} set={(v) => machine.setSwing(v)} />
			<KnobUnit id="drive" name="Drive" label="Drive, percent" unitClass="dm-drive" range={limits.drive} read={(s) => s.drive} set={(v) => machine.setDrive(v)} />
			<KnobUnit id="reverb" name="Reverb" label="Reverb, percent" unitClass="dm-reverb" range={limits.reverb} read={(s) => s.reverb} set={(v) => machine.setReverb(v)} />
			<PlayButton />
			<ClearButton />
		</section>
	);
}

function DisplayWindow({ text }: { text: string }) {
	const { state } = usePanel();
	return (
		<div className="dm-window">
			<SevenSegment text={text} />
			<p id="status" className="dm-print dm-status" role="status">{PanelText.status(state)}</p>
		</div>
	);
}

/** Play, with its LED; its icon turns into a stop square while playing. */
function PlayButton() {
	const { machine, state } = usePanel();
	return (
		<div className="dm-unit dm-play-unit">
			<span className="dm-print"><span id="play-led" className={state.playing ? "dm-led is-on" : "dm-led"} />Play</span>
			<button id="play" className="dm-rubber dm-rubber-play" aria-pressed={state.playing} aria-label={state.playing ? "Stop" : "Play"}
				disabled={state.status !== "ready"} onClick={() => machine.togglePlay()}><span className="dm-icon" /></button>
		</div>
	);
}

function ClearButton() {
	const { machine } = usePanel();
	return (
		<div className="dm-unit dm-clear-unit">
			<span className="dm-print">Clear</span>
			<button id="clear" className="dm-rubber" aria-label="Clear every step" onClick={() => machine.clear()} />
		</div>
	);
}
