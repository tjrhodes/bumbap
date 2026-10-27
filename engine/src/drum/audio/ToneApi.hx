package drum.audio;

import haxe.extern.Rest;
import js.lib.Float32Array;
import js.lib.Promise;

/**
 * The small part of Tone.js (v15) the engine uses, described as types.
 *
 * Front ends pass the Tone module in (`new DrumMachine({tone: Tone, …})`)
 * instead of the engine importing it. That keeps the engine free of
 * import paths, so it drops into Vite, the Angular CLI or a plain script
 * tag unchanged, and lets the tests hand it a fake Tone that just records.
 */
typedef ToneApi = {
	/** Unlocks audio; browsers only allow this inside a click or key press. */
	function start():Promise<Dynamic>;
	/** Resolves when every sample created so far is downloaded and decoded. */
	function loaded():Promise<Dynamic>;
	function getTransport():ToneTransport;
	function getDraw():ToneDraw;
	/** Makes this Tone's audio context the one every later object uses. */
	function setContext(context:Dynamic):Void;
	function getContext():ToneContext;
	/**
	 * Renders whatever the callback builds and schedules, faster than real time, into a buffer `duration`
	 * seconds long. Tone makes its offline context the current one while the callback (and its promise) runs.
	 */
	function Offline(callback:Dynamic->Promise<Dynamic>, duration:Float):Promise<ToneAudioBuffer>;
	/** Tone's classes, built with ToneNodes.create; their instances are typed below. */
	final ToneAudioBuffer:Dynamic;
	final ToneBufferSource:Dynamic;
	final Volume:Dynamic;
	final WaveShaper:Dynamic;
	final Filter:Dynamic;
	final Reverb:Dynamic;
	final Gain:Dynamic;
	final Context:Dynamic;
}

/** Tone's audio context, and the browser's own one inside it. */
typedef ToneContext = {
	final sampleRate:Float;
	final rawContext:{
		/** Seconds from the audio clock to the speakers; not every browser reports it. */
		final ?outputLatency:Float;
		final ?baseLatency:Float;
	};
}

/** A number Tone can change while sound plays. */
typedef ToneParam = {
	var value:Float;
}

/** Anything in Tone's audio graph. */
typedef ToneNode = {
	function connect(destination:ToneNode):ToneNode;
	function chain(nodes:Rest<ToneNode>):ToneNode;
	function toDestination():ToneNode;
	function dispose():Dynamic;
}

typedef ToneVolume = ToneNode & {final volume:ToneParam;};
typedef ToneFilter = ToneNode & {final frequency:ToneParam;};
typedef ToneReverb = ToneNode & {
	final wet:ToneParam;
	/** Resolves once the room's echo (its impulse response) has been worked out; until then it is silent. */
	final ready:Promise<Dynamic>;
};
typedef ToneGain = ToneNode & {final gain:ToneParam;};

typedef ToneWaveShaper = ToneNode & {
	/** null passes the sound straight through, at no cost. */
	var curve:Null<Float32Array>;
	var oversample:String;
}

/** One playing of one sample. It can be started once; Tone frees it after it ends. */
typedef ToneBufferSource = ToneNode & {
	var onended:Dynamic->Void;
	/** Seconds to fade in from silence when started, and to fade out once stopped. */
	var fadeIn:Float;
	var fadeOut:Float;
	/** 1 is the sample's own speed; 2 an octave up (and twice as short). */
	final playbackRate:ToneParam;
	/** duration is in real seconds, or undefined to play to the end. */
	function start(audioTime:Float, offset:Float, duration:Dynamic, gain:Float):Dynamic;
}

/** One decoded sample. */
typedef ToneAudioBuffer = {
	final sampleRate:Float;
	/** Length in seconds. */
	final duration:Float;
	/** Setting it to true flips the sample in place. */
	var reverse:Bool;
	function toArray(channel:Int):js.lib.Float32Array;
	/** A copy of part of the sample, from start to end in seconds. */
	function slice(start:Float, end:Float):ToneAudioBuffer;
	/** Downloads and decodes a file into this buffer. */
	function load(url:String):Promise<ToneAudioBuffer>;
	function dispose():Dynamic;
}

/** Tone's musical clock: tempo, start/stop and repeating events. */
typedef ToneTransport = {
	final bpm:ToneParam;
	function scheduleRepeat(callback:Float->Void, interval:String):Int;
	function clear(eventId:Int):Dynamic;
	function start():Dynamic;
	function stop():Dynamic;
}

/** Runs a callback on the animation frame nearest to an audio time. */
typedef ToneDraw = {
	function schedule(callback:() -> Void, audioTime:Float):Dynamic;
	function cancel(?after:Float):Dynamic;
}

/** Builds Tone objects from the classes on the module the front end passed in. */
class ToneNodes {
	public static function create<T>(toneClass:Dynamic, ?options:Dynamic):T {
		return js.Syntax.construct(toneClass, options);
	}
}
