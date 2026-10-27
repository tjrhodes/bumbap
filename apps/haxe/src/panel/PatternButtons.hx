package panel;

import drum.DrumMachine;
import drum.State.MachineState;
import drum.panel.PanelText;
import drum.panel.PatternPad;
import js.Browser.window;
import js.html.Element;
import js.html.MouseEvent;
import js.html.PointerEvent;

/**
 * The eight pattern buttons (version 2). Each snapshot draws them: in the chain, half lit; playing or
 * shown, fully lit; waiting for the end of the bar, blinking; empty, a dim number. Their gestures go
 * to the engine's PatternPad, which every build shares.
 */
class PatternButtons {
	final buttons:Array<Element>;
	final pad:PatternPad;

	public function new(group:Element, machine:DrumMachine) {
		buttons = [for (button in group.querySelectorAll(".dm-pattern")) cast button];
		pad = new PatternPad(machine);
		listen(group);
	}

	public function draw(state:MachineState) {
		for (index in 0...buttons.length) drawButton(buttons[index], index, state);
	}

	function drawButton(button:Element, index:Int, state:MachineState) {
		Dom.setAttribute(button, "aria-pressed", Std.string(state.chain.contains(index)));
		Dom.setAttribute(button, "aria-current", Std.string(state.pattern == index));
		Dom.setAttribute(button, "aria-label", PanelText.patternLabel(state, index));
		button.classList.toggle("is-next", state.nextPattern == index);
		button.classList.toggle("is-used", state.patternHasSteps[index]);
	}

	/** Down and click on the buttons; up anywhere, since a finger dragged onto another button is let go there. */
	function listen(group:Element) {
		group.addEventListener("pointerdown", (event:PointerEvent) -> {
			final pattern = Dom.numberFrom(event, "pattern");
			if (pattern != null) pad.press(event.pointerId, pattern);
		});
		group.addEventListener("click", (event:MouseEvent) -> {
			final pattern = Dom.numberFrom(event, "pattern");
			if (pattern != null) pad.click(pattern, event.shiftKey);
		});
		window.addEventListener("pointerup", (event:PointerEvent) -> pad.release(event.pointerId, PatternPad.patternAt(event.clientX, event.clientY)));
		window.addEventListener("pointercancel", (event:PointerEvent) -> pad.release(event.pointerId, PatternPad.NONE));
	}
}
