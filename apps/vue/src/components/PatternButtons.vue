<!-- The eight pattern buttons (v2), drawn from the snapshot: in the chain, half lit; playing or shown, fully lit;
     waiting for the end of the bar, blinking; empty, a dim number. Their gestures go to the engine's PatternPad. -->
<script setup lang="ts">
import { onMounted, onUnmounted } from "vue";
import { PanelText, PatternPad } from "bumbap-engine";
import { usePanel } from "../panel";

const PATTERNS = [0, 1, 2, 3, 4, 5, 6, 7];
const { machine, state } = usePanel();
const pad = new PatternPad(machine);

/** A finger dragged onto another button is lifted there, so lifting is heard from the whole window. */
const release = (event: PointerEvent) => pad.release(event.pointerId, PatternPad.patternAt(event.clientX, event.clientY));
const cancel = (event: PointerEvent) => pad.release(event.pointerId, PatternPad.NONE);

onMounted(() => {
	window.addEventListener("pointerup", release);
	window.addEventListener("pointercancel", cancel);
});
onUnmounted(() => {
	window.removeEventListener("pointerup", release);
	window.removeEventListener("pointercancel", cancel);
});
</script>

<template>
	<div class="dm-patterns" role="group" aria-label="Patterns">
		<span class="dm-print dm-dials-label">Pattern</span>
		<div class="dm-pattern-row">
			<button v-for="index in PATTERNS" :key="index" type="button" :data-pattern="index"
				:class="['dm-pattern', { 'is-used': state.patternHasSteps[index], 'is-next': state.nextPattern === index }]"
				:aria-pressed="state.chain.includes(index)" :aria-current="state.pattern === index" :aria-label="PanelText.patternLabel(state, index)"
				@pointerdown="pad.press($event.pointerId, index)" @click="pad.click(index, $event.shiftKey)">{{ index + 1 }}</button>
		</div>
		<p class="dm-print dm-pattern-hint">
			<span class="for-mouse">Shift-click to chain · drag to copy</span><span class="for-touch">Hold and tap to chain · drag to copy</span>
		</p>
	</div>
</template>
