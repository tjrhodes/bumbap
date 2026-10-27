package drum;

/**
 * Every range in one place, so the engine, the URL code and every front
 * end agree on them without repeating a single number.
 */
class Limits {
	/** One bar of sixteenth notes. */
	public static inline final STEPS = 16;

	/** Patterns the machine holds, each one bar long (version 2). */
	public static inline final PATTERNS = 8;

	/** The resolution of a nudge: a beat is split into 384 ticks. */
	public static inline final TICKS_PER_BEAT = 384;

	/** Beats per minute. */
	public static final TEMPO = new Range(60, 200, 100);

	/** MPC-style swing: 50 is straight, 66 a triplet shuffle, 75 the most. */
	public static final SWING = new Range(50, 75, 50);

	/** Track volume in percent; 80 leaves headroom when everything plays. */
	public static final VOLUME = new Range(0, 100, 80);

	/** How hard one step hits. New steps start at 85, so they can go louder as well as a long way quieter. */
	public static final VELOCITY = new Range(1, 100, 85);

	/**
	 * How early (negative) or late (positive) one step sounds, in ticks.
	 * ±16 ticks is ±1/24 of a beat: about ±25 ms at 100 BPM. Enough to make a
	 * snare properly lazy or a hat push, still short of sounding like a flam.
	 */
	public static final NUDGE = new Range(-16, 16, 0);

	/** A part's pitch in semitones; like a sampler, higher also plays shorter. */
	public static final PITCH = new Range(-12, 12, 0);

	/** How much of a part's sound is heard, in percent: lower fades it out sooner. */
	public static final LENGTH = new Range(5, 100, 100);

	/** An 808 knob's position: the sample set recorded five (fully left, 2.5, 5, 7.5, fully right). */
	public static final DIAL = new Range(0, 4, 2);

	/** Warm valve-style overdrive on the whole kit, in percent; 0 leaves the sound untouched. */
	public static final DRIVE = new Range(0, 100, 0);

	/** How much of the room is heard, in percent; 0 is dry. */
	public static final REVERB = new Range(0, 100, 0);
}
