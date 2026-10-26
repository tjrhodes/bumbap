package drum.audio;

/** How one hit is played from its sample: what Tone's buffer source is told. */
typedef HitPlan = {
	/** Seconds after the hit's time that the sample starts. */
	final startDelay:Float;
	/** Where in the sample to start, in sample seconds. */
	final offset:Float;
	/** Real seconds after starting to stop (the fade-out then follows); null plays to the end. */
	final stopAfter:Null<Float>;
	final fadeIn:Float;
	final fadeOut:Float;
}

/**
 * The maths of one hit, kept pure so it can be tested on its own. It works
 * from the part's three sound controls:
 *
 * - pitch: a playback rate, so higher also means shorter, as on a sampler;
 * - length: how much of the sound is heard before it has faded right out;
 * - reversed: a backwards hit swells into the end of its step and stops there.
 *
 * Times called "sound" are in the sample's own seconds; times called "heard"
 * are real seconds, after the playback rate.
 */
class HitShape {
	/** A shortened sound fades out over this share of what is heard, so it dies away rather than stops. */
	static inline final LENGTH_FADE_SHARE = 0.6;
	/** Fast enough to sound like a reversed swell starts on the step, slow enough that cutting in never clicks. */
	static inline final CUT_IN_FADE_SECONDS = 0.012;

	/** Each semitone is a twelfth of an octave; an octave doubles the speed. */
	public static function playbackRate(semitones:Int):Float {
		return Math.pow(2, semitones / 12);
	}

	/** A forwards hit: from the start, faded out early if the length is short. */
	public static function forwards(soundSeconds:Float, rate:Float, lengthShare:Float):HitPlan {
		if (lengthShare >= 1) return {startDelay: 0, offset: 0, stopAfter: null, fadeIn: 0, fadeOut: 0};
		final heard = soundSeconds * lengthShare / rate;
		final fadeOut = heard * LENGTH_FADE_SHARE;
		return {startDelay: 0, offset: 0, stopAfter: heard - fadeOut, fadeIn: 0, fadeOut: fadeOut};
	}

	/**
	 * A backwards hit, played from the reversed sample so that it ends exactly
	 * as its step ends. Only as much as fits in the step is heard, cut in with a
	 * fast fade; a shorter sound starts later instead. A short length fades the
	 * swell in, as the shortened sound would have faded out.
	 */
	public static function backwards(soundSeconds:Float, rate:Float, lengthShare:Float, stepSeconds:Float):HitPlan {
		final shortenedHeard = soundSeconds * lengthShare / rate;
		final heard = Math.min(stepSeconds, shortenedHeard);
		final cutByStep = heard < shortenedHeard;
		final fadeIn = cutByStep ? CUT_IN_FADE_SECONDS : (lengthShare < 1 ? heard * LENGTH_FADE_SHARE : 0);
		return {startDelay: stepSeconds - heard, offset: soundSeconds - heard * rate, stopAfter: heard, fadeIn: fadeIn, fadeOut: 0};
	}
}
