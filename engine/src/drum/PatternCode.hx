package drum;

import drum.State.Pattern;
import drum.State.StepSettings;
import drum.State.TrackSettings;

/**
 * Packs a whole pattern into a short, URL-safe code and back, so a groove
 * can be shared as a link:
 *
 *     5.<tempo>.<swing>.<drive>.<reverb>.<rows>.<volumes>.<mutes>.<sounds>
 *
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
 * The leading "5" is the format version, so a future format can tell old
 * links apart instead of misreading them.
 */
class PatternCode {
	static inline final VERSION = "5";
	static inline final SEPARATOR = ".";
	static inline final ROW_SEPARATOR = "_";
	static inline final MASK_DIGITS = 4; // 16 steps = 16 bits = 4 hex digits
	static inline final VELOCITY_DIGITS = 2; // 1–100 fits in two hex digits
	static inline final HIT_DIGITS = VELOCITY_DIGITS + 2; // velocity, one nudge digit, one direction digit
	static inline final VOLUME_DIGITS = 2;
	static inline final LENGTH_DIGITS = 2;
	static inline final SOUND_DIGITS = 1 + LENGTH_DIGITS + Kit.MOST_DIALS; // pitch, length, 808 knobs
	static inline final BASE_36 = "0123456789abcdefghijklmnopqrstuvwxyz";

	static final NUDGE_DIGITS = digitsFor(Limits.NUDGE);
	static final PITCH_DIGITS = digitsFor(Limits.PITCH);
	static final DIAL_DIGITS = digitsFor(Limits.DIAL);

	public static function encode(pattern:Pattern):String {
		final parts = [VERSION].concat([pattern.tempo, pattern.swing, pattern.drive, pattern.reverb].map(Std.string));
		parts.push([for (track in pattern.tracks) encodeRow(track.steps)].join(ROW_SEPARATOR));
		parts.push([for (track in pattern.tracks) StringTools.hex(track.volume, VOLUME_DIGITS)].join(""));
		parts.push([for (track in pattern.tracks) track.muted ? "1" : "0"].join(""));
		parts.push([for (track in pattern.tracks) encodeSound(track)].join(""));
		return parts.join(SEPARATOR).toLowerCase();
	}

	/** Returns null for anything that is not a valid code for this kit. */
	public static function decode(code:String):Null<Pattern> {
		final shape = codeShape();
		if (code == null || !shape.match(code.toLowerCase())) return null;
		final settings = [for (group in 1...5) Std.parseInt(shape.matched(group))];
		final tracks = decodeTracks(shape.matched(5).split(ROW_SEPARATOR), [for (group in 6...9) shape.matched(group)]);
		if (tracks == null) return null;
		return {
			tempo: Limits.TEMPO.clamp(settings[0]),
			swing: Limits.SWING.clamp(settings[1]),
			drive: Limits.DRIVE.clamp(settings[2]),
			reverb: Limits.REVERB.clamp(settings[3]),
			tracks: tracks
		};
	}

	/** One character for every whole value in the range, lowest first. */
	static function digitsFor(range:Range):String {
		return BASE_36.substr(0, range.max - range.min + 1);
	}

	// ── Encoding ───────────────────────────────────────────────────────

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

	/** The overall shape of a valid code; the row details are checked row by row. */
	static function codeShape():EReg {
		final voices = Kit.VOICES.length;
		final number = "(\\d{1,3})";
		final rows = '([0-9a-f${NUDGE_DIGITS}${ROW_SEPARATOR}]+)';
		final sound = '[$PITCH_DIGITS][0-9a-f]{$LENGTH_DIGITS}[$DIAL_DIGITS]{${Kit.MOST_DIALS}}';
		final parts = [VERSION, number, number, number, number, rows, '([0-9a-f]{${voices * VOLUME_DIGITS}})', '([01]{$voices})', '((?:$sound){$voices})'];
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
