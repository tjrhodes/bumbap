package drum;

/**
 * The order the eight patterns play in. Plain data with guarded edits; it knows nothing about sound or
 * time, the machine tells it when a bar ends.
 *
 * - The sequence is a list of patterns played in its own order and round again, repeats allowed:
 *   3, 1, 3, 6, 3, 1, 3, 6… It holds 1 to 16 entries.
 * - The shown pattern is the one playing, or when stopped the one on the keys; `position` is where in the
 *   list it is playing (NONE when it is not in it), so a pattern listed twice knows which turn it is on.
 * - A pattern chosen on its own while the machine plays waits, queued, for the end of the bar.
 */
class Sequence {
	public static inline final NONE = -1;
	public static inline final MOST = 16;

	public var shown(default, null) = 0;
	public var patterns(default, null):Array<Int> = [0];
	public var queued(default, null) = NONE;
	public var position(default, null) = 0;

	public function new() {}

	/** Just this pattern from now on. Playing, it is queued for the end of the bar (the machine shows it then). */
	public function choose(pattern:Int, playing:Bool) {
		patterns = [pattern];
		queued = playing && pattern != shown ? pattern : NONE;
		position = pattern == shown ? 0 : NONE;
	}

	/** Exactly these patterns, in this order (those that do not exist are dropped); an empty list changes nothing. */
	public function replace(list:Array<Int>) {
		final valid = list.filter(Patterns.exists).slice(0, MOST);
		if (valid.length == 0) return;
		patterns = valid;
		afterEdit();
	}

	/** One more at the end, while there is room. */
	public function append(pattern:Int) {
		if (Patterns.exists(pattern) && patterns.length < MOST) patterns = patterns.concat([pattern]);
		afterEdit();
	}

	/** In the sequence: taken out (every time it is there), unless it is all that is left. Not in it: added at the end. */
	public function toggle(pattern:Int) {
		final without = patterns.filter(listed -> listed != pattern);
		if (without.length == patterns.length) append(pattern); else replace(without);
	}

	/** The bar is ending: moves on to the queued pattern, or else the next in the list, and gives the one to play. */
	public function advance():Int {
		if (queued != NONE) {
			position = patterns.indexOf(queued);
			return queued;
		}
		position = (position + 1) % patterns.length; // from NONE (-1), that is the first
		return patterns[position];
	}

	/** Play starts on the shown pattern where the list has it, otherwise on the list's first. */
	public function start():Int {
		position = Std.int(Math.max(0, patterns.indexOf(shown)));
		return patterns[position];
	}

	/** The machine now shows this pattern; whatever was queued has arrived (or, stopped, is forgotten). */
	public function show(pattern:Int) {
		shown = pattern;
		queued = NONE;
		if (patterns[position] != shown) position = patterns.indexOf(shown);
	}

	/** From a shared link, which has already checked the numbers. */
	public function restore(shown:Int, patterns:Array<Int>) {
		this.patterns = patterns.copy();
		position = NONE;
		show(shown);
	}

	/** The shown pattern keeps its turn if the list still has it there; a queued pattern no longer listed is forgotten. */
	function afterEdit() {
		if (position == NONE || patterns[position] != shown) position = patterns.indexOf(shown);
		if (queued != NONE && !patterns.contains(queued)) queued = NONE;
	}
}
