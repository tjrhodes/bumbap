// What every bümbap build must do. The prototype is the reference; each
// framework build is done when this whole file passes against it.

import { expect, test as base } from "@playwright/test";
import { readFileSync } from "node:fs";
import { Panel } from "./panel";

/** A link as bümbap 1 wrote it: the starter beat with the kick on step 3 too. */
const ONE_PATTERN_LINK = "5.100.50.0.0.044564g055g055g064g0_901064g064g032g0_100055g0_555555g032g055g032g055g032g055g032g0"
	+ "_400055g0_0000_0000_208032g055g0.5050505050505050.00000000.c6412c6422c6400c6400c6420c6420c6420c6400";

const test = base.extend<{ panel: Panel; consoleErrors: string[] }>({
	consoleErrors: async ({ page }, use) => {
		const errors: string[] = [];
		page.on("pageerror", (error) => errors.push(error.message));
		page.on("console", (message) => message.type() === "error" && errors.push(message.text()));
		await use(errors);
	},
	panel: async ({ page }, use) => {
		const panel = new Panel(page);
		await panel.open();
		await use(panel);
	}
});

test.describe("starting", () => {
	test("opens on the starter beat, ready to play", async ({ panel }) => {
		await expect(panel.status).toHaveText(/ready/i);
		await expect(panel.pill("Kick")).toHaveAttribute("aria-pressed", "true");
		await expect(panel.key(1)).toHaveAttribute("aria-pressed", "true");
		await expect(panel.key(2)).toHaveAttribute("aria-pressed", "false");
		await panel.expectDisplay("100");
	});

	test("shows no errors", async ({ panel, consoleErrors }) => {
		await panel.play.click();
		await panel.page.waitForTimeout(500);
		expect(consoleErrors).toEqual([]);
	});
});

test.describe("transport", () => {
	test("Play runs the playhead; Stop clears it", async ({ panel, page }) => {
		await panel.play.click();
		await expect(panel.play).toHaveAttribute("aria-pressed", "true");
		await expect(page.locator(".dm-key.is-current")).toHaveCount(1);
		await panel.play.click();
		await expect(panel.play).toHaveAttribute("aria-pressed", "false");
		await expect(page.locator(".dm-key.is-current")).toHaveCount(0);
	});

	test("Clear empties every step", async ({ panel, page }) => {
		await panel.clear.click();
		await expect(page.locator('.dm-key[aria-pressed="true"]')).toHaveCount(0);
		await panel.pill("Closed hat").click();
		await expect(page.locator('.dm-key[aria-pressed="true"]')).toHaveCount(0);
	});
});

test.describe("steps", () => {
	test("tapping a key switches its step at level 85", async ({ panel }) => {
		await panel.key(2).click();
		await expect(panel.key(2)).toHaveAttribute("aria-pressed", "true");
		await expect(panel.key(2)).toHaveAttribute("aria-label", "Kick step 2, level 85, nudge 0");
		await panel.key(2).click();
		await expect(panel.key(2)).toHaveAttribute("aria-pressed", "false");
	});

	test("dragging a key up sets its level, shown on the display", async ({ panel }) => {
		await panel.drag(panel.key(3), 0, -40);
		await expect(panel.key(3)).toHaveAttribute("aria-label", /level 100/);
		await panel.expectDisplay("u100");
	});

	test("dragging a key sideways nudges it, and the key moves a hair", async ({ panel }) => {
		const before = (await panel.key(4).boundingBox())!.x;
		await panel.drag(panel.key(4), 24, 0);
		await expect(panel.key(4)).toHaveAttribute("aria-label", /nudge 8/);
		await panel.expectDisplay("n  8");
		expect((await panel.key(4).boundingBox())!.x).toBeGreaterThan(before);
	});

	test("the flip tab reverses a step", async ({ panel }) => {
		await panel.flip(5).click();
		await expect(panel.flip(5)).toHaveAttribute("aria-pressed", "true");
		await expect(panel.key(5)).toHaveAttribute("aria-label", /reversed/);
		await expect(panel.key(5)).toHaveClass(/is-reversed/);
	});

	test("arrow keys on a focused key change its level and nudge", async ({ panel }) => {
		await panel.key(1).focus();
		await panel.page.keyboard.press("ArrowDown");
		await panel.page.keyboard.press("ArrowRight");
		await expect(panel.key(1)).toHaveAttribute("aria-label", "Kick step 1, level 95, nudge 1");
	});
});

