"""Checks the house rule: no function or method longer than 15 lines,
counted from its first line to its last, signature and closing brace
included.

Python files are measured with the ast module. Haxe, JavaScript,
TypeScript (incl. .tsx) and Vue files are measured by brace matching from
each `function` keyword (and each `name(...) {` method in classes),
skipping braces inside strings and comments. React components and hooks are
written as `function Name(…)`, so they are measured too.

Usage: python3 tools/check-lengths.py engine/src engine/test tools ...
Exits with 1 if anything is over the limit.
"""

import ast
import re
import sys
from pathlib import Path

LIMIT = 15
BRACE_LANGUAGES = {".hx", ".js", ".mjs", ".ts", ".tsx", ".vue"}
SKIP_FOLDERS = {"node_modules", "dist", "bin", "vendor", ".angular", "test-results"}
FUNCTION_START = re.compile(r"\bfunction\b|^\s*(?:public |private |static |async )*\w+\s*\([^)]*\)\s*(?::\s*[\w<>\[\], |]+)?\s*\{")
QUOTES_AND_COMMENTS = re.compile(
    r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|`(?:\\.|[^`\\])*`', re.DOTALL)


def blank_out(match):
    """Empties a comment or string but keeps its line breaks, so line numbers stay true."""
    return '""' + "\n" * match.group(0).count("\n")


def python_functions(source):
    """(name, first line, last line) for every def in a Python file."""
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            yield node.name, node.lineno, node.end_lineno


def brace_functions(source):
    """(name, first line, last line) for every braced function in Haxe/JS/TS."""
    lines = QUOTES_AND_COMMENTS.sub(blank_out, source).splitlines()
    for number, line in enumerate(lines):
        if FUNCTION_START.search(line) and not line.rstrip().endswith(";"):
            end = matching_brace_line(lines, number)
            if end is not None:
                yield function_name(line), number + 1, end + 1


def matching_brace_line(lines, start):
    """Index of the line where the first brace opened on or after `start` closes."""
    depth, opened = 0, False
    for number in range(start, len(lines)):
        for char in lines[number]:
            depth += {"{": 1, "}": -1}.get(char, 0)
            opened = opened or char == "{"
            if opened and depth == 0:
                return number
        if not opened and lines[number].rstrip().endswith(";"):
            return None  # a declaration with no body, e.g. in a typedef or .d.ts
    return None


def function_name(line):
    match = re.search(r"function\s+(\w+)|(\w+)\s*\(", line)
    return (match.group(1) or match.group(2)) if match else "anonymous"


def source_files(paths):
    """Every checkable file under the given paths, skipping build output and libraries."""
    for path in map(Path, paths):
        for file in [path] if path.is_file() else sorted(path.rglob("*")):
            if file.suffix in BRACE_LANGUAGES | {".py"} and not SKIP_FOLDERS & set(file.parts):
                yield file


def too_long(file):
    """Functions in one file that break the limit, as printable lines."""
    source = file.read_text(encoding="utf8")
    finder = python_functions if file.suffix == ".py" else brace_functions
    for name, first, last in finder(source):
        if last - first + 1 > LIMIT:
            yield f"{file}:{first}  {name}  {last - first + 1} lines"


def main(paths):
    problems = [problem for file in source_files(paths) for problem in too_long(file)]
    for problem in problems:
        print(problem)
    print(f"{len(problems)} over {LIMIT} lines")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main(sys.argv[1:] or ["."])
