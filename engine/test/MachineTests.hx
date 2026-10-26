import Check.later;
import Check.test;
import drum.DrumMachine;
import drum.Loudness;
import drum.StepRow;
import drum.audio.Saturation;
import js.lib.Promise;

/** The DrumMachine as a front end uses it, with a fake Tone.js underneath. */
class MachineTests {
	static inline final KICK = 0;
	static inline final SNARE = 1;
	static inline final CLAP = 2;
	static inline final RIM = 7;

	public static function all():Array<Check.Test> {
		return withoutSound().concat(stepEdits()).concat(withSound()).concat(soundControls()).concat(sharingAndTidying());
	}

	static function withoutSound():Array<Check.Test> {
		return [
			test("a new machine has the starter beat and is loading", startsWithStarterBeat),
			test("an edit makes a new snapshot and leaves the old one alone", editsMakeNewSnapshots),
			test("snapshots cannot be changed by a front end", snapshotsAreFrozen),
			test("edits to tracks that do not exist are ignored", strayEditsIgnored),
			test("tempo and swing are clamped and reach the clock", tempoAndSwing),
			test("drive and reverb reach the master chain", driveAndReverb),
			test("drive and reverb at zero cost nothing: no curve, no send", effectsOffCostNothing),
			test("the machine asks for smooth playback before making anything", smoothPlaybackFirst),
			later("the playhead lights as the sound reaches the speakers", playheadWaitsForSpeakers),
			later("the playhead ignores a tick that arrives after Stop", lateTickIgnored)
		];
	}

	static function stepEdits():Array<Check.Test> {
		return [
			test("tapping a step on gives velocity 85 on the grid; tapping again rests it", tappingSteps),
			test("dragging a step's level switches it on and keeps its nudge", velocityEdits),
			test("nudging a step keeps its level and stays within ±16 ticks", nudgeEdits),
			test("flipping a step reverses it, keeps its level and nudge, and flips back", flippingSteps)
		];
	}

	static function withSound():Array<Check.Test> {
		return [
			later("Play does nothing until the samples are loaded", playWaitsForSamples),
			later("each step sounds its hits at the right audio time", stepsSoundOnTime),
			later("velocity sets the gain and nudge moves the hit", velocityAndNudgeAreHeard),
			later("a hit plays through its track's fader", hitsGoThroughTheFader),
			later("a reversed step plays the sample backwards, without its silent tail", reversedStepsPlayBackwards),
			later("a reversed hit fills its step and ends with it, faded in where it cuts in", reversedHitsEndWithTheirStep),
			later("a reversed sample shorter than its step starts late, so it still ends with the step", shortReversedHitsStartLate),
			later("the playhead moves on frames and clears on stop", playheadFollowsFrames),
			later("a muted track is silent", mutedTrackIsSilent)
		];
	}

	static function soundControls():Array<Check.Test> {
		return [
			test("pitch, length and the 808 knobs are clamped; parts without a knob ignore it", soundEdits),
			later("loading fetches the recording each part's knobs choose", loadingFetchesChosenRecordings),
			later("turning an 808 knob swaps the recording once it has loaded", dialsSwapRecordings),
			later("the last knob position wins, whatever order downloads finish in", lastDialWins),
			later("pitch and length shape every hit", pitchAndLengthShapeHits)
		];
	}

	static function sharingAndTidying():Array<Check.Test> {
		return [
			test("a shared code moves a pattern between machines", codesMovePatterns),
			test("an invalid code changes nothing", invalidCodeChangesNothing),
			test("loading a code publishes one snapshot, not one per setting", loadingCodePublishesOnce),
			test("dispose releases the clock, the audio graph and the listeners", disposeReleasesEverything)
		];
	}

	// ── Without sound ─────────────────────────────────────────────────

	static function startsWithStarterBeat() {
		final machine = newMachine().machine;
		final state = machine.getState();
		Check.equal(state.status, Loading, "status");
		Check.equal(state.tracks.length, 8, "eight tracks");
		Check.equal(StepRow.print(state.tracks[KICK].steps), "X.....x...X.....", "kick row, with accents");
		Check.equal('${state.tracks[KICK].sample} ${state.tracks[KICK].dialNames.join("/")}', "BD2550 Tone/Decay", "the kick's recording and 808 knobs");
		Check.equal('${state.tempo} ${state.drive} ${state.reverb}', "100 0 0", "default tempo, no effects");
	}

