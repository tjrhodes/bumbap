package drum;

import drum.State.Pattern;
import drum.State.SavedMachine;
import drum.State.StepSettings;
import drum.State.TrackSettings;
import js.lib.WeakMap;

/**
 * Packs the whole machine into a short, URL-safe code and back, so a groove
 * can be shared as a link:
 *
 *     6.<tempo>.<swing>.<drive>.<reverb>.<shown>.<chain>-<pattern 1>-<pattern 2>-…-<pattern 8>
 *
 * - shown: the pattern on the keys, 1–8. chain: the chained patterns, e.g. "136".
 * - each pattern is <rows>.<volumes>.<mutes>.<sounds>, or nothing at all when it
 *   is blank (no steps, every part as it starts), so unused patterns cost one "-".
 * - rows: one per track, joined by "_". Each row is 4 hex digits saying which
 *   steps play (step 1 is the lowest bit), then 4 characters per playing step,
 *   in order: 2 hex digits of velocity, 1 digit of nudge and 1 for direction
 *   (0 forwards, 1 reversed). Rests cost nothing.
 * - volumes: 2 hex digits per track. mutes: 0 or 1 per track.
 * - sounds: 5 characters per track: 1 digit of pitch, 2 hex digits of length,
 *   then 2 digits for the 808 knobs (0–4; parts with fewer knobs write 0).
 *
 * A "digit" for a signed setting (nudge, pitch) is its value counted from the
 * bottom of its range, in base 36: nudge −16 is "0", nudge 0 is "g".
 *
 * The leading digit is the format version. Version 5 is a bümbap 1 link, with
 * one pattern: "5.<tempo>.<swing>.<drive>.<reverb>.<pattern>". It still opens,
 * as pattern 1.
 */
class PatternCode {
	static inline final VERSION = "6";
	static inline final ONE_PATTERN_VERSION = "5";
	static inline final SEPARATOR = ".";
	static inline final PATTERN_SEPARATOR = "-";
	static inline final ROW_SEPARATOR = "_";
	static inline final MASK_DIGITS = 4; // 16 steps = 16 bits = 4 hex digits
	static inline final VELOCITY_DIGITS = 2; // 1–100 fits in two hex digits
	static inline final HIT_DIGITS = VELOCITY_DIGITS + 2; // velocity, one nudge digit, one direction digit
	static inline final VOLUME_DIGITS = 2;
	static inline final LENGTH_DIGITS = 2;
	static inline final SOUND_DIGITS = 1 + LENGTH_DIGITS + Kit.MOST_DIALS; // pitch, length, 808 knobs
	static inline final BASE_36 = "0123456789abcdefghijklmnopqrstuvwxyz";
	static inline final SETTINGS = "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})"; // tempo, swing, drive, reverb

	static final NUDGE_DIGITS = digitsFor(Limits.NUDGE);
	static final PITCH_DIGITS = digitsFor(Limits.PITCH);
	static final DIAL_DIGITS = digitsFor(Limits.DIAL);
	static final PATTERN_DIGITS = '[1-${Limits.PATTERNS}]';

	/**
	 * Patterns are never changed once saved, so each is packed only once: a code is made on every edit,
	 * and only the pattern being edited is new each time.
	 */
	static final packedAlready = new WeakMap<String>(); // keyed by the pattern itself
	static var blankPacked:Null<String>;

	public static function encode(saved:SavedMachine):String {
		final settings = [saved.tempo, saved.swing, saved.drive, saved.reverb].map(Std.string);
		final header = [VERSION].concat(settings).concat([numbered([saved.shown]), numbered(saved.chain)]);
		final patterns = [for (pattern in saved.patterns) isBlank(pattern) ? "" : pack(pattern)];
		return [header.join(SEPARATOR)].concat(patterns).join(PATTERN_SEPARATOR);
	}

	/** Returns null for anything that is not a valid code for this kit. */
	public static function decode(code:Null<String>):Null<SavedMachine> {
		if (code == null) return null;
		final lower = code.toLowerCase();
		return StringTools.startsWith(lower, ONE_PATTERN_VERSION + SEPARATOR) ? decodeOnePattern(lower) : decodeEveryPattern(lower);
	}

	/** One character for every whole value in the range, lowest first. */
	static function digitsFor(range:Range):String {
		return BASE_36.substr(0, range.max - range.min + 1);
	}

