package drum;

/**
 * The order the eight patterns play in. Plain data with guarded edits; it knows nothing about sound or
 * time, the machine tells it when a bar ends. Which pattern is being edited is not its business: any
 * pattern can be on the keys while the sequence plays.
 *
 * - The sequence is a list of patterns played in its own order and round again, repeats allowed:
 *   3, 1, 3, 6, 3, 1, 3, 6… It holds 1 to 16 entries.
 * - `playing` is the pattern sounding this bar, and `position` its turn in the list, so a pattern listed
 *   twice knows which turn it is on. Edited under it so that the pattern playing is no longer listed,
 *   the position is NONE: the bar finishes, then the sequence starts again from the top.
 */
class Sequence {
	public static inline final NONE = -1;
	public static inline final MOST = 16;

	public var patterns(default, null):Array<Int> = [0];
	public var position(default, null) = 0;
	public var playing(default, null) = 0;

	public function new() {}

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

	/** Play starts at the top of the list. */
	public function start():Int {
		position = 0;
		playing = patterns[0];
		return playing;
	}

	/** The bar is ending: moves on to the next turn (the top, after an edit took the playing one away). */
	public function advance():Int {
		position = (position + 1) % patterns.length; // from NONE (-1), that is the first
		playing = patterns[position];
		return playing;
	}

	/** The pattern the next bar plays. */
	public function next():Int {
		return patterns[(position + 1) % patterns.length];
	}

	/** From a shared link, which has already checked the numbers. */
	public function restore(patterns:Array<Int>) {
		this.patterns = patterns.copy();
		start();
	}

	/** The pattern playing keeps its turn where the list still has it; otherwise the next bar starts from the top. */
	function afterEdit() {
		if (patterns[position] != playing) position = patterns.indexOf(playing);
	}
}
