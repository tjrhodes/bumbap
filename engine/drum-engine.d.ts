// Types for the shared drum engine (dist/drum-engine.js, compiled from Haxe).
// Written by hand to mirror src/drum/State.hx and src/drum/DrumMachine.hx:
// if you change the public API there, change it here too. The React,
// Vue and Angular builds type-check against this file, so drift shows up
// as compile errors in those builds.

/** A setting's allowed span and starting value. Values are whole numbers. */
export interface Range {
	readonly min: number;
	readonly max: number;
	readonly initial: number;
	/** Rounds and clamps any number into the range (NaN gives the initial value). */
	clamp(value: number): number;
}

export type LoadStatus = "loading" | "ready" | "failed";

/** One step of one track; a new object replaces it on every edit. */
export interface StepState {
	readonly on: boolean;
	/** 1–100; a new step starts at 85 (the part's level). Kept while off, but not saved. */
	readonly velocity: number;
	/** Ticks early (negative) or late (positive), ±16; a beat is 384 ticks. */
	readonly nudge: number;
	/** Plays the sample backwards. */
	readonly reversed: boolean;
}

export interface TrackState {
	readonly id: string;
	readonly name: string;
	readonly steps: readonly StepState[];
	/** 0–100. */
	readonly volume: number;
	readonly muted: boolean;
	/** Semitones, ±12. */
	readonly pitch: number;
	/** Percent of the sound heard, 5–100. */
	readonly length: number;
	/** The part's 808 knob positions, 0–4 (fully left … fully right); empty if it has none. */
	readonly dials: readonly number[];
	/** Their names, matching dials, e.g. ["Tone", "Decay"]. */
	readonly dialNames: readonly string[];
	/** The recording the knobs choose, e.g. "BD2550". */
	readonly sample: string;
}

/** A frozen snapshot; a new object is made on every change. */
export interface MachineState {
	readonly status: LoadStatus;
	readonly playing: boolean;
	readonly tempo: number;
	readonly swing: number;
	/** Valve-style overdrive on the whole kit, 0–100. */
	readonly drive: number;
	/** Reverb mix, 0–100. */
	readonly reverb: number;
	/** The whole machine (all eight patterns and their sequence) as a URL-safe code, ready for location.hash. */
	readonly code: string;
	/** The parts of the pattern on the keys, being edited (it need not be the one playing). */
	readonly tracks: readonly TrackState[];
	/** Which pattern that is, 0–7. */
	readonly pattern: number;
	/** The pattern playing, 0–7; -1 when stopped. */
	readonly playingPattern: number;
	/** The order the patterns play in, repeats allowed; 1 to 16 of them. */
	readonly sequence: readonly number[];
	/** Where in the sequence the pattern playing is, from 0; -1 when the sequence changed under it. */
	readonly sequencePlace: number;
	/** While playing, the pattern taking over at the end of the bar because the sequence changed, or -1. */
	readonly nextPattern: number;
	/** For each of the eight patterns, whether any of its steps plays. */
	readonly patternHasSteps: readonly boolean[];
	/** The sequence button that is on ("" for none): a tap on a pattern then selects, copies or clears it. */
	readonly tool: SequenceTool;
	/** With Copy on, the pattern picked to copy, or -1 before one is. */
	readonly copyFrom: number;
	/** Steps have been copied, so Paste can paste them. */
	readonly stepsCopied: boolean;
	/** A loop is being rendered for download. */
	readonly exporting: boolean;
}

/** The sequence's small buttons; "" when none is on. */
export type SequenceTool = "" | "select" | "copy" | "clear";

export interface MachineOptions {
	/** The Tone.js v15 module: `import * as Tone from "tone"`. */
	tone: unknown;
	/** Folder the samples are served from, ending in "/". */
	samplesUrl: string;
}

export type Unsubscribe = () => void;

