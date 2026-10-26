<!-- One of the selected part's 808 knobs; a part without one there leaves the slot dimmed, unnamed and still. -->
<script setup lang="ts">
import { computed } from "vue";
import { DrumMachine, PanelText } from "bumbap-engine";
import { selectedTrack, usePanel } from "../panel";
import KnobControl from "./KnobControl.vue";

const props = defineProps<{ slotIndex: number }>();
const tools = usePanel();
const track = computed(() => selectedTrack(tools));
const name = computed(() => track.value.dialNames[props.slotIndex]);
const position = computed(() => track.value.dials[props.slotIndex] ?? DrumMachine.limits.dial.initial);

/** Picks another recording, and shows its 808 setting (e.g. "2510") while the knob turns. */
function turn(value: number) {
	if (!name.value) return;
	tools.machine.setDial(tools.selectedPart.value, props.slotIndex, value);
	tools.showBriefly(PanelText.dialSetting(tools.machine.getState().tracks[tools.selectedPart.value]));
}
</script>

<template>
	<div :class="['dm-unit', { 'is-unused': !name }]">
		<span class="dm-print">{{ name ?? "—" }}</span>
		<KnobControl :id="`dial-${slotIndex}`" variant="dm-knob-808" :label="PanelText.dialLabel(track, slotIndex)"
			:range="DrumMachine.limits.dial" :value="position" :disabled="!name" @turn="turn" />
	</div>
</template>
