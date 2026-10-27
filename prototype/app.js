"use strict";
/* The bümbap panel: one part's sixteen steps at a time, laid out like a
   small hardware groovebox. It talks to the shared engine only through the
   engine's public API (getState, subscribe, onStep and the edit methods). */

/* ── Embedded samples ─────────────────────────────────────────────────────────────── */

const SAMPLES_FOLDER = "samples/";

/** Decodes one embedded WAV (base64) into the bytes Tone.js would have downloaded. */
function sampleBytes(base64) {
	const text = atob(base64);
	const bytes = new Uint8Array(text.length);
	for (let index = 0; index < text.length; index++) bytes[index] = text.charCodeAt(index);
	return bytes.buffer;
}

/** Tone.js fetches each sample by URL; requests for samples/<file> are answered from the page itself. */
function serveEmbeddedSamples() {
	const realFetch = window.fetch.bind(window);
	window.fetch = (url, options) => {
		const file = String(url).split(SAMPLES_FOLDER)[1];
		if (file in EMBEDDED_SAMPLES) return Promise.resolve(new Response(sampleBytes(EMBEDDED_SAMPLES[file])));
		return realFetch(url, options);
	};
}

/* ── Small helpers ────────────────────────────────────────────────────────────────── */

const element = (id) => document.getElementById(id);

/** Makes an HTML element with its class and attributes in one go. */
function create(tag, className, attributes = {}) {
	const made = document.createElement(tag);
	made.className = className;
	for (const [name, value] of Object.entries(attributes)) made.setAttribute(name, value);
	return made;
}

function createSvg(tag, attributes) {
	const made = document.createElementNS("http://www.w3.org/2000/svg", tag);
	for (const [name, value] of Object.entries(attributes)) made.setAttribute(name, value);
	return made;
}

/** Follows one pointer from press to release, calling onMove for every move in between. */
function trackPointer(target, downEvent, onMove) {
	target.setPointerCapture(downEvent.pointerId);
	const finish = () => {
		target.removeEventListener("pointermove", onMove);
		target.removeEventListener("pointerup", finish);
		target.removeEventListener("pointercancel", finish);
	};
	target.addEventListener("pointermove", onMove);
	target.addEventListener("pointerup", finish);
	target.addEventListener("pointercancel", finish);
}

/* ── Seven-segment display ────────────────────────────────────────────────────────── */
/* Segments are named the standard way: a top, b top right, c bottom right,
   d bottom, e bottom left, f top left, g middle. */

const DIGIT_COUNT = 4;
const SEGMENT_THICKNESS = 8;
const HOLD_MS = 1200;   // how long a turned value stays up before the tempo returns

/** Which segments light for each character the panel ever shows. */
const LIT_SEGMENTS = {
	"0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg", "5": "acdfg", "6": "acdefg",
	"7": "abc", "8": "abcdefg", "9": "abcdfg", " ": "", "-": "g",
	A: "abcefg", d: "bcdeg", E: "adefg", r: "eg", L: "def", S: "acdfg", u: "cde", n: "ceg", P: "abefg"
};

/** Each segment's centre line in a 50 × 90 digit: [x1, y1, x2, y2]. */
const SEGMENT_LINES = {
	a: [7, 5, 43, 5], b: [45, 7, 45, 43], c: [45, 47, 45, 83], d: [7, 85, 43, 85],
	e: [5, 47, 5, 83], f: [5, 7, 5, 43], g: [7, 45, 43, 45]
};

const display = { digits: [], restingText: "", holdTimer: 0 };

/** A segment is a long hexagon pointed at both ends, so neighbours meet at a mitre like LED glass. */
function segmentPoints([x1, y1, x2, y2]) {
	const half = SEGMENT_THICKNESS / 2;
	const [alongX, alongY] = y1 === y2 ? [half, 0] : [0, half];
	const [acrossX, acrossY] = y1 === y2 ? [0, half] : [half, 0];
	const corners = [[x1, y1], [x1 + alongX - acrossX, y1 + alongY - acrossY],
		[x2 - alongX - acrossX, y2 - alongY - acrossY], [x2, y2],
		[x2 - alongX + acrossX, y2 - alongY + acrossY], [x1 + alongX + acrossX, y1 + alongY + acrossY]];
	return corners.map((corner) => corner.join(",")).join(" ");
}