/** The display, as data every front end draws the same way (segments a–g, four slanted digits). */
export declare const SevenSegmentFont: {
	readonly DIGITS: number;
	readonly VIEW_BOX: string;
	readonly SEGMENTS: readonly string[];
	/** Exactly four characters, right-aligned: "100" → [" ", "1", "0", "0"]. */
	characters(text: string): string[];
	isLit(character: string, segment: string): boolean;
	digitTransform(index: number): string;
	segmentPoints(segment: string): string;
};

/** Every word and number the panel shows, written once for every front end. */
export declare const PanelText: {
	readonly KNOB_LETTERS: Readonly<Record<string, string>>;
	readonly STEP_LETTERS: Readonly<{ level: string; nudge: string }>;
	/** "S 66", "L100", "n -3". */
	labelled(letter: string, value: number): string;
	/** The tempo, or "LoAd" / "Err". */
	resting(state: MachineState): string;
	/** The status line: "Ready", "Playing", … */
	status(state: MachineState): string;
	/** The recording's 808 setting, e.g. "2510". */
	dialSetting(track: TrackState): string;
	stepLabel(trackName: string, stepIndex: number, step: StepState): string;
	flipLabel(trackName: string, stepIndex: number): string;
	dialLabel(track: TrackState, slot: number): string;
	/** "Pattern 3", then ", on the keys", ", playing", ", next", ", empty", and with Select on ", sequence places 1 3". */
	patternLabel(state: MachineState, pattern: number): string;
	/** With Select on, a pattern's places in the sequence, from 1 ("1 3"); otherwise "". */
	sequencePlaces(state: MachineState, pattern: number): string;
	/** The sequence buttons' labels: "Select the sequence", "Copy a pattern", and "Clear a pattern" (with Select on, "Clear the sequence"). */
	toolLabel(state: MachineState, tool: Exclude<SequenceTool, "">): string;
	/** What a tap on a pattern does now: [for a mouse, for a touch screen]. */
	sequenceHints(state: MachineState): readonly [string, string];
};

/**
 * The pattern buttons' gestures, shared by every build: forward the events, the pad calls the machine.
 * A click is a tap (DrumMachine.tapPattern); with no tool on, holding one button and tapping others sets the
 * sequence in that order, and a drag onto another button copies.
 */
export declare class PatternPad {
	/** What `patternAt` gives where there is no pattern button. */
	static readonly NONE: number;
	/** The pattern button (`[data-pattern]`) under a point on the page, or NONE. */
	static patternAt(x: number, y: number): number;
	constructor(machine: DrumMachine);
	/** pointerdown on a pattern button. */
	press(pointerId: number, pattern: number): void;
	/** pointerup or pointercancel anywhere: pass `PatternPad.patternAt(x, y)` (or NONE when cancelled). */
	release(pointerId: number, under: number): void;
	/** click on a pattern button (from the mouse, touch or keyboard). */
	click(pattern: number, shift: boolean): void;
}

export declare class DrumMachine {
	static readonly limits: {
		readonly steps: number;
		/** The resolution of a nudge: ticks per beat. */
		readonly ticksPerBeat: number;
		readonly tempo: Range;
		readonly swing: Range;
		readonly volume: Range;
		readonly velocity: Range;
		readonly nudge: Range;
		readonly drive: Range;
		readonly reverb: Range;
		readonly pitch: Range;
		readonly length: Range;
		/** An 808 knob: 0–4. */
		readonly dial: Range;
	};

	constructor(options: MachineOptions);

	/** The current snapshot; the same object until something changes. */
	getState(): MachineState;
	/** Called after every change. */
	subscribe(listener: (state: MachineState) => void): Unsubscribe;
	/** The playhead on the keys: step 0–15 on the frame it is heard; -1 when stopped, or when the keys show a pattern not playing. */
	onStep(listener: (step: number) => void): Unsubscribe;

	/** Downloads and decodes each part's chosen recording; Play does nothing until this resolves. */
	load(): Promise<void>;
	/** Call from a click or key press: browsers only unlock audio then. */
	play(): Promise<void>;
	stop(): void;
	togglePlay(): Promise<void>;

