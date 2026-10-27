import Check.later;
import Check.test;
import drum.DrumMachine;
import drum.Sequence;
import drum.StepRow;
import drum.panel.PanelText;
import js.lib.Promise;

/** Version 2: eight patterns, the sequence that plays them, and the Select, Copy and Clear tools. */
class PatternTests {
	static inline final KICK = 0;
	static inline final SNARE = 1;
	static inline final STEPS_IN_A_BAR = 16;

	public static function all():Array<Check.Test> {
		return sequenceTests().concat(machineTests()).concat(toolTests()).concat(playingTests());
	}

	static function sequenceTests():Array<Check.Test> {
		return [
			test("choosing a pattern: stopped it is just chosen, playing it is queued", choosing),
			test("shift-click adds at the end or takes out, and the last one stays", toggling),
			test("the sequence plays in its own order, repeats included, from wherever it is", goingRound),
			test("a sequence set at once keeps its order and drops what does not exist", replacing),
			test("a queued pattern taken out of the sequence is forgotten", queuedTakenOut)
		];
	}

	static function machineTests():Array<Check.Test> {
		return [
			test("pattern 1 is the starter beat and 2–8 are empty", startingPatterns),
			test("choosing a pattern while stopped shows it; each keeps its own steps and sounds", eachPatternKeepsItsOwn),
			test("copying a pattern takes its steps and its part sounds", copying),
			test("a link carries every pattern and the chain", linksCarryEverything),
			later("loading downloads every pattern's recordings, not just the one shown", loadingEveryPattern)
		];
	}

	static function toolTests():Array<Check.Test> {
		return [
			test("Select: taps set the sequence in their order, repeats allowed, and show their places", selecting),
			test("Copy: the first tap picks, the second copies there, then Copy turns off", copyingWithTheTool),
			test("Clear: a tap blanks that pattern, part sounds too, then Clear turns off", clearingWithTheTool),
			test("a tool turns off when pressed again, and another one takes its place", toolsTakeTurns)
		];
	}

	static function playingTests():Array<Check.Test> {
		return [
			later("while playing, a chosen pattern waits for the end of the bar", chosenWaitsForTheBar),
			later("a sequence plays its patterns in turn, and the keys follow on the bar's first heard step", sequencePlaysInTurn),
			later("Play starts on the sequence's first pattern if the one shown is not in it", playStartsInTheSequence)
		];
	}

	// ── The chain on its own ──────────────────────────────────────────

	static function choosing() {
		final sequence = new Sequence();
		sequence.choose(3, false);
		Check.equal('${sequence.patterns} ${sequence.queued}', "[3] -1", "stopped: the sequence is that pattern, nothing queued");
		sequence.choose(5, true);
		Check.equal('${sequence.patterns} ${sequence.queued} ${sequence.advance()}', "[5] 5 5", "playing: queued, and next");
		sequence.choose(0, true);
		Check.equal(sequence.queued, Sequence.NONE, "choosing the one shown queues nothing");
	}

	static function toggling() {
		final sequence = new Sequence();
		sequence.toggle(5);
		sequence.toggle(2);
		Check.equal(Std.string(sequence.patterns), "[0,5,2]", "added at the end, in the order clicked");
		sequence.toggle(0);
		sequence.toggle(2);
		Check.equal(Std.string(sequence.patterns), "[5]", "taken out");
		sequence.toggle(5);
		Check.equal(Std.string(sequence.patterns), "[5]", "the last one stays");
	}

	static function goingRound() {
		final sequence = new Sequence();
		sequence.replace([0, 2, 0, 5]);
		final heard = [for (_ in 0...5) sequence.advance()];
		Check.equal(heard.join(","), "2,0,5,0,2", "after the first: 3, 1 again, 6, then round");
		sequence.show(4);
		Check.equal('${sequence.start()} ${sequence.position}', "0 0", "Play from outside the sequence starts at its first");
	}

	static function replacing() {
		final sequence = new Sequence();
		sequence.replace([6, 1, 6, 9, -1]);
		Check.equal(Std.string(sequence.patterns), "[6,1,6]", "in order, repeats kept, only patterns that exist");
		sequence.replace([]);
		Check.equal(Std.string(sequence.patterns), "[6,1,6]", "an empty sequence is ignored");
		sequence.replace([for (_ in 0...20) 1]);
		Check.equal(sequence.patterns.length, Sequence.MOST, "at most 16");
	}

