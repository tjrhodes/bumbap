/**
 * Follows one pointer from press to release. "Pointer capture" tells the browser that every move belongs to
 * this element until the press ends, even outside it, so a knob keeps turning when your finger slides off it.
 * When the press ends, the listeners take themselves away again.
 */
export function trackPointer(target: Element, down: PointerEvent, onMove: (move: PointerEvent) => void) {
	target.setPointerCapture(down.pointerId);
	const move = (event: Event) => onMove(event as PointerEvent);
	const finish = () => {
		target.removeEventListener("pointermove", move);
		target.removeEventListener("pointerup", finish);
		target.removeEventListener("pointercancel", finish);
	};
	target.addEventListener("pointermove", move);
	target.addEventListener("pointerup", finish);
	target.addEventListener("pointercancel", finish);
}
