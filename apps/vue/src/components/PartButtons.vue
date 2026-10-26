<!-- The eight part buttons: the pill selects a part (its LED flashes as it plays), the M tab above mutes it. -->
<script setup lang="ts">
import { onUnmounted } from "vue";
import { usePanel } from "../panel";

const { machine, state, selectedPart } = usePanel();
/** Each part's LED glow, by part number (refs gathered by v-for alone do not promise the list's order). */
const glows: (Element | null)[] = [];
const keepGlow = (index: number) => (glow: unknown) => void (glows[index] = glow as Element | null);

/**
 * Lets you see the parts you are not editing: each LED blinks as its part sounds, brighter
 * when harder. A one-off animation, so it is played on the element rather than kept in state.
 */
function flashPartsPlaying(step: number) {
	if (step < 0) return;
	machine.getState().tracks.forEach((track, index) => {
		const hit = track.steps[step];
		if (hit.on && !track.muted) glows[index]?.animate([{ opacity: Math.max(0.3, hit.velocity / 100) }, { opacity: 0 }], { duration: 260, easing: "ease-out" });
	});
}
onUnmounted(machine.onStep(flashPartsPlaying));
</script>

<template>
	<div id="pills" class="dm-pills" role="group" aria-label="Part">
		<div v-for="(track, index) in state.tracks" :key="track.id" class="dm-pill-wrap">
			<button class="dm-tab dm-mute" :aria-pressed="track.muted" :aria-label="`Mute ${track.name}`" @click="machine.toggleMute(index)">M</button>
			<button :class="['dm-pill', { 'is-muted': track.muted }]" :aria-pressed="index === selectedPart" @click="selectedPart = index">
				<span class="dm-led"><span :ref="keepGlow(index)" class="dm-led-glow"></span></span>{{ track.name }}
			</button>
		</div>
	</div>
</template>
