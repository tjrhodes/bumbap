package panel;

import drum.DrumMachine;
import drum.panel.ShareLink;
import haxe.Timer;
import js.html.Element;

/**
 * The share button at the top right: shares the link to the beat as it is now (see ShareLink in the
 * engine), then says beside it what happened, for a moment.
 */
class ShareButton {
	final note:Element;
	var noteTimer:Null<Timer>;

	public function new(button:Element, note:Element, machine:DrumMachine) {
		this.note = note;
		button.addEventListener("click", () -> ShareLink.share(machine.getState().code).then(showNote));
	}

	/** Shows the words, then clears them; a newer note restarts the wait. Nothing to say: nothing shown. */
	function showNote(words:String) {
		if (words == "") return;
		Dom.setText(note, words);
		if (noteTimer != null) noteTimer.stop();
		noteTimer = Timer.delay(() -> Dom.setText(note, ""), ShareLink.NOTE_MS);
	}
}