/** Draws four slanted digits with every segment present: unlit ones show faintly, as on real glass. */
function buildDisplay(svg) {
	return Array.from({ length: DIGIT_COUNT }, (_, index) => {
		const digit = createSvg("g", { transform: `translate(${22 + index * 56} 5) skewX(-7)` });
		for (const [name, line] of Object.entries(SEGMENT_LINES)) {
			digit.append(createSvg("polygon", { class: "dm-seg", "data-segment": name, points: segmentPoints(line) }));
		}
		svg.append(digit);
		return digit;
	});
}

/** Shows up to four characters, right-aligned like a calculator. */
function paintDisplay(text) {
	const characters = text.padStart(DIGIT_COUNT).slice(-DIGIT_COUNT);
	display.digits.forEach((digit, index) => {
		const lit = LIT_SEGMENTS[characters[index]] ?? "";
		for (const segment of digit.children) segment.classList.toggle("is-lit", lit.includes(segment.dataset.segment));
	});
}

/** What the display shows when nothing is being turned: the tempo, or the loading state. */
function showResting(text) {
	display.restingText = text;
	if (!display.holdTimer) paintDisplay(text);
}

/** A value being changed takes over the display for a moment, then the resting text returns. */
function showBriefly(text) {
	paintDisplay(text);
	clearTimeout(display.holdTimer);
	display.holdTimer = setTimeout(() => {
		display.holdTimer = 0;
		paintDisplay(display.restingText);
	}, HOLD_MS);
}

const RESTING_TEXT = { loading: "LoAd", failed: "Err" };
const restingText = (state) => RESTING_TEXT[state.status] ?? String(state.tempo);
/** One letter, then the number right-aligned: "S 66", "L100", "n -3". */
const labelled = (letter, value) => letter + String(value).padStart(DIGIT_COUNT - 1);

/** Changes text only if it differs: writing the same text still makes the browser redo the page's
    layout, which a framework would have skipped (measured: up to 10 ms per drag move on a phone). */
const setText = (target, text) => { if (target.textContent !== text) target.textContent = text; };

/* ── Knobs ────────────────────────────────────────────────────────────────────────── */
/* A knob is a slider in a round body: drag up or right to turn it up, scroll,
   or use the arrow keys. Double-click (double-tap) puts it back to its default. */

const KNOB_TRAVEL_PX = 160;        // dragging this far turns a knob from its minimum to its maximum
const KNOB_SWEEP_DEGREES = 270;    // from seven o'clock round to five o'clock
const KNOB_KEYS = { ArrowUp: 1, ArrowRight: 1, ArrowDown: -1, ArrowLeft: -1, PageUp: 10, PageDown: -10 };

const knobValue = (knob) => Number(knob.getAttribute("aria-valuenow"));

/** Wires one knob to a range from the engine and to what turning it should do. */
function makeKnob(knob, range, onTurn) {
	const turnTo = (value) => onTurn(range.clamp(value));
	knob.setAttribute("aria-valuemin", range.min);
	knob.setAttribute("aria-valuemax", range.max);
	knob.addEventListener("pointerdown", (event) => followKnobDrag(event, knob, range, turnTo));
	knob.addEventListener("wheel", (event) => {
		event.preventDefault();
		turnTo(knobValue(knob) - Math.sign(event.deltaY));
	}, { passive: false });
	knob.addEventListener("keydown", (event) => onKnobKey(event, knob, range, turnTo));
	knob.addEventListener("dblclick", () => turnTo(range.initial));
}

