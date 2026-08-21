#!/usr/bin/env python3
"""Mechanical static gates for recurring EA build defects.

The checks in this module deliberately cover only objective source shapes.  A
missing or ambiguous Strategy Card is surfaced as a warning; it is never
silently converted into a guessed contract.  ``build_check.ps1`` is the
authoritative caller and turns the returned failure strings into normal
BUILD_CHECK failures.
"""
from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


SCHEMA = "qm.build-gate-hardening/v1"
PIP_HELPER_ARGUMENTS = {
    "QM_StopRulesPipsToPriceDistance": (1,),
    "QM_TM_MoveToBreakEven": (1, 2),
}


@dataclass(frozen=True)
class SourceFile:
    path: Path
    raw: str
    code: str


def read_text_compatible(path: Path) -> str:
    """Read the two encodings present in the historical MQL/card corpus."""
    try:
        return path.read_text(encoding="utf-8-sig")
    except UnicodeDecodeError:
        return path.read_text(encoding="cp1252", errors="replace")


def strip_comments_preserve_lines(text: str) -> str:
    """Remove MQL comments while retaining offsets and line numbers."""

    def blank(match: re.Match[str]) -> str:
        return "".join("\n" if char == "\n" else " " for char in match.group(0))

    text = re.sub(r"/\*.*?\*/", blank, text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", blank, text)


def strip_literals_preserve_lines(text: str) -> str:
    """Remove quoted lexical decoys while retaining offsets and line numbers."""

    def blank(match: re.Match[str]) -> str:
        return "".join("\n" if char == "\n" else " " for char in match.group(0))

    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', blank, text)


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, max(0, offset)) + 1


def matching_delimiter(text: str, start: int, opening: str, closing: str) -> int | None:
    depth = 0
    quote = ""
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue
        if char in {'"', "'"}:
            quote = char
        elif char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return index
    return None


