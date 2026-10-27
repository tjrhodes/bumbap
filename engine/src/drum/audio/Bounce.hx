package drum.audio;

import drum.State.TrackState;
import drum.audio.ToneApi;
import js.lib.Float32Array;
import js.lib.Promise;

/** What a bounce plays: the machine's settings, and the sequence's patterns in play order, one bar each. */
typedef BouncePlan = {
	final tempo:Int;
	final swing:Int;
	final drive:Int;
	final reverb:Int;
	final bars:Array<Array<TrackState>>;
}

/**
 * One pass of the sequence, rendered faster than real time into stereo sound that loops seamlessly
 * ("bouncing", as studios call it). The same parts as live playback, built afresh in Tone's offline
 * context: a master chain (drive, reverb, clipper) and a sample bank lent the recordings already decoded.
 * Each part's level goes into its hits' gain, as the parts' levels can differ from pattern to pattern.
 *
 * To loop without a click, two passes are rendered and the second kept: by then the reverb and the long
 * sounds from the end of the first are ringing on into its start, as they do when the loop comes round.
 * A third pass's first bar is scheduled too, so hits nudged early from the top land at the end.
 */
class Bounce {
	static inline final PASSES_SCHEDULED = 3;

	public static function render(tone:ToneApi, plan:BouncePlan, recordings:SampleBank):Promise<Array<Float32Array>> {
		final passSeconds = barSeconds(plan) * plan.bars.length;
		return tone.Offline(_ -> {
			final master = new MasterChain(tone);
			master.setDrive(plan.drive);
			master.setReverb(plan.reverb);
			final bank = new SampleBank(tone, Kit.VOICES, "", master.input);
			bank.borrow(recordings);
			scheduleEveryPass(bank, plan, passSeconds);
			return master.ready();
		}, 2 * passSeconds).then(sound -> secondPass(sound, passSeconds));
	}

	static function barSeconds(plan:BouncePlan):Float {
		return Limits.STEPS * Timing.sixteenthSeconds(plan.tempo);
	}

	static function scheduleEveryPass(bank:SampleBank, plan:BouncePlan, passSeconds:Float) {
		for (pass in 0...PASSES_SCHEDULED)
			for (bar in 0...plan.bars.length) scheduleBar(bank, plan, plan.bars[bar], pass * passSeconds + bar * barSeconds(plan));
	}

	/** Every step of one bar, swung as the live clock swings it. */
	static function scheduleBar(bank:SampleBank, plan:BouncePlan, parts:Array<TrackState>, barStart:Float) {
		final sixteenth = Timing.sixteenthSeconds(plan.tempo);
		for (step in 0...Limits.STEPS) {
			final stepStart = barStart + step * sixteenth + Timing.swingDelay(step, plan.swing, sixteenth);
			final stepSeconds = Timing.stepSeconds(step, plan.swing, sixteenth);
			for (part in parts) scheduleHit(bank, part, step, stepStart, stepSeconds, plan.tempo);
		}
	}

	static function scheduleHit(bank:SampleBank, part:TrackState, step:Int, stepStart:Float, stepSeconds:Float, tempo:Int) {
		final hit = part.steps[step];
		if (!hit.on || part.muted) return;
		final start = stepStart + Timing.nudgeSeconds(hit.nudge, tempo);
		if (start < 0) return; // nudged early from the very first step: the third pass plays it at the end
		final gain = Loudness.velocityGain(hit.velocity) * part.volume / 100;
		bank.playRecording(part.id, part.sample, SampleBank.request(part, hit, start, stepSeconds, gain));
	}

	/** The second half of the render, left and right. */
	static function secondPass(sound:ToneAudioBuffer, passSeconds:Float):Array<Float32Array> {
		final start = Math.round(passSeconds * sound.sampleRate);
		return [for (channel in 0...2) sound.toArray(channel).slice(start, 2 * start)];
	}
}
