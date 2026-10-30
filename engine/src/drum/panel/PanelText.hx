package drum.panel;

import drum.State.MachineState;
import drum.State.SequenceTool;
import drum.State.StepSettings;
import drum.State.TrackState;

/**
 * Every word and number the panel shows, written once for every front end:
 * the display's texts, the status line and the labels screen readers hear.
 */
@:expose("PanelText")
class PanelText {
	/** The display letter of each knob that has one; tempo needs none, the display shows it anyway. */
	public static final KNOB_LETTERS:haxe.DynamicAccess<String> = {
		swing: "S", drive: "d", reverb: "r", level: "L", pitch: "P", length: "E"
	};

	/** And of the two things a key drag changes: velocity and nudge. */
	public static final STEP_LETTERS:haxe.DynamicAccess<String> = {level: "u", nudge: "n"};

	/** One letter, then the number right-aligned: "S 66", "L100", "n -3". */
	public static function labelled(letter:String, value:Int):String {
		return letter + StringTools.lpad(Std.string(value), " ", SevenSegmentFont.DIGITS - 1);
	}

	/** What the display shows when nothing is being changed: the tempo, or the loading state. */
	public static function resting(state:MachineState):String {
		return switch (state.status) {
			case Loading: "LoAd";
			case Failed: "Err";
			case Ready: Std.string(state.tempo);
		}
	}

	/** The status line under the display. */
	public static function status(state:MachineState):String {
		if (state.exporting) return "Rendering the loop";
		if (state.playing) return "Playing";
		return switch (state.status) {
			case Loading: "Loading the kit";
			case Failed: "Samples failed to load: reload to retry";
			case Ready: "Ready";
		}
	}

	/** An 808 knob shows the recording's own setting: the kick at Tone 2.5, Decay 10 is "2510". */
	public static function dialSetting(track:TrackState):String {
		return track.sample.substr(2);
	}

	/** "Kick step 3, level 85, nudge 0", with ", reversed" if it plays backwards; just "Kick step 3" if it is off. */
	public static function stepLabel(trackName:String, stepIndex:Int, step:StepSettings):String {
		final details = step.on ? ', level ${step.velocity}, nudge ${step.nudge}${step.reversed ? ", reversed" : ""}' : "";
		return '$trackName step ${stepIndex + 1}$details';
	}

	/**
	 * "Pattern 3", then what a screen reader needs beyond its pressed state (in the sequence): ", on the keys",
	 * ", playing", ", next", ", empty", and with Select on its places in the sequence: ", sequence places 1 3".
	 */
	public static function patternLabel(state:MachineState, pattern:Int):String {
		final onKeys = state.pattern == pattern ? ", on the keys" : "";
		final now = (state.playingPattern == pattern ? ", playing" : "") + (state.nextPattern == pattern ? ", next" : "");
		final empty = state.patternHasSteps[pattern] ? "" : ", empty";
		final places = sequencePlaces(state, pattern);
		return 'Pattern ${pattern + 1}$onKeys$now$empty${places == "" ? "" : ", sequence places " + places}';
	}

	/** With Select on, where a pattern comes in the sequence, from 1: "1 3" for one played first and third. Otherwise "". */
	public static function sequencePlaces(state:MachineState, pattern:Int):String {
		if (state.tool != Select) return "";
		return [for (place in 0...state.sequence.length) if (state.sequence[place] == pattern) Std.string(place + 1)].join(" ");
	}

	/** The line under the pattern buttons: what a tap does now, for a mouse and for a touch screen. */
	public static function sequenceHints(state:MachineState):Array<String> {
		return switch (state.tool) {
			case Select: both("Tap patterns in play order · Clear starts again · Select when done");
			case Copy: both(state.copyFrom < 0 ? "Tap the pattern to copy" : 'Now tap where pattern ${state.copyFrom + 1} goes');
			case Clear: both("Tap the pattern to clear");
			case Off: ["Tap to edit · shift-click to add to the sequence · drag to copy", "Tap to edit · hold one, tap others to sequence · drag to copy"];
		}
	}

	/** What each of the sequence's buttons does now, for screen readers: Clear clears the sequence while Select is on. */
	public static function toolLabel(state:MachineState, tool:SequenceTool):String {
		return switch (tool) {
			case Select: "Select the sequence";
			case Copy: "Copy a pattern";
			case Clear: state.tool == Select ? "Clear the sequence" : "Clear a pattern";
			case Off: "";
		}
	}

	static function both(hint:String):Array<String> {
		return [hint, hint];
	}

	public static function flipLabel(trackName:String, stepIndex:Int):String {
		return 'Play $trackName step ${stepIndex + 1} backwards';
	}

	/** An 808 slot's label for screen readers: the part's knob there, or that it has none. */
	public static function dialLabel(track:TrackState, slot:Int):String {
		final name = track.dialNames[slot];
		return name != null ? '${track.name} $name, 808 knob' : "No 808 knob on this part";
	}
}