def function_bodies(code: str) -> dict[str, tuple[int, int, str]]:
    """Return simple top-level MQL function bodies keyed by function name."""
    found: dict[str, tuple[int, int, str]] = {}
    header = re.compile(
        r"(?m)^\s*(?:bool|void|int|long|double|datetime|QM_[A-Za-z0-9_]+)\s+"
        r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*\{"
    )
    for match in header.finditer(code):
        brace = code.find("{", match.start(), match.end())
        end = matching_delimiter(code, brace, "{", "}")
        if end is not None:
            found[match.group("name")] = (brace + 1, end, code[brace + 1 : end])
    return found


def split_arguments(arguments: str) -> list[str]:
    result: list[str] = []
    start = 0
    depth = 0
    quote = ""
    escaped = False
    for index, char in enumerate(arguments):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue
        if char in {'"', "'"}:
            quote = char
        elif char in "([{":
            depth += 1
        elif char in ")]}":
            depth = max(0, depth - 1)
        elif char == "," and depth == 0:
            result.append(arguments[start:index].strip())
            start = index + 1
    result.append(arguments[start:].strip())
    return result


def iter_calls(code: str, names: Iterable[str]) -> Iterable[tuple[str, int, list[str]]]:
    name_pattern = "|".join(re.escape(name) for name in names)
    for match in re.finditer(rf"\b(?P<name>{name_pattern})\s*\(", code):
        open_paren = code.find("(", match.start(), match.end())
        end = matching_delimiter(code, open_paren, "(", ")")
        if end is None:
            continue
        yield match.group("name"), match.start(), split_arguments(code[open_paren + 1 : end])


def iter_early_return_conditions(body: str, stop: int) -> Iterable[tuple[int, str]]:
    cursor = 0
    while True:
        match = re.search(r"\bif\s*\(", body[cursor:stop])
        if not match:
            return
        if_start = cursor + match.start()
        open_paren = body.find("(", if_start, cursor + match.end())
        close_paren = matching_delimiter(body, open_paren, "(", ")")
        if close_paren is None or close_paren >= stop:
            return
        after = close_paren + 1
        while after < stop and body[after].isspace():
            after += 1
        if after < stop and body[after] == "{":
            after += 1
            while after < stop and body[after].isspace():
                after += 1
        if body.startswith("return", after):
            return_end = after + len("return")
            if return_end < stop and re.match(r"\s*;", body[return_end:stop]):
                yield if_start, body[open_paren + 1 : close_paren]
        cursor = close_paren + 1


def check_pip_double_conversion(source: SourceFile) -> list[str]:
    failures: list[str] = []
    times_ten = re.compile(r"(?:\*\s*10(?:\.0+)?\b|\b10(?:\.0+)?\s*\*)")
    for helper, offset, arguments in iter_calls(source.code, PIP_HELPER_ARGUMENTS):
        for arg_index in PIP_HELPER_ARGUMENTS[helper]:
            if arg_index >= len(arguments) or not times_ten.search(arguments[arg_index]):
                continue
            failures.append(
                "EA_PIP_DOUBLE_CONVERSION: "
                f"{source.path.name}:{line_number(source.code, offset)} passes an x10 expression "
                f"to pip-native {helper} argument {arg_index + 1}; pass whole pips exactly once."
            )
    return failures


def check_management_reachability(source: SourceFile) -> list[str]:
    functions = function_bodies(source.code)
    on_tick = functions.get("OnTick")
    if not on_tick:
        return []
    body_start, _, body = on_tick
    anchors = list(
        re.finditer(r"\b(?:Strategy_[A-Za-z0-9_]*Manage[A-Za-z0-9_]*|Strategy_[A-Za-z0-9_]*Exit[A-Za-z0-9_]*)\s*\(", body)
    )
    if not anchors:
        return []
    management_start = min(match.start() for match in anchors)
    count_call = r"(?:QM_TM_OpenPositionCount|PositionsTotal)\s*\([^;\r\n]*\)"

    def condition_proves_open(condition: str) -> bool:
        if re.search(rf"\b{count_call}\s*(?:>|>=|!=)\s*(?:0|1)\b", condition):
            return True
        # PositionSelect* returns true only when the requested position exists.
        # A negated select is the opposite condition and must not be classified.
        return bool(
            re.search(r"(?<!!)\b(?:PositionSelect|PositionSelectByTicket)\s*\(", condition)
        )

    def helper_blocks_when_open(helper_body: str) -> bool:
        for returned in re.finditer(r"\breturn\s+(?P<expr>[^;]+);", helper_body):
            if condition_proves_open(returned.group("expr")):
                return True
        for guarded in re.finditer(
            r"\bif\s*\((?P<condition>.{0,300}?)\)\s*(?:\{\s*)?return\s+true\s*;",
            helper_body,
            re.DOTALL,
        ):
            if condition_proves_open(guarded.group("condition")):
                return True
        return False

    failures: list[str] = []
    for offset, condition in iter_early_return_conditions(body, management_start):
        reason = None
        if condition_proves_open(condition):
            reason = "direct open-position guard"
        else:
            for called in re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", condition):
                helper = functions.get(called)
                if helper and helper_blocks_when_open(helper[2]):
                    reason = f"{called} contains an open-position guard"
                    break
        if reason:
            failures.append(
                "EA_MANAGEMENT_UNREACHABLE_OPEN_GUARD: "
                f"{source.path.name}:{line_number(source.code, body_start + offset)} returns before "
                f"position management/exit ({reason}); manage existing exposure before entry admission."
            )
    return failures[:1]


def check_bars_calculated_first(source: SourceFile) -> list[str]:
    """Reject raw EA-side BarsCalculated call sites.

    A raw call cannot prove that CopyBuffer was reached first across helper and
    callback boundaries.  The framework warm-up helpers make that order
    mechanical and attach bounded retry/permanent-error evidence.  Comments and
    string literals are blanked before calls are parsed, so documentary examples
    never enter the cohort.
    """

    code = strip_literals_preserve_lines(source.code)
    failures: list[str] = []
    for _, offset, _ in iter_calls(code, ("BarsCalculated",)):
        failures.append(
            "EA_BARSCALCULATED_FIRST: "
            f"{source.path.name}:{line_number(code, offset)} calls BarsCalculated directly; "
            "use QM_IndicatorWarmupReady/QM_IndicatorWarmupCalculated so CopyBuffer "
            "priming and bounded persistent-error evidence precede the readiness gate."
        )
    return failures


def _card_limit(line: str, label: str) -> float | None:
    if not re.search(label, line, re.IGNORECASE):
        return None
    match = re.search(r"(?:\$|\\ge\s*)?([0-9]+(?:\.[0-9]+)?)\s*\\?%", line)
    return float(match.group(1)) if match else None


def parse_card_loss_limits(card_text: str) -> dict[str, float]:
    limits: dict[str, float] = {}
    labels = {
        "daily_entry_halt": r"\bDaily\s+Loss\s+Limit\b",
        "daily_hard_stop": r"\bMaximum\s+Daily\s+Drawdown\s+Hard\s+Stop\b",
        "total_drawdown_stop": r"\bMaximum\s+Total\s+Drawdown\s+Stop\b",
    }
    for line in card_text.splitlines():
        for key, label in labels.items():
            value = _card_limit(line, label)
            if value is not None:
                limits[key] = value
    return limits


def parse_numeric_inputs(code: str) -> dict[str, float]:
    inputs: dict[str, float] = {}
    pattern = re.compile(
        r"\binput\s+(?:double|float)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
        r"(?P<value>[+-]?(?:\d+(?:\.\d*)?|\.\d+))\s*;"
    )
    for match in pattern.finditer(code):
        inputs[match.group("name")] = float(match.group("value"))
    return inputs


def check_loss_limit_contract(source: SourceFile, card_path: Path | None) -> tuple[list[str], list[str], dict]:
    failures: list[str] = []
    warnings: list[str] = []
    detail: dict = {"card_path": str(card_path) if card_path else None, "declared": {}}
    if card_path is None or not card_path.is_file():
        warnings.append(
            f"EA_CARD_LOSS_LIMIT_UNDECIDABLE: {source.path.name} has no unique approved/card-of-record file; no loss-limit value was guessed."
        )
        return failures, warnings, detail

    try:
        card_text = read_text_compatible(card_path)
    except (OSError, UnicodeError) as exc:
        warnings.append(f"EA_CARD_LOSS_LIMIT_UNDECIDABLE: cannot read {card_path}: {exc}")
        return failures, warnings, detail
    declared = parse_card_loss_limits(card_text)
    detail["declared"] = declared
    if not declared:
        return failures, warnings, detail

    inputs = parse_numeric_inputs(source.code)
    detail["numeric_inputs"] = inputs
    daily = {
        name: value
        for name, value in inputs.items()
        if re.search(r"daily", name, re.IGNORECASE)
        and re.search(r"(?:loss|drawdown|dd|hard)", name, re.IGNORECASE)
        and re.search(r"(?:halt|limit|stop)", name, re.IGNORECASE)
    }
    total = {
        name: value
        for name, value in inputs.items()
        if re.search(r"(?:total|overall)", name, re.IGNORECASE)
        and re.search(r"(?:loss|drawdown|dd)", name, re.IGNORECASE)
        and re.search(r"(?:halt|limit|stop)", name, re.IGNORECASE)
    }

    for contract, expected in declared.items():
        candidates = total if contract == "total_drawdown_stop" else daily
        matching = [name for name, value in candidates.items() if abs(value - expected) <= 1e-9]
        wired = [name for name in matching if len(re.findall(rf"\b{re.escape(name)}\b", source.code)) > 1]
        if not matching:
            rendered = ",".join(f"{name}={value:g}" for name, value in sorted(candidates.items())) or "none"
            failures.append(
                "EA_CARD_LOSS_LIMIT_MISMATCH: "
                f"{source.path.name} card {contract}={expected:g}% but matching input is absent; candidates={rendered}."
            )
        elif not wired:
            failures.append(
                "EA_CARD_LOSS_LIMIT_UNWIRED: "
                f"{source.path.name} declares {contract}={expected:g}% in input {matching[0]} but never consumes that input."
            )
    return failures, warnings, detail


def card_has_gmt_window(card_text: str) -> bool:
    for line in card_text.splitlines():
        if re.search(r"\b(?:GMT|UTC)\b", line, re.IGNORECASE) and re.search(r"\b\d{1,2}:\d{2}\b", line):
            return True
    return False


def check_broker_time_window(source: SourceFile, card_path: Path | None) -> tuple[list[str], list[str], dict]:
    detail = {"card_path": str(card_path) if card_path else None, "card_gmt_window": False}
    if card_path is None or not card_path.is_file():
        return [], [
            f"EA_BROKER_TIME_WINDOW_UNDECIDABLE: {source.path.name} has no unique card; GMT/session intent was not guessed."
        ], detail
    try:
        card_text = read_text_compatible(card_path)
    except (OSError, UnicodeError) as exc:
        return [], [f"EA_BROKER_TIME_WINDOW_UNDECIDABLE: cannot read {card_path}: {exc}"], detail
    detail["card_gmt_window"] = card_has_gmt_window(card_text)
    if not detail["card_gmt_window"]:
        return [], [], detail

    converter = re.search(
        r"\b(?:QM_BrokerToUTC|QM_BrokerToGMT|TimeGMT|[A-Za-z0-9_]*Broker[A-Za-z0-9_]*(?:UTC|GMT)|"
        r"[A-Za-z0-9_]*(?:UTC|GMT)[A-Za-z0-9_]*Broker[A-Za-z0-9_]*)\s*\(",
        source.code,
        re.IGNORECASE,
    )
    override = re.search(r"build-gate-allowed\s*:\s*broker-time-window", source.raw, re.IGNORECASE)
    raw_clock = re.search(r"\b(?:TimeCurrent|iTime)\s*\(", source.code)
    hour_logic = re.search(r"(?:\.hour\b|\bhhmm\b|Hhmm|TimeHour\s*\()", source.code, re.IGNORECASE)
    detail.update(
        {
            "converter_present": bool(converter),
            "documented_override": bool(override),
            "raw_broker_clock_present": bool(raw_clock),
            "hour_logic_present": bool(hour_logic),
        }
    )
    if converter:
        return [], [], detail
    if override:
        return [], [
            f"EA_BROKER_TIME_WINDOW_OVERRIDE: {source.path.name} uses the documented broker-time-window override; reviewer sign-off remains required."
        ], detail
    if raw_clock and hour_logic:
        return [
            "EA_BROKER_TIME_USED_FOR_GMT_WINDOW: "
            f"{source.path.name} has a card-declared GMT/UTC clock window but compares raw TimeCurrent/iTime hours without QM_BrokerToUTC or a documented equivalent."
        ], [], detail
    return [], [
        f"EA_BROKER_TIME_WINDOW_UNDECIDABLE: {source.path.name} card declares a GMT/UTC window but the static checker found no mechanically classifiable clock comparison."
    ], detail


def find_card(repo_root: Path, ea_label: str) -> Path | None:
    exact_candidates = [
        repo_root / "strategy-seeds" / "cards" / f"{ea_label}.md",
        Path(r"D:\QM\strategy_farm\artifacts\cards_approved") / f"{ea_label}.md",
    ]
    for candidate in exact_candidates:
        if candidate.is_file():
            return candidate.resolve()
    match = re.match(r"QM5_(\d+)", ea_label, re.IGNORECASE)
    if not match:
        return None
    ea_prefix = f"QM5_{match.group(1)}_"
    candidates: list[Path] = []
    for root in (repo_root / "strategy-seeds" / "cards", Path(r"D:\QM\strategy_farm\artifacts\cards_approved")):
        if root.is_dir():
            candidates.extend(root.glob(f"{ea_prefix}*.md"))
    unique = sorted({candidate.resolve() for candidate in candidates})
    return unique[0] if len(unique) == 1 else None


def analyze_file(source_path: Path, card_path: Path | None) -> dict:
    raw = read_text_compatible(source_path)
    source = SourceFile(source_path.resolve(), raw, strip_comments_preserve_lines(raw))
    failures: list[str] = []
    warnings: list[str] = []
    check_details: dict[str, dict] = {}

    pip_failures = check_pip_double_conversion(source)
    failures.extend(pip_failures)
    check_details["D3_pip_double_conversion"] = {"failures": len(pip_failures)}

    management_failures = check_management_reachability(source)
    failures.extend(management_failures)
    check_details["D4_management_reachability"] = {"failures": len(management_failures)}

    warmup_failures = check_bars_calculated_first(source)
    failures.extend(warmup_failures)
    check_details["D6_indicator_warmup_reachability"] = {
        "failures": len(warmup_failures)
    }

    loss_failures, loss_warnings, loss_detail = check_loss_limit_contract(source, card_path)
    failures.extend(loss_failures)
    warnings.extend(loss_warnings)
    check_details["D2_loss_limit_contract"] = {
        "failures": len(loss_failures),
        "warnings": len(loss_warnings),
        **loss_detail,
    }

    time_failures, time_warnings, time_detail = check_broker_time_window(source, card_path)
    failures.extend(time_failures)
    warnings.extend(time_warnings)
    check_details["D5_broker_time_window"] = {
        "failures": len(time_failures),
        "warnings": len(time_warnings),
        **time_detail,
    }
    return {
        "source_path": str(source.path),
        "card_path": str(card_path) if card_path else None,
        "failures": failures,
        "warnings": warnings,
        "checks": check_details,
    }


def analyze(repo_root: Path, ea_label: str | None = None) -> dict:
    ea_root = repo_root / "framework" / "EAs"
    directories = [ea_root / ea_label] if ea_label else sorted(path for path in ea_root.iterdir() if path.is_dir())
    rows: list[dict] = []
    failures: list[str] = []
    warnings: list[str] = []
    for directory in directories:
        label = directory.name
        card = find_card(repo_root, label)
        for source in sorted(directory.glob("*.mq5")):
            row = analyze_file(source, card)
            rows.append(row)
            failures.extend(row["failures"])
            warnings.extend(row["warnings"])
    return {
        "schema": SCHEMA,
        "repo_root": str(repo_root.resolve()),
        "ea_label": ea_label,
        "files_scanned": len(rows),
        "failures": failures,
        "warnings": warnings,
        "rows": rows,
        "false_positive_policy": {
            "D2": "FAIL only for explicit labeled card percentages; missing/ambiguous card is WARN",
            "D3": "FAIL only for literal x10 inside known pip-native helper arguments",
            "D4": "FAIL only when an early-return condition is mechanically tied to open-position state",
            "D5": "FAIL only when the card declares a GMT/UTC clock window and source uses raw broker-hour logic without a recognized/documented conversion",
            "D6": "FAIL on parsed EA call sites for raw BarsCalculated; comments and quoted literals are excluded and framework warm-up helpers are required",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True, type=Path)
    parser.add_argument("--ea-label")
    args = parser.parse_args()
    payload = analyze(args.repo_root.resolve(), args.ea_label)
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
