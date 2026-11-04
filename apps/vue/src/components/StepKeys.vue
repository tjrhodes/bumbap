<!-- The sixteen brass keys of the selected part, in four beats, each with a flip tab above it.
     Tap a key to switch its step; drag it up or down for its level, sideways for its nudge. -->
<script setup lang="ts">
import { computed } from "vue";
import { DrumMachine, PanelText, type StepState } from "bumbap-engine";
import { keyGestures } from "../keyGestures";
import { selectedTrack, usePanel, usePlayhead } from "../panel";

const STEPS_PER_BEAT = 4;
const BEATS = [0, 1, 2, 3];
const tools = usePanel();
/**
 * The step being heard. It changes up to 13 times a second, and because only this component reads it, only the
 * keys redraw on each step.
 */
const currentStep = usePlayhead(tools.machine);
const gestures = keyGestures(tools);
const track = computed(() => selectedTrack(tools));

/** The four step numbers of one beat, so the template can group the keys by beat. */
const stepsOfBeat = (beat: number) => Array.from({ length: STEPS_PER_BEAT }, (_, offset) => beat * STEPS_PER_BEAT + offset);
/** A step shows as reversed only while it plays; a step that's off isn't drawn flipped. */
const isReversed = (step: StepState) => step.on && step.reversed;
/**
 * The key's level and nudge as CSS custom properties: the stylesheet turns them into the height of the glow and
 * the slant of the key.
 */
const keyStyle = (step: StepState) => ({ "--level": step.velocity / 100, "--nudge": step.nudge / DrumMachine.limits.nudge.max });
</script>

<template>
	<section class="dm-steps" aria-label="Steps">
		<div class="dm-steps-head">
			<h2 class="dm-print dm-rule">Steps</h2>
			<button id="copy-steps" type="button" class="dm-tool" aria-label="Copy these steps" @click="tools.machine.copySteps(tools.selectedPart.value)">Copy</button>
			<button id="paste-steps" type="button" class="dm-tool" aria-label="Paste the copied steps" :disabled="!tools.state.value.stepsCopied"
				@click="tools.machine.pasteSteps(tools.selectedPart.value)">Paste</button>
		</div>
		<div id="keys" class="dm-keys">
			<div v-for="beat in BEATS" :key="beat" class="dm-beat" :data-beat="beat + 1">
				<template v-for="index in stepsOfBeat(beat)" :key="index">
					<button class="dm-tab dm-flip" :aria-pressed="isReversed(track.steps[index])" :aria-label="PanelText.flipLabel(track.name, index)"
						@click="tools.machine.toggleStepReverse(tools.selectedPart.value, index)"><span class="dm-flip-icon"></span></button>
					<button :class="['dm-key', { 'is-current': index === currentStep, 'is-reversed': isReversed(track.steps[index]) }]"
						:style="keyStyle(track.steps[index])" :aria-pressed="track.steps[index].on" :aria-label="PanelText.stepLabel(track.name, index, track.steps[index])"
						@pointerdown="gestures.start($event, index)" @click="gestures.click(index)" @keydown="gestures.arrow($event, index)">
						<span class="dm-key-fill"></span><span class="dm-key-led"></span><span class="dm-key-number">{{ index + 1 }}</span>
					</button>
				</template>
			</div>
		</div>
	</section>
</template>