/** Turns the knob by how far the pointer has moved since it went down; up and right both mean more. */
function followKnobDrag(event, knob, range, turnTo) {
	const start = { x: event.clientX, y: event.clientY, value: knobValue(knob) };
	const unitsPerPixel = (range.max - range.min) / KNOB_TRAVEL_PX;
	trackPointer(knob, event, (move) => turnTo(start.value + (start.y - move.clientY + move.clientX - start.x) * unitsPerPixel));
}

function onKnobKey(event, knob, range, turnTo) {
	if (event.key === "Home") turnTo(range.min);
	else if (event.key === "End") turnTo(range.max);
	else if (event.key in KNOB_KEYS) turnTo(knobValue(knob) + KNOB_KEYS[event.key]);
	else return;
	event.preventDefault();
}

/** Points the knob at its value. */
function setKnob(knob, value) {
	const min = Number(knob.getAttribute("aria-valuemin"));
	const max = Number(knob.getAttribute("aria-valuemax"));
	const share = (value - min) / (max - min);
	knob.setAttribute("aria-valuenow", value);
	knob.style.setProperty("--turn", `${share * KNOB_SWEEP_DEGREES - KNOB_SWEEP_DEGREES / 2}deg`);
}

/* ── Building the panel once; afterwards only attributes and classes change ─────── */

const panel = { machine: null, selectedPart: 0, currentStep: -1, pills: [], mutes: [], keys: [], flips: [], suppressClick: false };
const STEPS_PER_BEAT = 4;
const selectedTrack = (state) => state.tracks[panel.selectedPart];

const DIAL_SLOTS = [0, 1];   // the 808 group has room for the most knobs any part has

/** The display shows a letter and the value: "S 66". */
const lettered = (letter, read) => (state) => labelled(letter, read(state));

/** An 808 knob shows the set's own setting digits: the kick at Tone 2.5, Decay 10 is "2510". */
const sampleSetting = (state) => selectedTrack(state).sample.slice(2);

/** A knob for one of the selected part's 808 knobs; a part without that knob leaves it dimmed and still. */
const dialKnob = (slot) => ({
	id: `dial-${slot}`, range: "dial",
	read: (state) => selectedTrack(state).dials[slot] ?? DrumMachine.limits.dial.initial,
	set: (value) => panel.machine.setDial(panel.selectedPart, slot, value),
	show: (state) => slot < selectedTrack(state).dials.length ? sampleSetting(state) : null
});

/**
 * Every knob on the panel: which engine range it uses, how to read its value from a
 * snapshot, how to set it, and what the display shows while it turns (tempo shows
 * nothing extra, because the display shows the tempo anyway). The last five belong
 * to the selected part.
 */
const KNOBS = [
	{ id: "tempo", range: "tempo", read: (state) => state.tempo, set: (value) => panel.machine.setTempo(value) },
	{ id: "swing", range: "swing", read: (state) => state.swing, set: (value) => panel.machine.setSwing(value) },
	{ id: "drive", range: "drive", read: (state) => state.drive, set: (value) => panel.machine.setDrive(value) },
	{ id: "reverb", range: "reverb", read: (state) => state.reverb, set: (value) => panel.machine.setReverb(value) },
	{ id: "level", range: "volume", read: (state) => selectedTrack(state).volume, set: (value) => panel.machine.setVolume(panel.selectedPart, value) },
	{ id: "pitch", range: "pitch", read: (state) => selectedTrack(state).pitch, set: (value) => panel.machine.setPitch(panel.selectedPart, value) },
	{ id: "length", range: "length", read: (state) => selectedTrack(state).length, set: (value) => panel.machine.setLength(panel.selectedPart, value) },
	...DIAL_SLOTS.map(dialKnob)
];

/** The display letter of each knob that has one. */
const KNOB_LETTERS = { swing: "S", drive: "d", reverb: "r", level: "L", pitch: "P", length: "E" };

