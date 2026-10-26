#!/usr/bin/env bash
# Builds everything from a fresh checkout, in the order the parts depend on each other:
# the engine (tested first), then the four front ends, then the prototype page.
# The CI workflow runs this; so can you:  tools/build-all.sh
# Needs Haxe 4.3 and Node 22.22+ (the Angular CLI's minimum) on the PATH.

set -euo pipefail
cd "$(dirname "$0")/.."

# The engine: its unit tests on Node with a fake Tone.js, then the ES module every front end uses.
build_engine() {
	(cd engine && npm ci && haxe test.hxml && haxe build.hxml)
}

# Haxe compiles the engine's source in directly; the others install the built engine as a package.
build_front_ends() {
	(cd apps/haxe && haxe build.hxml)
	for app in react vue angular; do
		(cd "apps/$app" && npm ci && npm run build)
	done
}

build_engine
build_front_ends
python3 prototype/build.py
echo "Built the engine, the four front ends and the prototype."
