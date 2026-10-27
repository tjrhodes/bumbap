using StringTools;

import Check.test;
import drum.Kit;
import drum.Limits;
import drum.Loudness;
import drum.PatternCode;
import drum.Step;
import drum.StepRow;
import drum.Timing;
import drum.Patterns;
import drum.State.Pattern;
import drum.State.SavedMachine;
import drum.audio.HitShape;
import drum.audio.HitShape.HitPlan;
import drum.audio.Saturation;
import drum.audio.Silence;

/** The pure parts of the engine: numbers, rows, timing, loudness, the overdrive curve and the URL code. */
class ModelTests {
	public static function all():Array<Check.Test> {
		return [
			test("a range rounds and clamps whatever a UI sends", rangeClamps),
			test("a step row survives parse → print, accents and ghosts included", stepRowRoundTrip),
			test("new steps are checked and frozen", stepsAreChecked),
			test("straight time never moves a step", straightSwing),
			test("swing delays only the off-beats", swungOffbeats),
			test("a nudge is a share of a beat, so it scales with tempo", nudgeScalesWithTempo),
			test("a step lasts until the next one starts; swing lengthens on-beats", stepLengths),
			test("velocity 85 plays at the track's level; 8 points is 3 dB", velocityLoudness),
			test("a sample's sound ends at its last audible value", soundEnd),
			test("the volume fader is percent of full gain", volumeFader)
		].concat(soundTests()).concat(saturationTests()).concat(codeTests());
	}

	static function soundTests():Array<Check.Test> {
		return [
			test("the 808 knobs name the recording, as the sample set does", recordingNames),
			test("pitch is a playback rate: an octave doubles it", pitchRates),
			test("a forwards hit plays whole, or fades out early when shortened", forwardsHits),
			test("a backwards hit ends with its step, whatever its pitch and length", backwardsHits)
		];
	}

	static function saturationTests():Array<Check.Test> {
		return [
			test("drive 0 is a straight line", noDriveIsClean),
			test("full drive rounds the peaks but keeps silence silent and full level full", fullDriveShape),
			test("full drive is lopsided, for even harmonics", fullDriveIsLopsided),
			test("the overdrive darkens and trims as it rises", driveDarkensAndTrims),
			test("the safety clipper gives the headroom back and never passes full scale", safetyClipper)
		];
	}

	static function codeTests():Array<Check.Test> {
		return [
			test("a URL code rebuilds the exact patterns, the chain and the pattern shown", codeRoundTrip),
			test("bad URL codes are refused, not misread", badCodesRefused),
			test("a sequence past pattern 8, empty or longer than 16 is refused", badSequencesRefused),
			test("out-of-range numbers in a code are clamped", codeClamps),
			test("a blank pattern costs one character in a link", blankPatternsCostNothing),
			test("a bümbap 1 link still opens, as pattern 1", oneLinksStillOpen)
		];
	}

	// ── Numbers, rows and steps ───────────────────────────────────────

	static function rangeClamps() {
		Check.equal(Limits.TEMPO.clamp(120.4), 120, "rounds down");
		Check.equal(Limits.TEMPO.clamp(500), 200, "caps at max");
		Check.equal(Limits.TEMPO.clamp(-3), 60, "floors at min");
		Check.equal(Limits.TEMPO.clamp(Math.NaN), 100, "garbage gives the default");
	}

	static function stepRowRoundTrip() {
		final row = "X..x....o.x.....";
		Check.equal(StepRow.print(StepRow.parse(row)), row, "same row back");
		Check.equal(StepRow.parse("X")[0].velocity, 100, "an accent is velocity 100");
		Check.equal(StepRow.parse("x").length, Limits.STEPS, "short rows are padded with rests");
	}

	static function stepsAreChecked() {
		final step = Step.hit(250, -40);
		Check.equal(step.velocity, 100, "velocity capped");
		Check.equal(step.nudge, -16, "nudge capped");
		Check.isTrue(js.lib.Object.isFrozen(step), "frozen");
		Check.equal(Step.fresh().velocity, 85, "a fresh step starts at 85");
	}

