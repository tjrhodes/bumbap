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

	public function new(svg:Element) {
		digits = [for (index in 0...SevenSegmentFont.DIGITS) buildDigit(svg, index)];
	}

	public function showResting(text:String) {
		restingText = text;
		if (holdTimer == null) paint(text);
	}

	public function showBriefly(text:String) {
		paint(text);
		if (holdTimer != null) holdTimer.stop();
		holdTimer = Timer.delay(() -> {
			holdTimer = null;
			paint(restingText);
		}, HOLD_MS);
	}

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