	static function editsMakeNewSnapshots() {
		final machine = newMachine().machine;
		final before = machine.getState();
		final heard = [];
		machine.subscribe(state -> heard.push(state));
		machine.toggleStep(KICK, 1);
		Check.isTrue(machine.getState() != before, "a new snapshot object");
		Check.equal(machine.getState(), machine.getState(), "the same object until the next change");
		Check.isTrue(machine.getState().tracks[KICK].steps[1].on, "step is on");
		Check.isTrue(!before.tracks[KICK].steps[1].on, "old snapshot unchanged");
		Check.equal(heard.length, 1, "listeners told once");
	}

	static function snapshotsAreFrozen() {
		final state = newMachine().machine.getState();
		Check.isTrue(js.lib.Object.isFrozen(state), "the snapshot");
		Check.isTrue(js.lib.Object.isFrozen(state.tracks[0]), "a track");
		Check.isTrue(js.lib.Object.isFrozen(state.tracks[0].steps), "a row of steps");
		Check.isTrue(js.lib.Object.isFrozen(state.tracks[0].steps[0]), "a step");
	}

	static function strayEditsIgnored() {
		final machine = newMachine().machine;
		final before = machine.getState();
		machine.toggleStep(99, 0);
		machine.toggleStep(-1, 0);
		machine.setVolume(8, 50);
		Check.equal(machine.getState(), before, "no change, no new snapshot");
		machine.toggleStep(KICK, 16);
		machine.setStepVelocity(KICK, -1, 90);
		Check.equal(machine.getState().code, before.code, "steps outside 1–16 do not exist either");
	}

	static function tempoAndSwing() {
		final setup = newMachine();
		setup.machine.setTempo(250);
		setup.machine.setSwing(66.4);
		Check.equal(setup.machine.getState().tempo, 200, "tempo capped");
		Check.equal(setup.tone.bpm.value, 200.0, "the transport follows");
		Check.equal(setup.machine.getState().swing, 66, "swing rounded");
	}

	static function driveAndReverb() {
		final setup = newMachine();
		setup.machine.setDrive(100);
		setup.machine.setReverb(50);
		Check.equal(setup.tone.first("WaveShaper").curve[0], Saturation.curve(100)[0], "the full-drive curve is in place");
		Check.near(setup.tone.first("Filter").frequency.value, Saturation.cutoffHz(100), "the tone filter follows");
		Check.near(setup.tone.first("Gain").gain.value, 0.3, "half reverb sends at 0.3 into a fully wet room");
		Check.equal(setup.tone.first("Reverb").options.wet, 1, "the room itself is all reverb; the dry kit goes round it");
		final shapers = setup.tone.nodes.filter(node -> node.kind == "WaveShaper");
		Check.equal('${shapers[0].oversample} ${shapers[1].oversample}', "2x none", "overdrive oversampled; clipper not, so it cannot overshoot");
	}

	/** Tone stops a moment ahead, so the clock may still tick after Stop; nothing must be drawn or heard. */
	static function lateTickIgnored():Promise<Any> {
		final setup = newMachine();
		final playhead = [];
		setup.machine.onStep(step -> playhead.push(step));
		return playing(setup).then(_ -> {
			setup.machine.stop();
			setup.tone.sixteenthAfterStop(0.2);
			setup.tone.nextFrame();
			Check.equal(playhead.join(","), "-1", "only the stop");
			Check.equal(setup.tone.hits.length, 0, "and no sound");
		});
	}

	static function effectsOffCostNothing() {
		final setup = newMachine();
		Check.equal(setup.tone.first("WaveShaper").curve, null, "no overdrive curve at drive 0");
		Check.near(setup.tone.first("Gain").gain.value, 0, "nothing sent to the reverb");
		setup.machine.setDrive(30);
		setup.machine.setDrive(0);
		Check.equal(setup.tone.first("WaveShaper").curve, null, "back to no curve");
	}

	static function smoothPlaybackFirst() {
		final setup = newMachine();
		Check.equal(setup.tone.contextInUse.options.latencyHint, "playback", "bigger audio buffers, so phones do not crackle");
	}