test.describe("parts", () => {
	test("selecting a part shows its steps", async ({ panel }) => {
		await panel.pill("Snare").click();
		await expect(panel.pill("Snare")).toHaveAttribute("aria-pressed", "true");
		await expect(panel.key(5)).toHaveAttribute("aria-label", /^Snare step 5, level 100/);
	});

	test("keys 1–8 select parts", async ({ panel }) => {
		await panel.page.keyboard.press("4");
		await expect(panel.pill("Closed hat")).toHaveAttribute("aria-pressed", "true");
	});

	test("the M tab mutes a part without selecting it", async ({ panel }) => {
		await panel.mute("Clap").click();
		await expect(panel.mute("Clap")).toHaveAttribute("aria-pressed", "true");
		await expect(panel.pill("Clap")).toHaveClass(/is-muted/);
		await expect(panel.pill("Kick")).toHaveAttribute("aria-pressed", "true");
	});

	test("the 808 slots take the selected part's knobs", async ({ panel }) => {
		await expect(panel.dialSlot(0)).toContainText("Tone");
		await expect(panel.dialSlot(1)).toContainText("Decay");
		await panel.pill("Clap").click();
		await expect(panel.knob("dial-0")).toHaveAttribute("aria-disabled", "true");
		await expect(panel.dialSlot(1)).toHaveClass(/is-unused/);
		await panel.pill("Open hat").click();
		await expect(panel.dialSlot(0)).toContainText("Decay");
		await expect(panel.dialSlot(1)).toHaveClass(/is-unused/);
	});
});

test.describe("knobs", () => {
	test("work from the keyboard", async ({ panel }) => {
		await panel.knob("tempo").focus();
		for (const _ of [1, 2, 3]) await panel.page.keyboard.press("ArrowUp");
		await expect(panel.knob("tempo")).toHaveAttribute("aria-valuenow", "103");
		await panel.expectDisplay("103");
		await panel.page.keyboard.press("Home");
		await expect(panel.knob("tempo")).toHaveAttribute("aria-valuenow", "60");
	});

	test("turn when dragged, and show their value", async ({ panel }) => {
		await panel.drag(panel.knob("swing"), 0, -60);
		await expect(panel.knob("swing")).not.toHaveAttribute("aria-valuenow", "50");
		await panel.expectDisplay(`S ${await panel.knob("swing").getAttribute("aria-valuenow")}`);
	});

	test("an 808 knob shows the recording's setting", async ({ panel }) => {
		await panel.knob("dial-1").focus();
		await panel.page.keyboard.press("End");
		await panel.expectDisplay("2510");
	});

	test("part knobs belong to the selected part", async ({ panel }) => {
		await panel.knob("pitch").focus();
		await panel.page.keyboard.press("ArrowUp");
		await panel.expectDisplay("P  1");
		await panel.pill("Snare").click();
		await expect(panel.knob("pitch")).toHaveAttribute("aria-valuenow", "0");
	});
});

