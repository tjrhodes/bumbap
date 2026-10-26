// The four-digit LED display, drawn from the engine's SevenSegmentFont; unlit segments show faintly.
import { SevenSegmentFont } from "bumbap-engine";

export function SevenSegment({ text }: { text: string }) {
	return (
		<svg id="display" className="dm-display" viewBox={SevenSegmentFont.VIEW_BOX} aria-hidden="true">
			{SevenSegmentFont.characters(text).map((character, index) => <Digit key={index} index={index} character={character} />)}
		</svg>
	);
}

function Digit({ index, character }: { index: number; character: string }) {
	return (
		<g transform={SevenSegmentFont.digitTransform(index)}>
			{SevenSegmentFont.SEGMENTS.map((segment) => (
				<polygon key={segment} className={SevenSegmentFont.isLit(character, segment) ? "dm-seg is-lit" : "dm-seg"}
					data-segment={segment} points={SevenSegmentFont.segmentPoints(segment)} />
			))}
		</g>
	);
}
