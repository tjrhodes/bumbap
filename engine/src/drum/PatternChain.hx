package drum;

/**
 * Which of the eight patterns plays, and in what order. Plain data with guarded edits; it knows nothing
 * about sound or time, the machine tells it when a bar ends.
 *
 * - The chain is any set of patterns, played in number order and round again: 1, 3, 6, 1, 3, 6…
 *   It always keeps at least one.
 * - The shown pattern is the one playing, or when stopped the one on the keys.
 * - A pattern chosen while the machine plays waits, queued, for the end of the bar.
 */
class PatternChain {
	public static inline final NONE = -1;

	public var shown(default, null) = 0;
	public var members(default, null):Array<Int> = [0];
	public var queued(default, null) = NONE;

	public function new() {}

	/** Just this pattern from now on. Playing, it is queued for the end of the bar (the machine shows it then). */
	public function choose(pattern:Int, playing:Bool) {
		members = [pattern];
		queued = playing && pattern != shown ? pattern : NONE;
	}

	/** Exactly these patterns, in number order (duplicates dropped); an empty list changes nothing. */
	public function chainExactly(patterns:Array<Int>) {
		final ordered = inNumberOrder(patterns);
		if (ordered.length == 0) return;
		members = ordered;
		forgetQueuedOutsideChain();
	}

	/** Adds a pattern to the chain, or takes it out; the last one stays. */
	public function toggle(pattern:Int) {
		final without = members.filter(member -> member != pattern);
		if (without.length == members.length) members = inNumberOrder(members.concat([pattern]));
		else if (without.length > 0) members = without;
		forgetQueuedOutsideChain();
	}

	/** The pattern for the next bar: the queued one, or else the chain's next after the shown one, round again. */
	public function next():Int {
		if (queued != NONE) return queued;
		for (member in members) if (member > shown) return member;
		return members[0];
	}

	/** The pattern Play starts on: the shown one if it is in the chain, otherwise the chain's first. */
	public function first():Int {
		return members.contains(shown) ? shown : members[0];
	}

	/** The machine now shows this pattern; whatever was queued has arrived (or, stopped, is forgotten). */
	public function moveTo(pattern:Int) {
		shown = pattern;
		queued = NONE;
	}

	/** From a shared link, which has already checked the numbers. */
	public function restore(shown:Int, members:Array<Int>) {
		moveTo(shown);
		this.members = members.copy();
	}

	function forgetQueuedOutsideChain() {
		if (!members.contains(queued)) queued = NONE;
	}

	static function inNumberOrder(patterns:Array<Int>):Array<Int> {
		final unique = [for (pattern in patterns) if (Patterns.exists(pattern)) pattern => true];
		final ordered = [for (pattern in unique.keys()) pattern];
		ordered.sort((a, b) -> a - b);
		return ordered;
	}
}