function buildKnobs() {
	for (const knob of KNOBS) {
		const show = knob.show ?? (KNOB_LETTERS[knob.id] && lettered(KNOB_LETTERS[knob.id], knob.read));
		makeKnob(element(knob.id), DrumMachine.limits[knob.range], (value) => {
			knob.set(value);
			const text = show?.(panel.machine.getState());
			if (text) showBriefly(text);
		});
	}
}

/** One part button per part: the pill selects it (its LED flashes when it plays), the M tab above it mutes it. */
function buildPills(tracks) {
	panel.pills = tracks.map((track, index) => {
		const pill = create("button", "dm-pill", { "aria-pressed": "false", "data-part": index });
		const led = create("span", "dm-led");
		led.append(create("span", "dm-led-glow"));
		pill.append(led, track.name);
		return pill;
	});
	panel.mutes = tracks.map((track, index) => buildMute(track, index));
	element("pills").append(...panel.pills.map((pill, index) => wrapPill(pill, panel.mutes[index])));
}

function buildMute(track, index) {
	const mute = create("button", "dm-tab dm-mute", { "aria-pressed": "false", "aria-label": `Mute ${track.name}`, "data-mute": index });
	mute.textContent = "M";
	return mute;
}

function wrapPill(pill, mute) {
	const wrap = create("div", "dm-pill-wrap");
	wrap.append(mute, pill);
	return wrap;
}

/** Sixteen keys in groups of four, one group per beat. */
function buildKeys(stepCount) {
	for (let beatStart = 0; beatStart < stepCount; beatStart += STEPS_PER_BEAT) {
		const beat = create("div", "dm-beat", { "data-beat": beatStart / STEPS_PER_BEAT + 1 });
		for (let step = beatStart; step < beatStart + STEPS_PER_BEAT; step++) beat.append(buildFlip(step), buildKey(step));
		element("keys").append(beat);
	}
}

/** The small button above a key that plays its step backwards. */
function buildFlip(step) {
	const flip = create("button", "dm-tab dm-flip", { "aria-pressed": "false", "data-flip": step });
	flip.append(create("span", "dm-flip-icon"));
	panel.flips.push(flip);
	return flip;
}

/** A key: the level fill at the back, then its LED, then its printed number. */
function buildKey(step) {
	const key = create("button", "dm-key", { "aria-pressed": "false", "data-step": step });
	const number = create("span", "dm-key-number");
	number.textContent = step + 1;
	key.append(create("span", "dm-key-fill"), create("span", "dm-key-led"), number);
	panel.keys.push(key);
	return key;
}

/* ── Drawing a snapshot ───────────────────────────────────────────────────────────── */


/** Every snapshot redraws the panel, then remembers the pattern in the address. */
function draw(state) {
	const selected = selectedTrack(state);
	drawTransport(state);
	drawKnobs(state, selected);
	drawParts(state.tracks, selected);
	drawKeys(selected);
	drawPatterns(state);
	try { history.replaceState(null, "", `#${state.code}`); } catch { /* some frames refuse it; nothing is lost */ }
}

function drawTransport(state) {
	const play = element("play");
	play.disabled = state.status !== "ready";
	play.setAttribute("aria-pressed", String(state.playing));
	play.setAttribute("aria-label", state.playing ? "Stop" : "Play");
	element("play-led").classList.toggle("is-on", state.playing);
	element("save").disabled = state.status !== "ready" || state.exporting;
	element("paste-steps").disabled = !state.stepsCopied;
	setText(element("status"), PanelText.status(state));
	showResting(restingText(state));
}

function drawKnobs(state, selected) {
	for (const knob of KNOBS) setKnob(element(knob.id), knob.read(state));
	for (const name of ["level", "pitch", "length"]) element(name).setAttribute("aria-label", `${selected.name} ${name}`);
	DIAL_SLOTS.forEach((slot) => drawDialSlot(slot, selected));
}

