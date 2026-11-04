<!-- A knob with its name printed above it, as on the hardware. Turning it shows its letter and value ("S 66"). -->
<script setup lang="ts">
import { PanelText, type MachineState, type Range } from "bumbap-engine";
import { usePanel } from "../panel";
import KnobControl from "./KnobControl.vue";

const props = defineProps<{ id: string; name: string; label: string; range: Range; read: (state: MachineState) => number;
	set: (value: number) => void; unitClass?: string }>();
const { machine, state, showBriefly } = usePanel();

/**
 * The knob was turned: set the value on the machine, then show it on the display ("S 66") if this knob has a
 * display letter. The value shown is read back from the machine, so it is the one the machine really took.
 */
function onTurn(value: number) {
	props.set(value);
	const letter = PanelText.KNOB_LETTERS[props.id];
	if (letter) showBriefly(PanelText.labelled(letter, props.read(machine.getState())));
}
</script>

<template>
	<div :class="['dm-unit', unitClass]">
		<span class="dm-print">{{ name }}</span>
		<KnobControl :id="id" :label="label" :range="range" :value="read(state)" @turn="onTurn" />
	</div>
</template>
