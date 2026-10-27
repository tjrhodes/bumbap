package drum;

import drum.State.LoadStatus;
import drum.State.MachineState;
import drum.State.Pattern;
import drum.State.SavedMachine;
import drum.State.SequenceTool;
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
 * The one object every front end talks to. It owns the eight patterns and
 * the sequence they play in, the clock and the sounds, and tells the UI about changes on
 * two channels:
 *
 * - `subscribe`: a fresh, frozen snapshot after every edit (rare, cheap
 *   to compare: the same object comes back until something changes);
 * - `onStep`: the playhead, up to ~13 times a second, kept apart so each
 *   framework can choose how to draw it without re-rendering the grid.
 *
 * The pattern shown (the one playing, or when stopped the one on the keys)
 * lives in the tracks, where it is played and edited; the other seven wait as
 * saved settings, and the shown one is copied back to its slot before it is
 * swapped, copied or packed into a link.
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
	final patterns:Array<Pattern>;
	final sequence = new Sequence();
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
	/** Bars begun since Play: the first plays the pattern Play started on, each later one the sequence's next. */
	var barsStarted = 0;
	/** A new pattern has taken over the sound; the UI hears about it when its first step is heard. */
	var newPatternToShow = false;
	/** Which of the sequence's small buttons is on, and what it has been told so far. */
	var tool:SequenceTool = Off;
	var copyFrom = Sequence.NONE;
	var selectStartsAgain = true;

	public function new(options:MachineOptions) {
		tone = options.tone;
		Latency.preferSmoothPlayback(tone);
		tracks = [for (voice in Kit.VOICES) new Track(voice)];
		patterns = [for (index in 0...Limits.PATTERNS) index == 0 ? tracksNow() : Patterns.blank()];
		master = new MasterChain(tone);
		samples = new SampleBank(tone, Kit.VOICES, options.samplesUrl, master.input);
		clock = new StepClock(tone, soundStep, stepHeard);
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

	/** Downloads and decodes the recordings every pattern's 808 knobs choose; Play is refused until this is done. */
	public function load():Promise<Void> {
		final downloads = tracks.map(useChosenSample).concat(preloadEveryPatternsSamples());
		return Promise.all(downloads).then(_ -> setStatus(Ready), error -> {
			setStatus(Failed);
			js.Browser.console.error("Drum samples failed to load", error);
		});
	}

	/** Must be called from a click or key press: browsers only unlock audio then. */
	public function play():Promise<Void> {
		if (playing || status != Ready) return Promise.resolve();
		final first = sequence.start();
		if (first != sequence.shown) showPattern(first);
		barsStarted = 0;
		playing = true;
		return tone.start().then(_ -> {
			applyMixerAgain();
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
		sequence.show(sequence.shown); // anything queued is dropped: Play starts again from the sequence
		newPatternToShow = false;
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

	/** Empties the grid of the pattern shown; tempo, swing, effects and the mix are kept. */
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

	// ── Patterns and their sequence (version 2) ───────────────────────

	/** Just this pattern (0–7) from now on; while playing, it takes over at the end of the bar. */
	public function choosePattern(index:Int) {
		if (!Patterns.exists(index)) return;
		choose(index);
		changed();
	}

	/** Adds one pattern at the end of the sequence, or takes it out (shift-click); the sequence keeps at least one. */
	public function toggleInSequence(index:Int) {
		sequence.toggle(index);
		changed();
	}

	/** The sequence, in the order it plays, repeats allowed (up to 16); hold one button and tap others, say. */
	public function setSequence(indexes:Array<Int>) {
		sequence.replace(indexes);
		changed();
	}

	/** Copies one pattern over another, steps and part sounds; copied onto the one shown, it is heard at once. */
	public function copyPattern(from:Int, to:Int) {
		copy(from, to);
		changed();
	}

	/** Makes a pattern blank: no steps, and every part as it starts. Cleared while shown, the keys empty at once. */
	public function clearPattern(index:Int) {
		blank(index);
		changed();
	}

	/** The sequence's Select, Copy and Clear buttons: turns one on (and any other off), or off if it was on. */
	public function toggleTool(name:SequenceTool) {
		tool = tool == name ? Off : name;
		copyFrom = Sequence.NONE;
		selectStartsAgain = true;
		changed();
	}

	/** A tap on a pattern button, which means what the tool that is on says (none: play it; with Shift, sequence it). */
	public function tapPattern(index:Int, shift:Bool) {
		if (!Patterns.exists(index)) return;
		switch (tool) {
			case Off: if (shift) sequence.toggle(index); else choose(index);
			case Select: selectTap(index);
			case Copy: copyTap(index);
			case Clear: blank(index);
		}
		if (tool == Clear) tool = Off;
		changed();
	}

	/** Restores a shared machine; returns false (and changes nothing) if the code is invalid. */
	public function loadCode(code:String):Bool {
		final saved = PatternCode.decode(code);
		if (saved == null) return false;
		for (index in 0...Limits.PATTERNS) patterns[index] = saved.patterns[index];
		sequence.restore(saved.shown, saved.sequence);
		restoreTracks(patterns[saved.shown]);
		preloadEveryPatternsSamples();
		applyTempo(saved.tempo);
		applySwing(saved.swing);
		applyDrive(saved.drive);
		applyReverb(saved.reverb);
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
		if (step == 0) moveOnAtTheBar();
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

	/** Each bar after the first plays the sequence's next pattern; the keys change when that bar is heard. */
	function moveOnAtTheBar() {
		if (barsStarted++ == 0) return;
		final next = sequence.advance();
		if (next == sequence.shown) return;
		showPattern(next);
		newPatternToShow = true;
	}

	/** A step is being heard: a new pattern is published with its first step, then the playhead moves. */
	function stepHeard(step:Int) {
		if (step == 0 && newPatternToShow) {
			newPatternToShow = false;
			changed();
		}
		stepListeners.tell(step);
	}

	function choose(index:Int) {
		sequence.choose(index, playing);
		if (!playing) showPattern(index);
	}

	function copy(from:Int, to:Int) {
		if (!Patterns.exists(from) || !Patterns.exists(to) || from == to) return;
		keepShownPattern();
		patterns[to] = patterns[from]; // patterns are never changed in place, so two slots can share one
		if (to == sequence.shown) restoreTracks(patterns[to]);
	}

	function blank(index:Int) {
		if (!Patterns.exists(index)) return;
		keepShownPattern();
		patterns[index] = Patterns.blank();
		if (index == sequence.shown) restoreTracks(patterns[index]);
	}

	/** Select: the first tap starts the sequence afresh, each tap after it adds to the end. */
	function selectTap(index:Int) {
		if (selectStartsAgain) sequence.replace([index]); else sequence.append(index);
		selectStartsAgain = false;
	}

	/** Copy: the first tap picks the pattern to copy, the second where it goes; then Copy turns itself off. */
	function copyTap(index:Int) {
		if (copyFrom == Sequence.NONE) {
			copyFrom = index;
			return;
		}
		copy(copyFrom, index);
		tool = Off;
		copyFrom = Sequence.NONE;
	}

	/** Puts a pattern on the tracks; the one shown until now is kept in its slot first. */
	function showPattern(index:Int) {
		keepShownPattern();
		restoreTracks(patterns[index]);
		sequence.show(index);
	}

	/** The shown pattern lives in the tracks while it is edited; its slot takes a copy before anything reads it. */
	function keepShownPattern() {
		patterns[sequence.shown] = tracksNow();
	}

	function tracksNow():Pattern {
		return [for (track in tracks) track.toState()];
	}

	/** The tracks take over a pattern: steps, levels, mutes, pitch, length and the recordings its 808 knobs choose. */
	function restoreTracks(pattern:Pattern) {
		for (index in 0...tracks.length) tracks[index].restore(pattern[index]);
		for (track in tracks) useChosenSample(track).catchError(error -> js.Browser.console.error("808 sample failed to load", error));
		applyVolumesToSamples();
	}

	/** Every pattern's recordings, downloaded ahead, so a pattern plays its own sounds the moment its bar comes. */
	function preloadEveryPatternsSamples():Array<Promise<Void>> {
		return [
			for (pattern in patterns) for (index in 0...pattern.length)
				samples.preload(Kit.sampleName(Kit.VOICES[index], pattern[index].dials))
		];
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

	/**
	 * Levels set before the browser lets the audio run (a pattern loaded from the
	 * address, say) do not all reach the sound: a loaded drive played without its
	 * level trim, louder and harsher than the same drive set on the knob. So once
	 * the audio runs, the faders, drive and reverb are applied again as they stand.
	 */
	function applyMixerAgain() {
		applyVolumesToSamples();
		master.applyAgain();
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
		final everyPattern:Array<Pattern> = [for (index in 0...Limits.PATTERNS) index == sequence.shown ? cast trackStates : patterns[index]];
		return freeze({
			status: status, playing: playing, code: PatternCode.encode(saved(everyPattern)),
			tempo: tempo, swing: swing, drive: drive, reverb: reverb, tracks: trackStates,
			pattern: sequence.shown, sequence: sequence.patterns.copy(), sequencePlace: sequence.position, nextPattern: sequence.queued,
			patternHasSteps: everyPattern.map(Patterns.hasSteps), tool: tool, copyFrom: copyFrom
		});
	}

	/** What a link keeps: the machine's settings, the eight patterns and their sequence. */
	function saved(everyPattern:Array<Pattern>):SavedMachine {
		return {
			tempo: tempo, swing: swing, drive: drive, reverb: reverb,
			patterns: everyPattern, shown: sequence.shown, sequence: sequence.patterns
		};
	}

	/** Frozen all the way down (steps are frozen when made), so a front end cannot change a snapshot by accident. */
	static function freeze(state:MachineState):MachineState {
		for (track in state.tracks) js.lib.Object.freeze(js.lib.Object.freeze(track).steps);
		js.lib.Object.freeze(state.tracks);
		js.lib.Object.freeze(state.sequence);
		js.lib.Object.freeze(state.patternHasSteps);
		return js.lib.Object.freeze(state);
	}
}
