package panel;

import drum.DrumMachine;
import drum.State.StepSettings;
import drum.State.TrackState;
import drum.panel.PanelText;
import js.html.Element;
import js.html.KeyboardEvent;
import js.html.MouseEvent;
import js.html.PointerEvent;

/** One of the two things a key drag changes, and the letter the display shows for it. */
typedef StepAxis = {
	final letter:String;
	final read:StepSettings->Int;
	final set:(step:Int, value:Float) -> Void;
}

/** A press on a key: where it started, the step as it was, and the axis once the drag has chosen one. */
typedef KeyGesture = {
	final x:Float;
	final y:Float;
	final from:StepSettings;
	var axis:Null<String>;
}

/**
 * The sixteen brass keys of the selected part, in four beats, each with a
 * flip tab above it. Tap a key to switch its step; drag it up or down for its
 * level, sideways for its nudge; the tab plays it backwards.
 */
class StepKeys {
	static inline final STEPS_PER_BEAT = 4;
	/** Less movement than this is still a tap. */
	static inline final DRAG_THRESHOLD_PX = 6;
	/** Dragging this far up sweeps the whole velocity range. */
	static inline final LEVEL_TRAVEL_PX = 140;
	/** So the full ±16 ticks is about a key's width either way. */
	static inline final NUDGE_PX_PER_TICK = 3;
	static final ARROWS = [
		"ArrowUp" => {axis: "level", change: 5}, "ArrowDown" => {axis: "level", change: -5},
		"ArrowRight" => {axis: "nudge", change: 1}, "ArrowLeft" => {axis: "nudge", change: -1}
	];

	final keys:Array<Element> = [];
	final flips:Array<Element> = [];
	final machine:DrumMachine;
	final selectedPart:() -> Int;
	final display:SevenSegment;
	final axes:Map<String, StepAxis>;
	var currentStep = -1;
	var suppressClick = false;

	public function new(container:Element, machine:DrumMachine, selectedPart:() -> Int, display:SevenSegment) {
		this.machine = machine;
		this.selectedPart = selectedPart;
		this.display = display;
		axes = [
			"level" => {letter: PanelText.STEP_LETTERS["level"], read: step -> step.velocity, set: (index, value) -> machine.setStepVelocity(selectedPart(), index, value)},
			"nudge" => {letter: PanelText.STEP_LETTERS["nudge"], read: step -> step.nudge, set: (index, value) -> machine.setStepNudge(selectedPart(), index, value)}
		];
		build(container, DrumMachine.limits.steps);
		listen(container);
	}

	// ── Drawing ───────────────────────────────────────────────────────

	/** Each key shows whether its step plays, how hard, how nudged and which way round. */
	public function draw(track:TrackState) {
		for (index in 0...keys.length) {
			final step = track.steps[index];
			final reversed = step.on && step.reversed;
			Dom.setPressed(keys[index], step.on);
			keys[index].setAttribute("aria-label", PanelText.stepLabel(track.name, index, step));
			keys[index].style.setProperty("--level", Std.string(step.velocity / 100));
			keys[index].style.setProperty("--nudge", Std.string(step.nudge / DrumMachine.limits.nudge.max));
			keys[index].classList.toggle("is-reversed", reversed);
			Dom.setPressed(flips[index], reversed);
			flips[index].setAttribute("aria-label", PanelText.flipLabel(track.name, index));
		}
	}

	/** The playhead never goes through the snapshot: it just moves one key's light. */
	public function movePlayhead(step:Int) {
		if (currentStep >= 0) keys[currentStep].classList.remove("is-current");
		if (step >= 0) keys[step].classList.add("is-current");
		currentStep = step;
	}

	// ── Building ──────────────────────────────────────────────────────

	function build(container:Element, stepCount:Int) {
		var beatStart = 0;
		while (beatStart < stepCount) {
			final beat = Dom.create("div", "dm-beat", {"data-beat": Std.string(Std.int(beatStart / STEPS_PER_BEAT) + 1)});
			for (step in beatStart...beatStart + STEPS_PER_BEAT) beat.append(buildFlip(step), buildKey(step));
			container.append(beat);
			beatStart += STEPS_PER_BEAT;
		}
	}

