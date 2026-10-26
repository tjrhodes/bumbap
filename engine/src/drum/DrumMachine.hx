package drum;

import drum.State.LoadStatus;
import drum.State.MachineState;
import drum.State.Pattern;
import drum.State.StepSettings;
import drum.audio.HitShape;
import drum.audio.Latency;
import drum.audio.MasterChain;
import drum.audio.SampleBank;
import drum.audio.StepClock;
import drum.audio.ToneApi;
import js.lib.Promise;

/** What a front end hands the machine when it builds one. */
typedef MachineOptions = {
	/** The Tone.js module: `import * as Tone from "tone"`. */
	final tone:ToneApi;
	/** Folder the eight samples are served from, ending in "/". */
	final samplesUrl:String;
}

/**
 * The one object every front end talks to. It owns the pattern, the
 * clock and the sounds, and tells the UI about changes on two channels:
 *
 * - `subscribe`: a fresh, frozen snapshot after every edit (rare, cheap
 *   to compare: the same object comes back until something changes);
 * - `onStep`: the playhead, up to ~13 times a second, kept apart so each
 *   framework can choose how to draw it without re-rendering the grid.
 *
 * Building one sets Tone's audio context (see Latency), so build it before
 * making any Tone objects of your own.
 */
@:expose("DrumMachine")
class DrumMachine {
	/** The ranges and the timing resolution, for building controls without repeating numbers. */
	public static final limits = {
		steps: Limits.STEPS,
		ticksPerBeat: Limits.TICKS_PER_BEAT,
		tempo: Limits.TEMPO,
		swing: Limits.SWING,
		volume: Limits.VOLUME,
		velocity: Limits.VELOCITY,
		nudge: Limits.NUDGE,
		drive: Limits.DRIVE,
		reverb: Limits.REVERB,
		pitch: Limits.PITCH,
		length: Limits.LENGTH,
		dial: Limits.DIAL
	};

	final tracks:Array<Track>;
	final tone:ToneApi;
	final master:MasterChain;
	final samples:SampleBank;
	final clock:StepClock;
	final stateListeners = new Listeners<MachineState>();
	final stepListeners = new Listeners<Int>();
	var status:LoadStatus = Loading;
	var playing = false;
	var tempo = Limits.TEMPO.initial;
	var swing = Limits.SWING.initial;
	var drive = Limits.DRIVE.initial;
	var reverb = Limits.REVERB.initial;
	var state:MachineState;

	public function new(options:MachineOptions) {
		tone = options.tone;
		Latency.preferSmoothPlayback(tone);
		tracks = [for (voice in Kit.VOICES) new Track(voice)];
		master = new MasterChain(tone);
		samples = new SampleBank(tone, Kit.VOICES, options.samplesUrl, master.input);
		clock = new StepClock(tone, soundStep, step -> stepListeners.tell(step));
		clock.setTempo(tempo);
		applyVolumesToSamples();
		state = snapshot();
	}

	// ── Reading ────────────────────────────────────────────────────────

	/** The current snapshot; the same object until something changes. */
	public function getState():MachineState {
		return state;
	}

	/** Hears about every change; returns the function that stops listening. */
	public function subscribe(listener:MachineState->Void):() -> Void {
		return stateListeners.add(listener);
	}

	/** Hears the playhead: step 0–15 as it sounds, -1 when stopped. */
	public function onStep(listener:Int->Void):() -> Void {
		return stepListeners.add(listener);
	}

	// ── Sound ──────────────────────────────────────────────────────────

	/** Downloads and decodes the recording each part's knobs choose; Play is refused until this is done. */
	public function load():Promise<Void> {
		return Promise.all(tracks.map(useChosenSample)).then(_ -> setStatus(Ready), error -> {
			setStatus(Failed);
			js.Browser.console.error("Drum samples failed to load", error);
		});
	}

	/** Must be called from a click or key press: browsers only unlock audio then. */
	public function play():Promise<Void> {
		if (playing || status != Ready) return Promise.resolve();
		playing = true;
		return tone.start().then(_ -> {
			if (playing) clock.start(); // the user may have pressed Stop meanwhile
			changed();
		}, _ -> {
			playing = false; // audio could not be unlocked: stay stopped
			changed();
		});
	}

	public function stop() {
		if (!playing) return;
		playing = false;
		clock.stop();
		changed();
	}

	public function togglePlay():Promise<Void> {
		if (!playing) return play();
		stop();
		return Promise.resolve();
	}

	// ── Editing steps ──────────────────────────────────────────────────

	/** Off becomes a fresh hit (velocity 85, on the grid, forwards); on becomes a rest. */
	public function toggleStep(trackIndex:Int, step:Int) {
		editTrack(trackIndex, track -> track.toggleStep(step));
	}

	/** How hard one step hits, 1–100. A step that is off is switched on. */
	public function setStepVelocity(trackIndex:Int, step:Int, velocity:Float) {
		editTrack(trackIndex, track -> track.setVelocity(step, velocity));
	}

	/** How early (negative) or late one step sounds, in ticks. A step that is off is switched on. */
	public function setStepNudge(trackIndex:Int, step:Int, ticks:Float) {
		editTrack(trackIndex, track -> track.setNudge(step, ticks));
	}

	/** Flips one step between playing its sample forwards and backwards. A step that is off is switched on, reversed. */
	public function toggleStepReverse(trackIndex:Int, step:Int) {
		editTrack(trackIndex, track -> track.toggleReverse(step));
	}

	/** Empties the grid; tempo, swing, effects and the mix are kept. */
	public function clear() {
		for (track in tracks) track.clearSteps();
		changed();
	}

	// ── Editing the mix and the whole machine ─────────────────────────

