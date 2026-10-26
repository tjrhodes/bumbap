// The bümbap panel as a person (or a test) sees it: found by role, label and
// the class names of the DOM contract (SPEC.md §4), never by framework internals,
// so the same tests run against every build.

import { expect, type Locator, type Page } from "@playwright/test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const TONE_ON_CDN = "https://cdn.jsdelivr.net/npm/tone@15.1.22/build/Tone.js";
const TONE_LOCAL = fileURLToPath(new URL("../engine/node_modules/tone/build/Tone.js", import.meta.url));

/** Which segments a character lights (a top … g middle); the display is checked against this. */
const LIT_SEGMENTS: Record<string, string> = {
	"0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg", "5": "acdfg", "6": "acdefg",
	"7": "abc", "8": "abcdefg", "9": "abcdfg", " ": "", "-": "g",
	A: "abcefg", d: "bcdeg", E: "adefg", r: "eg", L: "def", S: "acdfg", u: "cde", n: "ceg", P: "abefg"
};

export class Panel {
	constructor(readonly page: Page) {}

	/** Opens the build (optionally with a pattern code) and waits until it can play. */
	async open(code = "") {
		await this.page.route(TONE_ON_CDN, (route) => route.fulfill({ body: readFileSync(TONE_LOCAL), contentType: "text/javascript" }));
		await this.page.goto(code ? `#${code}` : "");
		await expect(this.play).toBeEnabled({ timeout: 15_000 });
	}

	get play() { return this.page.locator(".dm-play-unit button"); }
	get clear() { return this.page.locator(".dm-clear-unit button"); }
	get status() { return this.page.getByRole("status"); }

	knob(id: string) { return this.page.locator(`#${id}`); }
	pill(name: string) { return this.page.locator(".dm-pill", { hasText: new RegExp(`^${name}$`, "i") }); }
	mute(name: string) { return this.page.getByRole("button", { name: `Mute ${name}`, exact: true }); }
	/** Keys and flip tabs are counted from 1, as printed on the panel. */
	key(number: number) { return this.page.locator(".dm-key").nth(number - 1); }
	flip(number: number) { return this.page.locator(".dm-flip").nth(number - 1); }
	dialSlot(slot: number) { return this.page.locator(".dm-dials .dm-unit").nth(slot); }

	/** Drags from the middle of an element by (dx, dy) pixels, in small moves like a hand. */
	async drag(target: Locator, dx: number, dy: number) {
		const box = (await target.boundingBox())!;
		const [x, y] = [box.x + box.width / 2, box.y + box.height / 2];
		await this.page.mouse.move(x, y);
		await this.page.mouse.down();
		await this.page.mouse.move(x + dx, y + dy, { steps: 8 });
		await this.page.mouse.up();
	}

	/** Waits until the seven-segment display shows this text (right-aligned, four digits). */
	async expectDisplay(text: string) {
		const expected = text.padStart(4).slice(-4).split("").map((character) => LIT_SEGMENTS[character]);
		await expect.poll(() => this.litSegments()).toEqual(expected);
	}

	/** Each digit's lit segments, sorted, e.g. ["", "bc", "abcdef", "abcdef"] for 100. */
	litSegments() {
		return this.page.locator(".dm-display g").evaluateAll((digits) =>
			digits.map((digit) => [...digit.querySelectorAll(".dm-seg.is-lit")].map((segment) => segment.getAttribute("data-segment")).sort().join("")));
	}
}
