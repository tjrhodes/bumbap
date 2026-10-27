import Check.test;
import drum.DrumMachine;
import drum.panel.PanelText;
import drum.panel.SevenSegmentFont;
import drum.panel.PatternPad;
import drum.panel.ShareLink;

/** The words and the display font every front end shares. */
class PanelTests {
	public static function all():Array<Check.Test> {
		return [
			test("the display right-aligns four characters", displayCharacters),
			test("the display texts read like the panel", displayTexts),
			test("step labels say what a screen reader needs", stepLabels),
			test("a shared link is the page with the beat at its end", sharedAddress),
			test("pattern buttons say whether they play, wait or are empty", patternLabels),
			test("a click puts a pattern on the keys; a shift-click adds it to the sequence", padClicks),
			test("holding one button and tapping others sequences them; the taps are not also clicks", padHolds),
			test("with a sequence button on, holding and dragging are just taps", padToolsOn),
			test("dragging one button onto another copies the pattern, and is not also a click", padDrags)
		];
	}

	static function displayCharacters() {
		Check.equal(SevenSegmentFont.characters("100").join("|"), " |1|0|0", "padded on the left");
		Check.equal(SevenSegmentFont.characters("12345").join(""), "2345", "only the last four");
		Check.isTrue(SevenSegmentFont.isLit("1", "b") && !SevenSegmentFont.isLit("1", "a"), "a 1 is two segments");
		Check.equal(SevenSegmentFont.segmentPoints("a").split(" ").length, 6, "a segment is a hexagon");
	}

	static function displayTexts() {
		final machine = new DrumMachine({tone: new FakeTone().api, samplesUrl: "/"});
		Check.equal(PanelText.labelled("S", 66), "S 66", "letter, then the value right-aligned");
		Check.equal(PanelText.resting(machine.getState()), "LoAd", "loading");
		Check.equal(PanelText.status(machine.getState()), "Loading the kit", "status line");
		Check.equal(PanelText.dialSetting(machine.getState().tracks[0]), "2550", "the kick's 808 setting");
	}

	static function stepLabels() {
		final kick = new DrumMachine({tone: new FakeTone().api, samplesUrl: "/"}).getState().tracks[0];
		Check.equal(PanelText.stepLabel("Kick", 0, kick.steps[0]), "Kick step 1, level 100, nudge 0", "a step that plays");
		Check.equal(PanelText.stepLabel("Kick", 1, kick.steps[1]), "Kick step 2", "a rest");
		Check.equal(PanelText.dialLabel(kick, 0), "Kick Tone, 808 knob", "an 808 knob");
		Check.equal(PanelText.dialLabel(new DrumMachine({tone: new FakeTone().api, samplesUrl: "/"}).getState().tracks[2], 0), "No 808 knob on this part", "the clap has none");
	}

	static function sharedAddress() {
		final lab = "https://tomrhodes.it/en/work/bumbap/?build=vue";
		Check.equal(ShareLink.addressWith(lab, "5.100"), '$lab#5.100', "the code becomes the ending");
		Check.equal(ShareLink.addressWith('$lab#5.90', "5.100"), '$lab#5.100', "an older beat is replaced");
		Check.equal(ShareLink.addressWith('$lab#results', "5.100"), '$lab#5.100', "and so is a link to a section");
	}

	static function patternLabels() {
		final machine = new DrumMachine({tone: new FakeTone().api, samplesUrl: "/"});
		machine.toggleInSequence(2);
		Check.equal(PanelText.patternLabel(machine.getState(), 0), "Pattern 1, on the keys", "the one on the keys");
		Check.equal(PanelText.patternLabel(machine.getState(), 2), "Pattern 3, empty", "in the sequence shows as pressed, not in words");
	}

	static function padClicks() {
		final pad = new PatternPad(machineWithPad());
		pad.click(3, false);
		Check.equal('${machineState().pattern} ${machineState().sequence}', "3 [0]", "a click edits; the sequence is left alone");
		pad.click(5, true);
		Check.equal(Std.string(machineState().sequence), "[0,5]", "a shift-click adds to the sequence");
	}

	static function padHolds() {
		final pad = new PatternPad(machineWithPad());
		pad.press(1, 2);
		pad.press(2, 6);
		pad.release(2, 6);
		pad.press(3, 4);
		pad.release(3, 4);
		Check.equal(Std.string(machineState().sequence), "[2,6,4]", "held 3, tapped 7 then 5: in that order");
		pad.click(6, false);
		pad.release(1, 2);
		pad.click(2, false);
		Check.equal('${machineState().pattern} ${machineState().sequence}', "0 [2,6,4]", "no click chose anything");
	}

	static function padDrags() {
		final pad = new PatternPad(machineWithPad());
		pad.press(1, 0);
		pad.release(1, 5);
		pad.click(0, false);
		Check.equal(Std.string(machineState().patternHasSteps.slice(4, 6)), "[false,true]", "pattern 1 copied onto 6");
		Check.equal(Std.string(machineState().sequence), "[0]", "and the drag was not a click on 1");
		pad.press(1, 3);
		pad.release(1, PatternPad.NONE);
		Check.isTrue(!machineState().patternHasSteps[3], "let go off the buttons: nothing copied");
	}

	static function padToolsOn() {
		final pad = new PatternPad(machineWithPad());
		padMachine.toggleTool(Select);
		pad.press(1, 3);
		pad.press(2, 1);
		pad.release(2, 1);
		pad.click(1, false);
		pad.release(1, 6);
		pad.click(3, false);
		Check.equal('${machineState().sequence} ${machineState().patternHasSteps[6]}', "[1,3] false", "two Select taps, no hold, no copy");
	}

	static var padMachine:DrumMachine;

	static function machineWithPad():DrumMachine {
		padMachine = new DrumMachine({tone: new FakeTone().api, samplesUrl: "/"});
		return padMachine;
	}

	static function machineState() {
		return padMachine.getState();
	}
}