	static function queuedTakenOut() {
		final sequence = new Sequence();
		sequence.choose(4, true);
		sequence.toggle(2);
		Check.equal(sequence.queued, 4, "still queued while in the sequence");
		sequence.toggle(4);
		Check.equal('${sequence.queued} ${sequence.advance()}', "-1 2", "taken out: forgotten, and the sequence moves on");
	}

	// ── The machine's patterns ────────────────────────────────────────

	static function startingPatterns() {
		final state = newMachine().machine.getState();
		Check.equal('${state.pattern} ${state.sequence} ${state.nextPattern} ${state.tool}', "0 [0] -1 ", "pattern 1 shown and in the sequence, no tool on");
		Check.equal(Std.string(state.patternHasSteps), "[true,false,false,false,false,false,false,false]", "only pattern 1 has steps");
	}

	static function eachPatternKeepsItsOwn() {
		final machine = newMachine().machine;
		machine.choosePattern(2);
		Check.equal(StepRow.print(machine.getState().tracks[KICK].steps), "................", "pattern 3 starts empty");
		machine.toggleStep(KICK, 4);
		machine.setPitch(SNARE, 7);
		machine.choosePattern(0);
		Check.equal('${machine.getState().tracks[KICK].steps[4].on} ${machine.getState().tracks[SNARE].pitch}', "false 0", "pattern 1 untouched");
		machine.choosePattern(2);
		Check.equal('${machine.getState().tracks[KICK].steps[4].on} ${machine.getState().tracks[SNARE].pitch}', "true 7", "pattern 3 kept its edits");
		Check.equal(Std.string(machine.getState().patternHasSteps.slice(0, 3)), "[true,false,true]", "both now have steps");
	}

	static function copying() {
		final machine = newMachine().machine;
		machine.setDial(KICK, 0, 4);
		machine.copyPattern(0, 5);
		machine.choosePattern(5);
		final copied = machine.getState().tracks[KICK];
		Check.equal('${copied.steps[0].on} ${copied.sample}', "true BD1050", "steps and the kick's 808 knob came too");
		machine.toggleStep(KICK, 1);
		machine.choosePattern(0);
		Check.isTrue(!machine.getState().tracks[KICK].steps[1].on, "the copy is its own: editing it leaves the original alone");
		machine.copyPattern(4, 0);
		Check.isTrue(!machine.getState().patternHasSteps[0], "copied onto the pattern shown: the keys show the copy at once");
	}

	static function linksCarryEverything() {
		final sender = newMachine().machine;
		sender.copyPattern(0, 3);
		sender.choosePattern(3);
		sender.toggleStep(SNARE, 2);
		sender.toggleInSequence(6);
		sender.toggleInSequence(3);
		sender.toggleInSequence(6);
		sender.setSequence([6, 3, 6]);
		final receiver = newMachine().machine;
		Check.isTrue(receiver.loadCode(sender.getState().code), "accepted");
		final received = receiver.getState();
		Check.equal('${received.pattern} ${received.sequence} ${received.code == sender.getState().code}', "3 [6,3,6] true", "same patterns, sequence and pattern shown");
		Check.isTrue(received.tracks[SNARE].steps[2].on, "with pattern 4's edit");
	}

	static function loadingEveryPattern():Promise<Any> {
		final sender = newMachine().machine;
		sender.choosePattern(6);
		sender.setDial(KICK, 1, 0);
		sender.choosePattern(0);
		final setup = newMachine();
		setup.machine.loadCode(sender.getState().code);
		return setup.machine.load().then(_ -> {
			Check.isTrue(setup.tone.loads.contains("/samples/BD2500.wav"), "pattern 7's kick, though pattern 1 is shown");
			Check.isTrue(setup.tone.loads.contains("/samples/CP.wav") && !setup.tone.loads.contains("/samples/CP0000.wav"), "the clap, which has no knobs, is just CP");
		});
	}

	// ── The tools ─────────────────────────────────────────────────────

