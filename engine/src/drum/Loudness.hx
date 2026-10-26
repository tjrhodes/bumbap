package drum;

/** Turns the machine's 0–100 numbers into the gains and decibels the audio graph needs. */
class Loudness {
	/**
	 * Every 8 points of velocity is 3 dB: a step at 85 (the default) plays at
	 * the track's level, 100 is about 5.6 dB louder, 45 is 15 dB quieter and
	 * 1 is 31.5 dB quieter, quiet enough for the faintest ghost note.
	 * Decibels, not straight gain, because that is how loudness is heard.
	 */
	static inline final DECIBELS_PER_VELOCITY_POINT = 3 / 8;

	/** The gain one hit is played at. */
	public static function velocityGain(velocity:Int):Float {
		final decibels = (velocity - Limits.VELOCITY.initial) * DECIBELS_PER_VELOCITY_POINT;
		return decibelsToGain(decibels);
	}

	/** The track volume is a plain fader: percent of full gain, given in decibels for Tone. */
	public static function volumeDecibels(percent:Int):Float {
		if (percent <= 0) return Math.NEGATIVE_INFINITY;
		return 20 * Math.log(percent / 100) / Math.log(10);
	}

	public static function decibelsToGain(decibels:Float):Float {
		return Math.pow(10, decibels / 20);
	}
}