	static function playheadWaitsForSpeakers():Promise<Any> {
		final setup = newMachine();
		setup.tone.speakerDelay = 0.04;
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(1.0);
			Check.near(setup.tone.drawTimes[0], 1.04, "drawn 40 ms after the audio clock, when it is heard");
			Check.near(setup.tone.hits[0].audioTime, 1.0, "while the sound itself is scheduled on time");
		});
	}

	// ── Editing steps ─────────────────────────────────────────────────

	static function tappingSteps() {
		final machine = newMachine().machine;
		machine.toggleStep(RIM, 0);
		final step = machine.getState().tracks[RIM].steps[0];
		Check.equal('${step.on} ${step.velocity} ${step.nudge} ${step.reversed}', "true 85 0 false", "a fresh hit");
		machine.toggleStep(RIM, 0);
		Check.isTrue(!machine.getState().tracks[RIM].steps[0].on, "rests again");
	}

	static function velocityEdits() {
		final machine = newMachine().machine;
		machine.setStepNudge(RIM, 2, 5);
		machine.setStepVelocity(RIM, 2, 140);
		final step = machine.getState().tracks[RIM].steps[2];
		Check.equal('${step.on} ${step.velocity} ${step.nudge}', "true 100 5", "on, capped at 100, nudge kept");
	}

	static function nudgeEdits() {
		final machine = newMachine().machine;
		machine.setStepVelocity(SNARE, 4, 40);
		machine.setStepNudge(SNARE, 4, -30);
		final step = machine.getState().tracks[SNARE].steps[4];
		Check.equal('${step.velocity} ${step.nudge}', "40 -16", "level kept, nudge capped");
	}

	static function flippingSteps() {
		final machine = newMachine().machine;
		machine.toggleStepReverse(RIM, 3);
		Check.isTrue(machine.getState().tracks[RIM].steps[3].reversed, "an empty step comes on, reversed");
		machine.setStepVelocity(RIM, 3, 30);
		machine.setStepNudge(RIM, 3, 2);
		Check.isTrue(machine.getState().tracks[RIM].steps[3].reversed, "level and nudge edits keep it reversed");
		machine.toggleStepReverse(RIM, 3);
		final step = machine.getState().tracks[RIM].steps[3];
		Check.equal('${step.reversed} ${step.velocity} ${step.nudge}', "false 30 2", "flipped back, level and nudge kept");
	}

	// ── With (fake) sound ─────────────────────────────────────────────

	static function playWaitsForSamples():Promise<Any> {
		final machine = newMachine().machine;
		return machine.play().then(_ -> Check.isTrue(!machine.getState().playing, "still stopped"));
	}

	static function stepsSoundOnTime():Promise<Any> {
		final setup = newMachine();
		setup.machine.setTempo(120);
		setup.machine.setSwing(75);
		setup.machine.toggleStep(RIM, 1);
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(0.0);
			setup.tone.sixteenth(0.125);
			Check.equal(describeHits(setup.tone), "BD2550@0, CH@0, RS@0.1875", "hits (by recording) and swung times");
		});
	}

	static function velocityAndNudgeAreHeard():Promise<Any> {
		final setup = newMachine();
		setup.machine.setTempo(120);
		setup.machine.setStepNudge(KICK, 0, 6);
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(1.0);
			final kick = setup.tone.hits[0];
			Check.near(kick.audioTime, 1 + 0.5 * 6 / 384, "6 ticks late at 120 BPM");
			Check.near(kick.gain, Loudness.velocityGain(100), "the starter kick is an accent");
			Check.near(setup.tone.hits[1].gain, Loudness.velocityGain(85), "the hat is a normal hit");
		});
	}

	static function hitsGoThroughTheFader():Promise<Any> {
		final setup = newMachine();
		setup.machine.setVolume(KICK, 50);
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(0.0);
			final fader = setup.tone.hits[0].into;
			Check.near(fader.volume.value, -6.020599913279624, "the kick's fader is at 50%");
			Check.equal(fader.output.output, setup.tone.first("WaveShaper"), "and feeds the overdrive, through the headroom cut");
			Check.equal(setup.tone.nodes.filter(node -> node.kind == "WaveShaper").length, 2, "overdrive and safety clipper");
		});
	}

	static function reversedStepsPlayBackwards():Promise<Any> {
		final setup = newMachine();
		setup.machine.toggleStepReverse(KICK, 0);
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(0.0);
			final kick = setup.tone.hits[0];
			Check.equal(kick.sample.played().join(" "), "0.25 0.5 1", "trimmed, then flipped: it starts at once");
			Check.equal(setup.tone.hits[1].sample.played().length, 10, "the hat, forwards, is untouched");
		});
	}

	/** The fake sample sounds for 0.3 s once trimmed; at 120 BPM straight a step lasts 0.125 s. */
	static function reversedHitsEndWithTheirStep():Promise<Any> {
		final setup = newMachine();
		setup.machine.setTempo(120);
		setup.machine.toggleStepReverse(KICK, 0);
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(2.0);
			final kick = setup.tone.hits[0];
			Check.near(kick.audioTime, 2.0, "starts on its step");
			Check.near(kick.offset + kick.duration, 0.3, "plays up to the end of the reversed sample…");
			Check.near(kick.duration, 0.125, "…for exactly one step");
			Check.isTrue(kick.fadeIn > 0 && kick.fadeIn <= 0.02, "cut in with a short fade");
		});
	}

	/** At 60 BPM with 75% swing, step 1 lasts 0.375 s: longer than the 0.3 s sample. */
	static function shortReversedHitsStartLate():Promise<Any> {
		final setup = newMachine();
		setup.machine.setTempo(60);
		setup.machine.setSwing(75);
		setup.machine.toggleStepReverse(KICK, 0);
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(0.0);
			final kick = setup.tone.hits[0];
			Check.near(kick.audioTime, 0.075, "starts 0.075 s in, so it ends at 0.375 s");
			Check.equal('${kick.offset} ${kick.duration} ${kick.fadeIn}', "0 0.3 0", "the whole sample, no fade needed");
		});
	}

	static function playheadFollowsFrames():Promise<Any> {
		final setup = newMachine();
		final playhead = [];
		setup.machine.onStep(step -> playhead.push(step));
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(0.0);
			setup.tone.sixteenth(0.15);
			Check.equal(playhead.join(","), "", "nothing drawn before the frame");
			setup.tone.nextFrame();
			setup.machine.stop();
			Check.equal(playhead.join(","), "0,1,-1", "steps on the frame, -1 on stop");
		});
	}

	static function mutedTrackIsSilent():Promise<Any> {
		final setup = newMachine();
		setup.machine.toggleMute(KICK);
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(0.0);
			Check.equal(describeHits(setup.tone), "CH@0", "no kick");
		});
	}

	// ── Part sound controls ───────────────────────────────────────────

	static function soundEdits() {
		final machine = newMachine().machine;
		machine.setPitch(KICK, 20);
		machine.setLength(KICK, 0);
		machine.setDial(KICK, 0, 9);
		machine.setDial(CLAP, 0, 3);
		final kick = machine.getState().tracks[KICK];
		Check.equal('${kick.pitch} ${kick.length} ${kick.sample}', "12 5 BD1050", "capped, floored, Tone fully right");
		Check.equal(machine.getState().tracks[CLAP].sample, "CP", "the clap has no knob to turn");
	}

	static function loadingFetchesChosenRecordings():Promise<Any> {
		final setup = newMachine();
		return setup.machine.load().then(_ -> {
			Check.equal(setup.tone.loads.join(" "), [for (name in ["BD2550", "SD5050", "CP", "CH", "OH50", "LT50", "HT50", "RS"]) '/samples/$name.wav'].join(" "), "one file per part");
			Check.equal(setup.machine.getState().status, Ready, "ready");
		});
	}

	static function dialsSwapRecordings():Promise<Any> {
		final setup = newMachine();
		return playing(setup).then(_ -> {
			setup.machine.setDial(KICK, 1, 4);
			return afterDownloads();
		}).then(_ -> {
			setup.tone.sixteenth(0.0);
			Check.equal(setup.tone.hits[0].voice, "BD2510", "the kick now plays Decay fully right");
		});
	}

	static function lastDialWins():Promise<Any> {
		final setup = newMachine();
		return playing(setup).then(_ -> {
			setup.tone.holdLoads = true;
			setup.machine.setDial(KICK, 1, 3);
			setup.machine.setDial(KICK, 1, 4);
			setup.tone.waitingLoads["/samples/BD2510.wav"]();
			setup.tone.waitingLoads["/samples/BD2575.wav"]();
			return afterDownloads();
		}).then(_ -> {
			setup.tone.sixteenth(0.0);
			Check.equal(setup.tone.hits[0].voice, "BD2510", "the earlier choice, finishing last, did not take over");
		});
	}

	/** The fake recording sounds for 0.3 s; at +12 and 50 % it is heard for 0.075 s. */
	static function pitchAndLengthShapeHits():Promise<Any> {
		final setup = newMachine();
		setup.machine.setPitch(KICK, 12);
		setup.machine.setLength(KICK, 50);
		return playing(setup).then(_ -> {
			setup.tone.sixteenth(0.0);
			final kick = setup.tone.hits[0];
			Check.near(kick.rate, 2, "an octave up");
			Check.near(kick.duration + kick.fadeOut, 0.075, "heard for half its sound, at double speed");
			Check.near(setup.tone.hits[1].rate, 1, "the hat is untouched");
		});
	}

	// ── Sharing and tidying up ────────────────────────────────────────

	static function codesMovePatterns() {
		final sender = machineWithAllKindsOfEdits();
		final receiver = newMachine().machine;
		Check.isTrue(receiver.loadCode(sender.getState().code), "accepted");
		final received = receiver.getState();
		Check.equal(received.code, sender.getState().code, "identical pattern");
		Check.equal(received.tracks[RIM].steps[0].nudge, -4, "nudge came too");
		Check.isTrue(received.tracks[SNARE].steps[4].reversed, "and so did the reversed snare");
		Check.equal('${received.tracks[SNARE].pitch} ${received.tracks[KICK].sample}', "-5 BD1050", "and the part sounds");
	}

	/** A machine with one edit of every kind a URL code has to carry. */
	static function machineWithAllKindsOfEdits():DrumMachine {
		final machine = newMachine().machine;
		machine.setStepVelocity(RIM, 0, 33);
		machine.setStepNudge(RIM, 0, -4);
		machine.toggleStepReverse(SNARE, 4);
		machine.setPitch(SNARE, -5);
		machine.setDial(KICK, 0, 4);
		machine.setTempo(87);
		machine.setReverb(30);
		machine.toggleMute(3);
		return machine;
	}

	static function invalidCodeChangesNothing() {
		final machine = newMachine().machine;
		final before = machine.getState();
		Check.isTrue(!machine.loadCode("5.120.50.0.0.nonsense"), "refused");
		Check.equal(machine.getState(), before, "untouched");
	}

	static function loadingCodePublishesOnce() {
		final code = newMachine().machine.getState().code;
		final machine = newMachine().machine;
		var told = 0;
		machine.subscribe(_ -> told++);
		machine.loadCode(code);
		Check.equal(told, 1, "one snapshot");
	}

	static function disposeReleasesEverything() {
		final setup = newMachine();
		var told = 0;
		setup.machine.subscribe(_ -> told++);
		setup.machine.dispose();
		setup.machine.toggleStep(KICK, 1);
		Check.isTrue(setup.tone.repeatCleared, "repeat removed from the transport");
		Check.isTrue(setup.tone.nodes.filter(node -> !node.disposed).length == 0, "every audio node freed");
		Check.equal(told, 0, "listeners forgotten");
	}

	// ── Helpers ───────────────────────────────────────────────────────

	/** Lets every pending download and the work after it finish. */
	static function afterDownloads():Promise<Any> {
		return new Promise((resolve, _) -> haxe.Timer.delay(() -> resolve(null), 0));
	}

	static function newMachine() {
		final tone = new FakeTone();
		return {tone: tone, machine: new DrumMachine({tone: tone.api, samplesUrl: "/samples/"})};
	}

	/** Loads the samples and presses Play, as a user would. */
	static function playing(setup:{tone:FakeTone, machine:DrumMachine}):Promise<Any> {
		return setup.machine.load().then(_ -> setup.machine.play());
	}

	/** "voice@time, …" in the order the samples were started. */
	static function describeHits(tone:FakeTone):String {
		return [for (hit in tone.hits) '${hit.voice}@${hit.audioTime}'].join(", ");
	}
}