	// ── Timing and loudness ───────────────────────────────────────────

	static function straightSwing() {
		for (step in 0...Limits.STEPS) Check.near(Timing.swingDelay(step, 50, 0.125), 0, 'step $step');
	}

	static function swungOffbeats() {
		Check.near(Timing.swingDelay(0, 75, 0.125), 0, "the downbeat stays put");
		Check.near(Timing.swingDelay(1, 75, 0.125), 0.0625, "at 75% the off-beat moves half a sixteenth");
		Check.near(Timing.sixteenthSeconds(120), 0.125, "a sixteenth at 120 BPM");
	}

	static function nudgeScalesWithTempo() {
		Check.near(Timing.nudgeSeconds(16, 120), 0.5 / 24, "the furthest nudge is 1/24 of a beat");
		Check.near(Timing.nudgeSeconds(-6, 60), -1 / 64, "early is negative, and slower tempo means longer");
	}

	static function stepLengths() {
		Check.near(Timing.stepSeconds(0, 50, 0.125), 0.125, "straight: a sixteenth");
		Check.near(Timing.stepSeconds(0, 75, 0.125), 0.1875, "swung on-beat: longer");
		Check.near(Timing.stepSeconds(1, 75, 0.125), 0.0625, "swung off-beat: shorter");
		Check.near(Timing.stepSeconds(15, 75, 0.125), 0.0625, "the last step ends where the next bar starts");
	}

	static function velocityLoudness() {
		Check.near(Loudness.velocityGain(85), 1, "85 is unity gain");
		Check.near(Loudness.velocityGain(100), Loudness.decibelsToGain(5.625), "100 is about 5.6 dB up");
		Check.near(Loudness.velocityGain(45), Loudness.decibelsToGain(-15), "45 is 15 dB down");
		Check.near(Loudness.velocityGain(1), Loudness.decibelsToGain(-31.5), "1 is 31.5 dB down");
	}

	static function soundEnd() {
		final rate = 10.0;
		Check.near(Silence.soundEndSeconds(new js.lib.Float32Array([1, 0.5, 0.0005, 0, 0]), rate), 0.2, "-66 dB is silence");
		Check.near(Silence.soundEndSeconds(new js.lib.Float32Array([0, 0, -1]), rate), 0.3, "ends on a negative peak");
		Check.near(Silence.soundEndSeconds(new js.lib.Float32Array([0, 0]), rate), 0.1, "all silence still keeps one value");
	}

	static function volumeFader() {
		Check.near(Loudness.volumeDecibels(100), 0, "full is 0 dB");
		Check.near(Loudness.volumeDecibels(50), -6.020599913279624, "half is about -6 dB");
		Check.equal(Loudness.volumeDecibels(0), Math.NEGATIVE_INFINITY, "zero is silence");
	}

	// ── Recordings and hit shapes ─────────────────────────────────────

	static function recordingNames() {
		final kick = Kit.VOICES[0];
		Check.equal(Kit.sampleName(kick, [1, 2]), "BD2550", "Tone 2.5, Decay 5");
		Check.equal(Kit.sampleName(kick, [4, 0]), "BD1000", "fully right is 10, fully left 00");
		Check.equal(Kit.sampleName(Kit.VOICES[2], []), "CP", "the clap has no knobs");
	}

	static function pitchRates() {
		Check.near(HitShape.playbackRate(0), 1, "no change");
		Check.near(HitShape.playbackRate(12), 2, "an octave up");
		Check.near(HitShape.playbackRate(-12), 0.5, "an octave down");
	}

	/** Every plan as "startDelay offset stopAfter fadeIn fadeOut", rounded, to compare at a glance. */
	static function describe(plan:HitPlan):String {
		final round = (value:Null<Float>) -> value == null ? "end" : Std.string(Math.round(value * 1000) / 1000);
		return [plan.startDelay, plan.offset, plan.stopAfter, plan.fadeIn, plan.fadeOut].map(round).join(" ");
	}

