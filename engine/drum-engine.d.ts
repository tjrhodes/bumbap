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
	/** The pattern as a URL-safe code, ready for location.hash. */
	readonly code: string;
	readonly tracks: readonly TrackState[];
}

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
};

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
	/** The playhead: step 0–15 on the frame it is heard, -1 when stopped. */
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
	/** Empties the grid; tempo, swing, effects and the mix are kept. */
	clear(): void;
	/** Restores a shared pattern; false (and no change) if the code is invalid. */
	loadCode(code: string): boolean;
	/** Stops, releases audio resources and forgets every listener. */
	dispose(): void;
}
