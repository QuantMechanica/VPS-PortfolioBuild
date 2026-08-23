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
import csv
import json
import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Iterable


SCHEMA = "qm.build-gate-hardening/v1"
PIP_HELPER_ARGUMENTS = {
    "QM_StopRulesPipsToPriceDistance": (1,),
    "QM_TM_MoveToBreakEven": (1, 2),
}
SYMBOL_TOKEN = re.compile(
    r"(?i)(?<![A-Z0-9])([A-Z0-9]+\.DWX)(?![A-Z0-9.])"
)
CURRENT_MAGIC_STATUSES = {"active", "reserved"}
TIMEFRAME_MINUTES = {
    "M1": 1,
    "M5": 5,
    "M15": 15,
    "M30": 30,
    "H1": 60,
    "H4": 240,
    "D1": 1440,
}
NEWS_TEMPORAL_WINDOWS: dict[str, tuple[int | None, int | None]] = {
    "QM_NEWS_TEMPORAL_OFF": (0, 0),
    "QM_NEWS_TEMPORAL_PRE30": (30, 0),
    "QM_NEWS_TEMPORAL_PRE60": (60, 0),
    "QM_NEWS_TEMPORAL_PRE30_POST30": (30, 30),
    "QM_NEWS_TEMPORAL_PRE60_POST60": (60, 60),
    "QM_NEWS_TEMPORAL_SKIP_DAY": (None, None),
    "QM_NEWS_TEMPORAL_CLOSE_ALL_PRE": (30, 0),
}

