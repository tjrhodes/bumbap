package drum;

/**
 * A list of functions waiting to hear about something. Adding one gives
 * back the function that removes it, which is the shape React effects,
 * Vue's onUnmounted and Angular's DestroyRef all expect.
 */
class Listeners<T> {
	final waiting:Array<T->Void> = [];

	public function new() {}

	public function add(listener:T->Void):() -> Void {
		waiting.push(listener);
		return () -> {
			waiting.remove(listener);
		};
	}

	/** Works on a copy, so a listener may unsubscribe while being told. */
	public function tell(news:T) {
		for (listener in waiting.copy()) listener(news);
	}

	public function forgetAll() {
		waiting.resize(0);
	}
}
