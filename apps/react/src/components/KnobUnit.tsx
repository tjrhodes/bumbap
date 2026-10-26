// A knob with its name printed above it, as on the hardware.
import { PanelText, type MachineState, type Range } from "bumbap-engine";
import { usePanel } from "../context";
import { Knob } from "./Knob";

export interface KnobUnitProps {
	id: string;
	name: string;
	label: string;
	range: Range;
	read: (state: MachineState) => number;
	set: (value: number) => void;
	unitClass?: string;
}

/** Turning it sets the value and, if the knob has a display letter, shows it for a moment ("S 66"). */
export function KnobUnit({ id, name, label, range, read, set, unitClass = "" }: KnobUnitProps) {
	const { machine, state, showBriefly } = usePanel();
	const letter = PanelText.KNOB_LETTERS[id];
	const onTurn = (value: number) => {
		set(value);
		if (letter) showBriefly(PanelText.labelled(letter, read(machine.getState())));
	};
	return (
		<div className={`dm-unit ${unitClass}`.trim()}>
			<span className="dm-print">{name}</span>
			<Knob id={id} label={label} range={range} value={read(state)} onTurn={onTurn} />
		</div>
	);
}
