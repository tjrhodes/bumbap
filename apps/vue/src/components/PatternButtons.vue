<!-- The sequence (v2): eight pattern buttons and the Select, Copy and Clear tools beside the title. In the sequence,
     half lit; playing, fully lit; on the keys, a ring; taking over at the end of the bar, blinking; empty, a dim number; with Select
     on, each button's places in the sequence. Taps go to the engine's PatternPad, shared by every build. -->
<script setup lang="ts">
import { computed, onMounted, onUnmounted } from "vue";
import { PanelText, PatternPad } from "bumbap-engine";
import { usePanel } from "../panel";

const PATTERNS = [0, 1, 2, 3, 4, 5, 6, 7];
const TOOLS = [
	{ tool: "select", name: "Select", label: "Select the sequence" },
	{ tool: "copy", name: "Copy", label: "Copy a pattern" },
	{ tool: "clear", name: "Clear", label: "Clear a pattern" }
] as const;
const { machine, state } = usePanel();
const pad = new PatternPad(machine);
const hints = computed(() => PanelText.sequenceHints(state.value));

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
	<div class="dm-patterns" role="group" aria-label="Sequence">
		<div class="dm-sequence-head">
			<span class="dm-print dm-sequence-title">Sequence</span>
			<button v-for="{ tool, name, label } in TOOLS" :key="tool" type="button" class="dm-tool" :data-tool="tool"
				:aria-pressed="state.tool === tool" :aria-label="label" @click="machine.toggleTool(tool)">{{ name }}</button>
		</div>
		<div class="dm-pattern-row">
			<button v-for="index in PATTERNS" :key="index" type="button" :data-pattern="index"
				:class="['dm-pattern', { 'is-used': state.patternHasSteps[index], 'is-playing': state.playingPattern === index, 'is-next': state.nextPattern === index, 'is-copy-source': state.copyFrom === index }]"
				:aria-pressed="state.sequence.includes(index)" :aria-current="state.pattern === index" :aria-label="PanelText.patternLabel(state, index)"
				@pointerdown="pad.press($event.pointerId, index)" @click="pad.click(index, $event.shiftKey)">
				<span class="dm-pattern-number">{{ index + 1 }}</span><span class="dm-pattern-places">{{ PanelText.sequencePlaces(state, index) }}</span>
			</button>
		</div>
		<p class="dm-print dm-pattern-hint"><span class="for-mouse">{{ hints[0] }}</span><span class="for-touch">{{ hints[1] }}</span></p>
	</div>
</template>
