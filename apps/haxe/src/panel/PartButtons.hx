package panel;

import drum.State.TrackState;
import js.html.Element;

/**
 * The eight part buttons: a pill that selects the part (its LED flashes when
 * the part plays) and a small M tab above it that mutes it.
 */
class PartButtons {
	final pills:Array<Element>;
	final mutes:Array<Element>;

	public function new(container:Element, tracks:Array<TrackState>) {
		pills = [for (index in 0...tracks.length) buildPill(tracks[index], index)];
		mutes = [for (index in 0...tracks.length) buildMute(tracks[index], index)];
		for (index in 0...tracks.length) container.append(wrap(mutes[index], pills[index]));
	}

	public function draw(tracks:Array<TrackState>, selectedIndex:Int) {
		for (index in 0...tracks.length) {
			Dom.setPressed(pills[index], index == selectedIndex);
			pills[index].classList.toggle("is-muted", tracks[index].muted);
			Dom.setPressed(mutes[index], tracks[index].muted);
		}
	}

	/** Lets you see the parts you are not editing: each LED blinks as its part sounds, brighter when harder. */
	public function flash(step:Int, tracks:Array<TrackState>) {
		for (index in 0...tracks.length) {
			final hit = tracks[index].steps[step];
			if (!hit.on || tracks[index].muted) continue;
			final glow = pills[index].querySelector(".dm-led-glow");
			glow.animate([{opacity: Math.max(0.3, hit.velocity / 100)}, {opacity: 0}], {duration: 260, easing: "ease-out"});
		}
	}

	static function buildPill(track:TrackState, index:Int):Element {
		final pill = Dom.create("button", "dm-pill", {"aria-pressed": "false", "data-part": Std.string(index)});
		final led = Dom.create("span", "dm-led");
		led.append(Dom.create("span", "dm-led-glow"));
		pill.append(led, js.Browser.document.createTextNode(track.name));
		return pill;
	}

	static function buildMute(track:TrackState, index:Int):Element {
		final mute = Dom.create("button", "dm-tab dm-mute", {"aria-pressed": "false", "aria-label": 'Mute ${track.name}', "data-mute": Std.string(index)});
		mute.textContent = "M";
		return mute;
	}

	static function wrap(mute:Element, pill:Element):Element {
		final wrapper = Dom.create("div", "dm-pill-wrap");
		wrapper.append(mute, pill);
		return wrapper;
	}
}
