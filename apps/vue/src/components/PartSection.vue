<!-- The selected part's own knobs (Level, Pitch, Length, and its 808 knobs), then the part buttons. -->
<script setup lang="ts">
import { computed } from "vue";
import { DrumMachine, type MachineState } from "bumbap-engine";
import { selectedTrack, usePanel } from "../panel";
import DialSlot from "./DialSlot.vue";
import KnobUnit from "./KnobUnit.vue";
import PartButtons from "./PartButtons.vue";

/** The 808 group has room for the most knobs any part has. */
const DIAL_SLOTS = [0, 1];
const tools = usePanel();
const { machine, selectedPart } = tools;
const { limits } = DrumMachine;
const name = computed(() => selectedTrack(tools).name);
const part = (state: MachineState) => state.tracks[selectedPart.value];
</script>

<template>
	<section class="dm-part" aria-label="Part">
		<h2 class="dm-print dm-rule">Part</h2>
		<div class="dm-strip">
			<KnobUnit id="level" name="Level" :label="`${name} level`" :range="limits.volume" :read="(s) => part(s).volume" :set="(v) => machine.setVolume(selectedPart, v)" />
			<KnobUnit id="pitch" name="Pitch" :label="`${name} pitch`" :range="limits.pitch" :read="(s) => part(s).pitch" :set="(v) => machine.setPitch(selectedPart, v)" />
			<KnobUnit id="length" name="Length" :label="`${name} length`" :range="limits.length" :read="(s) => part(s).length" :set="(v) => machine.setLength(selectedPart, v)" />
			<div class="dm-dials">
				<span class="dm-print dm-dials-label">808</span>
				<DialSlot v-for="slot in DIAL_SLOTS" :key="slot" :slot-index="slot" />
			</div>
		</div>
		<PartButtons />
	</section>
</template>
