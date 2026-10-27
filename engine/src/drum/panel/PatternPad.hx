package drum.panel;

import drum.DrumMachine;
import drum.Patterns;

/**
 * The pattern buttons' gestures, written once for every front end. Each build forwards three events and
 * the pad turns them into the machine's calls:
 *
 * - a click is a tap on that pattern, which the machine reads by the sequence button that is on: none
 *   plays it, Select adds it to the sequence, Copy and Clear copy or clear it (see DrumMachine.tapPattern);
 * - shortcuts, while no sequence button is on: a shift-click adds the pattern to the end of the sequence
 *   or takes it out; holding one button and tapping others (a second finger) makes the sequence those, in
 *   the order they were touched; dragging one button onto another copies the pattern there.
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
	/** Within one hold, the first tap sets the sequence and later taps add to it or take out. */
	var sequencingByHold = false;

	public function new(machine:DrumMachine) {
		this.machine = machine;
	}

	/** The pattern button under a point on the page (where a finger was lifted, say), or NONE. */
	public static function patternAt(x:Float, y:Float):Int {
		final element = js.Browser.document.elementFromPoint(Std.int(x), Std.int(y));
		final button = element == null ? null : element.closest("[data-pattern]");
		return button == null ? NONE : Std.parseInt(button.getAttribute("data-pattern"));
	}

	/** A pointer goes down on a pattern button. While another is held, this one joins it in the sequence. */
	public function press(pointerId:Int, pattern:Int) {
		final heldBefore = [for (other in held) other];
		if (heldBefore.length == 0) clickTaken.clear(); // a new gesture: nothing left over from the last one
		if (machine.getState().tool != Off) return; // with a sequence button on, a tap is just a tap
		held.set(pointerId, pattern);
		if (heldBefore.length == 0) return;
		if (sequencingByHold) machine.toggleInSequence(pattern); else machine.setSequence(heldBefore.concat([pattern]));
		sequencingByHold = true;
		for (sequenced in heldBefore.concat([pattern])) clickTaken.set(sequenced, true);
	}

	/** The pointer comes up over `under` (a pattern, or NONE). Let go over another button, it copies the pattern there. */
	public function release(pointerId:Int, under:Int) {
		final pressed = held.get(pointerId);
		held.remove(pointerId);
		if (!held.keys().hasNext()) sequencingByHold = false;
		if (pressed == null || under == pressed || !Patterns.exists(under) || clickTaken.exists(pressed)) return;
		machine.copyPattern(pressed, under);
		clickTaken.set(pressed, true);
	}

	/** A click on a pattern button: a tap, unless it ended a hold or a drag. */
	public function click(pattern:Int, shift:Bool) {
		if (!clickTaken.remove(pattern)) machine.tapPattern(pattern, shift);
	}
}
