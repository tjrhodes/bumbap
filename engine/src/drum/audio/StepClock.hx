package drum.audio;

import drum.audio.ToneApi;

/**
 * Turns Tone's transport into a stream of numbered steps, 0 to 15, round
 * and round. For every step it makes two calls:
 *
 * - `soundStep(step, audioTime)` a little ahead of time, so the samples can
 *   be scheduled sample-accurately on the audio clock;
 * - `showStep(step)` on the animation frame when that step is actually heard
 *   (after the browser's delay to the speakers), so the playhead on screen
 *   lines up with the sound, not with the scheduler.
 *
 * Swing is applied here, because it is a matter of time, not of the pattern.
 */
class StepClock {
	/** Sent to `showStep` when the machine stops: no column is playing. */
	public static inline final NO_STEP = -1;

	final tone:ToneApi;
	final transport:ToneTransport;
	final draw:ToneDraw;
	final soundStep:(step:Int, audioTime:Float) -> Void;
	final showStep:(step:Int) -> Void;
	final repeatId:Int;
	var swing = Limits.SWING.initial;
	var upcomingStep = 0;
	var running = false;

	public function new(tone:ToneApi, soundStep:(step:Int, audioTime:Float) -> Void, showStep:(step:Int) -> Void) {
		this.tone = tone;
		transport = tone.getTransport();
		draw = tone.getDraw();
		this.soundStep = soundStep;
		this.showStep = showStep;
		repeatId = transport.scheduleRepeat(onSixteenth, "16n");
	}

	public function setTempo(beatsPerMinute:Int) {
		transport.bpm.value = beatsPerMinute;
	}

	public function setSwing(percent:Int) {
		swing = percent;
	}

	/** Always starts from the top of the bar. */
	public function start() {
		upcomingStep = 0;
		running = true;
		transport.start();
	}

	/**
	 * Drops any playhead updates still waiting, then clears the playhead.
	 * Tone stops its transport a moment ahead (its look-ahead), so a tick
	 * can still arrive after this; `running` makes the clock ignore it.
	 */
	public function stop() {
		running = false;
		transport.stop();
		draw.cancel(0);
		showStep(NO_STEP);
	}

	public function dispose() {
		stop();
		transport.clear(repeatId);
	}

	/** Called by Tone once per sixteenth note, with the grid time it falls on. */
	function onSixteenth(gridTime:Float) {
		if (!running) return;
		final step = upcomingStep;
		upcomingStep = (step + 1) % Limits.STEPS;
		final sixteenth = Timing.sixteenthSeconds(transport.bpm.value);
		final audioTime = gridTime + Timing.swingDelay(step, swing, sixteenth);
		soundStep(step, audioTime);
		draw.schedule(() -> showStep(step), audioTime + Latency.speakerDelay(tone)); // light up as it is heard
	}
}
