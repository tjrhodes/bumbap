import drum.audio.ToneApi;
import js.lib.Promise;

/** A sample being started: which voice, when, how loud, and into which node. */
typedef Hit = {
	final voice:String;
	final audioTime:Float;
	final gain:Float;
	final into:FakeNode;
	/** The sample as it was played: reversed copies are flipped and trimmed. */
	final sample:FakeSample;
	/** Where in the sample it started and how much was played (null: to the end). */
	final offset:Float;
	final duration:Null<Float>;
	final fadeIn:Float;
	final fadeOut:Float;
	final rate:Float;
}

/**
 * Stands in for Tone.js in the tests. It makes no sound and keeps no time;
 * it records what the engine builds and plays, and lets a test play the
 * part of the clock (`sixteenth`) and of the screen (`nextFrame`).
 */
class FakeTone {
	/** The fake being used by the test running now; the fake nodes report to it. */
	public static var current(default, null):FakeTone;

	public final api:ToneApi;
	public final bpm = {value: 120.0};
	public final hits:Array<Hit> = [];
	/** Every file asked for, in order. */
	public final loads:Array<String> = [];
	/** While true, downloads wait in `waitingLoads` until the test finishes them, in any order. */
	public var holdLoads = false;
	/** The context the engine asked Tone to use, and how far behind the speakers pretend to be. */
	public var contextInUse(default, null):Null<FakeContext>;
	public var speakerDelay = 0.0;
	/** How long the last offline render was asked to be, in seconds (0 before any). */
	public var offlineSeconds(default, null) = 0.0;
	/** The audio time each playhead update was scheduled for. */
	public final drawTimes:Array<Float> = [];
	public final waitingLoads = new Map<String, () -> Void>();
	public final nodes:Array<FakeNode> = [];
	public var transportRunning(default, null) = false;
	public var repeatCleared(default, null) = false;

	var onSixteenth:Null<Float->Void>;
	var waitingFrames:Array<() -> Void> = [];

	/** Tone's classes, as the engine builds them; their fakes report back to `current`. */
	static final FAKE_CLASSES = {
		ToneAudioBuffer: FakeSample,
		ToneBufferSource: FakeSource,
		Volume: FakeVolume,
		WaveShaper: FakeShaper,
		Filter: FakeFilter,
		Reverb: FakeReverb,
		Gain: FakeGain,
		Context: FakeContext
	};

	public function new() {
		current = this;
		api = cast js.lib.Object.assign({}, FAKE_CLASSES, clockAndContext());
	}

	/** Tone's functions: audio unlocking, loading, the transport, the screen and the context. */
	function clockAndContext():Dynamic {
		return {
			start: () -> Promise.resolve(null),
			loaded: () -> Promise.resolve(null),
			getTransport: transport,
			getDraw: draw,
			setContext: context -> contextInUse = context,
			getContext: () -> {sampleRate: FakeSample.RATE, rawContext: {outputLatency: speakerDelay}},
			Offline: renderOffline
		};
	}

	/**
	 * Tone's offline rendering: runs the callback (its hits land in `hits` like live ones), then gives back a
	 * ramp of values as long as asked for, so a test can see which part of it was kept.
	 */
	function renderOffline(callback:Dynamic->Promise<Dynamic>, seconds:Float):Promise<FakeSample> {
		offlineSeconds = seconds;
		final frames = Math.round(seconds * FakeSample.RATE);
		return callback(null).then(_ -> new FakeSample("render", [for (frame in 0...frames) frame / frames]));
	}

	/** Called by every fake download: resolves at once, unless the test is holding downloads. */
	public function finishLoad(url:String, sample:FakeSample):Promise<FakeSample> {
		loads.push(url);
		if (!holdLoads) return Promise.resolve(sample);
		return new Promise((resolve, _) -> waitingLoads[url] = () -> resolve(sample));
	}

	/** Plays the clock: one sixteenth note falling on this grid time. */
	public function sixteenth(gridTime:Float) {
		if (transportRunning) onSixteenth(gridTime);
	}

	/** Plays a late clock: a tick Tone delivers after stop() because its transport stops a moment ahead. */
	public function sixteenthAfterStop(gridTime:Float) {
		onSixteenth(gridTime);
	}

	/** Plays the screen: runs every playhead update waiting for a frame. */
	public function nextFrame() {
		final frame = waitingFrames;
		waitingFrames = [];
		for (update in frame) update();
	}

	/** The first node of this kind the engine made, e.g. "Reverb"; for "WaveShaper" that is the overdrive. */
	public function first(kind:String):FakeNode {
		return [for (node in nodes) if (node.kind == kind) node][0];
	}

