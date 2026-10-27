// The selected part's own knobs (Level, Pitch, Length, and its 808 knobs), the pattern buttons, then the part buttons.
import { DrumMachine, PanelText, type MachineState } from "bumbap-engine";
import { selectedTrack, usePanel, type PanelTools } from "../context";
import { Knob } from "./Knob";
import { KnobUnit } from "./KnobUnit";
import { PartButtons } from "./PartButtons";
import { PatternButtons } from "./PatternButtons";

/** The 808 group has room for the most knobs any part has. */
const DIAL_SLOTS = [0, 1];

export function PartSection() {
	return (
		<section className="dm-part" aria-label="Part">
			<h2 className="dm-print dm-rule">Part</h2>
			<div className="dm-strip">
				<PartKnobs />
				<DialGroup />
				<PatternButtons />
			</div>
			<PartButtons />
		</section>
	);
}

function PartKnobs() {
	const tools = usePanel();
	const { machine, selectedPart } = tools;
	const { name } = selectedTrack(tools);
	const { limits } = DrumMachine;
	const part = (state: MachineState) => state.tracks[selectedPart];
	return (
		<>
			<KnobUnit id="level" name="Level" label={`${name} level`} range={limits.volume} read={(s) => part(s).volume} set={(v) => machine.setVolume(selectedPart, v)} />
			<KnobUnit id="pitch" name="Pitch" label={`${name} pitch`} range={limits.pitch} read={(s) => part(s).pitch} set={(v) => machine.setPitch(selectedPart, v)} />
			<KnobUnit id="length" name="Length" label={`${name} length`} range={limits.length} read={(s) => part(s).length} set={(v) => machine.setLength(selectedPart, v)} />
		</>
	);
}

function DialGroup() {
	return (
		<div className="dm-dials">
			<span className="dm-print dm-dials-label">808</span>
			{DIAL_SLOTS.map((slot) => <DialSlot key={slot} slot={slot} />)}
		</div>
	);
}

/** One of the part's 808 knobs; a part without one there leaves the slot dimmed, unnamed and still. */
function DialSlot({ slot }: { slot: number }) {
	const tools = usePanel();
	const track = selectedTrack(tools);
	const name = track.dialNames[slot];
	return (
		<div className={name ? "dm-unit" : "dm-unit is-unused"}>
			<span className="dm-print">{name ?? "—"}</span>
			<Knob id={`dial-${slot}`} variant="dm-knob-808" label={PanelText.dialLabel(track, slot)} range={DrumMachine.limits.dial}
				value={track.dials[slot] ?? DrumMachine.limits.dial.initial} onTurn={(position) => turnDial(tools, slot, position)} disabled={!name} />
		</div>
	);
}

/** Picks another recording, and shows its 808 setting (e.g. "2510") while the knob turns. */
function turnDial(tools: PanelTools, slot: number, position: number) {
	const { machine, selectedPart } = tools;
	if (slot >= machine.getState().tracks[selectedPart].dials.length) return;
	machine.setDial(selectedPart, slot, position);
	tools.showBriefly(PanelText.dialSetting(machine.getState().tracks[selectedPart]));
}
