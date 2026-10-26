package panel;

import js.html.Element;
import js.html.PointerEvent;

/** Follows one pointer from press to release; the element keeps it even if it wanders off. */
class Pointer {
	public static function track(target:Element, down:PointerEvent, onMove:PointerEvent->Void) {
		target.setPointerCapture(down.pointerId);
		final move = (event:js.html.Event) -> onMove(cast event);
		function finish(_:js.html.Event) {
			target.removeEventListener("pointermove", move);
			target.removeEventListener("pointerup", finish);
			target.removeEventListener("pointercancel", finish);
		}
		target.addEventListener("pointermove", move);
		target.addEventListener("pointerup", finish);
		target.addEventListener("pointercancel", finish);
	}
}
