// Turns the saved results (measure/results/*.json) into the Markdown tables in RESULTS.md.
//
// Run from tests/:  node measure/tables.mjs

import { readFileSync } from "node:fs";
import { round } from "./lab.mjs";

const read = (name) => JSON.parse(readFileSync(new URL(`results/${name}.json`, import.meta.url), "utf8"));
const NAMES = { baseline: "Baseline (engine, bare playhead)", prototype: "Prototype (plain JS)", haxe: "Haxe", react: "React", vue: "Vue", angular: "Angular" };

/** Counts and big numbers whole, small ones to one decimal place: enough to compare, not more than the noise. */
const shown = (cell) => {
	if (typeof cell !== "number") return cell;
	if (Number.isInteger(cell) || Math.abs(cell) >= 100) return String(Math.round(cell));
	return (Math.abs(cell) < 0.05 ? 0 : cell).toFixed(1);
};

function table(headings, rows) {
	const line = (cells) => `| ${cells.map(shown).join(" | ")} |`;
	return [line(headings), line(headings.map(() => "---")), ...rows.map(line)].join("\n");
}

/** Per step: all main-thread work, then script alone, each also as the extra over the bare baseline. */
function playheadTable(device) {
	const { results } = read("playhead");
	const floor = results.baseline[device].perStepMs;
	const rows = Object.entries(results).map(([build, { [device]: run }]) => [
		NAMES[build], run.perStepMs.busy, round(run.perStepMs.busy - floor.busy, 2), run.perStepMs.script, round(run.perStepMs.script - floor.script, 2),
		run.framesDropped, `${run.timing.withinAFrame} %`, run.timing.worstMs
	]);
	return table(["Build", "Main thread ms/step", "over baseline", "Script ms/step", "over baseline", "Frames dropped (30 s)", "Steps within a frame of 75 ms", "Worst step error ms"], rows);
}

function gestureTable(device) {
	const { results } = read("gestures");
	const rows = Object.entries(results).map(([build, { [device]: drags }]) => [
		NAMES[build], drags.knob.perMoveMs.busy, drags.knob.perMoveMs.script, drags.key.perMoveMs.busy, drags.key.perMoveMs.script
	]);
	return table(["Build", "Knob: main thread ms/move", "Knob: script ms/move", "Key: main thread ms/move", "Key: script ms/move"], rows);
}

function startupTable() {
	const { results } = read("startup");
	const rows = Object.entries(results).map(([build, run]) => [
		NAMES[build], run.playableMs, run.score, run.firstPaintMs, run.largestPaintMs, run.blockingMs, run.scriptBootMs, round(run.totalBytes / 1024)
	]);
	return table(["Build", "Play usable after ms", "Lighthouse score", "First paint ms", "Largest paint ms", "Blocking ms", "Script boot ms", "Page weight kB"], rows);
}

function codeTable() {
	const rows = Object.entries(read("code")).map(([build, figures]) => [
		NAMES[build], figures.uiCodeLines, figures.uiFiles, figures.buildSeconds, figures.installMB, figures.topLevelPackages
	]);
	return table(["Build", "UI code lines", "UI files", "Clean build s", "Installed MB", "Packages installed"], rows);
}

const sections = [
	["Playhead, desktop", () => playheadTable("desktop")], ["Playhead, phone (4x slower CPU)", () => playheadTable("phone")],
	["Dragging, desktop", () => gestureTable("desktop")], ["Dragging, phone (4x slower CPU)", () => gestureTable("phone")],
	["Start-up (Lighthouse mobile)", startupTable], ["Code, build and install", codeTable]
];
for (const [heading, makeTable] of sections) {
	try { console.log(`### ${heading}\n\n${makeTable()}\n`); } catch { console.log(`### ${heading}\n\n(not measured yet)\n`); }
}
