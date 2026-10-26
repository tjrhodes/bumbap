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

/** Everything the URL code stores: enough to rebuild the groove exactly. */
typedef Pattern = MachineSettings & {
	final tracks:Array<TrackSettings>;
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
	/** The current pattern as a URL-safe code, ready for location.hash. */
	final code:String;
	final tracks:Array<TrackState>;
}
