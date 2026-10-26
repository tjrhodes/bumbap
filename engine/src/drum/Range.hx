package drum;

/**
 * The allowed span of one user setting (tempo, swing, volume) and the
 * value it starts at. Settings are whole numbers so that what the user
 * sees, what the engine plays and what the URL stores are always equal.
 */
class Range {
	public final min:Int;
	public final max:Int;
	public final initial:Int;

	public function new(min:Int, max:Int, initial:Int) {
		this.min = min;
		this.max = max;
		this.initial = initial;
	}

	/**
	 * Turns any number a UI hands us (a slider value, a typed number,
	 * garbage) into a safe whole number inside the range.
	 */
	public function clamp(value:Float):Int {
		if (Math.isNaN(value)) return initial;
		final whole = Math.round(value);
		return whole < min ? min : (whole > max ? max : whole);
	}
}
