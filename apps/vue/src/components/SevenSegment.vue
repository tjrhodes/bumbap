<!-- The four-digit LED display, drawn from the engine's SevenSegmentFont; unlit segments show faintly. -->
<script setup lang="ts">
import { SevenSegmentFont as font } from "bumbap-engine";

defineProps<{ text: string }>();
</script>

<template>
	<svg id="display" class="dm-display" :viewBox="font.VIEW_BOX" aria-hidden="true">
		<g v-for="(character, index) in font.characters(text)" :key="index" :transform="font.digitTransform(index)">
			<polygon v-for="segment in font.SEGMENTS" :key="segment" :class="['dm-seg', { 'is-lit': font.isLit(character, segment) }]"
				:data-segment="segment" :points="font.segmentPoints(segment)" />
		</g>
	</svg>
</template>
