import Check.later;
import Check.test;
import drum.DrumMachine;
import drum.StepRow;
import drum.audio.WavFile;
import drum.panel.LoopFile;
import js.lib.DataView;
import js.lib.Float32Array;
import js.lib.Promise;

/** Getting a beat out: copying steps between parts and patterns, and downloading the sequence as a WAV loop. */
class ExportTests {
	static inline final KICK = 0;
	static inline final SNARE = 1;

	public static function all():Array<Check.Test> {
		return [
			test("Copy takes a part's steps; Paste puts them into any part of any pattern", copyAndPasteSteps),
			test("a WAV file: a RIFF header, then 16-bit samples, interleaved and held at full scale", wavFiles),
			test("the file is named after the tempo and the sequence's length", fileNames),
			later("a loop renders two passes and keeps the second, each part at its own level", loopRenders),
			later("rendering stops playback, says so, and lets Play work again after", renderingStopsPlayback)
		];
	}

	static function copyAndPasteSteps() {
		final machine = newMachine().machine;
		final starter = machine.getState().tracks;
		machine.pasteSteps(SNARE);
		Check.equal(machine.getState().tracks[SNARE], starter[SNARE], "nothing copied yet: Paste does nothing");
		machine.copySteps(KICK);
		Check.isTrue(machine.getState().stepsCopied, "copied");
		machine.editPattern(3);
		machine.pasteSteps(SNARE);
		final pasted = machine.getState().tracks[SNARE].steps;
		Check.equal(StepRow.print(pasted), StepRow.print(starter[KICK].steps), "pattern 4's snare plays pattern 1's kick steps");
		Check.equal(pasted[0].velocity, starter[KICK].steps[0].velocity, "levels came too");
	}

	static function wavFiles() {
		final file = new DataView(WavFile.encode([new Float32Array([0, 1, -2]), new Float32Array([0.5, 0, 0])], 8000));
		Check.equal(file.byteLength, 44 + 3 * 2 * 2, "header, then 3 frames of 2 channels of 2 bytes");
		Check.equal([for (at in [0, 8, 36]) [for (index in 0...4) String.fromCharCode(file.getUint8(at + index))].join("")].join(" "), "RIFF WAVE data", "the RIFF chunks");
		Check.equal('${file.getUint16(22, true)} ${file.getUint32(24, true)}', "2 8000", "stereo at 8000 Hz");
		Check.equal([for (sample in 0...6) file.getInt16(44 + sample * 2, true)].join(","), "0,16384,32767,0,-32767,0", "left, right, left…; -2 held at full scale");
	}

	static function fileNames() {
		final machine = newMachine().machine;
		Check.equal(LoopFile.fileName(machine.getState()), "bumbap-100bpm-1bar.wav", "one bar");
		machine.setTempo(120);
		machine.setSequence([0, 1, 0]);
		Check.equal(LoopFile.fileName(machine.getState()), "bumbap-120bpm-3bars.wav", "three");
	}

	static function loopRenders():Promise<Any> {
		final setup = newMachine();
		setup.machine.setTempo(120);
		setup.machine.editPattern(1);
		setup.machine.toggleStep(KICK, 0);
		setup.machine.setVolume(KICK, 50);
		setup.machine.setSequence([0, 1]);
		return setup.machine.load().then(_ -> setup.machine.exportLoop()).then(file -> {
			final quietKicks = [for (hit in setup.tone.hits) if (hit.gain == 0.5) hit.audioTime];
			Check.equal(setup.tone.offlineSeconds, 8.0, "two passes of two 2-second bars");
			Check.equal(quietKicks.join(","), "2,6,10", "pattern 2's kick at half level, in every pass scheduled");
			Check.equal(file.size, 44 + 40 * 2 * 2, "the second pass only: 4 seconds of stereo at the fake's 10 Hz");
			Check.equal(file.type, "audio/wav", "a WAV file");
		});
	}

	static function renderingStopsPlayback():Promise<Any> {
		final setup = newMachine();
		return setup.machine.load().then(_ -> setup.machine.play()).then(_ -> {
			final rendering = setup.machine.exportLoop();
			Check.equal('${setup.machine.getState().playing} ${setup.machine.getState().exporting}', "false true", "stopped, rendering");
			return rendering;
		}).then(_ -> {
			Check.isTrue(!setup.machine.getState().exporting, "done");
			return setup.machine.play();
		}).then(_ -> Check.isTrue(setup.machine.getState().playing, "Play works again"));
	}

	static function newMachine() {
		final tone = new FakeTone();
		return {tone: tone, machine: new DrumMachine({tone: tone.api, samplesUrl: "/samples/"})};
	}
}