	// ── Encoding ───────────────────────────────────────────────────────

	/** Pattern numbers as people count them, 1–8, written one after another: [0, 2, 5] is "136". */
	static function numbered(patterns:Array<Int>):String {
		return patterns.map(index -> Std.string(index + 1)).join("");
	}

	static function isBlank(pattern:Pattern):Bool {
		blankPacked ??= encodePattern(Patterns.blank());
		return pack(pattern) == blankPacked;
	}

	static function pack(pattern:Pattern):String {
		if (!packedAlready.has(pattern)) packedAlready.set(pattern, encodePattern(pattern));
		return packedAlready.get(pattern);
	}

	/** Rows, volumes, mutes, sounds: each a column across the eight parts. */
	static function encodePattern(tracks:Pattern):String {
		return [
			[for (track in tracks) encodeRow(track.steps)].join(ROW_SEPARATOR),
			[for (track in tracks) StringTools.hex(track.volume, VOLUME_DIGITS)].join(""),
			[for (track in tracks) track.muted ? "1" : "0"].join(""),
			[for (track in tracks) encodeSound(track)].join("")
		].join(SEPARATOR).toLowerCase();
	}

	/** The mask of playing steps, followed by each playing step's velocity, nudge and direction. */
	static function encodeRow(steps:Array<StepSettings>):String {
		var mask = 0;
		final hits = [];
		for (step in 0...Limits.STEPS) {
			if (!steps[step].on) continue;
			mask |= 1 << step;
			hits.push(encodeHit(steps[step]));
		}
		return StringTools.hex(mask, MASK_DIGITS) + hits.join("");
	}

	static function encodeHit(hit:StepSettings):String {
		final nudgeDigit = NUDGE_DIGITS.charAt(hit.nudge - Limits.NUDGE.min);
		return StringTools.hex(hit.velocity, VELOCITY_DIGITS) + nudgeDigit + (hit.reversed ? "1" : "0");
	}

	/** Pitch, length, then the 808 knobs, padded with 0 to the most any part has. */
	static function encodeSound(track:TrackSettings):String {
		final pitchDigit = PITCH_DIGITS.charAt(track.pitch - Limits.PITCH.min);
		final dials = [for (dial in 0...Kit.MOST_DIALS) DIAL_DIGITS.charAt(track.dials[dial] ?? 0)].join("");
		return pitchDigit + StringTools.hex(track.length, LENGTH_DIGITS) + dials;
	}

	// ── Decoding ───────────────────────────────────────────────────────

	/** A bümbap 1 link: its one pattern becomes pattern 1, the others blank, and the chain just pattern 1. */
	static function decodeOnePattern(code:String):Null<SavedMachine> {
		final shape = new EReg('^$ONE_PATTERN_VERSION\\.$SETTINGS\\.(.+)$$', "");
		if (!shape.match(code)) return null;
		final pattern = decodePattern(shape.matched(5));
		if (pattern == null) return null;
		return machine(shape, [pattern].concat([for (_ in 1...Limits.PATTERNS) Patterns.blank()]), 0, [0]);
	}

	static function decodeEveryPattern(code:String):Null<SavedMachine> {
		final parts = code.split(PATTERN_SEPARATOR);
		final header = new EReg('^$VERSION\\.$SETTINGS\\.($PATTERN_DIGITS)\\.($PATTERN_DIGITS+)$$', "");
		if (parts.length != Limits.PATTERNS + 1 || !header.match(parts[0])) return null;
		final patterns = [for (packed in parts.slice(1)) packed == "" ? Patterns.blank() : decodePattern(packed)];
		final chain = decodeChain(header.matched(6));
		if (patterns.contains(null) || chain == null) return null;
		return machine(header, patterns, Std.parseInt(header.matched(5)) - 1, chain);
	}

	/** The machine's settings (groups 1–4 of the shape that matched), clamped, with its patterns. */
	static function machine(shape:EReg, patterns:Array<Pattern>, shown:Int, chain:Array<Int>):SavedMachine {
		final setting = (group:Int) -> Std.parseInt(shape.matched(group));
		return {
			tempo: Limits.TEMPO.clamp(setting(1)), swing: Limits.SWING.clamp(setting(2)),
			drive: Limits.DRIVE.clamp(setting(3)), reverb: Limits.REVERB.clamp(setting(4)),
			patterns: patterns, shown: shown, chain: chain
		};
	}

