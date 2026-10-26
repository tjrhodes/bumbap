// bümbap in Angular: the machine is made once, before Angular starts, and provided to it.
import { bootstrapApplication } from "@angular/platform-browser";
import * as Tone from "tone";
import { DrumMachine } from "bumbap-engine";
import { appConfig } from "./app/app.config";
import { MACHINE } from "./app/panel-store";
import { Panel } from "./app/panel";

/** The shared kit sits at the repo root, beside apps/ (this build is served from apps/angular/dist/). */
const SAMPLES_URL = "../../../samples/";

const machine = new DrumMachine({ tone: Tone, samplesUrl: SAMPLES_URL });
machine.loadCode(location.hash.slice(1)); // a shared pattern, if the address carries one

bootstrapApplication(Panel, { providers: [...appConfig.providers, { provide: MACHINE, useValue: machine }] })
	.catch((error) => console.error(error));
