<!-- The bümbap panel: provides the machine's state and the selected part to every component below. -->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, watch } from "vue";
import { PanelText, type DrumMachine } from "bumbap-engine";
import { providePanel } from "../panel";
import DeckSection from "./DeckSection.vue";
import PartSection from "./PartSection.vue";
import ShareButton from "./ShareButton.vue";
import StepKeys from "./StepKeys.vue";

const props = defineProps<{ machine: DrumMachine }>();
/** Starts following the machine's snapshots and hands the tools to every component below this one. */
const tools = providePanel(props.machine);
/**
 * What the display shows: a value being changed if there is one, else the resting text (the tempo). `computed`
 * works it out again only when one of the two changes.
 */
const displayText = computed(() => tools.heldText.value ?? PanelText.resting(tools.state.value));

/** Remembers the pattern in the address; some frames refuse, and then it simply is not remembered there. */
watch(() => tools.state.value.code, (code) => {
	try { history.replaceState(null, "", `#${code}`); } catch { /* nothing is lost */ }
}, { immediate: true });

/** Space plays and stops unless a focused control already uses it; keys 1–8 pick a part. */
function onShortcut(event: KeyboardEvent) {
	const part = Number(event.key);
	if (event.key !== " " && part >= 1 && part <= tools.state.value.tracks.length) return void (tools.selectedPart.value = part - 1);
	const spaceAlreadyUsed = (event.target as Element).closest("button, [role='slider']");
	if (event.key !== " " || spaceAlreadyUsed) return;
	event.preventDefault();
	props.machine.togglePlay();
}

/**
 * Once the panel is on the page: download the sounds and listen for keyboard shortcuts. The shortcut listener
 * is removed when the panel goes away, so it can't fire on a panel that no longer exists.
 */
onMounted(() => {
	props.machine.load();
	document.addEventListener("keydown", onShortcut);
});
onUnmounted(() => document.removeEventListener("keydown", onShortcut));
</script>

<template>
	<main class="dm">
		<div class="dm-panel">
			<header class="dm-head"><span class="dm-wordmark">bümbap</span><span class="dm-print">16 step · 8 part · Haxe engine</span><ShareButton /></header>
			<DeckSection :display-text="displayText" />
			<PartSection />
			<StepKeys />
		</div>
	</main>
</template>
