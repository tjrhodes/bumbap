package drum;

/** One step of one track. Steps are values: an edit replaces the step, it never changes it. */
typedef StepSettings = {
	final on:Bool;
	/** 1–100; see Limits.VELOCITY. Kept while the step is off, but not saved. */
	final velocity:Int;
	/** Ticks early (negative) or late (positive); see Limits.NUDGE. */
	final nudge:Int;
	/** Plays the sample backwards. */
	final reversed:Bool;
}

/** What one track saves: its rhythm, its place in the mix and how its sound is shaped. */
typedef TrackSettings = {
	final steps:Array<StepSettings>;
	final volume:Int;
	final muted:Bool;
	/** Semitones; see Limits.PITCH. */
	final pitch:Int;
	/** Percent of the sound heard; see Limits.LENGTH. */
	final length:Int;
	/** The 808 knob positions, 0–4, one per knob the part has (see Kit). */
	final dials:Array<Int>;
}

/** The settings for the whole machine, as opposed to one track. */
typedef MachineSettings = {
	final tempo:Int;
	final swing:Int;
	final drive:Int;
	final reverb:Int;
}

/** One of the eight patterns: every part's steps and sound, one entry per part. */
typedef Pattern = Array<TrackSettings>;

/** Everything a link stores: enough to rebuild the machine exactly. */
typedef SavedMachine = MachineSettings & {
	/** All eight, in order; the one shown is as it stands now. */
	final patterns:Array<Pattern>;
	/** The pattern on the keys, 0–7. */
	final shown:Int;
	/** The order the patterns play in, repeats allowed; 1 to 16 of them. */
	final sequence:Array<Int>;
}

/** A track as the UI sees it: its settings plus what to call things. */
typedef TrackState = TrackSettings & {
	final id:String;
	final name:String;
	/** The names of its 808 knobs, matching `dials`, e.g. ["Tone", "Decay"]. */
	final dialNames:Array<String>;
	/** The recording its knobs choose, e.g. "BD2550". */
	final sample:String;
}

/** The sequence's small buttons; Off when none is on. */
enum abstract SequenceTool(String) to String {
	var Off = "";
	var Select = "select";
	var Copy = "copy";
	var Clear = "clear";
}

/** Whether the samples are ready to play. */
enum abstract LoadStatus(String) to String {
	var Loading = "loading";
	var Ready = "ready";
	var Failed = "failed";
}

/**
 * The snapshot every front end renders from. A new object is made on each
 * change and never mutated, so frameworks can compare snapshots by identity.
 */
typedef MachineState = MachineSettings & {
	final status:LoadStatus;
	final playing:Bool;
	/** The whole machine as a URL-safe code, ready for location.hash. */
	final code:String;
	/** The parts of the pattern shown: the one playing, or when stopped the one on the keys. */
	final tracks:Array<TrackState>;
	/** Which pattern that is, 0–7. */
	final pattern:Int;
	/** The order the patterns play in, repeats allowed; 1 to 16 of them. */
	final sequence:Array<Int>;
	/** Where in the sequence the shown pattern is playing, from 0; -1 when it is not in the sequence. */
	final sequencePlace:Int;
	/** The pattern waiting for the end of the bar, or -1. */
	final nextPattern:Int;
	/** For each of the eight patterns, whether any of its steps plays. */
	final patternHasSteps:Array<Bool>;
	/** The sequence button that is on: a tap on a pattern then selects, copies or clears instead of playing it. */
	final tool:SequenceTool;
	/** With Copy on, the pattern picked to copy, or -1 before one is. */
	final copyFrom:Int;
}
