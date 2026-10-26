package drum;

/**
 * When a hit sounds, relative to the straight grid. Two things move it:
 *
 * - swing, the way drum machines like the MPC describe it: the share of a
 *   pair of sixteenths that the first one takes. At 50% both are equal
 *   (straight); at 66% the first is twice as long as the second (a triplet
 *   shuffle). Only the second sixteenth of each pair, the off-beat, moves;
 * - nudge, per step, in ticks of a beat (see Limits.TICKS_PER_BEAT), so a
 *   nudged step keeps the same musical feel at any tempo.
 */
class Timing {
	/** How long one sixteenth note lasts at this tempo. */
	public static function sixteenthSeconds(beatsPerMinute:Float):Float {
		return beatSeconds(beatsPerMinute) / 4;
	}

	/** How much later than the straight grid swing puts this step. */
	public static function swingDelay(step:Int, swingPercent:Int, sixteenth:Float):Float {
		if (!isOffbeat(step)) return 0;
		final pairLength = sixteenth * 2;
		final firstNoteLength = pairLength * swingPercent / 100;
		return firstNoteLength - sixteenth;
	}

	/**
	 * How long this step lasts: from its (swung) start to the next step's start.
	 * With swing the on-beats grow and the off-beats shrink. A reversed hit fills it.
	 */
	public static function stepSeconds(step:Int, swingPercent:Int, sixteenth:Float):Float {
		return sixteenth + swingDelay(step + 1, swingPercent, sixteenth) - swingDelay(step, swingPercent, sixteenth);
	}

	/** How far a nudge moves a hit; negative is early. */
	public static function nudgeSeconds(ticks:Int, beatsPerMinute:Float):Float {
		return beatSeconds(beatsPerMinute) * ticks / Limits.TICKS_PER_BEAT;
	}

	static function beatSeconds(beatsPerMinute:Float):Float {
		return 60 / beatsPerMinute;
	}

	/** Steps are counted from 0, so the off-beats are the odd ones. */
	static function isOffbeat(step:Int):Bool {
		return step % 2 == 1;
	}
}