	static function forwardsHits() {
		Check.equal(describe(HitShape.forwards(0.3, 1, 1)), "0 0 end 0 0", "the whole sound");
		Check.equal(describe(HitShape.forwards(0.3, 1, 0.5)), "0 0 0.06 0 0.09", "half of it: heard 0.15 s, fading over the last 0.09");
		Check.equal(describe(HitShape.forwards(0.3, 2, 0.5)), "0 0 0.03 0 0.045", "an octave up is half as long again");
	}

	static function backwardsHits() {
		Check.equal(describe(HitShape.backwards(0.3, 1, 1, 0.125)), "0 0.175 0.125 0.012 0", "cut to the step, fast fade in");
		Check.equal(describe(HitShape.backwards(0.3, 1, 1, 0.375)), "0.075 0 0.3 0 0", "shorter than the step: starts late");
		Check.equal(describe(HitShape.backwards(0.3, 2, 1, 0.125)), "0 0.05 0.125 0.012 0", "an octave up covers twice the sample");
		Check.equal(describe(HitShape.backwards(0.3, 1, 0.5, 0.375)), "0.225 0.15 0.15 0.09 0", "shortened: swells in from silence");
	}

	// ── The overdrive curve ───────────────────────────────────────────

	static final MIDDLE = Std.int(Saturation.CURVE_POINTS / 2);
	static final LAST = Saturation.CURVE_POINTS - 1;

	/** Where the curve takes an input from -1 to 1. */
	static function inputAt(point:Int):Float {
		return point / LAST * 2 - 1;
	}

	static function noDriveIsClean() {
		final curve = Saturation.curve(0);
		var furthest = 0.0;
		for (point in 0...curve.length) furthest = Math.max(furthest, Math.abs(curve[point] - inputAt(point)));
		Check.isTrue(furthest < 0.005, 'within 0.5% of a straight line (was ${furthest})');
	}

	static function fullDriveShape() {
		final curve = Saturation.curve(100);
		Check.isTrue(Math.abs(curve[MIDDLE]) < 1e-6, "silence stays silent");
		Check.isTrue(Math.abs(curve[LAST] - 1) < 1e-6, "full level stays full level");
		Check.isTrue(curve[Std.int(LAST * 0.6)] > 0.6, "quiet sounds are pushed up: that is the drive");
		var rising = true;
		for (point in 1...curve.length) rising = rising && curve[point] >= curve[point - 1];
		Check.isTrue(rising, "never folds back on itself");
	}

	static function fullDriveIsLopsided() {
		final curve = Saturation.curve(100);
		final quarterUp = curve[Std.int(LAST * 0.625)];
		final quarterDown = curve[Std.int(LAST * 0.375)];
		Check.isTrue(Math.abs(quarterUp + quarterDown) > 0.05, "the lower half is rounded differently from the upper");
		Check.isTrue(Math.abs(curve[0] + 1) < 1e-6, "but both halves still reach full scale");
	}

	static function driveDarkensAndTrims() {
		Check.isTrue(Saturation.cutoffHz(100) < Saturation.cutoffHz(50), "more drive, darker");
		Check.near(Saturation.cutoffHz(0), 18000, "no drive, fully open");
		Check.near(Saturation.trimDecibels(100), -12, "full drive is trimmed 12 dB");
		Check.near(Saturation.trimDecibels(25), -6, "a quarter of the way is already half the trim");
	}

	static function safetyClipper() {
		final curve = Saturation.clipCurve();
		final slopeAtSilence = (curve[MIDDLE + 1] - curve[MIDDLE - 1]) / (inputAt(MIDDLE + 1) - inputAt(MIDDLE - 1));
		Check.isTrue(Math.abs(slopeAtSilence - Loudness.decibelsToGain(12)) < 0.01, "quiet sounds come back up 12 dB");
		Check.isTrue(curve[LAST] < 1 && curve[0] > -1, "the loudest peak stays under full scale");
	}

