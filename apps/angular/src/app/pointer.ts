// Follows one pointer from press to release; the element keeps it even if the pointer wanders off.
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
