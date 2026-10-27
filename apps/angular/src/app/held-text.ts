// A text shown for a moment, then gone (null); a newer text restarts the wait. The display's values and the share note use it.
import { signal } from "@angular/core";

export class HeldText {
	private readonly held = signal<string | null>(null);
	readonly text = this.held.asReadonly();
	private timer: number | undefined;

	constructor(private readonly holdMs: number) {}

	show(text: string) {
		this.held.set(text);
		window.clearTimeout(this.timer);
		this.timer = window.setTimeout(() => this.held.set(null), this.holdMs);
	}
}
