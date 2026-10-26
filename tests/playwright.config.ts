// One test suite, one project per build. A build is tested once it has been
// built (its page exists); the prototype is the reference the others match.
//
// Run from tests/: npx playwright test            (every build that exists)
//                  npx playwright test --project=haxe

import { defineConfig, devices } from "@playwright/test";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";

const PORT = 4173;
const REPO_ROOT = fileURLToPath(new URL("..", import.meta.url));

/** Where each build's page is, relative to the repo root (and so to the server). */
const BUILDS: Record<string, string> = {
	prototype: "prototype/drum-preview.html",
	haxe: "apps/haxe/dist/index.html",
	react: "apps/react/dist/index.html",
	vue: "apps/vue/dist/index.html",
	angular: "apps/angular/dist/index.html"
};

const builtOnes = Object.entries(BUILDS).filter(([, page]) => existsSync(REPO_ROOT + page));

export default defineConfig({
	testDir: ".",
	timeout: 30_000,
	fullyParallel: true,
	workers: 4,
	reporter: [["list"]],
	webServer: { command: `node ../tools/serve.mjs ${PORT}`, port: PORT, reuseExistingServer: true },
	use: {
		...devices["Desktop Chrome"],
		launchOptions: { args: ["--autoplay-policy=no-user-gesture-required"] }
	},
	projects: builtOnes.map(([name, page]) => ({ name, use: { baseURL: `http://localhost:${PORT}/${page}` } }))
});