/** An 808 slot takes the name of the part's knob there, or sits dimmed and out of the tab order if it has none. */
function drawDialSlot(slot, selected) {
	const knob = element(`dial-${slot}`);
	const name = selected.dialNames[slot];
	knob.closest(".dm-unit").classList.toggle("is-unused", !name);
	setText(knob.closest(".dm-unit").querySelector(".dm-print"), name ?? "—");
	knob.setAttribute("aria-label", name ? `${selected.name} ${name}, 808 knob` : "No 808 knob on this part");
	knob.setAttribute("aria-disabled", String(!name));
	knob.tabIndex = name ? 0 : -1;
}

function drawParts(tracks, selected) {
	tracks.forEach((track, index) => {
		panel.pills[index].setAttribute("aria-pressed", String(track === selected));
		panel.pills[index].classList.toggle("is-muted", track.muted);
		panel.mutes[index].setAttribute("aria-pressed", String(track.muted));
	});
}

/** Each key shows whether its step plays, how hard (fill and LED brightness), how nudged (shift) and which way round. */
function drawKeys(selected) {
	const furthestNudge = DrumMachine.limits.nudge.max;
	panel.keys.forEach((key, index) => {
		const step = selected.steps[index];
		const reversed = step.on && step.reversed;
		key.setAttribute("aria-pressed", String(step.on));
		key.setAttribute("aria-label", stepLabel(selected.name, index, step));
		key.style.setProperty("--level", step.velocity / 100);
		key.style.setProperty("--nudge", step.nudge / furthestNudge);
		key.classList.toggle("is-reversed", reversed);
		drawFlip(panel.flips[index], selected.name, index, reversed);
	});
}

function drawFlip(flip, name, index, reversed) {
	flip.setAttribute("aria-pressed", String(reversed));
	flip.setAttribute("aria-label", `Play ${name} step ${index + 1} backwards`);
}

const stepLabel = (name, index, step) =>
	`${name} step ${index + 1}` + (step.on ? `, level ${step.velocity}, nudge ${step.nudge}${step.reversed ? ", reversed" : ""}` : "");

/* ── The playhead: kept off the snapshot path, it only moves an LED and flashes parts ── */

function movePlayhead(step) {
	panel.keys[panel.currentStep]?.classList.remove("is-current");
	panel.keys[step]?.classList.add("is-current");
	panel.currentStep = step;
	if (step >= 0) flashPartsPlaying(step);
}

/** Lets you see the parts you are not editing: each one's LED blinks as it sounds, brighter when harder. */
function flashPartsPlaying(step) {
	panel.machine.getState().tracks.forEach((track, index) => {
		const hit = track.steps[step];
		if (!hit.on || track.muted) return;
		const glow = panel.pills[index].querySelector(".dm-led-glow");
		glow.animate([{ opacity: Math.max(0.3, hit.velocity / 100) }, { opacity: 0 }], { duration: 260, easing: "ease-out" });
	});
}

/* ── Key gestures: tap switches a step; drag up/down sets its level, sideways its nudge ── */

const DRAG_THRESHOLD_PX = 6;        // less movement than this is still a tap
const LEVEL_TRAVEL_PX = 140;        // dragging this far up sweeps the whole velocity range
const NUDGE_PX_PER_TICK = 3;        // so the full ±16 ticks is about a key's width either way
const KEY_ARROWS = { ArrowUp: ["level", 5], ArrowDown: ["level", -5], ArrowRight: ["nudge", 1], ArrowLeft: ["nudge", -1] };

/** The two things a drag can change, and the letter the display shows for each. */
const STEP_AXES = {
	level: { letter: "u", read: (step) => step.velocity,
		set: (index, value) => panel.machine.setStepVelocity(panel.selectedPart, index, value) },
	nudge: { letter: "n", read: (step) => step.nudge,
		set: (index, value) => panel.machine.setStepNudge(panel.selectedPart, index, value) }
};

const selectedStep = (index) => selectedTrack(panel.machine.getState()).steps[index];

