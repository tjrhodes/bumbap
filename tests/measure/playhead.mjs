// Playhead cost and timing (SPEC.md §6). Each build plays the starter beat at 200 BPM for 30 s,
// on desktop and on a slowed "phone", three times each. Measured per step of the playhead:
// main-thread time (script, style, layout, all work), frames dropped, and how evenly the lit key
// moves (a step at 200 BPM is 75 ms; one frame is ~16.7 ms).
//
// Run from tests/, after building everything:  node measure/playhead.mjs [build …]

import { BUILDS, DEVICES, launchBrowser, mainThreadTime, median, openBuild, round, saveResults, startServer, timeEach } from "./lab.mjs";

const LISTEN_MS = Number(process.env.LISTEN_MS ?? 30_000);
const SETTLE_MS = 2_000;
const RUNS = Number(process.env.RUNS ?? 3);
const STEP_MS = 60_000 / 200 / 4;

/** Runs inside the page: notes when each key lights and when each frame is drawn. */
function startRecording() {
	const record = (window.bumbapRecord = { lit: [], frames: [] });
	const becameLit = (change) => change.target.classList.contains("is-current") && !change.oldValue?.includes("is-current");
	new MutationObserver((changes) => changes.some(becameLit) && record.lit.push(performance.now()))
		.observe(document.querySelector(".dm-steps") ?? document.body, { subtree: true, attributeFilter: ["class"], attributeOldValue: true });
	const everyFrame = (time) => { record.frames.push(time); requestAnimationFrame(everyFrame); };
	requestAnimationFrame(everyFrame);
}

/** Frames whose gap was more than one and a half normal frames count as dropped (each gap may hide several). */
function framesDropped(frames) {
	const gaps = frames.slice(1).map((time, index) => time - frames[index]);
	const normalGap = median(gaps);
	return gaps.reduce((dropped, gap) => dropped + (gap > normalGap * 1.5 ? Math.round(gap / normalGap) - 1 : 0), 0);
}

/** How far each step's gap strayed from 75 ms: the average, the worst, and the share within one frame. */
function evenness(lit) {
	const errors = lit.slice(1).map((time, index) => Math.abs(time - lit[index] - STEP_MS));
	const withinAFrame = errors.filter((error) => error <= 1000 / 60).length / errors.length;
	return { averageMs: round(errors.reduce((a, b) => a + b, 0) / errors.length, 2), worstMs: round(Math.max(...errors)), withinAFrame: round(withinAFrame * 100) };
}

async function setTempoTo200(page) {
	await page.locator("#tempo").focus();
	await page.keyboard.press("End");
}

/** One 30-second listen of one build on one device. */
async function listenOnce(browser, build, device) {
	const { page, devtools } = await openBuild(browser, build, device);
	await setTempoTo200(page);
	await page.locator(".dm-play-unit button").click();
	await page.waitForTimeout(SETTLE_MS);
	await page.evaluate(startRecording);
	const before = await mainThreadTime(devtools);
	await page.waitForTimeout(LISTEN_MS);
	const after = await mainThreadTime(devtools);
	const { lit, frames } = await page.evaluate(() => window.bumbapRecord);
	await page.close();
	return { steps: lit.length, perStepMs: timeEach(before, after, lit.length), framesDropped: framesDropped(frames), frames: frames.length, timing: evenness(lit) };
}

/** The middle run of three, by main-thread time per step, so one noisy run cannot decide the result. */
async function listen(browser, build, device) {
	const runs = [];
	for (let run = 0; run < RUNS; run++) runs.push(await listenOnce(browser, build, device));
	const middle = runs.sort((a, b) => a.perStepMs.busy - b.perStepMs.busy)[Math.floor(runs.length / 2)];
	console.log(`${build.padEnd(9)} ${device.padEnd(7)} busy ${middle.perStepMs.busy} ms/step, script ${middle.perStepMs.script}, dropped ${middle.framesDropped}/${middle.frames}, within a frame ${middle.timing.withinAFrame} %`);
	return { ...middle, allRunsBusyMs: runs.map((each) => each.perStepMs.busy) };
}

async function measureAll(builds) {
	const server = await startServer();
	const browser = await launchBrowser();
	const results = {};
	try {
		for (const device of Object.keys(DEVICES)) for (const build of builds) (results[build] ??= {})[device] = await listen(browser, build, device);
	} finally {
		await browser.close();
		server.kill();
	}
	saveResults("playhead", { tempo: 200, listenSeconds: LISTEN_MS / 1000, runs: RUNS, results });
}

measureAll(process.argv.length > 2 ? process.argv.slice(2) : Object.keys(BUILDS));
