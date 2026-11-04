<!-- One knob: a slider in a round body (see knob.ts for its gestures). -->
<script setup lang="ts">
import type { Range } from "bumbap-engine";
import { followDrag, onKnobKey, turnStyle } from "../knob";

const props = withDefaults(defineProps<{ id: string; label: string; range: Range; value: number; variant?: string; disabled?: boolean }>(),
	{ variant: "", disabled: false });
const emit = defineEmits<{ turn: [value: number] }>();

/**
 * Every gesture ends here. The value is rounded and kept in range, then sent up to the parent as a "turn"
 * event. The knob doesn't set anything itself: it only says how far it was turned, and the parent decides.
 */
function turnTo(next: number) {
	emit("turn", props.range.clamp(next));
}
</script>

<template>
	<div :id="id" :class="['dm-knob', variant]" role="slider" :tabindex="disabled ? -1 : 0" :aria-label="label" :aria-disabled="disabled"
		:aria-valuemin="range.min" :aria-valuemax="range.max" :aria-valuenow="value" :style="turnStyle(value, range)"
		@pointerdown="followDrag($event, value, range, turnTo)" @keydown="onKnobKey($event, value, range, turnTo)"
		@wheel.prevent="turnTo(value - Math.sign($event.deltaY))" @dblclick="turnTo(range.initial)">
		<span class="dm-knob-cap"></span>
	</div>
</template>
