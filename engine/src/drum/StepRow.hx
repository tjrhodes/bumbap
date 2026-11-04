package drum;

import drum.State.StepSettings;

/**
 * A row of steps written the way drummers sketch them: "X" for an accent,
 * "x" for a normal hit, "o" for a ghost note, "." for a rest. For example
 * "X...x...X...x.o." Used for the starter beat and to keep tests readable.
 * Nudges are not written; a row always sits on the grid.
 */
class StepRow {
	static inline final REST = ".";
	static inline final NORMAL = "x";

	/** The velocity behind each written hit. */
	static final VELOCITY_OF = ["X" => 100, NORMAL => Limits.VELOCITY.initial, "o" => 50];

	/** Reads a written row, one character per step, into sixteen steps. A short row is padded with rests. */
	public static function parse(row:String):Array<StepSettings> {
		return [for (step in 0...Limits.STEPS) stepFor(row.charAt(step))];
	}

	/**
	 * The other way round: writes sixteen steps as a row, so a test can say what it expects in a form people
	 * can read.
	 */
	public static function print(steps:Array<StepSettings>):String {
		return [for (step in steps) step.on ? symbolFor(step.velocity) : REST].join("");
	}

	/**
	 * One character into one step. Anything that isn't a hit symbol (a dot, a space, a missing character) is a
	 * rest.
	 */
	static function stepFor(symbol:String):StepSettings {
		final velocity = VELOCITY_OF[symbol];
		return velocity == null ? Step.REST : Step.hit(velocity, Limits.NUDGE.initial);
	}

	/** Velocities between the written ones print as a normal hit. */
	static function symbolFor(velocity:Int):String {
		for (symbol => written in VELOCITY_OF) if (written == velocity) return symbol;
		return NORMAL;
	}
}
