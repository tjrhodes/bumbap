package drum;

import drum.State.Pattern;

/** What every one of the eight patterns may need: a blank one, and whether one has anything in it. */
class Patterns {
	/** An empty pattern: no steps, and every part at its starting level, pitch, length and 808 knobs. */
	public static function blank():Pattern {
		return [for (voice in Kit.VOICES) {
			steps: [for (_ in 0...Limits.STEPS) Step.REST],
			volume: Limits.VOLUME.initial,
			muted: false,
			pitch: Limits.PITCH.initial,
			length: Limits.LENGTH.initial,
			dials: [for (dial in voice.dials) dial.initial]
		}];
	}

	public static function hasSteps(pattern:Pattern):Bool {
		return Lambda.exists(pattern, track -> Lambda.exists(track.steps, step -> step.on));
	}

	/** A pattern number the machine has: 0–7. */
	public static function exists(index:Int):Bool {
		return index >= 0 && index < Limits.PATTERNS;
	}
}
