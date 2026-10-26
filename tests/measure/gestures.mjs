// Gesture cost (SPEC.md §6): main-thread time per pointer move while dragging the tempo knob and
// a key's level, on desktop and on the slowed "phone". Every move changes the value, so every move
// goes the whole way round: gesture → engine → new snapshot → the build redraws.
//
// Run from tests/, after building everything:  node measure/gestures.mjs [build …]

import { BUILDS, DEVICES, launchBrowser, mainThreadTime, median, openBuild, saveResults, startServer, timeEach } from "./lab.mjs";

const MOVES = 400;
const PIXELS_PER_MOVE = 4;
const SWING_PX = 40;   // the pointer goes back and forth over this distance, so values never hit a limit
const RUNS = Number(process.env.RUNS ?? 3);

/** What gets dragged, which attribute shows its value, and which way the drag goes. */
const TARGETS = {
	knob: { selector: "#tempo", index: 0, shows: "aria-valuenow", direction: -1 },
	key: { selector: ".dm-key", index: 0, shows: "aria-label", direction: 1 }
};

/** Pointer offsets that go out to SWING_PX and back again, over and over. */
const offsetAt = (move) => {
	const along = (move * PIXELS_PER_MOVE) % (SWING_PX * 2);
	return along <= SWING_PX ? along : SWING_PX * 2 - along;
};

/** Runs inside the page: counts how often the dragged thing's shown value changes. */
function countChanges([selector, index, attribute]) {
	window.bumbapChanges = 0;
	const target = document.querySelectorAll(selector)[index];
	new MutationObserver((changes) => window.bumbapChanges += changes.length).observe(target, { attributeFilter: [attribute] });
}

async function dragBackAndForth(page, target) {
	const element = page.locator(target.selector).nth(target.index);
	await element.scrollIntoViewIfNeeded();   // on a phone the keys start below the fold
	const box = await element.boundingBox();
	const [x, y] = [box.x + box.width / 2, box.y + box.height / 2];
	await page.mouse.move(x, y);
	await page.mouse.down();
	for (let move = 1; move <= MOVES; move++) await page.mouse.move(x, y + target.direction * offsetAt(move));
	await page.mouse.up();
}

async function dragOnce(browser, build, device, targetName) {
	const { page, devtools } = await openBuild(browser, build, device);
	const target = TARGETS[targetName];
	await page.evaluate(countChanges, [target.selector, target.index, target.shows]);
	await page.waitForTimeout(500);   // let the opening work finish before measuring
	const before = await mainThreadTime(devtools);
	await dragBackAndForth(page, target);
	const after = await mainThreadTime(devtools);
	const changes = await page.evaluate(() => window.bumbapChanges);
	await page.close();
	return { perMoveMs: timeEach(before, after, MOVES), valueChanges: changes, moves: MOVES };
}

async function drag(browser, build, device, targetName) {
	const runs = [];
	for (let run = 0; run < RUNS; run++) runs.push(await dragOnce(browser, build, device, targetName));
	const middle = runs.sort((a, b) => a.perMoveMs.busy - b.perMoveMs.busy)[Math.floor(runs.length / 2)];
	console.log(`${build.padEnd(9)} ${device.padEnd(7)} ${targetName.padEnd(4)} busy ${middle.perMoveMs.busy} ms/move, script ${middle.perMoveMs.script}, ${middle.valueChanges} changes in ${MOVES} moves`);
	return { ...middle, allRunsBusyMs: runs.map((each) => each.perMoveMs.busy), medianOfRuns: median(runs.map((each) => each.perMoveMs.busy)) };
}

async function measureAll(builds) {
	const server = await startServer();
	const browser = await launchBrowser();
	const results = {};
	try {
		for (const device of Object.keys(DEVICES)) for (const build of builds) for (const target of Object.keys(TARGETS)) {
			((results[build] ??= {})[device] ??= {})[target] = await drag(browser, build, device, target);
		}
	} finally {
		await browser.close();
		server.kill();
	}
	saveResults("gestures", { moves: MOVES, pixelsPerMove: PIXELS_PER_MOVE, runs: RUNS, results });
}

const panelBuilds = Object.keys(BUILDS).filter((build) => build !== "baseline");
measureAll(process.argv.length > 2 ? process.argv.slice(2) : panelBuilds);
