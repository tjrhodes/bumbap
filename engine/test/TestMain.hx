/** Runs every engine test on Node: `haxe test.hxml`. */
class TestMain {
	static function main() {
		Check.runAll(ModelTests.all().concat(MachineTests.all()).concat(PatternTests.all()).concat(PanelTests.all()));
	}
}
