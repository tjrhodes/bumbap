// Start-up (SPEC.md §6), two ways, five runs each, the middle run kept:
//  - Lighthouse's mobile preset (a mid-range phone on a slow 4G line, simulated);
//  - time until Play can be pressed (scripts run, kit downloaded and decoded), on a phone-sized
//    window with the CPU slowed four times and the network set to Lighthouse's slow 4G.
// The server gzips like a real host. Google Fonts is blocked in every build: it cannot be reached
// from the measuring machine and would be the same for all. The prototype is left out: it carries
// the whole kit inside its page, so it is not a fair start-up.
//
// Run from tests/, after building everything:  node measure/startup.mjs [build …]

import { chromium } from "@playwright/test";
import * as chromeLauncher from "chrome-launcher";
import lighthouse from "lighthouse";
import { DEVICES, launchBrowser, median, round, saveResults, startServer, urlOf } from "./lab.mjs";

const RUNS = Number(process.env.RUNS ?? 5);
const COMPARED = ["haxe", "react", "vue", "angular"];
const FONTS = ["*fonts.googleapis.com*", "*fonts.gstatic.com*"];
/** Lighthouse's slow 4G: 150 ms round trips, about 1.6 Mbit/s down and 0.75 up. */
const SLOW_4G = { offline: false, latency: 150, downloadThroughput: (1638.4 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 };

/** The Lighthouse audits reported, by the name used in the results. */
const AUDITS = {
	firstPaintMs: "first-contentful-paint",
	largestPaintMs: "largest-contentful-paint",
	speedIndexMs: "speed-index",
	blockingMs: "total-blocking-time",
	scriptBootMs: "bootup-time",
	mainThreadMs: "mainthread-work-breakdown",
	totalBytes: "total-byte-weight"
};

function summarise(report) {
	const reading = { score: Math.round(report.categories.performance.score * 100) };
	for (const [name, audit] of Object.entries(AUDITS)) reading[name] = round(report.audits[audit].numericValue);
	return reading;
}

async function auditOnce(url) {
	const chrome = await chromeLauncher.launch({ chromePath: chromium.executablePath(), chromeFlags: ["--headless=new", "--no-sandbox"] });
	try {
		const { lhr } = await lighthouse(url, { port: chrome.port, output: "json", onlyCategories: ["performance"], logLevel: "error", blockedUrlPatterns: FONTS });
		return summarise(lhr);
	} finally {
		await chrome.kill();
	}
}

/** Milliseconds from asking for the page to the Play button being enabled, on the slowed phone. */
async function playableOnce(browser, build) {
	const page = await browser.newPage({ viewport: DEVICES.phone.viewport });
	const devtools = await page.context().newCDPSession(page);
	await devtools.send("Network.emulateNetworkConditions", SLOW_4G);
	await devtools.send("Emulation.setCPUThrottlingRate", { rate: DEVICES.phone.cpuSlowdown });
	await page.route(/fonts\.(googleapis|gstatic)\.com/, (route) => route.abort());
	await page.goto(urlOf(build));
	await page.locator(".dm-play-unit button:enabled").waitFor({ timeout: 60_000 });
	const playableMs = await page.evaluate(() => performance.now());
	await page.close();
	return round(playableMs);
}

async function playable(build) {
	const browser = await launchBrowser();
	const runs = [];
	for (let run = 0; run < RUNS; run++) runs.push(await playableOnce(browser, build));
	await browser.close();
	return { playableMs: median(runs), allRunsPlayableMs: runs };
}

async function audit(build) {
	const runs = [];
	for (let run = 0; run < RUNS; run++) runs.push(await auditOnce(urlOf(build)));
	const middle = runs.sort((a, b) => a.score - b.score || a.largestPaintMs - b.largestPaintMs)[Math.floor(runs.length / 2)];
	const ready = await playable(build);
	console.log(`${build.padEnd(8)} score ${middle.score}, first paint ${middle.firstPaintMs} ms, largest ${middle.largestPaintMs} ms, blocking ${middle.blockingMs} ms, ${round(middle.totalBytes / 1024)} kB, playable ${ready.playableMs} ms`);
	return { ...middle, allRunsScores: runs.map((each) => each.score), ...ready };
}

async function measureAll(builds) {
	const server = await startServer();
	const results = {};
	try {
		for (const build of builds) results[build] = await audit(build);
	} finally {
		server.kill();
	}
	saveResults("startup", { preset: "Lighthouse mobile (simulated slow 4G, 4x CPU slowdown), Google Fonts blocked; playable: slow 4G + 4x CPU, throttled for real", runs: RUNS, results });
}

measureAll(process.argv.length > 2 ? process.argv.slice(2) : COMPARED);
