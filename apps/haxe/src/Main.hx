import drum.DrumMachine;
import drum.audio.ToneApi;
import panel.Panel;

/**
 * bümbap in Haxe: the panel written against the DOM directly, compiled
 * together with the engine's own Haxe source, so the whole build, from the
 * buttons down to the audio graph, is checked by one compiler.
 */
class Main {
	/** The shared kit sits at the repo root, beside apps/ (dist is apps/haxe/dist). */
	static inline final SAMPLES_URL = "../../../samples/";

	static function main() {
		final tone:ToneApi = js.Syntax.code("Tone"); // the global from the Tone.js script in index.html
		final machine = new DrumMachine({tone: tone, samplesUrl: SAMPLES_URL});
		machine.loadCode(js.Browser.location.hash.substr(1)); // a shared pattern, if the address carries one
		new Panel(machine).start();
	}
}