test.describe("sharing", () => {
	test("the pattern lives in the address and comes back from it", async ({ panel, page, browser }) => {
		await panel.key(2).click();
		await panel.knob("tempo").focus();
		await page.keyboard.press("End");
		await expect.poll(() => page.evaluate(() => location.hash)).toMatch(/^#6\.200\./);
		const code = (await page.evaluate(() => location.hash)).slice(1);
		const second = new Panel(await browser.newPage());
		await second.open(code);
		await expect(second.key(2)).toHaveAttribute("aria-pressed", "true");
		await expect(second.knob("tempo")).toHaveAttribute("aria-valuenow", "200");
	});

	test("Share copies the link to the beat as it is now, and says so for a moment", async ({ panel, page }) => {
		await page.context().grantPermissions(["clipboard-read", "clipboard-write"]);
		await panel.key(2).click();
		await page.getByRole("button", { name: "Share this beat" }).click();
		await expect(page.locator(".dm-share-note")).toHaveText("Link copied");
		expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(page.url());
		await expect(page.locator(".dm-share-note")).toHaveText("", { timeout: 5_000 });
	});
});

test.describe("the sequence (v2)", () => {
	test("eight pattern buttons: pattern 1 on the keys and in the sequence, the others empty", async ({ panel }) => {
		await expect(panel.page.locator(".dm-pattern")).toHaveCount(8);
		await expect(panel.pattern(1)).toHaveAttribute("aria-current", "true");
		await expect(panel.pattern(1)).toHaveAttribute("aria-pressed", "true");
		await expect(panel.pattern(1)).toHaveAttribute("aria-label", "Pattern 1, on the keys");
		await expect(panel.pattern(2)).toHaveAttribute("aria-label", "Pattern 2, empty");
		await expect(panel.pattern(2)).toHaveAttribute("aria-pressed", "false");
	});

	test("each pattern keeps its own steps", async ({ panel }) => {
		await panel.pattern(2).click();
		await expect(panel.key(1)).toHaveAttribute("aria-pressed", "false");
		await panel.key(3).click();
		await panel.pattern(1).click();
		await expect(panel.key(1)).toHaveAttribute("aria-pressed", "true");
		await expect(panel.key(3)).toHaveAttribute("aria-pressed", "false");
		await panel.pattern(2).click();
		await expect(panel.key(3)).toHaveAttribute("aria-pressed", "true");
		await expect(panel.pattern(2)).toHaveClass(/is-used/);
	});

	test("shift-click adds a pattern to the sequence, and the sequence plays in turn", async ({ panel }) => {
		await panel.pattern(3).click({ modifiers: ["Shift"] });
		await expect(panel.pattern(3)).toHaveAttribute("aria-pressed", "true");
		await expect(panel.pattern(1)).toHaveAttribute("aria-pressed", "true");
		await panel.knob("tempo").focus();
		await panel.page.keyboard.press("End");
		await panel.play.click();
		await expect(panel.pattern(3)).toHaveClass(/is-playing/, { timeout: 4_000 });
		await expect(panel.pattern(1)).toHaveClass(/is-playing/, { timeout: 4_000 });
		await expect(panel.pattern(1)).toHaveAttribute("aria-current", "true");
	});

	test("while playing, a new sequence blinks its first pattern until the end of the bar", async ({ panel }) => {
		await panel.play.click();
		await panel.tool("select").click();
		await panel.pattern(2).click();
		await expect(panel.pattern(2)).toHaveClass(/is-next/);
		await expect(panel.pattern(1)).toHaveClass(/is-playing/);
		await expect(panel.pattern(2)).toHaveClass(/is-playing/, { timeout: 4_000 });
		await expect(panel.pattern(2)).not.toHaveClass(/is-next/);
		await expect(panel.pattern(1)).toHaveAttribute("aria-current", "true");
	});

	test("tapping a pattern while the sequence plays edits it, and the sequence plays on", async ({ panel, page }) => {
		await panel.play.click();
		await expect(page.locator(".dm-key.is-current")).toHaveCount(1);
		await panel.pattern(3).click();
		await expect(panel.pattern(3)).toHaveAttribute("aria-current", "true");
		await expect(panel.pattern(1)).toHaveClass(/is-playing/);
		await expect(panel.key(1)).toHaveAttribute("aria-pressed", "false");
		await expect(page.locator(".dm-key.is-current")).toHaveCount(0);
		await panel.pattern(1).click();
		await expect(page.locator(".dm-key.is-current")).toHaveCount(1);
	});

	test("dragging one button onto another copies the pattern", async ({ panel }) => {
		await panel.dragOnto(panel.pattern(1), panel.pattern(4));
		await expect(panel.pattern(4)).toHaveAttribute("aria-label", "Pattern 4");
		await expect(panel.pattern(1)).toHaveAttribute("aria-current", "true");
		await panel.pattern(4).click();
		await expect(panel.key(1)).toHaveAttribute("aria-pressed", "true");
	});

	test("on a touch screen, holding one button and tapping others sequences them", async ({ panel }) => {
		await panel.touch(1, "down", panel.pattern(2));
		await panel.touch(2, "down", panel.pattern(5));
		await panel.touch(2, "up", panel.pattern(5));
		await panel.touch(1, "up", panel.pattern(2));
		for (const [number, chained] of [[1, "false"], [2, "true"], [5, "true"]] as const)
			await expect(panel.pattern(number)).toHaveAttribute("aria-pressed", chained);
		await expect(panel.pattern(1)).toHaveAttribute("aria-current", "true");
	});

	test("a link carries every pattern and the sequence; a bümbap 1 link opens as pattern 1", async ({ panel, page, browser }) => {
		await panel.pattern(2).click();
		await panel.key(5).click();
		await panel.pattern(6).click({ modifiers: ["Shift"] });
		const second = new Panel(await browser.newPage());
		await second.open((await page.evaluate(() => location.hash)).slice(1));
		await expect(second.pattern(6)).toHaveAttribute("aria-pressed", "true");
		await expect(second.pattern(2)).toHaveAttribute("aria-current", "true");
		await expect(second.key(5)).toHaveAttribute("aria-pressed", "true");
		const third = new Panel(await browser.newPage());
		await third.open(ONE_PATTERN_LINK);
		await expect(third.key(3)).toHaveAttribute("aria-pressed", "true");
		await expect(third.pattern(2)).toHaveAttribute("aria-label", "Pattern 2, empty");
	});
});

test.describe("the sequence's tools (v2)", () => {
	test("Select: patterns tapped in order make the sequence, each showing its places", async ({ panel }) => {
		await panel.tool("select").click();
		await expect(panel.tool("select")).toHaveAttribute("aria-pressed", "true");
		for (const number of [3, 1, 3]) await panel.pattern(number).click();
		await expect(panel.pattern(3).locator(".dm-pattern-places")).toHaveText("1 3");
		await expect(panel.pattern(1).locator(".dm-pattern-places")).toHaveText("2");
		await expect(panel.pattern(1)).toHaveAttribute("aria-current", "true");
		await panel.tool("select").click();
		await expect(panel.pattern(3).locator(".dm-pattern-places")).toHaveText("");
		await expect(panel.pattern(3)).toHaveAttribute("aria-pressed", "true");
	});

	test("with Select on, Clear lights up and clears the sequence", async ({ panel }) => {
		await panel.tool("select").click();
		for (const number of [3, 2]) await panel.pattern(number).click();
		await expect(panel.tool("clear")).toHaveAttribute("aria-label", "Clear the sequence");
		await expect(panel.tool("clear")).toHaveCSS("box-shadow", /rgba\(233, 201, 58/);
		await panel.tool("clear").click();
		await expect(panel.pattern(3)).toHaveAttribute("aria-pressed", "false");
		await expect(panel.pattern(1)).toHaveAttribute("aria-pressed", "true");
		await expect(panel.tool("select")).toHaveAttribute("aria-pressed", "true");
		await panel.pattern(6).click();
		await expect(panel.pattern(1)).toHaveAttribute("aria-pressed", "false");
		await expect(panel.pattern(6).locator(".dm-pattern-places")).toHaveText("1");
		await panel.tool("select").click();
		await expect(panel.tool("clear")).toHaveAttribute("aria-label", "Clear a pattern");
	});

	test("Copy: the first tap picks a pattern, the second copies it there", async ({ panel }) => {
		await panel.tool("copy").click();
		await panel.pattern(1).click();
		await expect(panel.pattern(1)).toHaveClass(/is-copy-source/);
		await expect(panel.page.locator(".dm-pattern-hint .for-mouse")).toHaveText("Now tap where pattern 1 goes");
		await panel.pattern(5).click();
		await expect(panel.pattern(5)).toHaveAttribute("aria-label", "Pattern 5");
		await expect(panel.tool("copy")).toHaveAttribute("aria-pressed", "false");
		await expect(panel.pattern(1)).toHaveAttribute("aria-current", "true");
	});

	test("Clear: a tap empties that pattern", async ({ panel }) => {
		await panel.tool("clear").click();
		await panel.pattern(1).click();
		await expect(panel.key(1)).toHaveAttribute("aria-pressed", "false");
		await expect(panel.pattern(1)).toHaveAttribute("aria-label", "Pattern 1, on the keys, empty");
		await expect(panel.tool("clear")).toHaveAttribute("aria-pressed", "false");
	});
});

test.describe("getting a beat out", () => {
	test("Copy takes the part's steps; Paste puts them into another part", async ({ panel, page }) => {
		const paste = page.locator(".dm-steps-head button", { hasText: "Paste" });
		await expect(paste).toBeDisabled();
		const kickSteps = await page.locator(".dm-key").evaluateAll((keys) => keys.map((key) => key.getAttribute("aria-pressed")));
		await page.locator(".dm-steps-head button", { hasText: "Copy" }).click();
		await panel.pill("Clap").click();
		await expect(panel.key(1)).toHaveAttribute("aria-pressed", "false");
		await paste.click();
		await expect.poll(() => page.locator(".dm-key").evaluateAll((keys) => keys.map((key) => key.getAttribute("aria-pressed")))).toEqual(kickSteps);
	});

	test("Download saves the sequence as a WAV loop, one pass long", async ({ panel, page }) => {
		const [download] = await Promise.all([page.waitForEvent("download"), page.locator(".dm-save-unit button").click()]);
		expect(download.suggestedFilename()).toBe("bumbap-100bpm-1bar.wav");
		const file = readFileSync((await download.path())!);
		expect(file.subarray(0, 4).toString()).toBe("RIFF");
		const seconds = file.readUInt32LE(40) / 4 / file.readUInt32LE(24);
		expect(seconds).toBeCloseTo(2.4, 2);   // one bar at 100 BPM
		await expect(panel.status).toHaveText(/ready/i);
	});
});

test.describe("layout", () => {
	test("fits a phone without sideways scrolling", async ({ page }) => {
		await page.setViewportSize({ width: 390, height: 844 });
		const panel = new Panel(page);
		await panel.open();
		expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
		expect((await panel.key(16).boundingBox())!.width).toBeGreaterThan(28);
	});
});
