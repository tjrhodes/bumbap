// The share button at the top right: shares the link to the beat (see ShareLink in the engine), then says beside it what happened.
import { ShareLink } from "bumbap-engine";
import { usePanel } from "../context";
import { useHeldText } from "../hooks";

export function ShareButton() {
	const { state } = usePanel();
	const [note, showNote] = useHeldText("", ShareLink.NOTE_MS);
	const share = () => ShareLink.share(state.code).then((words) => words && showNote(words));
	return (
		<>
			<span className="dm-print dm-share-note" aria-live="polite">{note}</span>
			<button className="dm-share" type="button" aria-label={ShareLink.LABEL} onClick={share}>
				<svg className="dm-share-icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="18" cy="5" r="2.2"/><circle cx="6" cy="12" r="2.2"/><circle cx="18" cy="19" r="2.2"/><path d="M15.5 6.5l-7 4M8.5 13.5l7 4"/></svg>
			</button>
		</>
	);
}
