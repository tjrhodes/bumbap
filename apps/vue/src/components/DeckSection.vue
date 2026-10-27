<!-- The deck: the display and the whole machine's controls (tempo, swing, drive, reverb, play, clear, download). -->
<script setup lang="ts">
import { DrumMachine, LoopFile, PanelText } from "bumbap-engine";
import { usePanel } from "../panel";
import KnobUnit from "./KnobUnit.vue";
import SevenSegment from "./SevenSegment.vue";

defineProps<{ displayText: string }>();
const { machine, state } = usePanel();
const { limits } = DrumMachine;
</script>

<template>
	<section class="dm-deck" aria-label="Controls">
		<div class="dm-window">
			<SevenSegment :text="displayText" />
			<p id="status" class="dm-print dm-status" role="status">{{ PanelText.status(state) }}</p>
		</div>
		<KnobUnit id="tempo" name="Tempo" label="Tempo, beats per minute" unit-class="dm-tempo" :range="limits.tempo" :read="(s) => s.tempo" :set="(v) => machine.setTempo(v)" />
		<KnobUnit id="swing" name="Swing" label="Swing, percent" unit-class="dm-swing" :range="limits.swing" :read="(s) => s.swing" :set="(v) => machine.setSwing(v)" />
		<KnobUnit id="drive" name="Drive" label="Drive, percent" unit-class="dm-drive" :range="limits.drive" :read="(s) => s.drive" :set="(v) => machine.setDrive(v)" />
		<KnobUnit id="reverb" name="Reverb" label="Reverb, percent" unit-class="dm-reverb" :range="limits.reverb" :read="(s) => s.reverb" :set="(v) => machine.setReverb(v)" />
		<div class="dm-unit dm-play-unit">
			<span class="dm-print"><span id="play-led" :class="['dm-led', { 'is-on': state.playing }]"></span>Play</span>
			<button id="play" class="dm-rubber dm-rubber-play" :aria-pressed="state.playing" :aria-label="state.playing ? 'Stop' : 'Play'"
				:disabled="state.status !== 'ready'" @click="machine.togglePlay()"><span class="dm-icon"></span></button>
		</div>
		<div class="dm-unit dm-clear-unit">
			<span class="dm-print">Clear</span>
			<button id="clear" class="dm-rubber" aria-label="Clear every step" @click="machine.clear()"></button>
		</div>
		<div class="dm-unit dm-save-unit">
			<span class="dm-print">Download</span>
			<button id="save" class="dm-rubber" type="button" :aria-label="LoopFile.LABEL" :disabled="state.status !== 'ready' || state.exporting"
				@click="LoopFile.download(machine)"><svg class="dm-download-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/></svg></button>
		</div>
	</section>
</template>
