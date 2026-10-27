<!-- The share button at the top right: shares the link to the beat (see ShareLink in the engine), then says beside it what happened. -->
<script setup lang="ts">
import { ref } from "vue";
import { ShareLink } from "bumbap-engine";
import { holdFor, usePanel } from "../panel";

const { state } = usePanel();
const note = ref<string | null>(null);
const showNote = holdFor(note, ShareLink.NOTE_MS);

async function share() {
	const words = await ShareLink.share(state.value.code);
	if (words) showNote(words);
}
</script>

<template>
	<span class="dm-print dm-share-note" aria-live="polite">{{ note }}</span>
	<button class="dm-share" type="button" :aria-label="ShareLink.LABEL" @click="share">
		<svg class="dm-share-icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="18" cy="5" r="2.2"/><circle cx="6" cy="12" r="2.2"/><circle cx="18" cy="19" r="2.2"/><path d="M15.5 6.5l-7 4M8.5 13.5l7 4"/></svg>
	</button>
</template>
