package drum;

import drum.State.Pattern;
import drum.State.TrackState;

/**
 * The eight patterns, each a full set of tracks that can be edited at any time, whichever one is playing.
 * Their snapshots are kept and made again only for a pattern that changed: a snapshot of the whole
 * machine is taken on every edit, and most edits touch one pattern.
 */
class PatternBank {
	final patterns:Array<Array<Track>>;
	final kept:Array<Null<Array<TrackState>>> = [for (_ in 0...Limits.PATTERNS) null];

	/** Pattern 1 is the starter beat, the others blank. */
	public function new() {
		patterns = [for (_ in 0...Limits.PATTERNS) [for (voice in Kit.VOICES) new Track(voice)]];
		for (index in 1...Limits.PATTERNS) restore(index, Patterns.blank());
	}

	public function tracks(index:Int):Array<Track> {
		return patterns[index];
	}

	/** A pattern's tracks were edited: its snapshot is made again when it is next asked for. */
	public function changed(index:Int) {
		kept[index] = null;
	}

	/** One pattern as the UI sees it; the same arrays until it changes. */
	public function snapshot(index:Int):Array<TrackState> {
		kept[index] ??= [for (track in patterns[index]) track.toState()];
		return kept[index];
	}

	public function snapshots():Array<Pattern> {
		return [for (index in 0...Limits.PATTERNS) cast snapshot(index)];
	}

	/** A pattern takes over saved settings (from a link, a copy or a blank); every value is checked again. */
	public function restore(index:Int, pattern:Pattern) {
		for (part in 0...patterns[index].length) patterns[index][part].restore(pattern[part]);
		changed(index);
	}

	public function copy(from:Int, to:Int) {
		restore(to, cast snapshot(from));
	}

	/** Every recording any pattern's 808 knobs choose, so all of them can be downloaded ahead. */
	public function everySampleName():Array<String> {
		return [for (pattern in patterns) for (track in pattern) track.sampleName()];
	}
}