# These decisions are deliberately part of the machine-readable report.  A
# static checker must not pretend that prose similarity proves data lineage or
# restart recovery.  The other five classes below have narrow, auditable source
# shapes and therefore admit fail-only-on-proof predicates.
SEMANTIC_AUTOMATION_SCOPE = {
    "D12_invented_inputs_or_proxies": {
        "mechanizable": False,
        "missing_card_declaration": (
            "required_data_inputs[] with canonical identifier, source kind, "
            "point-in-time/as-of lag, allowed transforms, and proxy policy"
        ),
    },
    "D13_pending_entry_type": {
        "mechanizable": True,
        "predicate": "explicit card BUY/SELL stop contract versus executable order-type assignments",
    },
    "D14_directional_series_order": {
        "mechanizable": True,
        "predicate": "explicit SMA rising/falling contract versus proven shift-1/shift-2 ordering",
    },
    "D15_news_entry_contract": {
        "mechanizable": True,
        "predicate": "explicit bar-based news window and entry-only placement versus literal source configuration",
    },
    "D16_restart_safe_management": {
        "mechanizable": False,
        "missing_card_declaration": (
            "restart_state_contract[] with required state, durable source, reconstruction trigger, "
            "idempotency invariant, and fail-closed fallback"
        ),
    },
    "D17_authorized_universe": {
        "mechanizable": True,
        "predicate": "explicit card target_symbols versus exact current magic/setfile observations",
    },
    "D18_deterministic_zero_trade_ordering": {
        "mechanizable": True,
        "predicate": "proven descending shift append followed by an impossible later-index ordering guard",
        "scope": "narrow proof only; general zero-trade reachability remains review-only",
    },
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


def normalize_expression(expression: str) -> str:
    """Return a whitespace-insensitive expression used only for exact proofs."""
    return re.sub(r"\s+", "", expression).strip("()")


def brace_depth(text: str, stop: int) -> int:
    """Return lexical brace depth immediately before ``stop``."""
    depth = 0
    for char in text[:stop]:
        if char == "{":
            depth += 1
        elif char == "}":
            depth = max(0, depth - 1)
    return depth


def check_mae_hook(source: SourceFile) -> list[str]:
    """Require the framework MAE lifecycle hook in framework-managed OnTick."""
    code = strip_literals_preserve_lines(source.code)
    functions = function_bodies(code)
    on_tick = functions.get("OnTick")
    framework_managed = bool(
        re.search(
            r"\b(?:QM_FrameworkInit|QM_KillSwitchCheck|QM_FrameworkOnTradeTransaction)\s*\(",
            code,
        )
    )
    if not on_tick or not framework_managed:
        return []
    body_start, _, body = on_tick
    if re.search(r"\bQM_FrameworkTrackOpenPositionMae\s*\(\s*\)\s*;", body):
        return []
    return [
        "EA_Q08_MAE_HOOK_MISSING: "
        f"{source.path.name}:{line_number(code, body_start)} is framework-managed but "
        "OnTick does not call QM_FrameworkTrackOpenPositionMae(); the compatibility "
        "kill-switch fallback does not satisfy the explicit current-build MAE hook contract."
    ]


def _if_condition_ranges(body: str) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    for match in re.finditer(r"\bif\s*\(", body):
        opening = body.find("(", match.start(), match.end())
        closing = matching_delimiter(body, opening, "(", ")")
        if closing is not None:
            ranges.append((opening + 1, closing))
    return ranges


def check_duplicate_new_bar_entry_gate(source: SourceFile) -> list[str]:
    """Reject two same-key, top-level new-bar consumers before an entry call."""
    code = strip_literals_preserve_lines(source.code)
    on_tick = function_bodies(code).get("OnTick")
    if not on_tick:
        return []
    body_start, _, body = on_tick
    entry = re.search(
        r"\b(?:Strategy_[A-Za-z0-9_]*EntrySignal|QM_TM_OpenPosition|OrderSend|OrderSendAsync)\s*\(",
        body,
    )
    if not entry:
        return []
    conditions = _if_condition_ranges(body)
    grouped: dict[str, list[int]] = {}
    for _, offset, arguments in iter_calls(body[: entry.start()], ("QM_IsNewBar",)):
        in_condition = any(start <= offset < end for start, end in conditions)
        if not in_condition or brace_depth(body, offset) != 0:
            continue
        key = ",".join(normalize_expression(argument) for argument in arguments)
        if not key:
            key = "_Symbol,_Period"
        grouped.setdefault(key, []).append(offset)
    for key, offsets in grouped.items():
        if len(offsets) < 2:
            continue
        second = offsets[1]
        return [
            "EA_ENTRY_DOUBLE_NEW_BAR_GATE: "
            f"{source.path.name}:{line_number(code, body_start + second)} consumes "
            f"QM_IsNewBar({key}) a second time before entry; the first same-key call "
            "can consume the event and starve every entry. Cache one result and reuse it."
        ]
    return []


def check_trade_request_initialization(source: SourceFile) -> list[str]:
    """Reject bare trade-request locals that reach a canonical consumer."""
    code = strip_literals_preserve_lines(source.code)
    failures: list[str] = []
    functions = function_bodies(code)
    for _, (body_start, _, body) in functions.items():
        declaration = re.compile(
            r"\b(?P<type>MqlTradeRequest|QM_EntryRequest)\s+"
            r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*;"
        )
        for match in declaration.finditer(body):
            request_type = match.group("type")
            name = match.group("name")
            tail = body[match.end() :]
            if request_type == "MqlTradeRequest":
                consumer_pattern = rf"\b(?:OrderSend|OrderSendAsync)\s*\(\s*{re.escape(name)}\b"
            else:
                consumer_pattern = (
                    rf"\b(?P<callee>Strategy_[A-Za-z0-9_]*EntrySignal|QM_TM_OpenPosition)\s*"
                    rf"\(\s*{re.escape(name)}\b"
                )
            consumer = re.search(consumer_pattern, tail)
            if not consumer:
                continue
            before_use = tail[: consumer.start()]
            zeroed = re.search(
                rf"\bZeroMemory\s*\(\s*{re.escape(name)}\s*\)\s*;", before_use
            )
            aggregate_reset = re.search(
                rf"\b{re.escape(name)}\s*=\s*\{{\s*(?:0\s*)?\}}\s*;", before_use
            )
            if zeroed or aggregate_reset:
                continue
            missing_fields: list[str] = []
            if request_type == "QM_EntryRequest":
                required_fields = {
                    "type",
                    "price",
                    "sl",
                    "tp",
                    "reason",
                    "symbol_slot",
                    "expiration_seconds",
                }
                callee = consumer.groupdict().get("callee")
                initializer = functions.get(callee or "")
                if initializer is not None and callee != "QM_TM_OpenPosition":
                    initializer_body = initializer[2]
                    assigned_fields = set(
                        re.findall(
                            r"\b[A-Za-z_][A-Za-z0-9_]*\s*\.\s*"
                            r"([A-Za-z_][A-Za-z0-9_]*)\s*=",
                            initializer_body,
                        )
                    )
                    missing_fields = sorted(required_fields - assigned_fields)
                    if not missing_fields:
                        continue
            failures.append(
                "EA_TRADE_REQUEST_UNINITIALIZED: "
                f"{source.path.name}:{line_number(code, body_start + match.start())} "
                f"declares bare {request_type} {name} and sends it to a canonical consumer "
                "without ZeroMemory or aggregate zero-initialization"
                + (
                    f"; initializer omits {','.join(missing_fields)}."
                    if missing_fields
                    else "."
                )
            )
    return failures


@dataclass(frozen=True)
class LoopRange:
    variable: str
    operator: str
    bound: str
    body_start: int
    body_end: int


def loop_ranges(body: str) -> list[LoopRange]:
    loops: list[LoopRange] = []
    header = re.compile(
        r"\bfor\s*\(\s*(?:int\s+)?(?P<variable>[A-Za-z_][A-Za-z0-9_]*)\s*="
        r"[^;]+;\s*(?P=variable)\s*(?P<operator><=|<)\s*(?P<bound>[^;]+);"
        r"[^)]*\)\s*(?P<brace>\{)?"
    )
    for match in header.finditer(body):
        if match.group("brace"):
            opening = body.find("{", match.start(), match.end())
            closing = matching_delimiter(body, opening, "{", "}")
            if closing is None:
                continue
            loop_body_start = opening + 1
            loop_body_end = closing
        else:
            loop_body_start = match.end()
            loop_body_end = body.find(";", loop_body_start)
            if loop_body_end < 0:
                continue
        loops.append(
            LoopRange(
                variable=match.group("variable"),
                operator=match.group("operator"),
                bound=match.group("bound"),
                body_start=loop_body_start,
                body_end=loop_body_end,
            )
        )
    return loops


def _prior_bound_guard(
    body: str,
    access_offset: int,
    array_name: str,
    index: str,
    size_expression: str | None,
) -> bool:
    """Recognize explicit fail-fast bounds, without attempting symbolic algebra."""
    before = body[:access_offset]
    array_size = rf"ArraySize\s*\(\s*{re.escape(array_name)}\s*\)"
    index_pattern = re.escape(index)
    if re.search(
        rf"\bif\s*\([^)]*(?:{index_pattern}\s*(?:>=|>)\s*{array_size}|"
        rf"{array_size}\s*(?:<=|<)\s*{index_pattern})[^)]*\)\s*"
        r"(?:\{\s*)?(?:return|break|continue)\b",
        before,
        re.DOTALL,
    ):
        return True
    if size_expression:
        size = re.escape(normalize_expression(size_expression))
        compact = normalize_expression(before)
        if re.search(
            rf"if\([^)]*(?:{index_pattern}(?:>=|>){size}|{size}(?:<=|<){index_pattern})"
            r"[^)]*\)(?:\{)?(?:return|break|continue)",
            compact,
        ):
            return True
    return False


def _loop_proves_bound(
    body: str,
    access_offset: int,
    array_name: str,
    index: str,
    size_expression: str | None,
    loops: list[LoopRange],
) -> bool:
    normalized_index = normalize_expression(index)
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", normalized_index):
        return False
    candidates = [
        loop
        for loop in loops
        if loop.body_start <= access_offset < loop.body_end
        and loop.variable == normalized_index
    ]
    if not candidates:
        return False
    loop = max(candidates, key=lambda item: item.body_start)
    bound = normalize_expression(loop.bound)
    array_size = normalize_expression(f"ArraySize({array_name})")
    if loop.operator == "<" and bound == array_size:
        return True
    if size_expression:
        size = normalize_expression(size_expression)
        if loop.operator == "<" and bound == size:
            return True
        if loop.operator == "<" and (
            re.fullmatch(rf"{re.escape(bound)}\+[1-9][0-9]*", size)
            or re.fullmatch(rf"[1-9][0-9]*\+{re.escape(bound)}", size)
        ):
            return True
        if loop.operator == "<=" and bound in {f"{size}-1", f"({size})-1"}:
            return True
    return _prior_bound_guard(body, access_offset, array_name, normalized_index, size_expression)


def _literal_access_is_bounded(index: str, size_expression: str | None) -> bool:
    if size_expression is None:
        return False
    normalized_index = normalize_expression(index)
    normalized_size = normalize_expression(size_expression)
    if not normalized_index.isdigit():
        return False
    # Literal local-array accesses are outside this narrow loop-bound check.
    # CopyBuffer targets are handled separately below using the copied count.
    if not normalized_size.isdigit():
        return True
    return int(normalized_index) < int(normalized_size)


def check_indicator_buffer_bounds(source: SourceFile) -> list[str]:
    """Require a local mechanical bound proof for dynamic numeric buffers."""
    code = strip_literals_preserve_lines(source.code)
    failures: list[str] = []
    for _, (body_start, _, body) in function_bodies(code).items():
        loops = loop_ranges(body)
        const_ints = {
            name: expression
            for name, expression in re.findall(
                r"\bconst\s+int\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;]+);",
                body,
            )
        }
        declarations = re.findall(
            r"\b(?:double|float|int|long)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\[\s*\]\s*;",
            body,
        )
        resize_sizes: dict[str, str] = {}
        for name in declarations:
            resize = re.search(
                rf"\bArrayResize\s*\(\s*{re.escape(name)}\s*,\s*([^,;)]+)\s*\)",
                body,
            )
            if resize:
                resize_sizes[name] = resize.group(1)

        for name, size_expression in resize_sizes.items():
            access_pattern = re.compile(
                rf"\b{re.escape(name)}\s*\[\s*(?P<index>[^\]]+)\s*\]"
            )
            resize_call = re.search(
                rf"\bArrayResize\s*\(\s*{re.escape(name)}\s*,", body
            )
            resize_offset = resize_call.start() if resize_call else -1
            for access in access_pattern.finditer(body):
                if access.start() <= resize_offset:
                    continue
                index = access.group("index")
                if _literal_access_is_bounded(index, size_expression):
                    continue
                if not re.fullmatch(
                    r"[A-Za-z_][A-Za-z0-9_]*", normalize_expression(index)
                ):
                    continue
                normalized_size = normalize_expression(size_expression)
                resolved_size = const_ints.get(normalized_size)
                size_proofs = [size_expression]
                if resolved_size and normalize_expression(resolved_size) != normalized_size:
                    size_proofs.append(resolved_size)
                if any(
                    _loop_proves_bound(
                        body,
                        access.start(),
                        name,
                        index,
                        size_proof,
                        loops,
                    )
                    for size_proof in size_proofs
                ):
                    continue
                if any(
                    _prior_bound_guard(
                        body,
                        access.start(),
                        name,
                        normalize_expression(index),
                        size_proof,
                    )
                    for size_proof in size_proofs
                ):
                    continue
                failures.append(
                    "EA_INDICATOR_BUFFER_UNBOUNDED: "
                    f"{source.path.name}:{line_number(code, body_start + access.start())} "
                    f"accesses dynamic numeric buffer {name}[{normalize_expression(index)}] "
                    f"without a loop bound tied to {normalize_expression(size_expression)} "
                    "or an explicit ArraySize guard."
                )
                break

        for _, call_offset, arguments in iter_calls(body, ("CopyBuffer",)):
            if not arguments:
                continue
            target = normalize_expression(arguments[-1])
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", target):
                continue
            statement_start = max(body.rfind(";", 0, call_offset), body.rfind("{", 0, call_offset)) + 1
            prefix = body[statement_start:call_offset]
            assigned = re.search(
                r"(?:const\s+)?int\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*$", prefix
            )
            copied_name = assigned.group(1) if assigned else None
            access_pattern = re.compile(
                rf"\b{re.escape(target)}\s*\[\s*(?P<index>[^\]]+)\s*\]"
            )
            access = next(
                (match for match in access_pattern.finditer(body) if match.start() > call_offset),
                None,
            )
            if access is None:
                continue
            index = normalize_expression(access.group("index"))
            if _loop_proves_bound(
                body,
                access.start(),
                target,
                index,
                copied_name,
                loops,
            ):
                continue
            if _prior_bound_guard(body, access.start(), target, index, copied_name):
                continue
            if copied_name and index.isdigit():
                needed = int(index) + 1
                before_access = body[call_offset:access.start()]
                if re.search(
                    rf"if\s*\(\s*{re.escape(copied_name)}\s*<\s*{needed}\s*\)"
                    r"\s*(?:\{\s*)?return\b",
                    before_access,
                ):
                    continue
            failures.append(
                "EA_INDICATOR_BUFFER_UNBOUNDED: "
                f"{source.path.name}:{line_number(code, body_start + access.start())} "
                f"accesses CopyBuffer target {target}[{index}] without checking the "
                "CopyBuffer result or ArraySize first."
            )
    return failures


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


@lru_cache(maxsize=4096)
def _card_text(card_path: Path | None) -> tuple[str | None, str | None]:
    if card_path is None or not card_path.is_file():
        return None, "card missing"
    try:
        return read_text_compatible(card_path), None
    except (OSError, UnicodeError) as exc:
        return None, f"card unreadable: {exc}"


def markdown_section(text: str, heading: str) -> str:
    match = re.search(rf"(?im)^###\s+{re.escape(heading)}\s*$", text)
    if match is None:
        return ""
    end = re.search(r"(?m)^#{1,3}\s+", text[match.end() :])
    stop = match.end() + end.start() if end else len(text)
    return text[match.end() : stop]


def card_entry_contract_text(card_text: str) -> str:
    """Return only card prose that explicitly owns entry semantics."""
    pieces = [markdown_section(card_text, "Entry")]
    pieces.extend(
        match.group(0)
        for match in re.finditer(
            r"(?ims)^\s*-\s+\*\*[^*\r\n]*entry[^*\r\n]*\*\*.*?"
            r"(?=^\s*-\s+\*\*|^#{1,3}\s+|\Z)",
            card_text,
        )
    )
    return "\n".join(piece for piece in pieces if piece)


def parse_card_pending_order_types(card_text: str) -> set[str]:
    entry = card_entry_contract_text(card_text)
    normalized = entry.replace("‑", "-").replace("–", "-").replace("—", "-")
    expected: set[str] = set()
    if re.search(r"(?i)\bbuy[ -]?stop\b", normalized):
        expected.add("BUY_STOP")
    if re.search(r"(?i)\bsell[ -]?stop\b", normalized):
        expected.add("SELL_STOP")
    if re.search(r"(?i)\boco\b", normalized) and re.search(
        r"(?i)\bstop\s+entr(?:y|ies)\b", normalized
    ):
        expected.update({"BUY_STOP", "SELL_STOP"})
    return expected


def check_card_pending_order_type(
    source: SourceFile, card_path: Path | None
) -> tuple[list[str], list[str], dict]:
    """D13: compare literal card stop-order types to executable assignments."""
    card_text, card_error = _card_text(card_path)
    if card_text is None:
        warning = (
            f"EA_CARD_PENDING_ORDER_UNDECIDABLE: {source.path.name} {card_error}; "
            "no pending-order contract was inferred."
        )
        return [], [warning], {"card_error": card_error, "expected": []}

    expected = parse_card_pending_order_types(card_text)
    lexical = strip_literals_preserve_lines(source.code)
    implemented: set[str] = set()
    evidence: list[dict[str, object]] = []
    for order_type in sorted(expected):
        assignment = re.search(
            rf"(?i)\.[ \t]*type\s*=\s*(?:QM_|ORDER_TYPE_){order_type}\b",
            lexical,
        )
        method = re.search(
            rf"(?i)\b{'BuyStop' if order_type == 'BUY_STOP' else 'SellStop'}\s*\(",
            lexical,
        )
        match = assignment or method
        if match is not None:
            implemented.add(order_type)
            evidence.append(
                {
                    "type": order_type,
                    "line": line_number(lexical, match.start()),
                }
            )

    failures = [
        "EA_CARD_PENDING_ORDER_TYPE_MISMATCH: "
        f"{source.path.name} card explicitly requires {order_type}, but no executable "
        f"{order_type} assignment/call is present; a market request is not equivalent."
        for order_type in sorted(expected - implemented)
    ]
    return failures, [], {
        "card_path": str(card_path),
        "expected": sorted(expected),
        "implemented": sorted(implemented),
        "evidence": evidence,
    }


def parse_card_sma_directions(card_text: str) -> set[str]:
    requirements: set[str] = set()
    for paragraph in re.split(r"\r?\n\s*\r?\n", card_text):
        if not re.search(r"(?i)\bSMA\b", paragraph):
            continue
        if re.search(r"(?i)\brising\b", paragraph):
            requirements.add("RISING")
        if re.search(r"(?i)\bfalling\b", paragraph):
            requirements.add("FALLING")
    return requirements


def _scalar_sma_shift_evidence(code: str) -> list[dict[str, object]]:
    """Recognize real shift-1/shift-2 QM_SMA pairs without guessing aliases."""
    calls: dict[tuple[str, ...], dict[int, tuple[str, int]]] = {}
    for _, offset, arguments in iter_calls(code, ("QM_SMA",)):
        if len(arguments) < 2 or arguments[-1].strip() not in {"1", "2"}:
            continue
        prefix = code[max(0, offset - 100) : offset]
        assignment = re.search(
            r"(?:const\s+)?double\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*$", prefix
        )
        if assignment is None:
            continue
        key = tuple(normalize_expression(argument) for argument in arguments[:-1])
        calls.setdefault(key, {})[int(arguments[-1].strip())] = (
            assignment.group(1),
            offset,
        )

    evidence: list[dict[str, object]] = []
    for pair in calls.values():
        if 1 not in pair or 2 not in pair:
            continue
        newer, newer_offset = pair[1]
        older, _ = pair[2]
        for direction, operator in (("RISING", r">=?"), ("FALLING", r"<=?")):
            comparison = re.search(
                rf"\b{re.escape(newer)}\s*{operator}\s*{re.escape(older)}\b", code
            )
            if comparison is not None:
                evidence.append(
                    {
                        "direction": direction,
                        "newer": newer,
                        "older": older,
                        "line": line_number(code, comparison.start()),
                        "reader_line": line_number(code, newer_offset),
                    }
                )
    return evidence


def check_card_sma_direction(
    source: SourceFile, card_path: Path | None
) -> tuple[list[str], list[str], dict]:
    """D14: reject only a proven oldest-first CopyBuffer sign inversion."""
    card_text, card_error = _card_text(card_path)
    if card_text is None:
        return [], [], {"card_error": card_error, "requirements": []}
    requirements = parse_card_sma_directions(card_text)
    if not requirements:
        return [], [], {"card_path": str(card_path), "requirements": []}

    lexical = strip_literals_preserve_lines(source.code)
    raw_pairs: list[dict[str, object]] = []
    failures: list[str] = []
    satisfied = _scalar_sma_shift_evidence(lexical)
    copy_pattern = re.compile(
        r"\bCopyBuffer\s*\(\s*[^,;]+,\s*[^,;]+,\s*1\s*,\s*2\s*,\s*"
        r"(?P<buffer>[A-Za-z_][A-Za-z0-9_]*)\s*\)",
        re.DOTALL,
    )
    for copied in copy_pattern.finditer(lexical):
        buffer = copied.group("buffer")
        if re.search(
            rf"\bArraySetAsSeries\s*\(\s*{re.escape(buffer)}\s*,\s*true\s*\)",
            lexical,
        ):
            # Logical indexing of an explicitly series-marked dynamic array is
            # outside this oldest-first proof.  Leave it to review.
            continue
        row: dict[str, object] = {
            "buffer": buffer,
            "copy_line": line_number(lexical, copied.start()),
        }
        for direction, operator, inverse_operator in (
            ("RISING", r">=?", r">=?"),
            ("FALLING", r"<=?", r"<=?"),
        ):
            correct = re.search(
                rf"\b{re.escape(buffer)}\s*\[\s*1\s*\]\s*{operator}\s*"
                rf"{re.escape(buffer)}\s*\[\s*0\s*\]",
                lexical,
            )
            inverted = re.search(
                rf"\b{re.escape(buffer)}\s*\[\s*0\s*\]\s*{inverse_operator}\s*"
                rf"{re.escape(buffer)}\s*\[\s*1\s*\]",
                lexical,
            )
            if direction in requirements and correct is not None:
                satisfied.append(
                    {
                        "direction": direction,
                        "buffer": buffer,
                        "line": line_number(lexical, correct.start()),
                    }
                )
            if direction in requirements and inverted is not None:
                failure_line = line_number(lexical, inverted.start())
                failures.append(
                    "EA_CARD_SMA_DIRECTION_INVERTED: "
                    f"{source.path.name}:{failure_line} tests {buffer}[0] against "
                    f"{buffer}[1] for card-declared {direction.lower()} SMA, but "
                    "CopyBuffer(start=1,count=2) stores older shift 2 at index 0 and "
                    "newer shift 1 at index 1."
                )
            row[direction.lower()] = {
                "correct_line": line_number(lexical, correct.start()) if correct else None,
                "inverted_line": line_number(lexical, inverted.start()) if inverted else None,
            }
        raw_pairs.append(row)

    satisfied_directions = {
        str(item["direction"]) for item in satisfied if "direction" in item
    }
    inverted_directions = {
        "RISING" if "rising" in failure else "FALLING"
        for failure in failures
    }
    undecidable = sorted(requirements - satisfied_directions - inverted_directions)
    warnings = (
        [
            "EA_CARD_SMA_DIRECTION_UNDECIDABLE: "
            f"{source.path.name} card declares {','.join(undecidable)}, but the checker "
            "found neither a proven shift-ordered comparison nor a proven inversion."
        ]
        if undecidable
        else []
    )
    return failures, warnings, {
        "card_path": str(card_path),
        "requirements": sorted(requirements),
        "raw_copy_pairs": raw_pairs,
        "satisfied_evidence": satisfied,
        "undecidable": undecidable,
    }


def parse_card_news_contract(card_text: str) -> dict[str, object] | None:
    for paragraph in re.split(r"\r?\n\s*\r?\n", card_text):
        if not re.search(r"(?i)high[- ]impact\s+news", paragraph):
            continue
        if not re.search(r"(?i)\bentr(?:y|ies)\b", paragraph):
            continue
        window = re.search(
            r"(?i)(?:\bwithin\s+(?:±|\+/-)?\s*|(?:±|\+/-)\s*)"
            r"(?P<count>\d+)\s*(?P<timeframe>M1|M5|M15|M30|H1|H4|D1)\s*bars?",
            paragraph,
        )
        if window is None:
            continue
        count = int(window.group("count"))
        timeframe = window.group("timeframe").upper()
        return {
            "count": count,
            "timeframe": timeframe,
            "before_minutes": count * TIMEFRAME_MINUTES[timeframe],
            "after_minutes": count * TIMEFRAME_MINUTES[timeframe],
            "entry_only": bool(
                re.search(r"(?i)\b(?:skip\s+entry|no\s+new\s+entr(?:y|ies))\b", paragraph)
            ),
            "excerpt": " ".join(paragraph.split()),
        }
    return None


def _literal_nonnegative_int(expression: str) -> int | None:
    normalized = re.sub(r"\([A-Za-z_][A-Za-z0-9_]*\)", "", expression).strip()
    match = re.fullmatch(r"\+?(\d+)(?:\.0+)?", normalized)
    return int(match.group(1)) if match else None


def _news_temporal_default(code: str) -> tuple[str | None, int | None]:
    match = re.search(
        r"\binput\s+QM_NewsTemporalMode\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*"
        r"(?P<mode>QM_NEWS_TEMPORAL_[A-Z0-9_]+)\s*;",
        code,
    )
    if match is None:
        return None, None
    return match.group("mode"), match.start("mode")


def check_card_news_contract(
    source: SourceFile, card_path: Path | None
) -> tuple[list[str], list[str], dict]:
    """D15: prove literal duration and entry-only placement when declared."""
    card_text, card_error = _card_text(card_path)
    if card_text is None:
        return [], [], {"card_error": card_error, "contract": None}
    contract = parse_card_news_contract(card_text)
    if contract is None:
        return [], [], {"card_path": str(card_path), "contract": None}

    lexical = strip_literals_preserve_lines(source.code)
    functions = function_bodies(lexical)
    entry_ranges = [
        (start, end)
        for name, (start, end, _) in functions.items()
        if name.startswith("Strategy_Entry")
    ]
    windows: list[dict[str, object]] = []
    for _, offset, arguments in iter_calls(lexical, ("QM_NewsInWindow",)):
        if len(arguments) < 4 or not any(start <= offset <= end for start, end in entry_ranges):
            continue
        before = _literal_nonnegative_int(arguments[2])
        after = _literal_nonnegative_int(arguments[3])
        if before is None or after is None:
            continue
        windows.append(
            {
                "source": "entry_call",
                "before_minutes": before,
                "after_minutes": after,
                "line": line_number(lexical, offset),
            }
        )

    mode, mode_offset = _news_temporal_default(lexical)
    mode_window = NEWS_TEMPORAL_WINDOWS.get(mode) if mode else None
    if mode_window and mode_window != (0, 0):
        windows.append(
            {
                "source": "temporal_default",
                "mode": mode,
                "before_minutes": mode_window[0],
                "after_minutes": mode_window[1],
                "line": line_number(lexical, mode_offset or 0),
            }
        )

    failures: list[str] = []
    warnings: list[str] = []
    expected_before = int(contract["before_minutes"])
    expected_after = int(contract["after_minutes"])
    if any(item["before_minutes"] is None for item in windows):
        failures.append(
            "EA_CARD_NEWS_WINDOW_MISMATCH: "
            f"{source.path.name} card requires ±{expected_before} minutes, but the "
            "source default is whole-day blocking rather than that literal window."
        )
    elif windows:
        effective_before = max(int(item["before_minutes"]) for item in windows)
        effective_after = max(int(item["after_minutes"]) for item in windows)
        if (effective_before, effective_after) != (expected_before, expected_after):
            failures.append(
                "EA_CARD_NEWS_WINDOW_MISMATCH: "
                f"{source.path.name} card requires {expected_before}/{expected_after} "
                f"minutes pre/post, but literal source configuration proves "
                f"{effective_before}/{effective_after}."
            )
    elif mode == "QM_NEWS_TEMPORAL_OFF":
        failures.append(
            "EA_CARD_NEWS_WINDOW_MISMATCH: "
            f"{source.path.name} card requires {expected_before}/{expected_after} minutes "
            "pre/post, but the temporal default is OFF and no literal entry-side "
            "QM_NewsInWindow contract is present."
        )
    else:
        warnings.append(
            "EA_CARD_NEWS_WINDOW_UNDECIDABLE: "
            f"{source.path.name} card requires {expected_before}/{expected_after} minutes "
            "pre/post, but source configuration is not a literal supported shape."
        )

    placement: dict[str, object] = {"checked": False}
    on_tick = functions.get("OnTick")
    temporal_active = bool(mode and mode != "QM_NEWS_TEMPORAL_OFF")
    if contract["entry_only"] and on_tick:
        body_start, _, body = on_tick
        anchors = list(
            re.finditer(
                r"\b(?:Strategy_[A-Za-z0-9_]*Manage[A-Za-z0-9_]*|"
                r"Strategy_[A-Za-z0-9_]*Exit[A-Za-z0-9_]*)\s*\(",
                body,
            )
        )
        if anchors:
            management_start = min(anchor.start() for anchor in anchors)
            placement = {
                "checked": True,
                "management_line": line_number(lexical, body_start + management_start),
                "temporal_active": temporal_active,
            }
            blocking_offset: int | None = None
            for offset, condition in iter_early_return_conditions(body, management_start):
                if "QM_NewsInWindow" in condition:
                    blocking_offset = offset
                    break
            if blocking_offset is None and temporal_active:
                for call in re.finditer(r"\bQM_NewsAllowsTrade2?\s*\(", body[:management_start]):
                    prefix = body[max(0, call.start() - 100) : call.start()]
                    assigned = re.search(
                        r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*$", prefix
                    )
                    if assigned is None:
                        continue
                    variable = assigned.group(1)
                    guard = re.search(
                        rf"\bif\s*\(\s*!\s*{re.escape(variable)}\s*\)\s*"
                        r"(?:\{\s*)?return\s*;",
                        body[call.end() : management_start],
                    )
                    if guard is not None:
                        blocking_offset = call.end() + guard.start()
                        break
            if blocking_offset is not None:
                failure_line = line_number(lexical, body_start + blocking_offset)
                failures.append(
                    "EA_CARD_NEWS_BLOCKS_MANAGEMENT: "
                    f"{source.path.name}:{failure_line} enforces an entry-only card "
                    "news blackout before position management/exit; protective handling "
                    "must remain reachable during the blackout."
                )
                placement["blocking_line"] = failure_line

    return failures, warnings, {
        "card_path": str(card_path),
        "contract": contract,
        "temporal_default": mode,
        "literal_windows": windows,
        "placement": placement,
    }


def check_deterministic_zero_trade_ordering(source: SourceFile) -> tuple[list[str], dict]:
    """D18: prove one recurrent descending-append/impossible-guard shape."""
    lexical = strip_literals_preserve_lines(source.code)
    descending_arrays: dict[str, int] = {}
    producer_functions: dict[str, str] = {}
    for function_name, (body_start, _, body) in function_bodies(lexical).items():
        for loop in re.finditer(
            r"\bfor\s*\(\s*int\s+(?P<var>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
            r"(?P<initial>[^;]+);\s*(?P<condition>[^;]+);\s*(?P<step>[^)]+)\)",
            body,
        ):
            variable = loop.group("var")
            condition = normalize_expression(loop.group("condition"))
            step = normalize_expression(loop.group("step"))
            if not condition.startswith(f"{variable}>=") or step not in {
                f"--{variable}",
                f"{variable}--",
            }:
                continue
            brace = body.find("{", loop.end())
            if brace < 0:
                continue
            end = matching_delimiter(body, brace, "{", "}")
            if end is None:
                continue
            loop_body = body[brace + 1 : end]
            for assignment in re.finditer(
                rf"\b(?P<array>[A-Za-z_][A-Za-z0-9_]*)\s*\[\s*"
                r"[A-Za-z_][A-Za-z0-9_]*\s*\]\s*\.\s*shift\s*=\s*"
                rf"{re.escape(variable)}\s*;",
                loop_body,
            ):
                array = assignment.group("array")
                preceding = loop_body[: assignment.start()]
                if not re.search(
                    rf"\bArrayResize\s*\(\s*{re.escape(array)}\s*,[^;]+\+\s*1\s*\)",
                    preceding,
                ):
                    continue
                if re.search(
                    rf"\bArrayReverse\s*\(\s*{re.escape(array)}\s*\)", lexical
                ):
                    continue
                descending_arrays[array] = line_number(
                    lexical, body_start + loop.start()
                )
                producer_functions[array] = function_name

    # Propagate a proven by-reference output parameter to simple identifier
    # arguments at its call sites (for example low_pivots[] -> lows[]).  Do not
    # infer through expressions, returned objects, copies, or helper aliases.
    for parameter, function_name in list(producer_functions.items()):
        signature = re.search(
            rf"\b{re.escape(function_name)}\s*\((?P<parameters>[^)]*)\)\s*\{{",
            lexical,
        )
        if signature is None:
            continue
        parameters = split_arguments(signature.group("parameters"))
        parameter_index = next(
            (
                index
                for index, declaration in enumerate(parameters)
                if re.search(
                    rf"&\s*{re.escape(parameter)}\s*\[\s*\]", declaration
                )
            ),
            None,
        )
        if parameter_index is None:
            continue
        for _, _, arguments in iter_calls(lexical, (function_name,)):
            if parameter_index >= len(arguments):
                continue
            alias = arguments[parameter_index].strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", alias):
                continue
            descending_arrays.setdefault(alias, descending_arrays[parameter])

    failures: list[str] = []
    contradictions: list[dict[str, object]] = []
    for array, producer_line in sorted(descending_arrays.items()):
        consumer = re.compile(
            rf"\b(?:const\s+)?int\s+(?P<first_shift>[A-Za-z_]\w*)\s*=\s*"
            rf"{re.escape(array)}\s*\[\s*(?P<first_index>[A-Za-z_]\w*)\s*\]"
            r"\s*\.\s*shift\s*;.{0,1600}?"
            r"\bfor\s*\(\s*int\s+(?P<second_index>[A-Za-z_]\w*)\s*=\s*"
            r"(?P=first_index)\s*\+\s*1\s*;.{0,500}?"
            rf"\b(?:const\s+)?int\s+(?P<second_shift>[A-Za-z_]\w*)\s*=\s*"
            rf"{re.escape(array)}\s*\[\s*(?P=second_index)\s*\]\s*\.\s*shift\s*;"
            r".{0,500}?\bif\s*\(\s*(?P=second_shift)\s*<=\s*"
            r"(?P=first_shift)\s*\)\s*(?:\{\s*)?continue\s*;",
            re.DOTALL,
        ).search(lexical)
        if consumer is None:
            continue
        failure_line = line_number(lexical, consumer.start())
        contradictions.append(
            {
                "array": array,
                "producer_line": producer_line,
                "consumer_line": failure_line,
            }
        )
        failures.append(
            "EA_DETERMINISTIC_ZERO_TRADE_ORDERING: "
            f"{source.path.name}:{failure_line} consumes {array} as if later indices "
            "had larger shifts, but line "
            f"{producer_line} appends strictly descending shifts; the <= guard is "
            "therefore true for every later candidate and makes the nested entry path unreachable."
        )
    return failures, {
        "descending_shift_arrays": [
            {"array": array, "producer_line": line}
            for array, line in sorted(descending_arrays.items())
        ],
        "contradictions": contradictions,
    }


def parse_card_target_symbols(card_text: str) -> set[str]:
    """Extract only explicit front-matter or labeled target-symbol contracts."""
    def extract_card_symbols(text: str) -> set[str]:
        # A prose list commonly ends ``EURUSD.DWX.``; the terminal sentence
        # period is punctuation, not part of the broker symbol.
        return {
            match.group(1)
            for match in re.finditer(
                r"(?i)(?<![A-Z0-9])([A-Z0-9]+\.DWX)\b", text
            )
        }

    symbols: set[str] = set()
    front_matter = re.match(r"\A---\s*\r?\n(?P<body>.*?)\r?\n---", card_text, re.DOTALL)
    if front_matter:
        target = re.search(
            r"(?im)^target_symbols\s*:\s*\[(?P<symbols>[^\]]*)\]",
            front_matter.group("body"),
        )
        if target:
            symbols.update(extract_card_symbols(target.group("symbols")))

    lines = card_text.splitlines()
    for index, line in enumerate(lines):
        if not re.search(r"(?i)^\s*-?\s*(?:\*\*)?target symbols(?:\*\*)?\s*:", line):
            continue
        paragraph = [line]
        for continuation in lines[index + 1 :]:
            if not continuation.strip() or re.match(r"^\s*(?:-|#)", continuation):
                break
            if continuation[:1].isspace():
                paragraph.append(continuation)
                continue
            break
        symbols.update(extract_card_symbols("\n".join(paragraph)))
    return symbols


def load_dwx_symbol_matrix(path: Path) -> tuple[set[str], list[str], dict]:
    """Load the exact buildable-symbol namespace, failing closed on ambiguity."""
    failures: list[str] = []
    symbols: set[str] = set()
    casefold_symbols: dict[str, str] = {}
    detail: dict = {"path": str(path.resolve()), "symbols": []}
    if not path.is_file():
        failures.append(
            f"EA_DWX_SYMBOL_MATRIX_MISSING: canonical symbol matrix is missing: {path}."
        )
        detail.update({"valid": False, "symbol_count": 0})
        return symbols, failures, detail

    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fieldnames = set(reader.fieldnames or [])
            if "symbol" not in fieldnames:
                failures.append(
                    "EA_DWX_SYMBOL_MATRIX_SCHEMA_INVALID: "
                    f"{path} is missing required column 'symbol'."
                )
            else:
                for row in reader:
                    symbol = str(row.get("symbol") or "").strip()
                    if not symbol:
                        failures.append(
                            "EA_DWX_SYMBOL_MATRIX_ROW_INVALID: "
                            f"{path}:{reader.line_num} has an empty symbol."
                        )
                        continue
                    folded = symbol.casefold()
                    prior = casefold_symbols.get(folded)
                    if prior is not None:
                        failures.append(
                            "EA_DWX_SYMBOL_MATRIX_DUPLICATE: "
                            f"{path}:{reader.line_num} duplicates canonical symbol "
                            f"{prior!r} as {symbol!r}."
                        )
                        continue
                    casefold_symbols[folded] = symbol
                    symbols.add(symbol)
    except (OSError, UnicodeError, csv.Error) as exc:
        failures.append(f"EA_DWX_SYMBOL_MATRIX_UNREADABLE: cannot parse {path}: {exc}")

    detail.update(
        {
            "valid": not failures,
            "symbol_count": len(symbols),
            "symbols": sorted(symbols),
        }
    )
    return symbols, failures, detail


def load_magic_build_symbols(
    path: Path,
) -> tuple[dict[tuple[str, str], list[dict[str, str]]], list[str], dict]:
    """Index active/reserved magic rows by exact EA identity."""
    failures: list[str] = []
    by_build: dict[tuple[str, str], list[dict[str, str]]] = {}
    detail: dict = {"path": str(path.resolve())}
    if not path.is_file():
        failures.append(
            f"EA_MAGIC_REGISTRY_MISSING_FOR_SYMBOL_CHECK: magic registry is missing: {path}."
        )
        detail.update({"valid": False, "current_rows": 0, "builds": 0})
        return by_build, failures, detail

    required = {"ea_id", "ea_slug", "symbol_slot", "symbol", "status"}
    current_rows = 0
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fieldnames = set(reader.fieldnames or [])
            missing = sorted(required - fieldnames)
            if missing:
                failures.append(
                    "EA_MAGIC_REGISTRY_SCHEMA_INVALID_FOR_SYMBOL_CHECK: "
                    f"{path} is missing required columns {','.join(missing)}."
                )
            else:
                for row in reader:
                    status = str(row.get("status") or "").strip().casefold()
                    if status not in CURRENT_MAGIC_STATUSES:
                        continue
                    ea_id = str(row.get("ea_id") or "").strip()
                    slug = str(row.get("ea_slug") or "").strip()
                    symbol = str(row.get("symbol") or "").strip()
                    slot = str(row.get("symbol_slot") or "").strip()
                    if not ea_id or not slug or not symbol or not slot:
                        failures.append(
                            "EA_MAGIC_REGISTRY_ROW_INVALID_FOR_SYMBOL_CHECK: "
                            f"{path}:{reader.line_num} has an incomplete current row."
                        )
                        continue
                    by_build.setdefault((ea_id, slug), []).append(
                        {
                            "symbol": symbol,
                            "symbol_slot": slot,
                            "status": status,
                            "line": str(reader.line_num),
                        }
                    )
                    current_rows += 1
    except (OSError, UnicodeError, csv.Error) as exc:
        failures.append(
            f"EA_MAGIC_REGISTRY_UNREADABLE_FOR_SYMBOL_CHECK: cannot parse {path}: {exc}"
        )

    detail.update(
        {
            "valid": not failures,
            "current_rows": current_rows,
            "builds": len(by_build),
        }
    )
    return by_build, failures, detail


def extract_dwx_symbols(text: str) -> list[str]:
    return [match.group(1) for match in SYMBOL_TOKEN.finditer(text)]


def _symbol_failure_hint(symbol: str) -> str:
    if symbol.upper() in {"GER40.DWX", "DE30.DWX", "DAX40.DWX"}:
        return " The canonical DAX house symbol is GDAXI.DWX."
    return ""


def check_build_symbols(
    repo_root: Path,
    ea_dir: Path,
    matrix_symbols: set[str],
    matrix_valid: bool,
    magic_by_build: dict[tuple[str, str], list[dict[str, str]]],
    card_path: Path | None = None,
) -> dict:
    """D11/D17: prove registry validity and an explicit card universe."""
    failures: list[str] = []
    observations: dict[str, set[str]] = {}

    def observe(symbol: str, origin: str) -> None:
        observations.setdefault(symbol, set()).add(origin)

    for setfile in sorted(ea_dir.rglob("*.set")) if ea_dir.is_dir() else []:
        try:
            relative = setfile.resolve().relative_to(repo_root.resolve()).as_posix()
        except ValueError:
            relative = str(setfile.resolve())
        for symbol in extract_dwx_symbols(setfile.name):
            observe(symbol, f"setfile_name:{relative}")
        try:
            content = read_text_compatible(setfile)
        except (OSError, UnicodeError) as exc:
            failures.append(
                "EA_SYMBOL_SETFILE_UNREADABLE: "
                f"{relative} cannot be checked for symbols: {exc}"
            )
            continue
        for line_number_value, line in enumerate(content.splitlines(), start=1):
            for symbol in extract_dwx_symbols(line):
                observe(symbol, f"setfile_content:{relative}:{line_number_value}")

    identity = re.fullmatch(r"QM5_(\d+)_(.+)", ea_dir.name, re.IGNORECASE)
    if identity is None:
        failures.append(
            "EA_SYMBOL_BUILD_LABEL_INVALID: "
            f"{ea_dir.name!r} does not match QM5_<numeric-ea-id>_<slug>."
        )
        ea_id = None
        slug = None
    else:
        ea_id, slug = identity.group(1), identity.group(2)
        for row in magic_by_build.get((ea_id, slug), []):
            observe(
                row["symbol"],
                "magic_registry:"
                f"line={row['line']}:slot={row['symbol_slot']}:status={row['status']}",
            )

    rows: list[dict] = []
    matrix_casefold = {symbol.casefold(): symbol for symbol in matrix_symbols}
    for symbol in sorted(observations):
        exact_match = symbol in matrix_symbols if matrix_valid else None
        canonical_case = matrix_casefold.get(symbol.casefold()) if matrix_valid else None
        origins = sorted(observations[symbol])
        rows.append(
            {
                "symbol": symbol,
                "matrix_exact_match": exact_match,
                "canonical_case": canonical_case,
                "origins": origins,
            }
        )
        if matrix_valid and not exact_match:
            case_hint = (
                f" Exact canonical spelling is {canonical_case}."
                if canonical_case is not None
                else _symbol_failure_hint(symbol)
            )
            failures.append(
                "EA_SYMBOL_NOT_IN_DWX_MATRIX: "
                f"{ea_dir.name} uses {symbol} from {', '.join(origins)}, but it is not "
                f"an exact row in framework/registry/dwx_symbol_matrix.csv.{case_hint}"
            )

    card_symbols: set[str] = set()
    card_error: str | None = None
    card_text, card_error = _card_text(card_path)
    if card_text is not None:
        card_symbols = parse_card_target_symbols(card_text)
    for symbol in sorted(set(observations) - card_symbols if card_symbols else set()):
        origins = sorted(observations[symbol])
        failures.append(
            "EA_SYMBOL_NOT_IN_CARD_UNIVERSE: "
            f"{ea_dir.name} uses {symbol} from {', '.join(origins)}, but the explicit "
            f"card target_symbols contract contains only {', '.join(sorted(card_symbols))}."
        )

    return {
        "ea_label": ea_dir.name,
        "ea_id": ea_id,
        "slug": slug,
        "matrix_valid": matrix_valid,
        "symbols_observed": len(rows),
        "symbols": rows,
        "card_path": str(card_path) if card_path else None,
        "card_target_symbols": sorted(card_symbols),
        "card_error": card_error,
        "failures": failures,
    }


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

    mae_failures = check_mae_hook(source)
    failures.extend(mae_failures)
    check_details["D7_mae_hook"] = {"failures": len(mae_failures)}

    new_bar_failures = check_duplicate_new_bar_entry_gate(source)
    failures.extend(new_bar_failures)
    check_details["D8_duplicate_new_bar_entry_gate"] = {
        "failures": len(new_bar_failures)
    }

    request_failures = check_trade_request_initialization(source)
    failures.extend(request_failures)
    check_details["D9_trade_request_initialization"] = {
        "failures": len(request_failures)
    }

    buffer_failures = check_indicator_buffer_bounds(source)
    failures.extend(buffer_failures)
    check_details["D10_indicator_buffer_bounds"] = {
        "failures": len(buffer_failures)
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

    pending_failures, pending_warnings, pending_detail = check_card_pending_order_type(
        source, card_path
    )
    failures.extend(pending_failures)
    warnings.extend(pending_warnings)
    check_details["D13_pending_entry_type"] = {
        "failures": len(pending_failures),
        "warnings": len(pending_warnings),
        **pending_detail,
    }

    direction_failures, direction_warnings, direction_detail = check_card_sma_direction(
        source, card_path
    )
    failures.extend(direction_failures)
    warnings.extend(direction_warnings)
    check_details["D14_directional_series_order"] = {
        "failures": len(direction_failures),
        "warnings": len(direction_warnings),
        **direction_detail,
    }

    news_failures, news_warnings, news_detail = check_card_news_contract(
        source, card_path
    )
    failures.extend(news_failures)
    warnings.extend(news_warnings)
    check_details["D15_news_entry_contract"] = {
        "failures": len(news_failures),
        "warnings": len(news_warnings),
        **news_detail,
    }

    ordering_failures, ordering_detail = check_deterministic_zero_trade_ordering(source)
    failures.extend(ordering_failures)
    check_details["D18_deterministic_zero_trade_ordering"] = {
        "failures": len(ordering_failures),
        **ordering_detail,
    }

    check_details["D12_invented_inputs_or_proxies"] = SEMANTIC_AUTOMATION_SCOPE[
        "D12_invented_inputs_or_proxies"
    ]
    check_details["D16_restart_safe_management"] = SEMANTIC_AUTOMATION_SCOPE[
        "D16_restart_safe_management"
    ]
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
    matrix_symbols, matrix_failures, matrix_detail = load_dwx_symbol_matrix(
        repo_root / "framework" / "registry" / "dwx_symbol_matrix.csv"
    )
    magic_by_build, magic_failures, magic_detail = load_magic_build_symbols(
        repo_root / "framework" / "registry" / "magic_numbers.csv"
    )
    failures.extend(matrix_failures)
    failures.extend(magic_failures)
    build_symbol_checks: list[dict] = []
    for directory in directories:
        label = directory.name
        card = find_card(repo_root, label)
        for source in sorted(directory.glob("*.mq5")):
            row = analyze_file(source, card)
            rows.append(row)
            failures.extend(row["failures"])
            warnings.extend(row["warnings"])
        symbol_check = check_build_symbols(
            repo_root,
            directory,
            matrix_symbols,
            not matrix_failures,
            magic_by_build,
            card,
        )
        build_symbol_checks.append(symbol_check)
        failures.extend(symbol_check["failures"])
    return {
        "schema": SCHEMA,
        "repo_root": str(repo_root.resolve()),
        "ea_label": ea_label,
        "files_scanned": len(rows),
        "failures": failures,
        "warnings": warnings,
        "rows": rows,
        "registry_checks": {
            "dwx_symbol_matrix": matrix_detail,
            "magic_numbers": magic_detail,
        },
        "build_symbol_checks": build_symbol_checks,
        "semantic_automation_scope": SEMANTIC_AUTOMATION_SCOPE,
        "false_positive_policy": {
            "D2": "FAIL only for explicit labeled card percentages; missing/ambiguous card is WARN",
            "D3": "FAIL only for literal x10 inside known pip-native helper arguments",
            "D4": "FAIL only when an early-return condition is mechanically tied to open-position state",
            "D5": "FAIL only when the card declares a GMT/UTC clock window and source uses raw broker-hour logic without a recognized/documented conversion",
            "D6": "FAIL on parsed EA call sites for raw BarsCalculated; comments and quoted literals are excluded and framework warm-up helpers are required",
            "D7": "FAIL only for a framework-managed OnTick with no direct QM_FrameworkTrackOpenPositionMae call",
            "D8": "FAIL only for two same-key, top-level QM_IsNewBar conditions before a canonical entry call; different keys and cached results pass",
            "D9": "FAIL only when a bare MqlTradeRequest reaches OrderSend without zero-init, or a bare QM_EntryRequest reaches entry with neither zero-init nor a mechanically complete seven-field initializer",
            "D10": "FAIL only when a dynamic numeric/CopyBuffer target is indexed without a syntactically tied loop, CopyBuffer-result, resize-count, or ArraySize proof",
            "D11": "FAIL closed when either symbol registry is missing/malformed, a setfile cannot be read, the EA label is invalid, or any exact .DWX token observed in setfile names/content or current magic rows is absent from the exact dwx_symbol_matrix.csv namespace",
            "D12": "NOT AUTOMATED until cards declare canonical point-in-time data lineage, lag, transforms, and proxy policy",
            "D13": "FAIL only when an explicit Entry contract names BUY/SELL stop orders and the corresponding executable order-type assignment/call is absent",
            "D14": "FAIL only for an explicit card SMA direction and a proven CopyBuffer(start=1,count=2) oldest/newest comparison with the inverse sign; unclassified aliases WARN",
            "D15": "FAIL only for an explicit bar-based high-impact-news entry window with a literal mismatching source window, or a proven active news return before management/exit",
            "D16": "NOT AUTOMATED until cards declare required restart state, durable reconstruction sources, idempotency, and fail-closed fallback",
            "D17": "FAIL only when an exact current setfile/magic symbol is outside an explicit target_symbols/Target symbols card contract",
            "D18": "FAIL only for a proven strictly descending shift append followed by a later-index <= earlier-index continue guard; general reachability remains review-only",
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
