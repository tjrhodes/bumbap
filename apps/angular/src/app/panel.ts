// The bümbap panel: loads the kit, keeps the pattern in the address and listens for the keyboard shortcuts.
import { Component, effect, inject } from "@angular/core";
import { Deck } from "./deck";
import { PanelStore } from "./panel-store";
import { PartSection } from "./part-section";
import { ShareButton } from "./share-button";
import { StepKeys } from "./step-keys";

@Component({
	selector: "bm-panel",
	imports: [Deck, PartSection, ShareButton, StepKeys],
	host: { "(document:keydown)": "onShortcut($event)" },
	template: `
		<main class="dm">
			<div class="dm-panel">
				<header class="dm-head"><span class="dm-wordmark">bümbap</span><span class="dm-print">16 step · 8 part · Haxe engine</span><bm-share></bm-share></header>
				<section bmDeck></section>
				<section bmPartSection></section>
				<section bmStepKeys></section>
			</div>
		</main>
	`
})
export class Panel {
	private readonly store = inject(PanelStore);

	constructor() {
		this.store.machine.load();
		effect(() => rememberInAddress(this.store.state().code));
	}

	/** Space plays and stops unless a focused control already uses it; keys 1–8 pick a part. */
	protected onShortcut(event: KeyboardEvent) {
		const part = Number(event.key);
		if (event.key !== " " && part >= 1 && part <= this.store.state().tracks.length) return this.store.selectedPart.set(part - 1);
		const spaceAlreadyUsed = (event.target as Element).closest("button, [role='slider']");
		if (event.key !== " " || spaceAlreadyUsed) return;
		event.preventDefault();
		this.store.machine.togglePlay();
	}
}

/** Some frames refuse to change the address; then the pattern simply is not remembered there. */
function rememberInAddress(code: string) {
	try { history.replaceState(null, "", `#${code}`); } catch { /* nothing is lost */ }
}