	// ── The URL code ──────────────────────────────────────────────────

	static function codeRoundTrip() {
		final code = PatternCode.encode(exampleMachine());
		final decoded = PatternCode.decode(code);
		Check.equal(PatternCode.encode(decoded), code, "encode → decode → encode is stable");
		Check.equal('${decoded.tempo} ${decoded.swing} ${decoded.drive} ${decoded.reverb}', "133 66 40 25", "machine settings");
		Check.equal('${decoded.shown} ${decoded.sequence.join(",")}', "7 7,0,7,2", "the pattern shown and the sequence, in its order");
		Check.isTrue(!Patterns.hasSteps(decoded.patterns[2]), "a blank pattern comes back blank");
		Check.equal(StepRow.print(decoded.patterns[0][1].steps), "....x.......x...", "pattern 1");
		checkUnusualPattern(decoded.patterns[7]);
	}

	/** Pattern 8 of the example, after its trip through a code: every unusual value intact. */
	static function checkUnusualPattern(tracks:Pattern) {
		Check.equal(StepRow.print(tracks[0].steps), "x..X....o.x....x", "first row, incl. step 16");
		Check.equal('${tracks[0].steps[10].velocity} ${tracks[0].steps[10].reversed}', "61 true", "an odd velocity, reversed");
		Check.isTrue(!tracks[0].steps[0].reversed, "forwards stays forwards");
		Check.equal('${tracks[0].steps[0].nudge} ${tracks[0].steps[15].nudge}', "-16 16", "nudges at both ends");
		Check.equal('${tracks[2].volume} ${tracks[1].pitch} ${tracks[3].pitch} ${tracks[0].length}', "100 -12 12 5", "volume, pitch both ways, shortest length");
		Check.equal(tracks[0].dials.join(","), "4,0", "the kick's 808 knobs");
		Check.isTrue(tracks[2].muted, "mute");
	}

	static function badCodesRefused() {
		final valid = PatternCode.encode(exampleMachine());
		for (bad in [null, "", "4" + valid.substr(1), valid.substr(0, valid.length - 1), valid + "0", valid + "-"])
			Check.equal(PatternCode.decode(bad), null, 'refused: ${bad == null ? "null" : bad.substr(0, 12) + "…"}');
		Check.equal(PatternCode.decode(withLastPattern(valid, packed -> packed.split("_").slice(1).join("_"))), null, "a row missing");
		Check.equal(PatternCode.decode(withSecondRow(valid, row -> row + "4b60")), null, "a hit the mask does not mention");
		Check.equal(PatternCode.decode(withSecondRow(valid, row -> row + "4bz0")), null, "a nudge digit out of range");
		Check.equal(PatternCode.decode(withSecondRow(valid, row -> row.substr(0, row.length - 1) + "2")), null, "a direction that is not 0 or 1");
		Check.equal(PatternCode.decode(valid.substr(0, valid.length - 5)), null, "a part's sound settings missing");
		Check.equal(PatternCode.decode(valid.substr(0, valid.length - 1) + "5"), null, "an 808 knob past fully right");
		Check.isTrue(PatternCode.decode(valid.toUpperCase()) != null, "case does not matter");
	}

	static function badSequencesRefused() {
		final valid = PatternCode.encode(exampleMachine());
		final withHeader = (shown:String, sequence:String) -> valid.replace(".8.8183-", '.$shown.$sequence-');
		Check.isTrue(PatternCode.decode(withHeader("2", "3112")) != null, "any order, repeats included");
		final tooLong = [for (_ in 0...17) "1"].join("");
		for (bad in [["8", "19"], ["0", "1"], ["9", "1"], ["8", ""], ["8", tooLong]])
			Check.equal(PatternCode.decode(withHeader(bad[0], bad[1])), null, 'refused: shown ${bad[0]}, sequence "${bad[1]}"');
	}

