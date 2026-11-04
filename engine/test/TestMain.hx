/** Runs every engine test on Node: `haxe test.hxml`. */
class TestMain {
	/** Runs every test file's tests in one queue, one after another, then prints the totals. */
	static function main() {
		Check.runAll(ModelTests.all().concat(MachineTests.all()).concat(PatternTests.all()).concat(ExportTests.all()).concat(PanelTests.all()));
	}
}
