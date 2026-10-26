<!-- A knob with its name printed above it, as on the hardware. Turning it shows its letter and value ("S 66"). -->
<script setup lang="ts">
import { PanelText, type MachineState, type Range } from "bumbap-engine";
import { usePanel } from "../panel";
import KnobControl from "./KnobControl.vue";

const props = defineProps<{ id: string; name: string; label: string; range: Range; read: (state: MachineState) => number;
	set: (value: number) => void; unitClass?: string }>();
const { machine, state, showBriefly } = usePanel();

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