function adjustStep(index, axisName, value) {
	const axis = STEP_AXES[axisName];
	axis.set(index, value);
	showBriefly(labelled(axis.letter, axis.read(selectedStep(index))));
}

function startKeyGesture(event) {
	const key = event.target.closest(".dm-key");
	if (!key) return;
	panel.suppressClick = false;
	const gesture = { x: event.clientX, y: event.clientY, from: selectedStep(Number(key.dataset.step)), axis: null };
	trackPointer(key, event, (move) => followKeyDrag(move, gesture, Number(key.dataset.step)));
}

/** The first clear movement picks the axis, and the gesture keeps it, so a level drag never nudges by accident. */
function followKeyDrag(move, gesture, index) {
	const rise = gesture.y - move.clientY;
	const across = move.clientX - gesture.x;
	gesture.axis ??= Math.max(Math.abs(rise), Math.abs(across)) < DRAG_THRESHOLD_PX ? null
		: Math.abs(rise) >= Math.abs(across) ? "level" : "nudge";
	if (!gesture.axis) return;
	panel.suppressClick = true;   // this press is a drag, so its click must not switch the step
	const { velocity } = DrumMachine.limits;
	if (gesture.axis === "level") adjustStep(index, "level", gesture.from.velocity + rise * (velocity.max - velocity.min) / LEVEL_TRAVEL_PX);
	else adjustStep(index, "nudge", gesture.from.nudge + across / NUDGE_PX_PER_TICK);
}

/** Arrow keys on a focused key: up/down change the level by 5, left/right the nudge by a tick. */
function onKeyArrow(event) {
	const index = numberFrom(event, "step");
	const arrow = KEY_ARROWS[event.key];
	if (index === null || !arrow) return;
	event.preventDefault();
	const [axisName, change] = arrow;
	adjustStep(index, axisName, STEP_AXES[axisName].read(selectedStep(index)) + change);
}

/* ── Input ───────────────────────────────────────────────────────────────────────── */

function selectPart(index) {
	panel.selectedPart = index;
	draw(panel.machine.getState());
}

/** The number in data-<name> of the event's element (or its ancestor), or null if there is none. */
function numberFrom(event, name) {
	const target = event.target.closest(`[data-${name}]`);
	return target ? Number(target.dataset[name]) : null;
}

/** The pill selects its part; the M tab above it mutes that part without selecting it. */
function onPillsClick(event) {
	const muted = numberFrom(event, "mute");
	if (muted !== null) return panel.machine.toggleMute(muted);
	const part = numberFrom(event, "part");
	if (part !== null) selectPart(part);
}

/** A click on a flip button reverses its step; one on a key switches its step, unless the press was a drag. */
function onKeyClick(event) {
	const flipped = numberFrom(event, "flip");
	if (flipped !== null) return panel.machine.toggleStepReverse(panel.selectedPart, flipped);
	const index = numberFrom(event, "step");
	if (panel.suppressClick || index === null) return void (panel.suppressClick = false);
	panel.machine.toggleStep(panel.selectedPart, index);
}

/** Space plays and stops unless a focused control already uses it; keys 1–8 pick a part. */
function onShortcut(event) {
	const part = Number(event.key) - 1;
	if (event.key !== " " && part >= 0 && part < panel.pills.length) return selectPart(part);
	const spaceAlreadyUsed = event.target.closest("button, [role='slider']");
	if (event.key !== " " || spaceAlreadyUsed) return;
	event.preventDefault();
	panel.machine.togglePlay();
}

/* ── The sequence (v2): drawn from each snapshot; taps go to the engine's PatternPad ───── */

const patternButtons = () => [...document.querySelectorAll(".dm-pattern")];

