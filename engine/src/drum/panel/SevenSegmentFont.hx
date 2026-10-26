package drum.panel;

/**
 * The four-digit LED display, as data every front end draws the same way.
 * Segments are named the standard way: a top, b top right, c bottom right,
 * d bottom, e bottom left, f top left, g middle. Each digit is a 50 × 90 box,
 * slanted like LED glass; all seven segments are always drawn, lit or not.
 */
@:expose("SevenSegmentFont")
class SevenSegmentFont {
	public static inline final DIGITS = 4;
	/** For the display's svg element. */
	public static inline final VIEW_BOX = "0 0 250 100";
	public static final SEGMENTS = ["a", "b", "c", "d", "e", "f", "g"];

	static inline final THICKNESS = 8;

	/** Which segments light for each character the panel ever shows. */
	static final LIT:haxe.DynamicAccess<String> = {
		"0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg", "5": "acdfg", "6": "acdefg",
		"7": "abc", "8": "abcdefg", "9": "abcdfg", " ": "", "-": "g",
		"A": "abcefg", "d": "bcdeg", "E": "adefg", "r": "eg", "L": "def", "S": "acdfg", "u": "cde", "n": "ceg", "P": "abefg"
	};

	/** Each segment's centre line: [x1, y1, x2, y2]. */
	static final LINES:haxe.DynamicAccess<Array<Float>> = {
		a: [7, 5, 43, 5], b: [45, 7, 45, 43], c: [45, 47, 45, 83], d: [7, 85, 43, 85],
		e: [5, 47, 5, 83], f: [5, 7, 5, 43], g: [7, 45, 43, 45]
	};

	/** Exactly four characters, right-aligned like a calculator: "100" → [" ", "1", "0", "0"]. */
	public static function characters(text:String):Array<String> {
		final padded = StringTools.lpad(text, " ", DIGITS);
		return padded.substr(padded.length - DIGITS).split("");
	}

	public static function isLit(character:String, segment:String):Bool {
		return (LIT[character] ?? "").indexOf(segment) >= 0;
	}

	/** Places digit 0–3 along the display and slants it. */
	public static function digitTransform(index:Int):String {
		return 'translate(${22 + index * 56} 5) skewX(-7)';
	}

	/** A segment is a long hexagon pointed at both ends, so neighbours meet at a mitre like LED glass. */
	public static function segmentPoints(segment:String):String {
		final line = LINES[segment];
		final half = THICKNESS / 2;
		final horizontal = line[1] == line[3];
		final along = horizontal ? [half, 0.0] : [0.0, half];
		final across = horizontal ? [0.0, half] : [half, 0.0];
		final corners = [[line[0], line[1]], [line[0] + along[0] - across[0], line[1] + along[1] - across[1]],
			[line[2] - along[0] - across[0], line[3] - along[1] - across[1]], [line[2], line[3]],
			[line[2] - along[0] + across[0], line[3] - along[1] + across[1]], [line[0] + along[0] + across[0], line[1] + along[1] + across[1]]];
		return [for (corner in corners) corner.join(",")].join(" ");
	}
}