	/** Off becomes a fresh hit (velocity 85, on the grid, forwards); on becomes a rest. */
	toggleStep(trackIndex: number, step: number): void;
	/** 1–100. A step that is off is switched on. */
	setStepVelocity(trackIndex: number, step: number, velocity: number): void;
	/** Ticks, ±16. A step that is off is switched on. */
	setStepNudge(trackIndex: number, step: number, ticks: number): void;
	/** Flips a step between forwards and backwards; a step that is off is switched on, reversed. */
	toggleStepReverse(trackIndex: number, step: number): void;
	setVolume(trackIndex: number, percent: number): void;
	/** Semitones, ±12; higher also plays shorter, like a sampler. */
	setPitch(trackIndex: number, semitones: number): void;
	/** Percent of the sound heard, 5–100. */
	setLength(trackIndex: number, percent: number): void;
	/** Turns one of a part's 808 knobs (0–4); the new recording plays once it has loaded. */
	setDial(trackIndex: number, dial: number, position: number): void;
	/** A muted track is skipped as its steps come round. */
	toggleMute(trackIndex: number): void;
	setTempo(beatsPerMinute: number): void;
	setSwing(percent: number): void;
	setDrive(percent: number): void;
	setReverb(percent: number): void;
	/** Empties the grid of the pattern on the keys; tempo, swing, effects and the mix are kept. */
	clear(): void;
	/** Copies one part's sixteen steps (levels, nudges, flips) from the pattern on the keys. */
	copySteps(trackIndex: number): void;
	/** Pastes the copied steps into one part of the pattern on the keys. */
	pasteSteps(trackIndex: number): void;
	/** Renders one pass of the sequence, loop-ready, as a WAV file; playback stops first. */
	exportLoop(): Promise<Blob>;
	/** Puts a pattern (0–7) on the keys to edit; the sequence plays on. */
	editPattern(index: number): void;
	/** Adds one pattern at the end of the sequence, or takes it out; the sequence keeps at least one. */
	toggleInSequence(index: number): void;
	/** The sequence, in the order it plays, repeats allowed (up to 16). */
	setSequence(indexes: readonly number[]): void;
	/** Copies one pattern (steps and part sounds) over another. */
	copyPattern(from: number, to: number): void;
	/** Makes a pattern blank: no steps, every part as it starts. */
	clearPattern(index: number): void;
	/** Turns one of the sequence's buttons on (any other off), or off if it was on; with Select on, "clear" clears the sequence. */
	toggleTool(tool: Exclude<SequenceTool, "">): void;
	/** A tap on a pattern button, read by the tool that is on (none: edit it; with Shift, add to or take out of the sequence). */
	tapPattern(index: number, shift: boolean): void;
	/** Restores a shared machine (a bümbap 1 link opens as pattern 1); false (and no change) if the code is invalid. */
	loadCode(code: string): boolean;
	/** Stops, releases audio resources and forgets every listener. */
	dispose(): void;
}

/** The Download button: renders the sequence as a loop-ready WAV and saves it ("bumbap-120bpm-4bars.wav"). */
export declare const LoopFile: {
	/** "Download the sequence as a WAV loop", for the button's label. */
	readonly LABEL: string;
	download(machine: DrumMachine): Promise<void>;
	fileName(state: MachineState): string;
};

/** Sharing a beat as a link: the page the visitor sees, with the pattern's code at its end. */
export declare const ShareLink: {
	/** "Share this beat", for the button's label. */
	readonly LABEL: string;
	readonly COPIED: string;
	readonly NOT_COPIED: string;
	/** How long the panel shows what happened, in milliseconds. */
	readonly NOTE_MS: number;
	addressWith(pageAddress: string, code: string): string;
	/** The share sheet on a touch screen, otherwise the clipboard; gives the words to show ("" for none). Never fails. */
	share(code: string): Promise<string>;
};