/** In the sequence: half lit. Playing: fully lit. On the keys: a ring. Taking over at the bar: blinking. With Select on: its places. */
function drawPatterns(state) {
	patternButtons().forEach((button, index) => {
		button.setAttribute("aria-pressed", String(state.sequence.includes(index)));
		button.setAttribute("aria-current", String(state.pattern === index));
		button.setAttribute("aria-label", PanelText.patternLabel(state, index));
		button.querySelector(".dm-pattern-places").textContent = PanelText.sequencePlaces(state, index);
		const looks = { "is-playing": state.playingPattern === index, "is-next": state.nextPattern === index, "is-used": state.patternHasSteps[index], "is-copy-source": state.copyFrom === index };
		for (const [name, on] of Object.entries(looks))
			button.classList.toggle(name, on);
	});
	for (const tool of document.querySelectorAll(".dm-tool")) tool.setAttribute("aria-pressed", String(tool.dataset.tool === state.tool));
	const hints = PanelText.sequenceHints(state);
	document.querySelectorAll(".dm-pattern-hint span").forEach((span, index) => (span.textContent = hints[index]));
}

/** A pattern button is a tap for the pad; a tool button turns its tool on or off. */
function onSequenceClick(pad, event) {
	const pattern = event.target.closest("[data-pattern]")?.dataset.pattern;
	if (pattern !== undefined) return pad.click(Number(pattern), event.shiftKey);
	const tool = event.target.closest("[data-tool]")?.dataset.tool;
	if (tool) panel.machine.toggleTool(tool);
}

/** Down and click on the group; up anywhere, since a finger dragged onto another button is lifted there. */
function listenToPatterns(pad) {
	element("patterns").addEventListener("pointerdown", (event) => {
		const pattern = event.target.closest("[data-pattern]")?.dataset.pattern;
		if (pattern !== undefined) pad.press(event.pointerId, Number(pattern));
	});
	element("patterns").addEventListener("click", (event) => onSequenceClick(pad, event));
	window.addEventListener("pointerup", (event) => pad.release(event.pointerId, PatternPad.patternAt(event.clientX, event.clientY)));
	window.addEventListener("pointercancel", (event) => pad.release(event.pointerId, PatternPad.NONE));
}

/* ── Sharing ───────────────────────────────────────────────────────────────────────── */

let shareNoteTimer = 0;

/** Shares the link to the beat (see ShareLink in the engine), then says beside the button what happened, for a moment. */
function shareBeat() {
	ShareLink.share(panel.machine.getState().code).then((words) => {
		if (!words) return;
		element("share-note").textContent = words;
		clearTimeout(shareNoteTimer);
		shareNoteTimer = setTimeout(() => (element("share-note").textContent = ""), ShareLink.NOTE_MS);
	});
}

function listen() {
	const machine = panel.machine;
	element("share").addEventListener("click", shareBeat);
	element("save").addEventListener("click", () => LoopFile.download(machine));
	element("copy-steps").addEventListener("click", () => machine.copySteps(panel.selectedPart));
	element("paste-steps").addEventListener("click", () => machine.pasteSteps(panel.selectedPart));
	listenToPatterns(new PatternPad(machine));
	element("play").addEventListener("click", () => machine.togglePlay());
	element("clear").addEventListener("click", () => machine.clear());
	element("pills").addEventListener("click", onPillsClick);
	element("keys").addEventListener("pointerdown", startKeyGesture);
	element("keys").addEventListener("click", onKeyClick);
	element("keys").addEventListener("keydown", onKeyArrow);
	document.addEventListener("keydown", onShortcut);
}

/* ── Start ───────────────────────────────────────────────────────────────────────── */

function start() {
	serveEmbeddedSamples();
	panel.machine = new DrumMachine({ tone: Tone, samplesUrl: SAMPLES_FOLDER });
	panel.machine.loadCode(location.hash.slice(1));   // a shared pattern, if the address carries one
	display.digits = buildDisplay(element("display"));
	buildPills(panel.machine.getState().tracks);
	buildKeys(DrumMachine.limits.steps);
	buildKnobs();
	draw(panel.machine.getState());
	panel.machine.subscribe(draw);
	panel.machine.onStep(movePlayhead);
	listen();
	panel.machine.load();
}

start();
