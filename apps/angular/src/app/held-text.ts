// A text shown for a moment, then gone (null); a newer text restarts the wait. The display's values and the share note use it.
import { signal } from "@angular/core";

/**
 * The text sits in a signal, so whatever shows it (the display, the share note) redraws by itself when it
 * changes.
 */
export class HeldText {
	private readonly held = signal<string | null>(null);
	readonly text = this.held.asReadonly();
	private timer: number | undefined;

	constructor(private readonly holdMs: number) {}

	/** Shows the text, and clears it again after a while. A newer text restarts the wait. */
	show(text: string) {
		this.held.set(text);
		window.clearTimeout(this.timer);
		this.timer = window.setTimeout(() => this.held.set(null), this.holdMs);
	}
}
