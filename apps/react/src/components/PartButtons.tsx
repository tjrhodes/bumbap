// The eight part buttons: the pill selects a part (its LED flashes as it plays), the M tab above mutes it.
import { useEffect, useRef } from "react";
import type { TrackState } from "bumbap-engine";
import { usePanel } from "../context";

export function PartButtons() {
	const { state } = usePanel();
	const glows = useFlashOnHits();
	return (
		<div id="pills" className="dm-pills" role="group" aria-label="Part">
			{state.tracks.map((track, index) => (
				<PartButton key={track.id} track={track} index={index} glowRef={(glow) => { glows.current[index] = glow; }} />
			))}
		</div>
	);
}

function PartButton({ track, index, glowRef }: { track: TrackState; index: number; glowRef: (glow: HTMLSpanElement | null) => void }) {
	const { machine, selectedPart, selectPart } = usePanel();
	return (
		<div className="dm-pill-wrap">
			<button className="dm-tab dm-mute" aria-pressed={track.muted} aria-label={`Mute ${track.name}`} onClick={() => machine.toggleMute(index)}>M</button>
			<button className={track.muted ? "dm-pill is-muted" : "dm-pill"} aria-pressed={index === selectedPart} onClick={() => selectPart(index)}>
				<span className="dm-led"><span className="dm-led-glow" ref={glowRef} /></span>{track.name}
			</button>
		</div>
	);
}

/**
 * Lets you see the parts you are not editing: each LED blinks as its part sounds, brighter
 * when harder. A one-off animation, so it is played on the element rather than kept in state.
 */
function useFlashOnHits() {
	const { machine } = usePanel();
	const glows = useRef<(HTMLSpanElement | null)[]>([]);
	useEffect(() => machine.onStep((step) => {
		if (step < 0) return;
		machine.getState().tracks.forEach((track, index) => {
			const hit = track.steps[step];
			if (hit.on && !track.muted) glows.current[index]?.animate([{ opacity: Math.max(0.3, hit.velocity / 100) }, { opacity: 0 }], { duration: 260, easing: "ease-out" });
		});
	}), [machine]);
	return glows;
}
