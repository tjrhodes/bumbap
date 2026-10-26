// bümbap in React: the machine is made once, outside React, and handed to the panel.
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import * as Tone from "tone";
import { DrumMachine } from "bumbap-engine";
import "../../../shared/bumbap.css";
import { Panel } from "./components/Panel";

/** The shared kit sits at the repo root, beside apps/ (this build is served from apps/react/dist/). */
const SAMPLES_URL = "../../../samples/";

const machine = new DrumMachine({ tone: Tone, samplesUrl: SAMPLES_URL });
machine.loadCode(location.hash.slice(1)); // a shared pattern, if the address carries one

createRoot(document.getElementById("root")!).render(
	<StrictMode>
		<Panel machine={machine} />
	</StrictMode>
);
