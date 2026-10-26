// Code, build and install figures (SPEC.md §6): lines of UI code (the shared engine and
// stylesheet are not counted), files, a clean build's time (the middle of three), and how much
// each build installs. Run with Node 22.22+ on the PATH (the Angular CLI needs it).
//
// Run from tests/:  HAXE=/path/to/haxe node measure/code.mjs

import { execSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { median, round, saveResults } from "./lab.mjs";

const APPS = fileURLToPath(new URL("../../apps/", import.meta.url));
const ENGINE = fileURLToPath(new URL("../../engine/", import.meta.url));
const UI_SOURCE = /\.(hx|ts|tsx|vue|html)$/;
const BUILD_RUNS = 3;

/** How each app builds from clean, and what it installs (the Haxe build uses only the engine's packages). */
const APP_BUILDS = {
	haxe: { build: `${process.env.HAXE ?? "haxe"} build.hxml`, installs: `${ENGINE}node_modules` },
	react: { build: "npm run build", installs: `${APPS}react/node_modules` },
	vue: { build: "npm run build", installs: `${APPS}vue/node_modules` },
	angular: { build: "npm run build", installs: `${APPS}angular/node_modules` }
};

/** Every file under a folder, skipping what tools make. */
function filesUnder(folder) {
	return readdirSync(folder, { withFileTypes: true }).flatMap((entry) => {
		const path = join(folder, entry.name);
		if (entry.isDirectory()) return ["node_modules", "dist", ".angular"].includes(entry.name) ? [] : filesUnder(path);
		return [path];
	});
}

/** Lines that hold code: not blank, not only a comment. */
function codeLines(file) {
	const isComment = (line) => /^(\/\/|\/\*|\*|<!--|#)/.test(line);
	return readFileSync(file, "utf8").split("\n").map((line) => line.trim()).filter((line) => line && !isComment(line)).length;
}

/** The app's own UI source: src/ plus its page (Angular's page sits inside src/ already). */
function uiSource(app) {
	const page = join(APPS, app, "index.html");
	const sources = filesUnder(join(APPS, app, "src")).filter((file) => UI_SOURCE.test(file));
	return existsSync(page) ? [...sources, page] : sources;
}

const megabytes = (folder) => round(filesUnder(folder).reduce((sum, file) => sum + statSync(file).size, 0) / 1024 / 1024);
const packageCount = (folder) => readdirSync(folder).flatMap((name) => (name.startsWith("@") ? readdirSync(join(folder, name)) : name.startsWith(".") ? [] : [name])).length;

/** Seconds for a build from clean (outputs and caches removed first). */
function cleanBuildSeconds(app) {
	for (const made of ["dist", ".angular"]) rmSync(join(APPS, app, made), { recursive: true, force: true });
	const started = performance.now();
	execSync(APP_BUILDS[app].build, { cwd: join(APPS, app), stdio: "ignore" });
	return (performance.now() - started) / 1000;
}

function measure(app) {
	const files = uiSource(app);
	const buildSeconds = round(median(Array.from({ length: BUILD_RUNS }, () => cleanBuildSeconds(app))));
	const installs = APP_BUILDS[app].installs;
	const figures = { uiFiles: files.length, uiCodeLines: files.reduce((sum, file) => sum + codeLines(file), 0), buildSeconds, installMB: megabytes(installs), topLevelPackages: packageCount(installs) };
	console.log(app.padEnd(8), JSON.stringify(figures));
	return figures;
}

saveResults("code", Object.fromEntries(Object.keys(APP_BUILDS).map((app) => [app, measure(app)])));
