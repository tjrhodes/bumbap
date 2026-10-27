import Check.later;
import Check.test;
import drum.DrumMachine;
import drum.PatternChain;
import drum.StepRow;
import js.lib.Promise;

/** Version 2: eight patterns, the chain that plays them, and copying one onto another. */
class PatternTests {
	static inline final KICK = 0;
	static inline final SNARE = 1;
	static inline final STEPS_IN_A_BAR = 16;

	public static function all():Array<Check.Test> {
		return chainTests().concat(machineTests()).concat(playingTests());
	}

	static function chainTests():Array<Check.Test> {
		return [
			test("choosing a pattern: stopped it is just chosen, playing it is queued", choosing),
			test("the chain adds and takes out patterns in number order, and keeps one", toggling),
			test("the chain goes round in number order, from wherever it is", goingRound),
			test("a chain set at once drops repeats and numbers that do not exist", chainingExactly),
			test("a queued pattern taken out of the chain is forgotten", queuedTakenOut)
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

	static function playingTests():Array<Check.Test> {
		return [
			later("while playing, a chosen pattern waits for the end of the bar", chosenWaitsForTheBar),
			later("a chain plays its patterns in turn, and the keys follow on the bar's first heard step", chainPlaysInTurn),
			later("Play starts on the chain's first pattern if the one shown is not in it", playStartsInTheChain)
		];
	}

	// ── The chain on its own ──────────────────────────────────────────

	static function choosing() {
		final chain = new PatternChain();
		chain.choose(3, false);
		Check.equal('${chain.members} ${chain.queued}', "[3] -1", "stopped: the chain is that pattern, nothing queued");
		chain.choose(5, true);
		Check.equal('${chain.members} ${chain.queued} ${chain.next()}', "[5] 5 5", "playing: queued, and next");
		chain.choose(0, true);
		Check.equal(chain.queued, PatternChain.NONE, "choosing the one shown queues nothing");
	}

	static function toggling() {
		final chain = new PatternChain();
		chain.toggle(5);
		chain.toggle(2);
		Check.equal(Std.string(chain.members), "[0,2,5]", "added, in number order");
		chain.toggle(0);
		chain.toggle(2);
		Check.equal(Std.string(chain.members), "[5]", "taken out");
		chain.toggle(5);
		Check.equal(Std.string(chain.members), "[5]", "the last one stays");
	}

	static function goingRound() {
		final chain = new PatternChain();
		chain.chainExactly([0, 2, 5]);
		Check.equal(chain.next(), 2, "after 1 comes 3");
		chain.moveTo(5);
		Check.equal(chain.next(), 0, "after the last, the first again");
		chain.moveTo(3);
		Check.equal('${chain.next()} ${chain.first()}', "5 0", "from outside the chain: the next one up; Play starts on the first");
	}

	static function chainingExactly() {
		final chain = new PatternChain();
		chain.chainExactly([6, 1, 6, 9, -1]);
		Check.equal(Std.string(chain.members), "[1,6]", "sorted, once each, only patterns that exist");
		chain.chainExactly([]);
		Check.equal(Std.string(chain.members), "[1,6]", "an empty chain is ignored");
	}

	static function queuedTakenOut() {
		final chain = new PatternChain();
		chain.choose(4, true);
		chain.toggle(2);
		Check.equal(chain.queued, 4, "still queued while in the chain");
		chain.toggle(4);
		Check.equal('${chain.queued} ${chain.next()}', "-1 2", "taken out: forgotten, and the chain moves on");
	}

	// ── The machine's patterns ────────────────────────────────────────

	static function startingPatterns() {
		final state = newMachine().machine.getState();
		Check.equal('${state.pattern} ${state.chain} ${state.nextPattern}', "0 [0] -1", "pattern 1 shown and chained");
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
		sender.toggleInChain(6);
		final receiver = newMachine().machine;
		Check.isTrue(receiver.loadCode(sender.getState().code), "accepted");
		final received = receiver.getState();
		Check.equal('${received.pattern} ${received.chain} ${received.code == sender.getState().code}', "3 [3,6] true", "same patterns, chain and pattern shown");
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
		});
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

	static function chainPlaysInTurn():Promise<Any> {
		final setup = newMachine();
		setup.machine.toggleInChain(2);
		final shownAtEachBar = [];
		setup.machine.onStep(step -> if (step == 0) shownAtEachBar.push(setup.machine.getState().pattern + 1));
		return playing(setup).then(_ -> {
			for (_ in 0...3) {
				playSteps(setup, STEPS_IN_A_BAR);
				setup.tone.nextFrame();
			}
			Check.equal(shownAtEachBar.join(" → "), "1 → 3 → 1", "patterns 1 and 3 in turn, shown as each bar is heard");
		});
	}

	static function playStartsInTheChain():Promise<Any> {
		final setup = newMachine();
		setup.machine.chainPatterns([4, 6]);
		return playing(setup).then(_ -> {
			Check.equal(setup.machine.getState().pattern, 4, "pattern 5, the chain's first");
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