	function buildFlip(step:Int):Element {
		final flip = Dom.create("button", "dm-tab dm-flip", {"aria-pressed": "false", "data-flip": Std.string(step)});
		flip.append(Dom.create("span", "dm-flip-icon"));
		flips.push(flip);
		return flip;
	}

	/** A key: the level fill at the back, then its LED, then its printed number. */
	function buildKey(step:Int):Element {
		final key = Dom.create("button", "dm-key", {"aria-pressed": "false", "data-step": Std.string(step)});
		final number = Dom.create("span", "dm-key-number");
		number.textContent = Std.string(step + 1);
		key.append(Dom.create("span", "dm-key-fill"), Dom.create("span", "dm-key-led"), number);
		keys.push(key);
		return key;
	}

	// ── Gestures ──────────────────────────────────────────────────────

	function listen(container:Element) {
		container.addEventListener("pointerdown", startGesture);
		container.addEventListener("click", onClick);
		container.addEventListener("keydown", onArrow);
	}

	function selectedStep(index:Int):StepSettings {
		return machine.getState().tracks[selectedPart()].steps[index];
	}

	function adjust(index:Int, axisName:String, value:Float) {
		final axis = axes[axisName];
		axis.set(index, value);
		display.showBriefly(PanelText.labelled(axis.letter, axis.read(selectedStep(index))));
	}

	function startGesture(down:PointerEvent) {
		final key = (cast down.target : Element).closest(".dm-key");
		if (key == null) return;
		suppressClick = false;
		final index = Std.parseInt(key.getAttribute("data-step"));
		final gesture:KeyGesture = {x: down.clientX, y: down.clientY, from: selectedStep(index), axis: null};
		Pointer.track(key, down, move -> followDrag(move, gesture, index));
	}

	/** The first clear movement picks the axis, and the gesture keeps it, so a level drag never nudges by accident. */
	function followDrag(move:PointerEvent, gesture:KeyGesture, index:Int) {
		final rise = gesture.y - move.clientY;
		final across = move.clientX - gesture.x;
		if (gesture.axis == null) gesture.axis = chooseAxis(rise, across);
		if (gesture.axis == null) return;
		suppressClick = true; // this press is a drag, so its click must not switch the step
		final velocity = DrumMachine.limits.velocity;
		if (gesture.axis == "level") adjust(index, "level", gesture.from.velocity + rise * (velocity.max - velocity.min) / LEVEL_TRAVEL_PX);
		else adjust(index, "nudge", gesture.from.nudge + across / NUDGE_PX_PER_TICK);
	}

	static function chooseAxis(rise:Float, across:Float):Null<String> {
		if (Math.max(Math.abs(rise), Math.abs(across)) < DRAG_THRESHOLD_PX) return null;
		return Math.abs(rise) >= Math.abs(across) ? "level" : "nudge";
	}

	/** A flip tab reverses its step; a key switches its step, unless the press was a drag. Enter and Space arrive here too. */
	function onClick(event:MouseEvent) {
		final flipped = Dom.numberFrom(event, "flip");
		if (flipped != null) return machine.toggleStepReverse(selectedPart(), flipped);
		final index = Dom.numberFrom(event, "step");
		final wasDrag = suppressClick;
		suppressClick = false;
		if (index != null && !wasDrag) machine.toggleStep(selectedPart(), index);
	}

	/** On a focused key: up and down change its level by 5, left and right its nudge by a tick. */
	function onArrow(event:KeyboardEvent) {
		final index = Dom.numberFrom(event, "step");
		final arrow = ARROWS[event.key];
		if (index == null || arrow == null) return;
		event.preventDefault();
		adjust(index, arrow.axis, axes[arrow.axis].read(selectedStep(index)) + arrow.change);
	}
}
