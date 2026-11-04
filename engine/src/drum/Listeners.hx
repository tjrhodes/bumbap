package drum;

/**
 * A list of functions waiting to hear about something. Adding one gives
 * back the function that removes it, which is the shape React effects,
 * Vue's onUnmounted and Angular's DestroyRef all expect.
 */
class Listeners<T> {
	final waiting:Array<T->Void> = [];

	public function new() {}

	/**
	 * Adds a listener and gives back a little function that removes it again. Whoever subscribed keeps that
	 * function and calls it when they are done, so nobody needs to remember which listener was theirs.
	 */
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

	/** Drops every listener at once, when the machine is thrown away. */
	public function forgetAll() {
		waiting.resize(0);
	}
}
