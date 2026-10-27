package drum.panel;

import js.Browser.navigator;
import js.Browser.window;
import js.lib.Promise;

/**
 * Sharing a beat as a link, written once for every front end. The whole pattern is the code at the end
 * of the address, so the link is the beat.
 *
 * - Inside a frame on a page of the same site (the Lab page on tomrhodes.it), the link is to that page,
 *   which hands its address ending on to the frame; opened on its own, it is to the build's own page.
 * - On a phone or tablet the system's share sheet offers the link; elsewhere it is copied.
 * - What happened comes back as a few words for the panel to show for a moment ("" when there is nothing
 *   to say: the share sheet speaks for itself, and closing it is the visitor's own choice).
 */
@:expose("ShareLink")
class ShareLink {
	public static final LABEL = "Share this beat";
	public static final COPIED = "Link copied";
	public static final NOT_COPIED = "Copy failed";

	/** How long the panel shows what happened. */
	public static final NOTE_MS = 2500;

	static inline final SHARE_TITLE = "A beat on bümbap";

	/** The page's address with the pattern's code as its ending, in place of any ending it had. */
	public static function addressWith(pageAddress:String, code:String):String {
		return pageAddress.split("#")[0] + "#" + code;
	}

	/** Shares the link to this beat; the promise gives the words to show (never fails). */
	public static function share(code:String):Promise<String> {
		final address = addressWith(visiblePage(), code);
		if (!onATouchScreen() || (cast navigator).share == null) return copy(address);
		return (cast navigator).share({title: SHARE_TITLE, url: address})
			.then(_ -> "", error -> error.name == "AbortError" ? Promise.resolve("") : copy(address));
	}

	/** The page the visitor sees: the one around this frame if the browser lets us read it (same site), else this one. */
	static function visiblePage():String {
		try {
			return window.parent.location.href;
		} catch (_) {
			return window.location.href;
		}
	}

	/** Phones and tablets: where a share sheet is what people expect from a share button. */
	static function onATouchScreen():Bool {
		return window.matchMedia("(pointer: coarse)").matches;
	}

	static function copy(address:String):Promise<String> {
		if (navigator.clipboard == null) return Promise.resolve(NOT_COPIED);
		return navigator.clipboard.writeText(address).then(_ -> COPIED, _ -> NOT_COPIED);
	}
}
