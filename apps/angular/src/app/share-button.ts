// The share button at the top right: shares the link to the beat (see ShareLink in the engine), then says beside it what happened.
import { Component, inject } from "@angular/core";
import { ShareLink } from "bumbap-engine";
import { HeldText } from "./held-text";
import { PanelStore } from "./panel-store";

@Component({
	selector: "bm-share",
	host: { style: "display: contents" },   // the note and the button take their own places in the header's grid
	template: `
		<span class="dm-print dm-share-note" aria-live="polite">{{ note.text() }}</span>
		<button class="dm-share" type="button" [attr.aria-label]="label" (click)="share()">
			<svg class="dm-share-icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="18" cy="5" r="2.2"/><circle cx="6" cy="12" r="2.2"/><circle cx="18" cy="19" r="2.2"/><path d="M15.5 6.5l-7 4M8.5 13.5l7 4"/></svg>
		</button>
	`
})
export class ShareButton {
	private readonly store = inject(PanelStore);
	protected readonly note = new HeldText(ShareLink.NOTE_MS);
	protected readonly label = ShareLink.LABEL;

	protected async share() {
		const words = await ShareLink.share(this.store.state().code);
		if (words) this.note.show(words);
	}
}
