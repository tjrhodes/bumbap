// Script size of every build, minified and gzipped the same way (esbuild, gzip -9), and of the
// parts every build shares (Tone.js, the engine), so each framework's own share can be read off.
//
// Run from tests/, after building the engine and the apps:  node measure-sizes.mjs

import { build } from "esbuild";
import { readdirSync, readFileSync } from "node:fs";
import { gzipSync } from "node:zlib";
import { fileURLToPath } from "node:url";
import { round, saveResults } from "./measure/lab.mjs";

const REPO = fileURLToPath(new URL("..", import.meta.url));
const gzipped = (bytes) => gzipSync(bytes, { level: 9 }).length;
const kilobytes = (bytes) => `${(bytes / 1024).toFixed(1)} kB`.padStart(9);

/** One file or snippet, bundled and minified as a browser would get it. */
async function minified(entry) {
	const source = entry.code ? { stdin: { contents: entry.code, resolveDir: `${REPO}engine` } } : { entryPoints: [entry.file] };
	const result = await build({ ...source, bundle: true, minify: true, write: false, format: "esm", logLevel: "silent" });
	return result.outputFiles[0].contents;
}

/** Every script a Vite or Angular build wrote (already minified by its own tooling). */
function scriptsIn(folder) {
	return readdirSync(folder).filter((name) => name.endsWith(".js")).reduce((sum, name) => sum + gzipped(readFileSync(`${folder}/${name}`)), 0);
}

/** Each build's whole page of scripts (Haxe's page also loads Tone.js on its own, so it is added). */
async function pageTotals(tone) {
	return {
		haxe: gzipped(await minified({ file: `${REPO}apps/haxe/dist/app.js` })) + tone,
		react: scriptsIn(`${REPO}apps/react/dist/assets`),
		vue: scriptsIn(`${REPO}apps/vue/dist/assets`),
		angular: scriptsIn(`${REPO}apps/angular/dist`)
	};
}

async function measure() {
	const tone = gzipped(await minified({ code: 'import * as Tone from "tone"; window.Tone = Tone;' }));
	const engine = gzipped(await minified({ file: `${REPO}engine/dist/drum-engine.js` }));
	console.log(`Shared by every build: Tone.js ${kilobytes(tone)}, engine ${kilobytes(engine)}`);
	const results = {};
	for (const [name, total] of Object.entries(await pageTotals(tone))) {
		console.log(`${name.padEnd(8)} page ${kilobytes(total)}   UI + framework ${kilobytes(total - tone - engine)}`);
		results[name] = { pageKB: round(total / 1024), ownKB: round((total - tone - engine) / 1024) };
	}
	saveResults("size", { sharedKB: { tone: round(tone / 1024), engine: round(engine / 1024) }, results });
}

measure();
