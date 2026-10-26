package drum.audio;

import js.lib.Float32Array;

/**
 * The maths of the overdrive: a valve-style soft clip.
 *
 * The shape is tanh, which rounds peaks off smoothly the way a valve does,
 * instead of chopping them flat like a transistor fuzz. The two halves of
 * the wave are rounded by different amounts, as in a single triode, so the
 * overdrive adds even harmonics, which is what is heard as warmth. A
 * low-pass filter after it takes the fizz off, closing as the drive rises,
 * and a trim stops the overdrive simply sounding like "louder".
 *
 * A WaveShaper only shapes -1…1 and flattens anything beyond, so the master
 * chain turns the signal down by HEADROOM_DB before the overdrive; accents
 * louder than full scale then pass through clean at drive 0. The safety
 * clipper at the very end gives that headroom back (see clipCurve).
 */
class Saturation {
	/** Odd, so the curve has a point exactly at silence. */
	public static inline final CURVE_POINTS = 2049;

	public static inline final HEADROOM_DB = 12.0;
	static final HEADROOM_GAIN = drum.Loudness.decibelsToGain(HEADROOM_DB);

	static inline final GENTLEST = 0.05; // so gentle that drive 0 is a straight line
	static inline final STEEPEST = 10.0;
	static inline final NEGATIVE_HALF_SOFTNESS = 0.6; // the lower half rounds off later than the upper
	static inline final OPEN_CUTOFF_HZ = 18000.0;
	static inline final CLOSED_CUTOFF_HZ = 5500.0;
	static inline final MOST_TRIM_DB = -12.0;

	/** The transfer curve for Tone's WaveShaper: input from -1 to 1 maps to these outputs. */
	public static function curve(drivePercent:Int):Float32Array {
		final steepness = GENTLEST + (STEEPEST - GENTLEST) * drivePercent / 100;
		return sampled(input -> shape(input, steepness));
	}

	/**
	 * The safety clipper at the end of the chain: plain tanh over the headroom
	 * range. Quiet signals come back up by exactly the headroom taken at the
	 * start (tanh is a straight line near zero); the rare peaks that stack up
	 * are rounded off, and nothing can ever pass full scale.
	 */
	public static function clipCurve():Float32Array {
		return sampled(input -> tanh(input * HEADROOM_GAIN));
	}

	/** A WaveShaper curve: the mapping, read at evenly spaced inputs from -1 to 1. */
	static function sampled(mapping:Float->Float):Float32Array {
		final curve = new Float32Array(CURVE_POINTS);
		for (point in 0...CURVE_POINTS) curve[point] = mapping(point / (CURVE_POINTS - 1) * 2 - 1);
		return curve;
	}

	/** The low-pass filter's cutoff, sliding down evenly in pitch as the drive goes up. */
	public static function cutoffHz(drivePercent:Int):Float {
		return OPEN_CUTOFF_HZ * Math.pow(CLOSED_CUTOFF_HZ / OPEN_CUTOFF_HZ, drivePercent / 100);
	}

	/**
	 * Level taken off after the overdrive, to keep loudness roughly even, so the
	 * knob changes the character more than the volume. Saturation gets louder
	 * fastest at the start of the knob, so the trim follows a square root.
	 */
	public static function trimDecibels(drivePercent:Int):Float {
		return MOST_TRIM_DB * Math.sqrt(drivePercent / 100);
	}

	/** Each half is tanh scaled so that silence stays silent and full scale stays full scale. */
	static function shape(input:Float, steepness:Float):Float {
		final halfSteepness = input >= 0 ? steepness : steepness * NEGATIVE_HALF_SOFTNESS;
		return tanh(halfSteepness * input) / tanh(halfSteepness);
	}

	/** Haxe's Math has no tanh. */
	static function tanh(x:Float):Float {
		final doubled = Math.exp(2 * x);
		return (doubled - 1) / (doubled + 1);
	}
}
