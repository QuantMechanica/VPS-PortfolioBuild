#!/usr/bin/env python3
"""Reject forbidden framework-input pins in an MQL5 OnInit guard.

The generated-EA build contract permits a locked-configuration guard to pin
only strategy_* inputs, qm_ea_id, qm_magic_slot_offset, and fixed backtest
risk. Runtime controls for RNG, news, and Friday close must remain mutable.
The stress rejection probability may be validated, but never pinned.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


COMPARISON = r"(?:==|!=|<=|>=|<|>)"
FORBIDDEN_PIN_NAMES = (
    "qm_rng_seed",
    "qm_news_*",
    "qm_friday_close_*",
)


@dataclass(frozen=True)
class Finding:
    line: int
    message: str


def _mask_comments_and_strings(text: str) -> str:
    """Replace non-code characters with spaces while preserving newlines."""
    chars = list(text)
    i = 0
    state = "code"
    while i < len(chars):
        ch = chars[i]
        nxt = chars[i + 1] if i + 1 < len(chars) else ""
        if state == "code":
            if ch == "/" and nxt == "/":
                chars[i] = chars[i + 1] = " "
                state = "line_comment"
                i += 2
                continue
            if ch == "/" and nxt == "*":
                chars[i] = chars[i + 1] = " "
                state = "block_comment"
                i += 2
                continue
            if ch in ('"', "'"):
                quote = ch
                chars[i] = " "
                state = quote
                i += 1
                continue
        elif state == "line_comment":
            if ch == "\n":
                state = "code"
            else:
                chars[i] = " "
            i += 1
            continue
        elif state == "block_comment":
            if ch == "*" and nxt == "/":
                chars[i] = chars[i + 1] = " "
                state = "code"
                i += 2
                continue
            if ch != "\n":
                chars[i] = " "
            i += 1
            continue
        else:
            if ch == "\\" and nxt:
                chars[i] = " "
                if nxt != "\n":
                    chars[i + 1] = " "
                i += 2
                continue
            if ch == state:
                chars[i] = " "
                state = "code"
            elif ch != "\n":
                chars[i] = " "
            i += 1
            continue
        i += 1
    return "".join(chars)


def _matching(text: str, start: int, opening: str, closing: str) -> int:
    depth = 0
    for index in range(start, len(text)):
        if text[index] == opening:
            depth += 1
        elif text[index] == closing:
            depth -= 1
            if depth == 0:
                return index
    return -1


def _on_init_body(masked: str) -> tuple[int, str] | None:
    match = re.search(r"\b(?:int|void)\s+OnInit\s*\([^)]*\)\s*\{", masked)
    if not match:
        return None
    opening = masked.find("{", match.start())
    closing = _matching(masked, opening, "{", "}")
    if closing < 0:
        return None
    return opening + 1, masked[opening + 1 : closing]


def _if_conditions(body: str, body_offset: int) -> list[tuple[int, str]]:
    conditions: list[tuple[int, str]] = []
    for match in re.finditer(r"\bif\s*\(", body):
        opening = body.find("(", match.start())
        closing = _matching(body, opening, "(", ")")
        if closing >= 0:
            conditions.append((body_offset + opening + 1, body[opening + 1 : closing]))
    return conditions


def _line_at(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _compares_name(condition: str, name_pattern: str) -> bool:
    left = rf"\b(?:{name_pattern})\b\s*{COMPARISON}"
    right = rf"{COMPARISON}\s*\b(?:{name_pattern})\b"
    unary = rf"!\s*\b(?:{name_pattern})\b(?!\s*\()"
    return bool(re.search(rf"(?:{left}|{right}|{unary})", condition))


def _stress_comparisons(condition: str) -> list[tuple[str, str, bool]]:
    name = r"qm_stress_reject_probability"
    number = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)"
    found: list[tuple[str, str, bool]] = []
    for match in re.finditer(rf"\b{name}\b\s*({COMPARISON})\s*({number})", condition):
        found.append((match.group(1), match.group(2), False))
    for match in re.finditer(rf"({number})\s*({COMPARISON})\s*\b{name}\b", condition):
        found.append((match.group(2), match.group(1), True))
    return found


def _valid_stress_bound(operator: str, literal: str, reversed_order: bool) -> bool:
    try:
        value = float(literal)
    except ValueError:
        return False
    if operator in ("==", "!="):
        return False
    if reversed_order:
        operator = {"<": ">", ">": "<", "<=": ">=", ">=": "<="}[operator]
    return (value == 0.0 and operator in ("<", ">=")) or (
        value == 1.0 and operator in (">", "<=")
    )


def audit_source(text: str) -> list[Finding]:
    masked = _mask_comments_and_strings(text)
    located = _on_init_body(masked)
    if located is None:
        return [Finding(1, "OnInit body is missing or syntactically unbalanced")]
    body_offset, body = located
    findings: list[Finding] = []
    for offset, condition in _if_conditions(body, body_offset):
        line = _line_at(masked, offset)
        forbidden_patterns = (
            (r"qm_rng_seed", "qm_rng_seed"),
            (r"qm_news_[A-Za-z0-9_]*", "qm_news_*"),
            (r"qm_friday_close_[A-Za-z0-9_]*", "qm_friday_close_*"),
        )
        for pattern, label in forbidden_patterns:
            if _compares_name(condition, pattern):
                findings.append(
                    Finding(line, f"locked-configuration guard compares forbidden input {label}")
                )

        stress_name = "qm_stress_reject_probability"
        if re.search(rf"!\s*\b{stress_name}\b(?!\s*\()", condition):
            findings.append(
                Finding(line, "stress rejection probability is used as a boolean/default pin")
            )
        for operator, literal, reversed_order in _stress_comparisons(condition):
            if not _valid_stress_bound(operator, literal, reversed_order):
                findings.append(
                    Finding(
                        line,
                        "stress rejection probability may only be range-checked against inclusive bounds 0 and 1; equality/default pins are forbidden",
                    )
                )
    return findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-source", required=True, type=Path)
    args = parser.parse_args(argv)
    source = args.check_source.resolve()
    if not source.is_file():
        print(f"ERROR: source not found: {source}", file=sys.stderr)
        return 2
    try:
        text = source.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        print(f"ERROR: cannot read source {source}: {exc}", file=sys.stderr)
        return 2

    findings = audit_source(text)
    if findings:
        for finding in findings:
            print(f"FINDING: {source}:{finding.line}: {finding.message}")
        return 1
    print(f"PASS: {source}: locked-input pin audit found no violations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
