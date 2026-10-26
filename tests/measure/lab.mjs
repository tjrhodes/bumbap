// What every measurement script shares: the builds, the local server, opening a build the way a
// person would, and reading how long Chrome's main thread spent on script, style and layout.

import { chromium } from "@playwright/test";
import { spawn } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const PORT = 4173;
const REPO = fileURLToPath(new URL("../../", import.meta.url));
const TONE_ON_CDN = "https://cdn.jsdelivr.net/npm/tone@15.1.22/build/Tone.js";
const TONE_LOCAL = `${REPO}engine/node_modules/tone/build/Tone.js`;

/** The four builds being compared, the prototype (plain JavaScript) as the reference, and the bare baseline (engine + a bare playhead). */
export const BUILDS = {
	baseline: "tests/measure/baseline.html",
	prototype: "prototype/drum-preview.html",
	haxe: "apps/haxe/dist/index.html",
	react: "apps/react/dist/index.html",
	vue: "apps/vue/dist/index.html",
	angular: "apps/angular/dist/index.html"
};

/** Desktop as tested so far; "phone" is a phone-sized window on a CPU slowed four times, Chrome's mid-range phone setting. */
export const DEVICES = {
	desktop: { viewport: { width: 1280, height: 800 }, cpuSlowdown: 1 },
	phone: { viewport: { width: 390, height: 844 }, cpuSlowdown: 4 }
};

export const urlOf = (build) => `http://localhost:${PORT}/${BUILDS[build]}`;

/** Starts the repo's static server (gzip on, like a real host) and resolves once it answers. */
export async function startServer() {
	const server = spawn("node", [`${REPO}tools/serve.mjs`, String(PORT)], { stdio: ["ignore", "pipe", "inherit"] });
	await new Promise((ready) => server.stdout.once("data", ready));
	return server;
}

export const launchBrowser = () => chromium.launch({ args: ["--autoplay-policy=no-user-gesture-required"] });

/** Opens one build on one device, waits until it can play, and hands back the page and a DevTools session. */
export async function openBuild(browser, build, device) {
	const page = await browser.newPage({ viewport: DEVICES[device].viewport });
	await page.route(TONE_ON_CDN, (route) => route.fulfill({ body: readFileSync(TONE_LOCAL), contentType: "text/javascript" }));
	await page.goto(urlOf(build));
	await page.locator(".dm-play-unit button:enabled").waitFor({ timeout: 20_000 });
	const devtools = await page.context().newCDPSession(page);
	await devtools.send("Performance.enable");
	await devtools.send("Emulation.setCPUThrottlingRate", { rate: DEVICES[device].cpuSlowdown });
	return { page, devtools };
}

/** Milliseconds the main thread has spent so far, by kind, since the page opened. */
export async function mainThreadTime(devtools) {
	const { metrics } = await devtools.send("Performance.getMetrics");
	const seconds = (name) => metrics.find((metric) => metric.name === name).value;
	return {
		script: seconds("ScriptDuration") * 1000,
		style: seconds("RecalcStyleDuration") * 1000,
		layout: seconds("LayoutDuration") * 1000,
		busy: seconds("TaskDuration") * 1000
	};
}

/** Main-thread time spent between two readings, each kind divided by how many things happened. */
export function timeEach(before, after, count) {
	const each = (kind) => round((after[kind] - before[kind]) / count, 3);
	return { script: each("script"), style: each("style"), layout: each("layout"), busy: each("busy") };
}

export const round = (number, places = 1) => Number(number.toFixed(places));
export const median = (numbers) => [...numbers].sort((a, b) => a - b)[Math.floor(numbers.length / 2)];

/** Saves a measurement's results next to the scripts, for RESULTS.md and the Lab page. */
export function saveResults(name, results) {
	const file = fileURLToPath(new URL(`results/${name}.json`, import.meta.url));
	const earlier = existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : {};
	if (results.results) results.results = { ...earlier.results, ...results.results };   // a run of some builds keeps the others
	writeFileSync(file, JSON.stringify(results, null, "\t") + "\n");
	console.log(`Saved ${file}`);
}
