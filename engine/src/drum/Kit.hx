package drum;

/** One of the 808's own knobs on a part, e.g. the kick's Tone. */
typedef DialSpec = {
	final name:String;
	/** Where it starts: 0 fully left … 4 fully right (see Limits.DIAL). */
	final initial:Int;
}

/** One drum sound: how the engine refers to it, how the UI labels it, which recordings it has. */
typedef Voice = {
	final id:String;
	final name:String;
	/** The TR-808 set's two-letter code, which starts every file name of this part. */
	final sampleCode:String;
	/** The 808 knobs this part was recorded at; each position is a different file. */
	final dials:Array<DialSpec>;
	/** The starter beat for this voice, written as a step row (see StepRow). */
	final starterRow:String;
}

/**
 * The eight sounds of the machine, in the order they appear in the grid
 * and in the URL code. Changing the order changes what old URLs mean.
 *
 * The samples are Michael Fischer's TR-808 set, whose file names spell out
 * the 808's knob positions: two digits per knob, 00, 25, 50, 75 or 10 (fully
 * right). So the kick with Tone at 2.5 and Decay at 5 is BD2550.wav.
 */
class Kit {
	static final DIAL_DIGITS = ["00", "25", "50", "75", "10"];

	public static final VOICES:Array<Voice> = [
		voice("kick", "Kick", "BD", [dial("Tone", 1), dial("Decay", 2)], "X.....x...X....."),
		voice("snare", "Snare", "SD", [dial("Tone", 2), dial("Snappy", 2)], "....X.......X..o"),
		voice("clap", "Clap", "CP", [], "............x..."),
		voice("closed-hat", "Closed hat", "CH", [], "x.o.x.o.x.o.x.o."),
		voice("open-hat", "Open hat", "OH", [dial("Decay", 2)], "..............x."),
		voice("low-tom", "Low tom", "LT", [dial("Tuning", 2)], "................"),
		voice("high-tom", "High tom", "HT", [dial("Tuning", 2)], "................"),
		voice("rim", "Rim", "RS", [], ".......o.....x..")
	];

	/** The most 808 knobs any part has; the URL code keeps room for this many. */
	public static inline final MOST_DIALS = 2;

	/**
	 * The recording for these knob positions, e.g. "BD2550". Only the voice's own knobs count: a link keeps
	 * room for two on every part, so the clap arrives with two it does not have.
	 */
	public static function sampleName(voice:Voice, positions:Array<Int>):String {
		return voice.sampleCode + [for (dial in 0...voice.dials.length) DIAL_DIGITS[positions[dial]]].join("");
	}

	static function voice(id:String, name:String, sampleCode:String, dials:Array<DialSpec>, starterRow:String):Voice {
		return {id: id, name: name, sampleCode: sampleCode, dials: dials, starterRow: starterRow};
	}

	static function dial(name:String, initial:Int):DialSpec {
		return {name: name, initial: initial};
	}
}
