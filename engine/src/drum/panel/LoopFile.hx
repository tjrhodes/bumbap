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

	public static function download(machine:DrumMachine):Promise<Void> {
		final name = fileName(machine.getState());
		return machine.exportLoop().then(file -> save(file, name), error -> js.Browser.console.error("The loop could not be rendered", error));
	}

	public static function fileName(state:MachineState):String {
		final bars = state.sequence.length;
		return 'bumbap-${state.tempo}bpm-$bars${bars == 1 ? "bar" : "bars"}.wav';
	}

	static function save(file:Blob, name:String) {
		final link:AnchorElement = cast document.createElement("a");
		link.href = URL.createObjectURL(file);
		link.download = name;
		link.click();
		haxe.Timer.delay(() -> URL.revokeObjectURL(link.href), RELEASE_AFTER_MS);
	}
}
