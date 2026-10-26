package drum;

import drum.Kit.Voice;
import drum.State.StepSettings;
import drum.State.TrackSettings;
import drum.State.TrackState;

/**
 * One row of the machine: its sixteen steps, how loud, whether muted, and
 * how its sound is shaped (pitch, length, the 808 knobs). Plain data with
 * guarded edits; it knows nothing about sound.
 */
class Track {
	public final voice:Voice;
	public var volume(default, null):Int = Limits.VOLUME.initial;
	public var muted(default, null):Bool = false;
	public var pitch(default, null):Int = Limits.PITCH.initial;
	public var length(default, null):Int = Limits.LENGTH.initial;

	final steps:Array<StepSettings>;
	final dials:Array<Int>;

	public function new(voice:Voice) {
		this.voice = voice;
		steps = StepRow.parse(voice.starterRow);
		dials = [for (dial in voice.dials) dial.initial];
	}

	/** The recording the 808 knobs currently choose, e.g. "BD2550". */
	public function sampleName():String {
		return Kit.sampleName(voice, dials);
	}

	public function stepAt(step:Int):StepSettings {
		return steps[step];
	}

	/** Off becomes a fresh hit; on becomes a rest. */
	public function toggleStep(step:Int) {
		editStep(step, current -> current.on ? Step.REST : Step.fresh());
	}

	/** Setting a level on a step that is off switches it on at that level. */
	public function setVelocity(step:Int, velocity:Float) {
		editStep(step, current -> Step.hit(velocity, current.nudge, current.reversed));
	}

	/** Nudging a step that is off switches it on, nudged. */
	public function setNudge(step:Int, ticks:Float) {
		editStep(step, current -> Step.hit(current.velocity, ticks, current.reversed));
	}

	/** Flips a step between forwards and backwards; flipping a step that is off switches it on, reversed. */
	public function toggleReverse(step:Int) {
		editStep(step, current -> Step.hit(current.velocity, current.nudge, !(current.on && current.reversed)));
	}

	public function clearSteps() {
		for (step in 0...Limits.STEPS) steps[step] = Step.REST;
	}

	public function setVolume(percent:Float) {
		volume = Limits.VOLUME.clamp(percent);
	}

	public function toggleMute() {
		muted = !muted;
	}

	public function setPitch(semitones:Float) {
		pitch = Limits.PITCH.clamp(semitones);
	}

	public function setLength(percent:Float) {
		length = Limits.LENGTH.clamp(percent);
	}

	/** Turns one of the part's 808 knobs; parts without that knob ignore it. */
	public function setDial(dial:Int, position:Float) {
		if (dial >= 0 && dial < dials.length) dials[dial] = Limits.DIAL.clamp(position);
	}

	/** Takes over a saved row, e.g. one decoded from a shared URL; every value is re-checked. */
	public function restore(saved:TrackSettings) {
		for (step in 0...Limits.STEPS) {
			final savedStep = saved.steps[step];
			steps[step] = savedStep != null && savedStep.on ? Step.hit(savedStep.velocity, savedStep.nudge, savedStep.reversed == true) : Step.REST;
		}
		for (dial in 0...dials.length) setDial(dial, saved.dials[dial] ?? voice.dials[dial].initial);
		setVolume(saved.volume);
		setPitch(saved.pitch);
		setLength(saved.length);
		muted = saved.muted;
	}

	/**
	 * A snapshot for the UI. It is also a valid TrackSettings, so the URL
	 * code reads it directly. The row is copied; the steps themselves are
	 * frozen values, so the snapshot never changes after it is handed out.
	 */
	public function toState():TrackState {
		return {
			id: voice.id, name: voice.name, steps: steps.copy(), volume: volume, muted: muted,
			pitch: pitch, length: length, dials: dials.copy(),
			dialNames: [for (dial in voice.dials) dial.name], sample: sampleName()
		};
	}

	/** Out-of-range steps are ignored, so a stray gesture can never corrupt the row. */
	function editStep(step:Int, change:StepSettings->StepSettings) {
		if (step >= 0 && step < Limits.STEPS) steps[step] = change(steps[step]);
	}
}