	static function codeClamps() {
		final code = PatternCode.encode(exampleMachine()).split(".");
		code[1] = "999";
		code[2] = "10";
		final decoded = PatternCode.decode(code.join("."));
		Check.equal(decoded.tempo, Limits.TEMPO.max, "tempo capped");
		Check.equal(decoded.swing, Limits.SWING.min, "swing floored");
	}

	static function blankPatternsCostNothing() {
		final code = PatternCode.encode(exampleMachine());
		Check.equal(code.split("-").length, Limits.PATTERNS + 1, "the settings, then one place per pattern");
		Check.equal([for (packed in code.split("-")) packed == "" ? "." : "x"].join(""), "xx......x", "only the used ones take space");
	}

	/** The beat a bümbap 1 link carried: the starter beat with the kick on step 3 too, exactly as the live site wrote it. */
	static function oneLinksStillOpen() {
		final oldLink = "5.100.50.0.0.044564g055g055g064g0_901064g064g032g0_100055g0_555555g032g055g032g055g032g055g032g0"
			+ "_400055g0_0000_0000_208032g055g0.5050505050505050.00000000.c6412c6422c6400c6400c6420c6420c6420c6400";
		final opened = PatternCode.decode(oldLink);
		Check.equal(StepRow.print(opened.patterns[0][0].steps).substr(0, 4), "X.x.", "pattern 1 is the old beat");
		Check.equal('${opened.shown} ${opened.sequence.join(",")}', "0 0", "shown, and the whole sequence");
		Check.isTrue(!Lambda.exists(opened.patterns.slice(1), Patterns.hasSteps), "the other seven are blank");
		Check.equal(opened.tempo, 100, "with its tempo");
	}

	/** The code with its last pattern changed, to make one precise kind of damage. */
	static function withLastPattern(code:String, damage:String->String):String {
		final patterns = code.split("-");
		patterns[patterns.length - 1] = damage(patterns[patterns.length - 1]);
		return patterns.join("-");
	}

	/** The code with the second step row of its last pattern changed. */
	static function withSecondRow(code:String, damage:String->String):String {
		return withLastPattern(code, packed -> {
			final columns = packed.split(".");
			final rows = columns[0].split("_");
			rows[1] = damage(rows[1]);
			columns[0] = rows.join("_");
			return columns.join(".");
		});
	}

	/** Pattern 1 a small groove, pattern 8 the unusual one, the rest blank; the sequence 8, 1, 8, 3, with 8 shown. */
	static function exampleMachine():SavedMachine {
		final first = Patterns.blank();
		first[1] = {steps: StepRow.parse("....x.......x..."), volume: 80, muted: false, pitch: 0, length: 100, dials: [2, 2]};
		final patterns = [for (index in 0...Limits.PATTERNS) index == 0 ? first : (index == 7 ? exampleTracks() : Patterns.blank())];
		return {tempo: 133, swing: 66, drive: 40, reverb: 25, patterns: patterns, shown: 7, sequence: [7, 0, 7, 2]};
	}

	/** A pattern with something unusual on every axis, to catch packing mistakes. */
	static function exampleTracks():Pattern {
		final rows = ["x..X....o.x....x", "....x.......x...", "x.x.x.x.x.x.x.x."];
		final tracks = [for (index in 0...Kit.VOICES.length) {
			steps: StepRow.parse(index < rows.length ? rows[index] : ""),
			volume: index == 2 ? 100 : index * 7,
			muted: index == 2,
			pitch: index == 1 ? -12 : (index == 3 ? 12 : 0),
			length: index == 0 ? 5 : 100,
			dials: index == 0 ? [4, 0] : [2, 2]
		}];
		tracks[0].steps[0] = Step.hit(75, -16);
		tracks[0].steps[10] = Step.hit(61, 3, true);
		tracks[0].steps[15] = Step.hit(75, 16);
		return tracks;
	}
}
