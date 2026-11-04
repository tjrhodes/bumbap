package panel;

import drum.DrumMachine;
import drum.Kit;
import drum.Range;
import drum.State.MachineState;
import drum.State.TrackState;
import drum.panel.LoopFile;
import drum.panel.PanelText;
import js.Browser.document;
import js.Browser.window;
import js.html.Element;
import js.html.KeyboardEvent;
import js.html.MouseEvent;

/**
 * Everything a knob needs: which range, how to read its value from a snapshot,
 * how to set it, and what the display shows while it turns (null: nothing).
 */
typedef KnobSpec = {
	final id:String;
	final range:Range;
	final read:MachineState->Int;
	final set:Int->Void;
	final show:MachineState->Null<String>;
}

/**
 * The bümbap panel: draws each snapshot of the machine into the page's
 * markup (index.html, the DOM contract), and turns clicks, drags and keys
 * into the machine's edits. One part's sixteen steps are shown at a time.
 */
class Panel {
	final machine:DrumMachine;
	final display:SevenSegment;
	final parts:PartButtons;
	final keys:StepKeys;
	final patterns:PatternButtons;
	final knobs:Array<{spec:KnobSpec, knob:Knob}>;
	var selectedPart = 0;

	/**
	 * Finds the panel's pieces in the page by their ids and gives each a small helper object to look after it:
	 * the display, the part buttons, the step keys, the pattern buttons and the knobs. Nothing is drawn yet;
	 * that happens in `start`.
	 */
	public function new(machine:DrumMachine) {
		this.machine = machine;
		display = new SevenSegment(Dom.byId("display"));
		parts = new PartButtons(Dom.byId("pills"), machine.getState().tracks);
		keys = new StepKeys(Dom.byId("keys"), machine, () -> selectedPart, display);
		patterns = new PatternButtons(Dom.byId("patterns"), machine);
		knobs = [for (spec in knobSpecs()) {spec: spec, knob: buildKnob(spec)}];
	}

	/**
	 * Draws the machine once, then subscribes: every snapshot redraws the panel and every step moves the
	 * playhead. After that it starts listening for input and asks the machine to download its sounds.
	 */
	public function start() {
		draw(machine.getState());
		machine.subscribe(draw);
		machine.onStep(movePlayhead);
		listen();
		machine.load();
	}

	/** The part whose steps are on the keys right now, picked by the part buttons. */
	function selectedTrack(state:MachineState):TrackState {
		return state.tracks[selectedPart];
	}

	// ── Knobs ─────────────────────────────────────────────────────────

	/** The machine's four knobs, then the selected part's three, then its 808 knobs. */
	function knobSpecs():Array<KnobSpec> {
		final limits = DrumMachine.limits;
		final part = () -> selectedPart;
		return [
			lettered("tempo", limits.tempo, state -> state.tempo, machine.setTempo),
			lettered("swing", limits.swing, state -> state.swing, machine.setSwing),
			lettered("drive", limits.drive, state -> state.drive, machine.setDrive),
			lettered("reverb", limits.reverb, state -> state.reverb, machine.setReverb),
			lettered("level", limits.volume, state -> selectedTrack(state).volume, value -> machine.setVolume(part(), value)),
			lettered("pitch", limits.pitch, state -> selectedTrack(state).pitch, value -> machine.setPitch(part(), value)),
			lettered("length", limits.length, state -> selectedTrack(state).length, value -> machine.setLength(part(), value))
		].concat([for (slot in 0...Kit.MOST_DIALS) dialSpec(slot)]);
	}

	/** A knob whose display shows its letter and value, e.g. "S 66" (or nothing, for tempo). */
	function lettered(id:String, range:Range, read:MachineState->Int, set:Int->Void):KnobSpec {
		final letter = PanelText.KNOB_LETTERS[id];
		return {id: id, range: range, read: read, set: set, show: state -> letter == null ? null : PanelText.labelled(letter, read(state))};
	}

	/** One of the selected part's 808 knobs; its display shows the recording's setting, e.g. "2550". */
	function dialSpec(slot:Int):KnobSpec {
		final hasKnob = (state:MachineState) -> slot < selectedTrack(state).dials.length;
		return {
			id: 'dial-$slot', range: DrumMachine.limits.dial,
			read: state -> hasKnob(state) ? selectedTrack(state).dials[slot] : DrumMachine.limits.dial.initial,
			set: value -> machine.setDial(selectedPart, slot, value),
			show: state -> hasKnob(state) ? PanelText.dialSetting(selectedTrack(state)) : null
		};
	}

	/**
	 * Makes a knob from its spec. Turning it sets the value on the machine, and then shows the new value on the
	 * display for a moment, so you can see the number while you turn.
	 */
	function buildKnob(spec:KnobSpec):Knob {
		return new Knob(Dom.byId(spec.id), spec.range, value -> {
			spec.set(value);
			final text = spec.show(machine.getState());
			if (text != null) display.showBriefly(text);
		});
	}

	// ── Drawing a snapshot ────────────────────────────────────────────

