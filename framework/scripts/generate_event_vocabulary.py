"""Generate the deterministic QM event-vocabulary registry.

The scanner resolves direct string literals, scalar ``const string`` aliases,
top-level ternary branches, and both QM_LogEvent/QM_LogFatal call shapes. Calls
whose event expression cannot be proven statically are retained in the registry
as ``unresolved_calls`` instead of being silently discarded.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / "framework" / "registry" / "event_vocabulary.json"
DEFAULT_SOURCE_ROOTS = (
    "framework/include",
    "framework/templates",
    "framework/EAs",
    "framework/tests",
)
SOURCE_SUFFIXES = frozenset({".mq5", ".mqh"})
CALL_RE = re.compile(r"\b(QM_LogEvent|QM_LogFatal)\s*\(")
CONST_RE = re.compile(
    r"\b(?:static\s+)?const\s+string\s+([A-Za-z_]\w*)\s*=\s*"
    r"(\"(?:\\.|[^\"\\])*\")\s*;",
    re.MULTILINE,
)
DEFINE_RE = re.compile(
    r"(?m)^\s*#define\s+([A-Za-z_]\w*)\s+(\"(?:\\.|[^\"\\])*\")\s*$"
)
IDENT_RE = re.compile(r"^[A-Za-z_]\w*$")
STRING_RE = re.compile(r'^\"(?:\\.|[^\"\\])*\"$')


@dataclass(frozen=True)
class EventCall:
    path: str
    line: int
    callee: str
    expression: str


def _decode_string(literal: str) -> str:
    return json.loads(literal)


def mask_comments(text: str) -> str:
    """Replace comments with spaces while preserving strings and line numbers."""

    out = list(text)
    i = 0
    state = "code"
    quote = ""
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if state == "code":
            if ch in ('"', "'"):
                state = "string"
                quote = ch
                i += 1
                continue
            if ch == "/" and nxt == "/":
                out[i] = out[i + 1] = " "
                i += 2
                state = "line_comment"
                continue
            if ch == "/" and nxt == "*":
                out[i] = out[i + 1] = " "
                i += 2
                state = "block_comment"
                continue
        elif state == "string":
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                state = "code"
                quote = ""
        elif state == "line_comment":
            if ch == "\n":
                state = "code"
            else:
                out[i] = " "
        elif state == "block_comment":
            if ch == "*" and nxt == "/":
                out[i] = out[i + 1] = " "
                i += 2
                state = "code"
                continue
            if ch != "\n":
                out[i] = " "
        i += 1
    return "".join(out)


def _matching_paren(text: str, open_index: int) -> int | None:
    depth = 0
    quote = ""
    i = open_index
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = ""
        elif ch in ('"', "'"):
            quote = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return None


def _split_arguments(text: str) -> list[str]:
    args: list[str] = []
    start = 0
    depths = {"(": 0, "[": 0, "{": 0}
    closing = {")": "(", "]": "[", "}": "{"}
    quote = ""
    i = 0
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = ""
        elif ch in ('"', "'"):
            quote = ch
        elif ch in depths:
            depths[ch] += 1
        elif ch in closing:
            depths[closing[ch]] -= 1
        elif ch == "," and all(value == 0 for value in depths.values()):
            args.append(text[start:i].strip())
            start = i + 1
        i += 1
    args.append(text[start:].strip())
    return args


def _fully_wrapped(expression: str) -> bool:
    if not (expression.startswith("(") and expression.endswith(")")):
        return False
    return _matching_paren(expression, 0) == len(expression) - 1


def _ternary_branches(expression: str) -> tuple[str, str] | None:
    depths = {"(": 0, "[": 0, "{": 0}
    closing = {")": "(", "]": "[", "}": "{"}
    quote = ""
    question = -1
    nested = 0
    i = 0
    while i < len(expression):
        ch = expression[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = ""
        elif ch in ('"', "'"):
            quote = ch
        elif ch in depths:
            depths[ch] += 1
        elif ch in closing:
            depths[closing[ch]] -= 1
        elif all(value == 0 for value in depths.values()):
            if ch == "?":
                if question < 0:
                    question = i
                else:
                    nested += 1
            elif ch == ":" and question >= 0:
                if nested:
                    nested -= 1
                else:
                    return expression[question + 1 : i], expression[i + 1 :]
        i += 1
    return None


def resolve_event_expression(
    expression: str,
    constants: dict[str, frozenset[str]],
) -> frozenset[str]:
    expression = expression.strip()
    while _fully_wrapped(expression):
        expression = expression[1:-1].strip()
    if STRING_RE.fullmatch(expression):
        return frozenset({_decode_string(expression)})
    if IDENT_RE.fullmatch(expression):
        return constants.get(expression, frozenset())
    branches = _ternary_branches(expression)
    if branches:
        left = resolve_event_expression(branches[0], constants)
        right = resolve_event_expression(branches[1], constants)
        if left and right:
            return left | right
    return frozenset()


def _source_files(repo_root: Path, source_roots: Sequence[str]) -> list[Path]:
    files: set[Path] = set()
    for relative_root in source_roots:
        root = repo_root / relative_root
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES:
                files.add(path)
    return sorted(files, key=lambda item: item.relative_to(repo_root).as_posix())


def _constants_for_sources(
    repo_root: Path,
    files: Iterable[Path],
) -> tuple[dict[str, frozenset[str]], dict[str, dict[str, frozenset[str]]]]:
    global_values: dict[str, set[str]] = defaultdict(set)
    file_values: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    for path in files:
        relative = path.relative_to(repo_root).as_posix()
        masked = mask_comments(path.read_text(encoding="utf-8", errors="ignore"))
        for pattern in (CONST_RE, DEFINE_RE):
            for match in pattern.finditer(masked):
                name = match.group(1)
                value = _decode_string(match.group(2))
                global_values[name].add(value)
                file_values[relative][name].add(value)
    globals_frozen = {
        name: frozenset(values)
        for name, values in global_values.items()
        if len(values) == 1
    }
    files_frozen = {
        path: {
            name: frozenset(values)
            for name, values in names.items()
            if len(values) == 1
        }
        for path, names in file_values.items()
    }
    return globals_frozen, files_frozen


def _is_function_definition(masked: str, call_start: int) -> bool:
    prefix = masked[max(0, call_start - 80) : call_start]
    return bool(re.search(r"\b(?:bool|void|int|string)\s+$", prefix))


def scan_event_calls(
    repo_root: Path,
    source_roots: Sequence[str] = DEFAULT_SOURCE_ROOTS,
) -> tuple[set[str], list[EventCall], int]:
    files = _source_files(repo_root, source_roots)
    global_constants, per_file_constants = _constants_for_sources(repo_root, files)
    events: set[str] = set()
    unresolved: list[EventCall] = []
    resolved_call_count = 0

    for path in files:
        relative = path.relative_to(repo_root).as_posix()
        masked = mask_comments(path.read_text(encoding="utf-8", errors="ignore"))
        constants = dict(global_constants)
        constants.update(per_file_constants.get(relative, {}))
        for match in CALL_RE.finditer(masked):
            if _is_function_definition(masked, match.start()):
                continue
            close_index = _matching_paren(masked, match.end() - 1)
            if close_index is None:
                continue
            args = _split_arguments(masked[match.end() : close_index])
            event_index = 1 if match.group(1) == "QM_LogEvent" else 0
            if len(args) <= event_index:
                continue
            expression = args[event_index].strip()
            # QM_LogFatal delegates to QM_LogEvent; its caller is the emission
            # site, so do not report the logger's plumbing parameter as dynamic.
            if relative == "framework/include/QM/QM_Logger.mqh" and expression == "event_name":
                continue
            values = resolve_event_expression(expression, constants)
            if values:
                events.update(values)
                resolved_call_count += 1
            else:
                unresolved.append(
                    EventCall(
                        path=relative,
                        line=masked.count("\n", 0, match.start()) + 1,
                        callee=match.group(1),
                        expression=" ".join(expression.split()),
                    )
                )

    unresolved.sort(key=lambda row: (row.path, row.line, row.callee, row.expression))
    return events, unresolved, resolved_call_count


def generate_registry(
    repo_root: Path = REPO_ROOT,
    source_roots: Sequence[str] = DEFAULT_SOURCE_ROOTS,
) -> dict:
    events, unresolved, resolved_call_count = scan_event_calls(repo_root, source_roots)
    return {
        "schema_version": 1,
        "generated_by": "framework/scripts/generate_event_vocabulary.py",
        "source_roots": list(source_roots),
        "streams": {
            "q08_trades": {
                "stream": "q08_trades",
                "schema_version": 1,
                "encoding": "jsonl",
                "envelope": "bare_trade_record",
                "event_names": ["TRADE_CLOSED"],
                "required_fields": [
                    "event",
                    "magic",
                    "time",
                    "entry_time",
                    "mae_acct",
                    "net",
                    "profit",
                    "swap",
                    "commission",
                    "volume",
                    "notional",
                    "symbol",
                ],
                "emitter": "framework/include/QM/QM_Common.mqh",
                "note": "Deliberately bare second schema; it is not a QM_LogEvent envelope.",
            },
            "qm_events": {
                "stream": "qm_events",
                "schema_version": 1,
                "encoding": "jsonl",
                "envelope": "QM_LogEvent",
                "required_fields": [
                    "sv",
                    "ts_utc",
                    "ts_broker",
                    "level",
                    "ea_id",
                    "slug",
                    "symbol",
                    "tf",
                    "magic",
                    "event",
                    "payload",
                ],
                "event_names": sorted(events),
                "resolved_call_count": resolved_call_count,
            },
        },
        "unresolved_calls": [
            {
                "path": row.path,
                "line": row.line,
                "callee": row.callee,
                "event_expression": row.expression,
            }
            for row in unresolved
        ],
    }


def render_registry(registry: dict) -> str:
    return json.dumps(registry, indent=2, sort_keys=True, ensure_ascii=True) + "\n"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--stdout", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    repo_root = args.repo_root.resolve()
    output = (args.output or (repo_root / "framework/registry/event_vocabulary.json")).resolve()
    rendered = render_registry(generate_registry(repo_root))
    if args.stdout:
        sys.stdout.write(rendered)
        return 0
    if args.check:
        if not output.is_file() or output.read_text(encoding="utf-8") != rendered:
            print(
                f"event_vocabulary.check=FAIL path={output} "
                "(run generate_event_vocabulary.py to refresh)",
                file=sys.stderr,
            )
            return 1
        registry = json.loads(rendered)
        print(
            "event_vocabulary.check=PASS "
            f"events={len(registry['streams']['qm_events']['event_names'])} "
            f"unresolved={len(registry['unresolved_calls'])} path={output}"
        )
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered, encoding="utf-8", newline="\n")
    registry = json.loads(rendered)
    print(
        "event_vocabulary.generated "
        f"events={len(registry['streams']['qm_events']['event_names'])} "
        f"unresolved={len(registry['unresolved_calls'])} path={output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
