package drum.audio;

import drum.audio.ToneApi;

/**
 * Everything after the drum faders:
 *
 *     headroom cut → overdrive → its tone filter → trim ─┬──────────────────────┬→ safety clipper → speakers
 *                                                        └→ reverb send → reverb ┘
 *
 * The overdrive comes before the reverb so the tail stays clean. The reverb
 * is a send, fully wet, added to the dry kit: when the send is at zero the
 * browser stops running the reverb altogether. Likewise the overdrive passes
 * the sound straight through at drive 0 (see shapeOverdrive). The safety clipper comes last:
 * drums are almost all attack, which a compressor-style limiter lets straight
 * through, so a soft clip is what keeps loud accents from passing full scale.
 */
class MasterChain {
	static inline final REVERB_SECONDS = 2.2;
	static inline final REVERB_PRE_DELAY_SECONDS = 0.012;
	/** At 100% the room is a little quieter than the dry kit, so it never swamps it. */
	static inline final MOST_REVERB_SEND = 0.6;
	/**
	 * Set for the TR-808 kit: its normal hits peak a few dB under full scale, and
	 * when accents (+6 dB) and several drums land together, the clipper rounds them.
	 */
	static inline final MIX_LEVEL_DB = -4.0;
	/** A straight line from -1 to 1: every sample comes out exactly as it went in. */
	static final PASS_THROUGH = new js.lib.Float32Array([-1.0, 1.0]);

	/** Where every drum fader plugs in. */
	public final input:ToneNode;

	final headroom:ToneVolume;
	final overdrive:ToneWaveShaper;
	final toneFilter:ToneFilter;
	final trim:ToneVolume;
	final reverbSend:ToneGain;
	final reverb:ToneReverb;
	final clipper:ToneWaveShaper;
	/** The drive the overdrive is set to; setting the same value again touches nothing. */
	var drivePercent = Limits.DRIVE.initial;
	var reverbPercent = Limits.REVERB.initial;

	public function new(tone:ToneApi) {
		headroom = ToneNodes.create(tone.Volume, -Saturation.HEADROOM_DB);
		overdrive = shaper(tone, null, "2x"); // starts at drive 0: no curve at all, so the browser does no work
		toneFilter = ToneNodes.create(tone.Filter, {type: "lowpass", rolloff: -12, Q: 0.5, frequency: Saturation.cutoffHz(Limits.DRIVE.initial)});
		trim = ToneNodes.create(tone.Volume, trimDecibels(Limits.DRIVE.initial));
		reverbSend = ToneNodes.create(tone.Gain, 0);
		reverb = ToneNodes.create(tone.Reverb, {decay: REVERB_SECONDS, preDelay: REVERB_PRE_DELAY_SECONDS, wet: 1});
		clipper = shaper(tone, Saturation.clipCurve(), "none");
		headroom.chain(overdrive, toneFilter, trim, clipper);
		trim.chain(reverbSend, reverb, clipper);
		clipper.toDestination();
		input = headroom;
	}

	public function setDrive(percent:Int) {
		if (percent == drivePercent) return;
		drivePercent = percent;
		shapeOverdrive(percent);
		setDriveLevels(percent);
	}

	/** The tone filter and the level trim that go with a drive setting. */
	function setDriveLevels(percent:Int) {
		toneFilter.frequency.value = Saturation.cutoffHz(percent);
		trim.volume.value = trimDecibels(percent);
	}

	/** Sets the levels again as they stand, once the browser's audio is running (see DrumMachine.applyMixerAgain). */
	public function applyAgain() {
		setDriveLevels(drivePercent);
		setReverb(reverbPercent);
	}

	/**
	 * Drive 0 gets the straight-line curve, with oversampling off, so the sound
	 * passes through unchanged and nearly free. The curve is never set back to
	 * null: a Tone.js WaveShaper whose curve is set to null after it is made goes
	 * silent (found in the browser: the wrapper under Tone's nodes mishandles it).
	 * A shared pattern at drive 0 used to switch the whole machine off this way.
	 */
	function shapeOverdrive(percent:Int) {
		overdrive.curve = percent == 0 ? PASS_THROUGH : Saturation.curve(percent);
		overdrive.oversample = percent == 0 ? "none" : "2x";
	}

	public function setReverb(percent:Int) {
		reverbPercent = percent;
		reverbSend.gain.value = MOST_REVERB_SEND * percent / 100;
	}

	public function dispose() {
		final everyNode:Array<ToneNode> = [headroom, overdrive, toneFilter, trim, reverbSend, reverb, clipper];
		for (node in everyNode) node.dispose();
	}

	/**
	 * Shaping makes new harmonics; the overdrive oversamples (2x: on a phone, 4x
	 * cost more than it was worth) so they do not fold back as grit. The clipper
	 * must not: the oversampling filter overshoots squashed peaks, which would
	 * push them past full scale again.
	 */
	static function shaper(tone:ToneApi, curve:Null<js.lib.Float32Array>, oversample:String):ToneWaveShaper {
		final made:ToneWaveShaper = ToneNodes.create(tone.WaveShaper, curve);
		made.oversample = oversample;
		return made;
	}

	static function trimDecibels(drivePercent:Int):Float {
		return MIX_LEVEL_DB + Saturation.trimDecibels(drivePercent);
	}
}
