package panel;

import drum.Range;
import js.html.Element;
import js.html.KeyboardEvent;
import js.html.PointerEvent;
import js.html.WheelEvent;

/**
 * A rotary knob: a slider in a round body. Drag up or right to turn it up,
 * scroll, or use the arrow keys; double-click (double-tap) resets it.
 * The engine's Range rounds and clamps whatever the gesture works out.
 */
class Knob {
	/** Dragging this far turns a knob from its minimum to its maximum. */
	static inline final TRAVEL_PX = 160;
	/** From seven o'clock round to five o'clock. */
	static inline final SWEEP_DEGREES = 270;
	static final KEY_STEPS = ["ArrowUp" => 1, "ArrowRight" => 1, "ArrowDown" => -1, "ArrowLeft" => -1, "PageUp" => 10, "PageDown" => -10];

	final element:Element;
	final range:Range;
	final turnTo:Float->Void;

	/**
	 * Makes a knob from its element. Every way of turning it ends in `turnTo`, which rounds and clamps the
	 * value before telling the panel, so a knob can never ask for something out of range.
	 */
	public function new(element:Element, range:Range, onTurn:Int->Void) {
		this.element = element;
		this.range = range;
		turnTo = value -> onTurn(range.clamp(value));
		element.setAttribute("aria-valuemin", Std.string(range.min));
		element.setAttribute("aria-valuemax", Std.string(range.max));
		listen();
	}

	/** Points the knob at its value. */
	public function show(value:Int) {
		final share = (value - range.min) / (range.max - range.min);
		element.setAttribute("aria-valuenow", Std.string(value));
		element.style.setProperty("--turn", '${share * SWEEP_DEGREES - SWEEP_DEGREES / 2}deg');
	}

	/** The value the knob shows now, read back from its `aria-valuenow`, which is where `show` writes it. */
	function value():Int {
		return Std.parseInt(element.getAttribute("aria-valuenow"));
	}

	/**
	 * Four ways to turn a knob: drag, scroll wheel, keys, and double-click to reset. The wheel listener isn't
	 * passive, so it can stop the page scrolling while the mouse is over a knob.
	 */
	function listen() {
		element.addEventListener("pointerdown", (event:PointerEvent) -> followDrag(event));
		element.addEventListener("wheel", (event:WheelEvent) -> {
			event.preventDefault();
			turnTo(value() - (event.deltaY > 0 ? 1 : -1));
		}, {passive: false});
		element.addEventListener("keydown", onKey);
		element.addEventListener("dblclick", () -> turnTo(range.initial));
	}

	/** Turns by how far the pointer has moved since it went down; up and right both mean more. */
	function followDrag(down:PointerEvent) {
		final startValue = value();
		final unitsPerPixel = (range.max - range.min) / TRAVEL_PX;
		Pointer.track(element, down, move -> turnTo(startValue + (down.clientY - move.clientY + move.clientX - down.clientX) * unitsPerPixel));
	}

	/**
	 * The keys sliders use everywhere: arrows move by one, Page Up and Down by ten, Home and End go to the
	 * ends. Other keys are left alone, so Tab still moves on.
	 */
	function onKey(event:KeyboardEvent) {
		if (event.key == "Home") turnTo(range.min);
		else if (event.key == "End") turnTo(range.max);
		else if (KEY_STEPS.exists(event.key)) turnTo(value() + KEY_STEPS[event.key]);
		else return;
		event.preventDefault();
	}
}