	/** "136" is [0, 2, 5]; numbers out of order or twice are refused, as no machine writes them. */
	static function decodeChain(digits:String):Null<Array<Int>> {
		final chain = [for (digit in digits.split("")) Std.parseInt(digit) - 1];
		for (index in 1...chain.length) if (chain[index] <= chain[index - 1]) return null;
		return chain;
	}

	/** One pattern: rows, volumes, mutes and sounds; null unless every part is there and well formed. */
	static function decodePattern(packed:String):Null<Pattern> {
		final shape = patternShape();
		if (!shape.match(packed)) return null;
		return decodeTracks(shape.matched(1).split(ROW_SEPARATOR), [for (group in 2...5) shape.matched(group)]);
	}

	/** The overall shape of one pattern; the row details are checked row by row. */
	static function patternShape():EReg {
		final voices = Kit.VOICES.length;
		final rows = '([0-9a-f${NUDGE_DIGITS}${ROW_SEPARATOR}]+)';
		final sound = '[$PITCH_DIGITS][0-9a-f]{$LENGTH_DIGITS}[$DIAL_DIGITS]{${Kit.MOST_DIALS}}';
		final parts = [rows, '([0-9a-f]{${voices * VOLUME_DIGITS}})', '([01]{$voices})', '((?:$sound){$voices})'];
		return new EReg("^" + parts.join("\\" + SEPARATOR) + "$", "");
	}

	/** Every row must be valid, and there must be exactly one per voice. columns = [volumes, mutes, sounds]. */
	static function decodeTracks(rows:Array<String>, columns:Array<String>):Null<Array<TrackSettings>> {
		if (rows.length != Kit.VOICES.length) return null;
		final tracks = [];
		for (index in 0...rows.length) {
			final steps = decodeRow(rows[index]);
			if (steps == null) return null;
			tracks.push(decodeTrack(index, steps, columns));
		}
		return tracks;
	}

	/** Each track owns one slice of each column. */
	static function decodeTrack(index:Int, steps:Array<StepSettings>, columns:Array<String>):TrackSettings {
		final volumeHex = columns[0].substr(index * VOLUME_DIGITS, VOLUME_DIGITS);
		final sound = columns[2].substr(index * SOUND_DIGITS, SOUND_DIGITS);
		return {
			steps: steps,
			volume: Limits.VOLUME.clamp(Std.parseInt("0x" + volumeHex)),
			muted: columns[1].charAt(index) == "1",
			pitch: PITCH_DIGITS.indexOf(sound.charAt(0)) + Limits.PITCH.min,
			length: Limits.LENGTH.clamp(Std.parseInt("0x" + sound.substr(1, LENGTH_DIGITS))),
			dials: [for (dial in 0...Kit.MOST_DIALS) DIAL_DIGITS.indexOf(sound.charAt(1 + LENGTH_DIGITS + dial))]
		};
	}

	/** Null unless the row is well formed and has one hit for each step its mask says plays. */
	static function decodeRow(row:String):Null<Array<StepSettings>> {
		if (!rowShape().match(row)) return null;
		final mask = Std.parseInt("0x" + row.substr(0, MASK_DIGITS));
		final hits = row.substr(MASK_DIGITS);
		var nextHit = 0;
		final steps = [];
		for (step in 0...Limits.STEPS) steps.push((mask & (1 << step)) == 0 ? Step.REST : decodeHit(hits, nextHit++));
		return hits.length == nextHit * HIT_DIGITS ? steps : null;
	}

	/** A mask, then any number of hits: two hex digits of velocity, a nudge digit, a direction digit. */
	static function rowShape():EReg {
		return new EReg('^[0-9a-f]{$MASK_DIGITS}([0-9a-f]{$VELOCITY_DIGITS}[$NUDGE_DIGITS][01])*$', "");
	}

	static function decodeHit(hits:String, index:Int):StepSettings {
		final hit = hits.substr(index * HIT_DIGITS, HIT_DIGITS);
		final velocity = Std.parseInt("0x" + hit.substr(0, VELOCITY_DIGITS));
		final nudge = NUDGE_DIGITS.indexOf(hit.charAt(VELOCITY_DIGITS)) + Limits.NUDGE.min;
		return Step.hit(velocity, nudge, hit.charAt(VELOCITY_DIGITS + 1) == "1");
	}
}
