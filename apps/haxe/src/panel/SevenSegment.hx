package panel;

import drum.panel.SevenSegmentFont;
import haxe.Timer;
import js.html.Element;

/**
 * The four-digit LED display, drawn from the engine's SevenSegmentFont.
 * It shows a resting text (the tempo) and, for a moment, whatever is being
 * changed (e.g. "S 66").
 */
class SevenSegment {
	/** How long a changed value stays up before the resting text returns. */
	static inline final HOLD_MS = 1200;

	final digits:Array<Element>;
	var restingText = "";
	var holdTimer:Null<Timer>;

	/** Draws the four digits into the display's SVG, every segment of each, ready to be lit. */
	public function new(svg:Element) {
		digits = [for (index in 0...SevenSegmentFont.DIGITS) buildDigit(svg, index)];
	}

	/**
	 * What the display goes back to when nothing is being changed, usually the tempo. If a value is being shown
	 * for a moment, the new resting text waits until that moment is over.
	 */
	public function showResting(text:String) {
		restingText = text;
		if (holdTimer == null) paint(text);
	}

	/**
	 * Shows a value while a knob or key is changing it, then goes back to the resting text after a little
	 * while. Each new value restarts the wait, so the display holds while you keep turning.
	 */
	public function showBriefly(text:String) {
		paint(text);
		if (holdTimer != null) holdTimer.stop();
		holdTimer = Timer.delay(() -> {
			holdTimer = null;
			paint(restingText);
		}, HOLD_MS);
	}

	/**
	 * Lights the segments that spell the text. Segments are switched on and off with a class, and the
	 * stylesheet does the glowing.
	 */
	function paint(text:String) {
		final characters = SevenSegmentFont.characters(text);
		for (index in 0...digits.length) {
			for (segment in digits[index].children) {
				segment.classList.toggle("is-lit", SevenSegmentFont.isLit(characters[index], segment.getAttribute("data-segment")));
			}
		}
	}

	/** Every segment is drawn; unlit ones show faintly, as on real glass. */
	function buildDigit(svg:Element, index:Int):Element {
		final digit = Dom.createSvg("g", {transform: SevenSegmentFont.digitTransform(index)});
		for (name in SevenSegmentFont.SEGMENTS) {
			digit.append(Dom.createSvg("polygon", {"class": "dm-seg", "data-segment": name, points: SevenSegmentFont.segmentPoints(name)}));
		}
		svg.append(digit);
		return digit;
	}
}
