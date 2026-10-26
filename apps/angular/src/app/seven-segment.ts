// The four-digit LED display, drawn from the engine's SevenSegmentFont; unlit segments show faintly.
import { Component, computed, input } from "@angular/core";
import { SevenSegmentFont } from "bumbap-engine";

@Component({
	selector: "svg[bmSevenSegment]",
	host: { id: "display", class: "dm-display", "aria-hidden": "true", "[attr.viewBox]": "font.VIEW_BOX" },
	template: `
		@for (character of characters(); track $index) {
			<svg:g [attr.transform]="font.digitTransform($index)">
				@for (segment of font.SEGMENTS; track segment) {
					<svg:polygon class="dm-seg" [class.is-lit]="font.isLit(character, segment)" [attr.data-segment]="segment" [attr.points]="font.segmentPoints(segment)" />
				}
			</svg:g>
		}
	`
})
export class SevenSegment {
	protected readonly font = SevenSegmentFont;
	readonly text = input.required<string>();
	protected readonly characters = computed(() => SevenSegmentFont.characters(this.text()));
}
