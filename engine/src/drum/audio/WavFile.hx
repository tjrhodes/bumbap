package drum.audio;

import js.lib.ArrayBuffer;
import js.lib.DataView;
import js.lib.Float32Array;

/**
 * Sound as a WAV file: 16-bit PCM, the channels interleaved, the format every DAW and sampler reads.
 * Pure, so it can be tested without a browser.
 */
class WavFile {
	static inline final HEADER_BYTES = 44;
	static inline final BYTES_PER_SAMPLE = 2;
	static inline final LOUDEST = 32767;

	/** `channels` are the same length; values are -1 to 1 (anything past that is held at full scale). */
	public static function encode(channels:Array<Float32Array>, sampleRate:Int):ArrayBuffer {
		final frames = channels[0].length;
		final file = new DataView(new ArrayBuffer(HEADER_BYTES + frames * channels.length * BYTES_PER_SAMPLE));
		writeHeader(file, channels.length, sampleRate, frames);
		for (frame in 0...frames) for (channel in 0...channels.length) {
			final at = HEADER_BYTES + (frame * channels.length + channel) * BYTES_PER_SAMPLE;
			file.setInt16(at, Math.round(Math.max(-1, Math.min(1, channels[channel][frame])) * LOUDEST), true);
		}
		return file.buffer;
	}

	/** The RIFF header: what the data is, then how much of it there is. */
	static function writeHeader(file:DataView, channelCount:Int, sampleRate:Int, frames:Int) {
		final dataBytes = frames * channelCount * BYTES_PER_SAMPLE;
		final blockAlign = channelCount * BYTES_PER_SAMPLE;
		writeText(file, 0, "RIFF");
		file.setUint32(4, HEADER_BYTES - 8 + dataBytes, true);
		writeText(file, 8, "WAVEfmt ");
		for (field in [[16, 16, 4], [20, 1, 2], [22, channelCount, 2], [24, sampleRate, 4], [28, sampleRate * blockAlign, 4], [32, blockAlign, 2], [34, 16, 2]])
			if (field[2] == 4) file.setUint32(field[0], field[1], true); else file.setUint16(field[0], field[1], true);
		writeText(file, 36, "data");
		file.setUint32(40, dataBytes, true);
	}

	static function writeText(file:DataView, at:Int, text:String) {
		for (index in 0...text.length) file.setUint8(at + index, text.charCodeAt(index));
	}
}
