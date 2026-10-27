// What adding one feature cost each front end: version 2's eight patterns and their chain, against
// bümbap 1.0. Lines of front-end code added and removed (from git), and code shipped (from size.json,
// before and after). The engine's share is counted once, as every build gets it.
//
// Run from tests/, after measure-sizes.mjs, in a clone with history:  node measure/feature-cost.mjs

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { round, saveResults } from "./lab.mjs";

/** bümbap 1.0, as live on tomrhodes.it (tagged v1.0 where tags could be pushed). */
const VERSION_1 = "a28930d";
const FRONT_ENDS = {
	haxe: ["apps/haxe/src", "apps/haxe/index.html"],
	react: ["apps/react/src"],
	vue: ["apps/vue/src"],
	angular: ["apps/angular/src"]
};
const SHARED = { engine: ["engine/src"], engineTests: ["engine/test"], browserTests: ["tests/bumbap.spec.ts", "tests/panel.ts"], stylesheet: ["shared"] };

const git = (...args) => execFileSync("git", args, { cwd: new URL("../..", import.meta.url), encoding: "utf8" });
const sum = (rows, column) => rows.reduce((total, row) => total + row[column], 0);

/** Lines added and removed in these paths since version 1, and how many files they touched. */
function linesChanged(paths) {
	const rows = git("diff", "--numstat", VERSION_1, "--", ...paths).trim().split("\n").filter(Boolean);
	const counts = rows.map((row) => row.split("\t").slice(0, 2).map(Number));
	return { added: sum(counts, 0), removed: sum(counts, 1), files: counts.length };
}

function sizes() {
	const before = JSON.parse(git("show", `${VERSION_1}:tests/measure/results/size.json`));
	const now = JSON.parse(readFileSync(new URL("results/size.json", import.meta.url), "utf8"));
	return { before: before.results, now: now.results, engineKB: round(now.sharedKB.engine - before.sharedKB.engine) };
}

function measure() {
	const { before, now, engineKB } = sizes();
	const builds = Object.fromEntries(Object.entries(FRONT_ENDS).map(([build, paths]) =>
		[build, { lines: linesChanged(paths), ownKBAdded: round(now[build].ownKB - before[build].ownKB) }]));
	const shared = Object.fromEntries(Object.entries(SHARED).map(([part, paths]) => [part, linesChanged(paths)]));
	saveResults("feature-cost", { since: VERSION_1, engineKBAdded: engineKB, shared, results: builds });
	for (const [build, cost] of Object.entries(builds)) console.log(`${build.padEnd(8)} +${cost.lines.added} −${cost.lines.removed} lines, +${cost.ownKBAdded} kB`);
}

measure();
