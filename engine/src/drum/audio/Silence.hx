package drum.audio;

import js.lib.Float32Array;

/**
 * Finds where a sample's sound actually ends. A reversed sample starts with
 * whatever came last, so any silent tail would play first as a gap before
 * the hit; the reversed copy is cut here before it is flipped.
 */
class Silence {
	/** Quieter than this, relative to the sample's own peak, counts as silence. */
	static inline final THRESHOLD_DB = -60.0;

	/** The time just after the last audible sample (at least one sample, so a cut is never empty). */
	public static function soundEndSeconds(samples:Float32Array, sampleRate:Float):Float {
		final threshold = peak(samples) * drum.Loudness.decibelsToGain(THRESHOLD_DB);
		var lastAudible = 0;
		for (index in 0...samples.length) if (Math.abs(samples[index]) > threshold) lastAudible = index;
		return (lastAudible + 1) / sampleRate;
	}

	static function peak(samples:Float32Array):Float {
		var loudest = 0.0;
		for (index in 0...samples.length) loudest = Math.max(loudest, Math.abs(samples[index]));
		return loudest;
	}
}
