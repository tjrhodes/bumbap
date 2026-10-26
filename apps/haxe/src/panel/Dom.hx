package panel;

import js.Browser.document;
import js.html.Element;
import js.html.Event;

/** Small DOM helpers, so the rest of the panel reads as what it does. */
class Dom {
	static inline final SVG_NAMESPACE = "http://www.w3.org/2000/svg";

	public static function byId(id:String):Element {
		return document.getElementById(id);
	}

	/** An HTML element with its class and attributes in one go. */
	public static function create(tag:String, className:String, ?attributes:Dynamic<String>):Element {
		final made = document.createElement(tag);
		made.className = className;
		setAttributes(made, attributes);
		return made;
	}

	public static function createSvg(tag:String, attributes:Dynamic<String>):Element {
		final made:Element = cast document.createElementNS(SVG_NAMESPACE, tag);
		setAttributes(made, attributes);
		return made;
	}

	/** The number in data-<name> on the event's element or an ancestor, or null if there is none. */
	public static function numberFrom(event:Event, name:String):Null<Int> {
		final target = (cast event.target : Element).closest('[data-$name]');
		return target == null ? null : Std.parseInt(target.getAttribute('data-$name'));
	}

	/**
	 * Changes an element's text only if it is different. Writing the same text still replaces the
	 * text node, and the browser then works out the page's layout again; a framework skips that
	 * for you, plain DOM code has to skip it itself (measured: up to 10 ms per drag move on a phone).
	 */
	public static function setText(element:Element, text:String) {
		if (element.textContent != text) element.textContent = text;
	}

	public static function setPressed(element:Element, pressed:Bool) {
		element.setAttribute("aria-pressed", pressed ? "true" : "false");
	}

	static function setAttributes(element:Element, attributes:Null<Dynamic<String>>) {
		if (attributes == null) return;
		for (name in Reflect.fields(attributes)) element.setAttribute(name, Reflect.field(attributes, name));
	}
}
