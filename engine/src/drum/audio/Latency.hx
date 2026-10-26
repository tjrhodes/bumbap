package drum.audio;

import drum.audio.ToneApi;

/**
 * The audio clock against the real world.
 *
 * Browsers default to tiny audio buffers ("interactive"), about 3 ms of sound
 * each. A phone under load (a long kick through drive and reverb) can miss
 * one, which is heard as a crackle. Every hit here is scheduled ahead of time,
 * so bigger buffers ("playback") cost nothing in timing; Play just answers a
 * few tens of milliseconds later.
 *
 * Bigger buffers also mean a sound reaches the speakers a little after the
 * audio clock reaches its time, so the playhead waits that long too.
 */
class Latency {
	/** Must run before any other Tone object is made: they belong to the context they were made in. */
	public static function preferSmoothPlayback(tone:ToneApi) {
		tone.setContext(ToneNodes.create(tone.Context, {latencyHint: "playback"}));
	}

	/** Seconds from the audio clock to the speakers, as the browser reports it (0 if it does not). */
	public static function speakerDelay(tone:ToneApi):Float {
		final browserContext = tone.getContext().rawContext;
		return browserContext.outputLatency ?? browserContext.baseLatency ?? 0;
	}
}
