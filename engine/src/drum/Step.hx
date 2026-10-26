package drum;

import drum.State.StepSettings;

/**
 * Makes steps. Every step is checked against the limits and frozen when it
 * is made, so a step found anywhere in the engine or a snapshot is valid.
 */
class Step {
	/** A step that does not play. Switching it on gives a fresh hit (see `fresh`). */
	public static final REST:StepSettings = frozen(false, Limits.VELOCITY.initial, Limits.NUDGE.initial, false);

	/** A step that plays, at this velocity and nudge (clamped to the limits), forwards or reversed. */
	public static function hit(velocity:Float, nudge:Float, reversed = false):StepSettings {
		return frozen(true, Limits.VELOCITY.clamp(velocity), Limits.NUDGE.clamp(nudge), reversed);
	}

	/** A newly tapped step: default velocity, right on the grid, forwards. */
	public static function fresh():StepSettings {
		return hit(Limits.VELOCITY.initial, Limits.NUDGE.initial);
	}

	static function frozen(on:Bool, velocity:Int, nudge:Int, reversed:Bool):StepSettings {
		final step:StepSettings = {on: on, velocity: velocity, nudge: nudge, reversed: reversed};
		return js.lib.Object.freeze(step);
	}
}
