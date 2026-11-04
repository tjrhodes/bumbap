import js.lib.Promise;

/** One named test; every body is run as if it might have to wait. */
typedef Test = {
	final name:String;
	final body:() -> Promise<Any>;
}

/**
 * A deliberately tiny test runner: no library to install, nothing to learn. Tests run one after another; every
 * failed check is printed with the name of its test, and the process exits with code 1 if anything failed.
 *
 * Each test is registered with a sentence saying what it checks, e.g. `test("muted tracks are silent",
 * mutedTrackIsSilent)`. That sentence is the test's description, and it's printed if the test fails, so the
 * test functions themselves don't repeat it in a comment.
 */
class Check {
	static var passed = 0;
	static var failed = 0;
	static var currentTest = "";

	/** A test that finishes straight away. */
	public static function test(name:String, body:() -> Void):Test {
		return later(name, () -> {
			body();
			return Promise.resolve(null);
		});
	}

	/** A test that has to wait for something, e.g. samples loading. */
	public static function later(name:String, body:() -> Promise<Any>):Test {
		return {name: name, body: body};
	}

	/**
	 * The basic check: is `actual` what we expected? If not, the failure message says what was being checked
	 * and both values, so you can see what went wrong without running it again.
	 */
	public static function equal<T>(actual:T, expected:T, what:String) {
		if (actual == expected) passed++; else fail('$what: expected $expected, got $actual');
	}

	/** A check that something is so, when there's no value to compare. */
	public static function isTrue(condition:Bool, what:String) {
		equal(condition, true, what);
	}

	/** For seconds and decibels, where floating point never lands exactly. */
	public static function near(actual:Float, expected:Float, what:String) {
		if (Math.abs(actual - expected) < 1e-9) passed++; else fail('$what: expected $expected, got $actual');
	}

	/** Runs every test in order, then prints the totals. */
	public static function runAll(tests:Array<Test>):Promise<Any> {
		var queue:Promise<Any> = Promise.resolve(null);
		for (test in tests) queue = queue.then(_ -> runOne(test));
		return queue.then(_ -> report());
	}

	/** A test that throws, or whose promise rejects, counts as one failure. */
	static function runOne(test:Test):Promise<Any> {
		currentTest = test.name;
		try {
			return test.body().then(null, error -> fail('rejected: $error'));
		} catch (error:haxe.Exception) {
			fail('threw: ${error.message}');
			return Promise.resolve(null);
		}
	}

	/** Counts a failure and prints it with the name of the test it happened in. */
	static function fail(message:String) {
		failed++;
		js.Browser.console.log('  ✗ $currentTest — $message');
	}

	/**
	 * The totals at the end. A failure sets the exit code to 1, which is what makes the build fail on GitHub.
	 */
	static function report() {
		js.Browser.console.log('${passed} checks passed, ${failed} failed');
		if (failed > 0) js.Syntax.code("process.exitCode = 1");
	}
}
