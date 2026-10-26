// The eight part buttons: the pill selects a part (its LED flashes as it plays), the M tab above mutes it.
import { Component, DestroyRef, ElementRef, inject, viewChildren } from "@angular/core";
import { PanelStore } from "./panel-store";

@Component({
	selector: "div[bmPartButtons]",
	host: { id: "pills", class: "dm-pills", role: "group", "aria-label": "Part" },
	template: `
		@for (track of store.state().tracks; track track.id; let index = $index) {
			<div class="dm-pill-wrap">
				<button class="dm-tab dm-mute" [attr.aria-pressed]="track.muted" [attr.aria-label]="'Mute ' + track.name" (click)="store.machine.toggleMute(index)">M</button>
				<button class="dm-pill" [class.is-muted]="track.muted" [attr.aria-pressed]="index === store.selectedPart()" (click)="store.selectedPart.set(index)">
					<span class="dm-led"><span #glow class="dm-led-glow"></span></span>{{ track.name }}</button>
			</div>
		}
	`
})
export class PartButtons {
	protected readonly store = inject(PanelStore);
	/** In the order of the parts: viewChildren follows the template's order. */
	private readonly glows = viewChildren<ElementRef<HTMLElement>>("glow");

	constructor() {
		const stop = this.store.machine.onStep((step) => this.flashPartsPlaying(step));
		inject(DestroyRef).onDestroy(stop);
	}

	/** Lets you see the parts you are not editing: each LED blinks as its part sounds, brighter when harder. */
	private flashPartsPlaying(step: number) {
		if (step < 0) return;
		this.store.machine.getState().tracks.forEach((track, index) => {
			const hit = track.steps[step];
			if (hit.on && !track.muted) this.glows()[index]?.nativeElement.animate([{ opacity: Math.max(0.3, hit.velocity / 100) }, { opacity: 0 }], { duration: 260, easing: "ease-out" });
		});
	}
}