	public function setVolume(trackIndex:Int, percent:Float) {
		editTrack(trackIndex, track -> {
			track.setVolume(percent);
			samples.setVolume(track.voice.id, track.volume);
		});
	}

	/** A part's pitch in semitones, ±12; higher also plays shorter, like a sampler. */
	public function setPitch(trackIndex:Int, semitones:Float) {
		editTrack(trackIndex, track -> track.setPitch(semitones));
	}

	/** How much of a part's sound is heard, 5–100 %: lower fades it out sooner. */
	public function setLength(trackIndex:Int, percent:Float) {
		editTrack(trackIndex, track -> track.setLength(percent));
	}

	/**
	 * Turns one of a part's 808 knobs (0–4), which chooses another recording
	 * from the set. The part keeps its old sound until the new one has loaded.
	 */
	public function setDial(trackIndex:Int, dial:Int, position:Float) {
		editTrack(trackIndex, track -> {
			track.setDial(dial, position);
			useChosenSample(track).catchError(error -> js.Browser.console.error("808 sample failed to load", error));
		});
	}

	/** A muted track is skipped when its steps come round; a hit already sounding rings out. */
	public function toggleMute(trackIndex:Int) {
		editTrack(trackIndex, track -> track.toggleMute());
	}

	public function setTempo(beatsPerMinute:Float) {
		applyTempo(beatsPerMinute);
		changed();
	}

	public function setSwing(percent:Float) {
		applySwing(percent);
		changed();
	}

	/** Warm valve-style overdrive on the whole kit, 0–100. */
	public function setDrive(percent:Float) {
		applyDrive(percent);
		changed();
	}

	/** How much room the kit plays in, 0–100. */
	public function setReverb(percent:Float) {
		applyReverb(percent);
		changed();
	}

	/** Restores a shared pattern; returns false (and changes nothing) if the code is invalid. */
	public function loadCode(code:String):Bool {
		final pattern = PatternCode.decode(code);
		if (pattern == null) return false;
		for (index in 0...tracks.length) tracks[index].restore(pattern.tracks[index]);
		for (track in tracks) useChosenSample(track).catchError(error -> js.Browser.console.error("808 sample failed to load", error));
		applyVolumesToSamples();
		applyTempo(pattern.tempo);
		applySwing(pattern.swing);
		applyDrive(pattern.drive);
		applyReverb(pattern.reverb);
		changed();
		return true;
	}

	/** Stops, releases the clock and the audio graph, and forgets all listeners. */
	public function dispose() {
		stop();
		clock.dispose();
		samples.dispose();
		master.dispose();
		stateListeners.forgetAll();
		stepListeners.forgetAll();
	}

	// ── Inside ─────────────────────────────────────────────────────────

	/** The clock asks for a step to be heard: each unmuted track that plays on it, at its velocity, nudge and direction. */
	function soundStep(step:Int, audioTime:Float) {
		final stepSeconds = Timing.stepSeconds(step, swing, Timing.sixteenthSeconds(tempo));
		for (track in tracks) {
			final hit = track.stepAt(step);
			if (!hit.on || track.muted) continue;
			soundHit(track, hit, audioTime + Timing.nudgeSeconds(hit.nudge, tempo), stepSeconds);
		}
	}

	/** A nudge moves the whole hit; a reversed hit also needs to know how long its step lasts, to end with it. */
	function soundHit(track:Track, hit:StepSettings, startTime:Float, stepSeconds:Float) {
		samples.play(track.voice.id, {
			startTime: startTime,
			gain: Loudness.velocityGain(hit.velocity),
			rate: HitShape.playbackRate(track.pitch),
			lengthShare: track.length / 100,
			reversed: hit.reversed,
			stepSeconds: stepSeconds
		});
	}

	function useChosenSample(track:Track):Promise<Void> {
		return samples.useSample(track.voice.id, track.sampleName());
	}

	/** Ignores track numbers that do not exist, then publishes the change. */
	function editTrack(trackIndex:Int, edit:Track->Void) {
		final track = tracks[trackIndex];
		if (track == null) return;
		edit(track);
		changed();
	}

	// The apply… functions change one setting without publishing, so loadCode publishes once.

	function applyTempo(beatsPerMinute:Float) {
		tempo = Limits.TEMPO.clamp(beatsPerMinute);
		clock.setTempo(tempo);
	}

	function applySwing(percent:Float) {
		swing = Limits.SWING.clamp(percent);
		clock.setSwing(swing);
	}

	function applyDrive(percent:Float) {
		drive = Limits.DRIVE.clamp(percent);
		master.setDrive(drive);
	}

	function applyReverb(percent:Float) {
		reverb = Limits.REVERB.clamp(percent);
		master.setReverb(reverb);
	}

	function applyVolumesToSamples() {
		for (track in tracks) samples.setVolume(track.voice.id, track.volume);
	}

	function setStatus(newStatus:LoadStatus) {
		status = newStatus;
		changed();
	}

	/** Every edit ends here: build the next snapshot and tell the listeners. */
	function changed() {
		state = snapshot();
		stateListeners.tell(state);
	}

	function snapshot():MachineState {
		final trackStates = [for (track in tracks) track.toState()];
		final pattern:Pattern = {tempo: tempo, swing: swing, drive: drive, reverb: reverb, tracks: trackStates};
		return freeze({
			status: status, playing: playing, code: PatternCode.encode(pattern),
			tempo: tempo, swing: swing, drive: drive, reverb: reverb, tracks: trackStates
		});
	}

	/** Frozen all the way down (steps are frozen when made), so a front end cannot change a snapshot by accident. */
	static function freeze(state:MachineState):MachineState {
		for (track in state.tracks) js.lib.Object.freeze(js.lib.Object.freeze(track).steps);
		js.lib.Object.freeze(state.tracks);
		return js.lib.Object.freeze(state);
	}
}