	function transport():ToneTransport {
		return {
			bpm: bpm,
			scheduleRepeat: (callback, _) -> {
				onSixteenth = callback;
				return 7;
			},
			clear: _ -> repeatCleared = true,
			start: () -> transportRunning = true,
			stop: () -> transportRunning = false
		};
	}

	function draw():ToneDraw {
		return {
			schedule: (update, audioTime) -> {
				drawTimes.push(audioTime);
				waitingFrames.push(update);
			},
			cancel: (?after:Float) -> waitingFrames = []
		};
	}
}

/** Any fake audio node: remembers its settings and what it is plugged into. */
class FakeNode {
	public final kind:String;
	public final options:Dynamic;
	public final volume = {value: 0.0};
	public final frequency = {value: 0.0};
	public final wet = {value: 0.0};
	public final gain = {value: 0.0};
	/** A reverb's room, worked out at once. */
	public final ready:Promise<Dynamic> = Promise.resolve(null);
	public var curve:Dynamic;
	public var oversample = "none";
	public var output(default, null):Null<FakeNode>;
	public var disposed(default, null) = false;

	public function new(kind:String, options:Dynamic) {
		this.kind = kind;
		this.options = options;
		FakeTone.current.nodes.push(this);
	}

	public function connect(destination:FakeNode):FakeNode {
		output = destination;
		return this;
	}

	/** Plugs each node into the next, as Tone does. */
	public function chain(rest:haxe.Rest<FakeNode>):FakeNode {
		var from = this;
		for (next in rest) {
			from.connect(next);
			from = next;
		}
		return this;
	}

	public function toDestination():FakeNode {
		return this;
	}

	public function dispose() {
		disposed = true;
	}
}

class FakeVolume extends FakeNode {
	public function new(decibels:Float) {
		super("Volume", decibels);
		volume.value = decibels;
	}
}

class FakeShaper extends FakeNode {
	public function new(startingCurve:Dynamic) {
		super("WaveShaper", null);
		curve = startingCurve;
	}
}

class FakeFilter extends FakeNode {
	public function new(settings:Dynamic) {
		super("Filter", settings);
		frequency.value = settings.frequency;
	}
}

class FakeGain extends FakeNode {
	public function new(startingGain:Float) {
		super("Gain", startingGain);
		gain.value = startingGain;
	}
}

class FakeContext {
	public final options:Dynamic;

	public function new(options:Dynamic) {
		this.options = options;
	}
}

class FakeReverb extends FakeNode {
	public function new(settings:Dynamic) {
		super("Reverb", settings);
		wet.value = settings.wet;
	}
}

/** One playing of a sample: starting it logs a hit. */
class FakeSource extends FakeNode {
	public var onended:Dynamic;
	public var fadeIn = 0.0;
	public var fadeOut = 0.0;
	public final playbackRate = {value: 1.0};

	public function new(sample:FakeSample) {
		super("Source", sample);
	}

	public function start(audioTime:Float, offset:Float, duration:Dynamic, gain:Float) {
		FakeTone.current.hits.push({
			voice: options.name, audioTime: audioTime, gain: gain, into: output, sample: options,
			offset: offset, duration: duration, fadeIn: fadeIn, fadeOut: fadeOut, rate: playbackRate.value
		});
	}
}

/**
 * A sample of ten values at ten values a second: a short loud-to-quiet sound,
 * then a silent tail, so trimming and flipping can be checked by eye. Every
 * file loads as this same sound, named after the file ("BD2550").
 */
class FakeSample {
	public static final SOUND_THEN_SILENCE = [1.0, 0.5, 0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	public static inline final RATE = 10.0;

	public var name(default, null):String;
	public final sampleRate = RATE;
	public var values(default, null):Array<Float>;
	/** Plain fields, as the engine reads them straight off the object. */
	public var duration:Float;
	/** Real Tone flips the data in a setter; the engine sets this as a plain field, so the fake reads it when played. */
	public var reverse = false;

	public function new(?name:String, ?values:Array<Float>) {
		this.name = name;
		this.values = values ?? [];
		duration = this.values.length / RATE;
	}

	/** "Downloads" the file: at once, or when the test lets it (see FakeTone.holdLoads). */
	public function load(url:String):Promise<FakeSample> {
		name = url.split("/").pop().split(".")[0];
		values = SOUND_THEN_SILENCE.copy();
		duration = values.length / RATE;
		return FakeTone.current.finishLoad(url, this);
	}

	public function toArray(channel:Int):js.lib.Float32Array {
		return new js.lib.Float32Array(values);
	}

	public function slice(start:Float, end:Float):FakeSample {
		return new FakeSample(name, values.slice(Math.round(start * RATE), Math.round(end * RATE)));
	}

	/** The values as a source would play them. */
	public function played():Array<Float> {
		return reverse ? [for (index in 0...values.length) values[values.length - 1 - index]] : values;
	}

	public function dispose() {}
}
