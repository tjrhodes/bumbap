package panel;

import drum.DrumMachine;
import drum.State.MachineState;
import drum.State.SequenceTool;
import drum.panel.PanelText;
import drum.panel.PatternPad;
import js.Browser.window;
import js.html.Element;
import js.html.MouseEvent;
import js.html.PointerEvent;

/**
 * The sequence (version 2): eight pattern buttons and the Select, Copy and Clear tools beside the title.
 * Each snapshot draws them: in the sequence, half lit; playing, fully lit; on the keys, a ring; taking over
 * at the end of the bar, blinking; empty, a dim number; with Select on, each button's places in the
 * sequence. A tap goes to the engine's PatternPad, which every build shares, and so does the line saying
 * what a tap does now.
 */
class PatternButtons {
	final buttons:Array<Element>;
	final tools:Array<Element>;
	final hints:Array<Element>;
	final pad:PatternPad;
	final machine:DrumMachine;

	public function new(group:Element, machine:DrumMachine) {
		this.machine = machine;
		buttons = [for (button in group.querySelectorAll(".dm-pattern")) cast button];
		tools = [for (tool in group.querySelectorAll(".dm-tool")) cast tool];
		hints = [for (hint in group.querySelectorAll(".dm-pattern-hint span")) cast hint];
		pad = new PatternPad(machine);
		listen(group);
	}

	public function draw(state:MachineState) {
		for (index in 0...buttons.length) drawButton(buttons[index], index, state);
		for (tool in tools) Dom.setAttribute(tool, "aria-pressed", Std.string(tool.dataset.tool == state.tool));
		final words = PanelText.sequenceHints(state);
		for (index in 0...hints.length) Dom.setText(hints[index], words[index]);
	}

	function drawButton(button:Element, index:Int, state:MachineState) {
		Dom.setAttribute(button, "aria-pressed", Std.string(state.sequence.contains(index)));
		Dom.setAttribute(button, "aria-current", Std.string(state.pattern == index));
		Dom.setAttribute(button, "aria-label", PanelText.patternLabel(state, index));
		Dom.setText(button.querySelector(".dm-pattern-places"), PanelText.sequencePlaces(state, index));
		button.classList.toggle("is-playing", state.playingPattern == index);
		button.classList.toggle("is-next", state.nextPattern == index);
		button.classList.toggle("is-used", state.patternHasSteps[index]);
		button.classList.toggle("is-copy-source", state.copyFrom == index);
	}

	/** Down and click on the group; up anywhere, since a finger dragged onto another button is lifted there. */
	function listen(group:Element) {
		group.addEventListener("pointerdown", (event:PointerEvent) -> {
			final pattern = Dom.numberFrom(event, "pattern");
			if (pattern != null) pad.press(event.pointerId, pattern);
		});
		group.addEventListener("click", onClick);
		window.addEventListener("pointerup", (event:PointerEvent) -> pad.release(event.pointerId, PatternPad.patternAt(event.clientX, event.clientY)));
		window.addEventListener("pointercancel", (event:PointerEvent) -> pad.release(event.pointerId, PatternPad.NONE));
	}

	/** A pattern button is a tap for the pad; a tool button turns its tool on or off. */
	function onClick(event:MouseEvent) {
		final pattern = Dom.numberFrom(event, "pattern");
		if (pattern != null) return pad.click(pattern, event.shiftKey);
		final tool = (cast event.target : Element).closest("[data-tool]");
		if (tool != null) machine.toggleTool(cast tool.dataset.tool);
	}
}
