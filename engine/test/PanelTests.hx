import Check.test;
import drum.DrumMachine;
import drum.panel.PanelText;
import drum.panel.SevenSegmentFont;
import drum.panel.ShareLink;

/** The words and the display font every front end shares. */
class PanelTests {
	public static function all():Array<Check.Test> {
		return [
			test("the display right-aligns four characters", displayCharacters),
			test("the display texts read like the panel", displayTexts),
			test("step labels say what a screen reader needs", stepLabels),
			test("a shared link is the page with the beat at its end", sharedAddress)
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
}
