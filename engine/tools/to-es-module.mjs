// Turns Haxe's JavaScript output (a classic script) into an ES module.
//
// Haxe wraps everything in one function and hands it the object to put
// @:expose'd classes on: `exports` under Node, `window` in a browser.
// Bundlers (Vite, the Angular CLI) see that `exports` and may treat the
// file as CommonJS, and a browser would leak the classes onto window.
// So we hand the function a private object instead, and export from it.
//
// Usage: node tools/to-es-module.mjs <haxe output> <es module>

import { readFileSync, writeFileSync } from "node:fs";

/** The expression Haxe passes in as the exports target, exactly as it writes it. */
const HAXE_EXPORTS_TARGET =
	'typeof exports != "undefined" ? exports : typeof window != "undefined" ? window : typeof self != "undefined" ? self : this';

const PRIVATE_EXPORTS = "$hx_module_exports";

/** Every top-level name Haxe exposes, e.g. `$hx_exports["DrumMachine"] = …`. */
function findExposedNames(haxeOutput) {
	const exposures = haxeOutput.matchAll(/\$hx_exports\["(\w+)"\]\s*=/g);
	return [...new Set([...exposures].map((match) => match[1]))];
}

/** Points Haxe's wrapper at our private object; fails loudly if Haxe changes its output. */
function redirectExports(haxeOutput) {
	if (!haxeOutput.includes(HAXE_EXPORTS_TARGET)) {
		throw new Error("Haxe output has an unexpected shape: exports target not found");
	}
	return haxeOutput.replace(HAXE_EXPORTS_TARGET, PRIVATE_EXPORTS);
}

/** The finished module: a private exports object, Haxe's code, then real exports. */
function toEsModule(haxeOutput) {
	const names = findExposedNames(haxeOutput);
	const exportLines = names.map((name) => `export const ${name} = ${PRIVATE_EXPORTS}.${name};`);
	return [`const ${PRIVATE_EXPORTS} = {};`, redirectExports(haxeOutput), ...exportLines, ""].join("\n");
}

const [haxeOutputPath, modulePath] = process.argv.slice(2);
writeFileSync(modulePath, toEsModule(readFileSync(haxeOutputPath, "utf8")));
