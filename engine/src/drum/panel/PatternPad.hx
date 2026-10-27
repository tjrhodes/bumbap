package drum.panel;

import drum.DrumMachine;
import drum.Patterns;

/**
 * The pattern buttons' gestures, written once for every front end. Each build forwards three events and
 * the pad turns them into the machine's calls:
 *
 * - a click chooses that pattern; a shift-click adds it to the chain or takes it out;
 * - holding one button and tapping others (a second finger) chains exactly those, in number order;
 * - dragging one button onto another copies the pattern there.
 *
 * Clicks come from the mouse, touch and the keyboard alike, so Enter and Shift+Enter work too. A press that
 * was part of a hold or a drag takes the click the browser sends after it, so it is not also a tap.
 */
@:expose("PatternPad")
class PatternPad {
	/** What `patternAt` gives where there is no pattern button. */
	public static final NONE = -1; // not inline: front ends read it

	final machine:DrumMachine;
	/** The pattern under each finger (or mouse button) that is down, by pointer id. */
	final held = new Map<Int, Int>();
	/** Patterns whose next click belongs to a hold or a drag, not a tap. */
	final clickTaken = new Map<Int, Bool>();
	/** Within one hold, the first tap sets the chain and later taps add to it or take out. */
	var chainingByHold = false;

	public function new(machine:DrumMachine) {
		this.machine = machine;
	}

	/** The pattern button under a point on the page (where a finger was lifted, say), or NONE. */
	public static function patternAt(x:Float, y:Float):Int {
		final element = js.Browser.document.elementFromPoint(Std.int(x), Std.int(y));
		final button = element == null ? null : element.closest("[data-pattern]");
		return button == null ? NONE : Std.parseInt(button.getAttribute("data-pattern"));
	}

	/** A pointer goes down on a pattern button. While another is held, this one is chained with it. */
	public function press(pointerId:Int, pattern:Int) {
		final heldBefore = [for (other in held) other];
		if (heldBefore.length == 0) clickTaken.clear(); // a new gesture: nothing left over from the last one
		held.set(pointerId, pattern);
		if (heldBefore.length == 0) return;
		if (chainingByHold) machine.toggleInChain(pattern); else machine.chainPatterns(heldBefore.concat([pattern]));
		chainingByHold = true;
		for (chained in heldBefore.concat([pattern])) clickTaken.set(chained, true);
	}

	/** The pointer comes up over `under` (a pattern, or NONE). Let go over another button, it copies the pattern there. */
	public function release(pointerId:Int, under:Int) {
		final pressed = held.get(pointerId);
		held.remove(pointerId);
		if (!held.keys().hasNext()) chainingByHold = false;
		if (pressed == null || under == pressed || !Patterns.exists(under) || clickTaken.exists(pressed)) return;
		machine.copyPattern(pressed, under);
		clickTaken.set(pressed, true);
	}

	/** A click on a pattern button: a tap chooses it, with Shift it joins or leaves the chain. */
	public function click(pattern:Int, shift:Bool) {
		if (clickTaken.remove(pattern)) return;
		if (shift) machine.toggleInChain(pattern); else machine.choosePattern(pattern);
	}
}