	/** Every snapshot redraws the panel, then remembers the pattern in the address. */
	function draw(state:MachineState) {
		final selected = selectedTrack(state);
		drawTransport(state);
		for (entry in knobs) entry.knob.show(entry.spec.read(state));
		drawPartKnobs(selected);
		parts.draw(state.tracks, selectedPart);
		keys.draw(selected);
		patterns.draw(state);
		rememberInAddress(state.code);
	}

	/**
	 * The top row: Play is enabled only once the sounds have loaded, and lights up while playing. Download
	 * waits for the sounds too, and for any render already going. Paste waits until something has been copied.
	 * The status line and the display show what the machine is doing.
	 */
	function drawTransport(state:MachineState) {
		final play = Dom.byId("play");
		(cast play : js.html.ButtonElement).disabled = state.status != Ready;
		Dom.setPressed(play, state.playing);
		play.setAttribute("aria-label", state.playing ? "Stop" : "Play");
		Dom.byId("play-led").classList.toggle("is-on", state.playing);
		(cast Dom.byId("save") : js.html.ButtonElement).disabled = state.status != Ready || state.exporting;
		(cast Dom.byId("paste-steps") : js.html.ButtonElement).disabled = !state.stepsCopied;
		Dom.setText(Dom.byId("status"), PanelText.status(state));
		display.showResting(PanelText.resting(state));
	}

	/**
	 * The part knobs say which part they belong to ("Snare level"), so a screen reader is clear; and each 808
	 * slot shows that part's own knob, or none.
	 */
	function drawPartKnobs(selected:TrackState) {
		for (name in ["level", "pitch", "length"]) Dom.byId(name).setAttribute("aria-label", '${selected.name} $name');
		for (slot in 0...Kit.MOST_DIALS) drawDialSlot(slot, selected);
	}

	/** An 808 slot takes the name of the part's knob there, or sits dimmed and out of the tab order if it has none. */
	function drawDialSlot(slot:Int, selected:TrackState) {
		final knob = Dom.byId('dial-$slot');
		final name = selected.dialNames[slot];
		final unit = knob.closest(".dm-unit");
		unit.classList.toggle("is-unused", name == null);
		Dom.setText(unit.querySelector(".dm-print"), name ?? "—");
		knob.setAttribute("aria-label", PanelText.dialLabel(selected, slot));
		knob.setAttribute("aria-disabled", name == null ? "true" : "false");
		knob.tabIndex = name == null ? -1 : 0;
	}

	/** Some frames refuse to change the address; then the pattern simply is not remembered there. */
	static function rememberInAddress(code:String) {
		try {
			window.history.replaceState(null, "", '#$code');
		} catch (_) {}
	}

	// ── The playhead ──────────────────────────────────────────────────

	/**
	 * The playhead moves on the step keys, and each part button flashes when its part hits, like LEDs on
	 * hardware. This runs up to 13 times a second, so it only touches those few things and never redraws the
	 * whole panel.
	 */
	function movePlayhead(step:Int) {
		keys.movePlayhead(step);
		if (step >= 0) parts.flash(step, machine.getState().tracks);
	}

	// ── Input ─────────────────────────────────────────────────────────

	/**
	 * Connects every button to what it does. Most just call the machine; the machine then sends a new snapshot,
	 * and `draw` shows the result. The panel never changes the screen directly in response to a click.
	 */
	function listen() {
		Dom.byId("play").addEventListener("click", () -> machine.togglePlay());
		Dom.byId("clear").addEventListener("click", () -> machine.clear());
		Dom.byId("save").addEventListener("click", () -> LoopFile.download(machine));
		Dom.byId("copy-steps").addEventListener("click", () -> machine.copySteps(selectedPart));
		Dom.byId("paste-steps").addEventListener("click", () -> machine.pasteSteps(selectedPart));
		Dom.byId("pills").addEventListener("click", onPillsClick);
		new ShareButton(Dom.byId("share"), Dom.byId("share-note"), machine);
		document.addEventListener("keydown", onShortcut);
	}

	/**
	 * Shows another part's steps on the keys. Which part is shown belongs to the panel, not the machine (sound
	 * doesn't depend on it), so the panel redraws itself here instead of waiting for a snapshot.
	 */
	function selectPart(index:Int) {
		selectedPart = index;
		draw(machine.getState());
	}

	/** The pill selects its part; the M tab above it mutes that part without selecting it. */
	function onPillsClick(event:MouseEvent) {
		final muted = Dom.numberFrom(event, "mute");
		if (muted != null) return machine.toggleMute(muted);
		final part = Dom.numberFrom(event, "part");
		if (part != null) selectPart(part);
	}

	/** Space plays and stops unless a focused control already uses it; keys 1–8 pick a part. */
	function onShortcut(event:KeyboardEvent) {
		final part = Std.parseInt(event.key);
		if (part != null && part >= 1 && part <= machine.getState().tracks.length) return selectPart(part - 1);
		final spaceAlreadyUsed = (cast event.target : Element).closest("button, [role='slider']") != null;
		if (event.key != " " || spaceAlreadyUsed) return;
		event.preventDefault();
		machine.togglePlay();
	}
}
