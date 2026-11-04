package drum.panel;

import drum.DrumMachine;
import drum.State.MachineState;
import js.Browser.document;
import js.html.AnchorElement;
import js.html.Blob;
import js.html.URL;
import js.lib.Promise;

/**
 * The Download button, written once for every front end: renders the sequence as a loop-ready WAV
 * (DrumMachine.exportLoop) and hands it to the browser to save, named after its tempo and length,
 * "bumbap-120bpm-4bars.wav". While it renders, the status line says so (PanelText.status).
 */
@:expose("LoopFile")
class LoopFile {
	public static final LABEL = "Download the sequence as a WAV loop";

	/** Long enough for the browser to have started saving the file before its address is let go. */
	static inline final RELEASE_AFTER_MS = 10000;

	/**
	 * What the Download button does. The name is worked out first, from the sequence as it is when the button
	 * is pressed; then the machine renders the loop, and the file is handed to the browser to save. If the
	 * render fails, the reason goes to the console and nothing is saved.
	 */
	public static function download(machine:DrumMachine):Promise<Void> {
		final name = fileName(machine.getState());
		return machine.exportLoop().then(file -> save(file, name), error -> js.Browser.console.error("The loop could not be rendered", error));
	}

	/**
	 * A name that says what's in the file, so a folder of loops stays easy to sort: "bumbap-120bpm-4bars.wav".
	 */
	public static function fileName(state:MachineState):String {
		final bars = state.sequence.length;
		return 'bumbap-${state.tempo}bpm-$bars${bars == 1 ? "bar" : "bars"}.wav';
	}

	/**
	 * Browsers have no "save this file" command for a page to call, so this does what a download link would: it
	 * gives the file a temporary address, makes an invisible link to it, and clicks it. The address is released
	 * a little later, once the browser has started saving.
	 */
	static function save(file:Blob, name:String) {
		final link:AnchorElement = cast document.createElement("a");
		link.href = URL.createObjectURL(file);
		link.download = name;
		link.click();
		haxe.Timer.delay(() -> URL.revokeObjectURL(link.href), RELEASE_AFTER_MS);
	}
}
