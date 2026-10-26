// What every bümbap build must do. The prototype is the reference; each
// framework build is done when this whole file passes against it.

import { expect, test as base } from "@playwright/test";
import { Panel } from "./panel";

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
		await expect.poll(() => page.evaluate(() => location.hash)).toMatch(/^#5\.200\./);
		const code = (await page.evaluate(() => location.hash)).slice(1);
		const second = new Panel(await browser.newPage());
		await second.open(code);
		await expect(second.key(2)).toHaveAttribute("aria-pressed", "true");
		await expect(second.knob("tempo")).toHaveAttribute("aria-valuenow", "200");
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
