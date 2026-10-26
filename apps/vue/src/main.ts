// bümbap in Vue: the machine is made once, outside Vue, and handed to the panel as a prop.
import { createApp } from "vue";
import * as Tone from "tone";
import { DrumMachine } from "bumbap-engine";
import "../../../shared/bumbap.css";
import BumbapPanel from "./components/BumbapPanel.vue";

/** The shared kit sits at the repo root, beside apps/ (this build is served from apps/vue/dist/). */
const SAMPLES_URL = "../../../samples/";

const machine = new DrumMachine({ tone: Tone, samplesUrl: SAMPLES_URL });
machine.loadCode(location.hash.slice(1)); // a shared pattern, if the address carries one

createApp(BumbapPanel, { machine }).mount("#app");
