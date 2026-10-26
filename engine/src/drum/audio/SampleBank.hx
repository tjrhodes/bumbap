package drum.audio;

import drum.Kit.Voice;
import drum.audio.HitShape.HitPlan;
import drum.audio.ToneApi;
import js.lib.Promise;

/** A recording ready to play both ways round. */
typedef LoadedSample = {
	final forwards:ToneAudioBuffer;
	/** Trimmed of its silent tail, then flipped, so a reversed hit starts at once. */
	final backwards:ToneAudioBuffer;
	/** How long it actually sounds, without the silent tail. */
	final soundSeconds:Float;
}

/** What the machine asks for when a step comes round. */
typedef HitRequest = {
	final startTime:Float;
	final gain:Float;
	final rate:Float;
	final lengthShare:Float;
	final reversed:Bool;
	final stepSeconds:Float;
}

/**
 * The drum sounds. Each voice has its own volume fader feeding the master
 * chain; every hit is a fresh one-shot with its own gain, rate and fades,
 * which lets two steps of the same drum play differently and lets an open
 * hat ring on under the next hit.
 *
 * Recordings load when first needed (the 808 knobs choose between dozens)
 * and are kept, so turning a knob back is instant. A voice keeps playing its
 * old recording until the new one is ready.
 */
class SampleBank {
	final tone:ToneApi;
	final folderUrl:String;
	final faders = new Map<String, ToneVolume>();
	final loads = new Map<String, Promise<LoadedSample>>();
	final current = new Map<String, LoadedSample>();
	final wanted = new Map<String, String>();
	final everyLoaded:Array<LoadedSample> = [];

	public function new(tone:ToneApi, voices:Array<Voice>, folderUrl:String, output:ToneNode) {
		this.tone = tone;
		this.folderUrl = folderUrl;
		for (voice in voices) {
			final fader:ToneVolume = ToneNodes.create(tone.Volume, 0);
			fader.connect(output);
			faders[voice.id] = fader;
		}
	}

	/**
	 * Makes a recording (e.g. "BD2550") the voice's sound once it has loaded.
	 * If the knob moved on meanwhile, the later choice wins whatever order the
	 * downloads finish in.
	 */
	public function useSample(voiceId:String, sampleName:String):Promise<Void> {
		wanted[voiceId] = sampleName;
		return fetch(sampleName).then(sample -> {
			if (wanted[voiceId] == sampleName) current[voiceId] = sample;
		});
	}

	/** Plays one hit; a voice whose recording has not loaded yet stays silent. */
	public function play(voiceId:String, hit:HitRequest) {
		final sample = current[voiceId];
		if (sample == null) return;
		final plan = hit.reversed
			? HitShape.backwards(sample.soundSeconds, hit.rate, hit.lengthShare, hit.stepSeconds)
			: HitShape.forwards(sample.soundSeconds, hit.rate, hit.lengthShare);
		final source = newSource(voiceId, hit.reversed ? sample.backwards : sample.forwards, hit.rate, plan);
		source.start(hit.startTime + plan.startDelay, plan.offset, plan.stopAfter ?? js.Lib.undefined, hit.gain);
	}

	public function setVolume(voiceId:String, percent:Int) {
		faders[voiceId].volume.value = Loudness.volumeDecibels(percent);
	}

	public function dispose() {
		for (sample in everyLoaded) {
			sample.forwards.dispose();
			sample.backwards.dispose();
		}
		for (fader in faders) fader.dispose();
	}

	/** Each file is downloaded once; asking again gives the same promise. */
	function fetch(sampleName:String):Promise<LoadedSample> {
		if (!loads.exists(sampleName)) {
			final buffer:ToneAudioBuffer = ToneNodes.create(tone.ToneAudioBuffer);
			loads[sampleName] = buffer.load('$folderUrl$sampleName.wav').then(prepare);
		}
		return loads[sampleName];
	}

	/** Finds where the sound ends and makes the reversed copy from just that part. */
	function prepare(forwards:ToneAudioBuffer):LoadedSample {
		final soundSeconds = Silence.soundEndSeconds(forwards.toArray(0), forwards.sampleRate);
		final backwards = forwards.slice(0, soundSeconds);
		backwards.reverse = true;
		final sample:LoadedSample = {forwards: forwards, backwards: backwards, soundSeconds: soundSeconds};
		everyLoaded.push(sample);
		return sample;
	}

	/** A one-shot of this buffer, plugged into its voice's fader and shaped by the plan. */
	function newSource(voiceId:String, buffer:ToneAudioBuffer, rate:Float, plan:HitPlan):ToneBufferSource {
		final source:ToneBufferSource = ToneNodes.create(tone.ToneBufferSource, buffer);
		source.connect(faders[voiceId]);
		source.playbackRate.value = rate;
		source.fadeIn = plan.fadeIn;
		source.fadeOut = plan.fadeOut;
		source.onended = _ -> {}; // having an onended at all makes Tone free the source once it has finished
		return source;
	}
}