	static function selecting() {
		final machine = newMachine().machine;
		machine.toggleTool(Select);
		for (pattern in [2, 0, 2, 5]) machine.tapPattern(pattern, false);
		final state = machine.getState();
		Check.equal('${state.sequence} ${state.pattern}', "[2,0,2,5] 0", "the taps' order, the keys still on pattern 1");
		Check.equal(PanelText.sequencePlaces(state, 2), "1 3", "pattern 3 plays first and third");
		Check.equal(PanelText.patternLabel(state, 2), "Pattern 3, empty, sequence places 1 3", "and says so");
		machine.toggleTool(Select);
		Check.equal(PanelText.sequencePlaces(machine.getState(), 2), "", "Select off: no places shown");
		machine.toggleTool(Select);
		machine.tapPattern(4, false);
		Check.equal(Std.string(machine.getState().sequence), "[4]", "Select again: a new sequence from its first tap");
	}

	static function copyingWithTheTool() {
		final machine = newMachine().machine;
		machine.toggleTool(Copy);
		machine.tapPattern(0, false);
		Check.equal('${machine.getState().copyFrom} ${machine.getState().tool}', "0 copy", "pattern 1 picked");
		machine.tapPattern(6, false);
		final state = machine.getState();
		Check.equal('${state.patternHasSteps[6]} ${state.tool} ${state.copyFrom} ${state.pattern}', "true  -1 0", "copied, Copy off, keys unchanged");
	}

	static function clearingWithTheTool() {
		final machine = newMachine().machine;
		machine.setPitch(KICK, 5);
		machine.toggleTool(Clear);
		machine.tapPattern(0, false);
		final state = machine.getState();
		Check.equal('${state.patternHasSteps[0]} ${state.tracks[KICK].pitch} ${state.tool}', "false 0 ", "blank, pitch back to 0, Clear off");
	}

	static function toolsTakeTurns() {
		final machine = newMachine().machine;
		machine.toggleTool(Copy);
		machine.tapPattern(1, false);
		machine.toggleTool(Clear);
		Check.equal('${machine.getState().tool} ${machine.getState().copyFrom}', "clear -1", "Clear replaces Copy, forgetting its pick");
		machine.toggleTool(Clear);
		Check.equal(Std.string(machine.getState().tool), "", "pressed again: off");
	}

	// ── Playing ───────────────────────────────────────────────────────

	static function chosenWaitsForTheBar():Promise<Any> {
		final setup = newMachine();
		return playing(setup).then(_ -> {
			playSteps(setup, 4);
			setup.machine.choosePattern(1);
			Check.equal('${setup.machine.getState().pattern} ${setup.machine.getState().nextPattern}', "0 1", "queued, still on pattern 1");
			playSteps(setup, STEPS_IN_A_BAR - 4 + 1);
			setup.tone.nextFrame();
			Check.equal('${setup.machine.getState().pattern} ${setup.machine.getState().nextPattern}', "1 -1", "pattern 2 from the next bar");
		});
	}

	static function sequencePlaysInTurn():Promise<Any> {
		final setup = newMachine();
		setup.machine.setSequence([0, 2, 2]);
		final shownAtEachBar = [];
		setup.machine.onStep(step -> if (step == 0) shownAtEachBar.push(setup.machine.getState().pattern + 1));
		return playing(setup).then(_ -> {
			for (_ in 0...4) {
				playSteps(setup, STEPS_IN_A_BAR);
				setup.tone.nextFrame();
			}
			Check.equal(shownAtEachBar.join(" → "), "1 → 3 → 3 → 1", "1, then 3 twice, then round, each shown as its bar is heard");
		});
	}

	static function playStartsInTheSequence():Promise<Any> {
		final setup = newMachine();
		setup.machine.setSequence([6, 4]);
		return playing(setup).then(_ -> {
			Check.equal(setup.machine.getState().pattern, 6, "pattern 7, the sequence's first");
		});
	}

	// ── Helpers ───────────────────────────────────────────────────────

	static function newMachine() {
		final tone = new FakeTone();
		return {tone: tone, machine: new DrumMachine({tone: tone.api, samplesUrl: "/samples/"})};
	}

	static function playing(setup:{tone:FakeTone, machine:DrumMachine}):Promise<Any> {
		return setup.machine.load().then(_ -> setup.machine.play());
	}

	/** The clock's part: this many sixteenths (their times do not matter here). */
	static function playSteps(setup:{tone:FakeTone, machine:DrumMachine}, count:Int) {
		for (_ in 0...count) setup.tone.sixteenth(0.0);
	}
}
