#!/usr/bin/env python3
"""Reproducibly identify pre-fix relative-host magic exposure.

The historical detector only searched each top-level ``.mq5`` file for a
``symbol_slot`` assignment. That over-counted EAs whose reachable EA-local
include assigns the slot (notably the shared MQL5-codebase rebuild helper).
This scanner expands only EA-local includes, removes comments/strings, and
classifies the request passed to the actual entry boundary.

Framework includes are deliberately not expanded: their implementation owns
the boundary being audited and must not be mistaken for EA-side wiring.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


SCHEMA = "qm.host-slot-magic-affected-set/v2"
EA_ID_RE = re.compile(r"^QM5_(\d+)")
INCLUDE_RE = re.compile(r'^\s*#include\s*["<]([^">]+)[">]', re.MULTILINE)
STANDARD_ENTRY_CALLS = ("QM_TM_OpenPosition", "QM_Entry")


@dataclass(frozen=True)
class Call:
    name: str
    args: tuple[str, ...]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def strip_comments_and_literals(source: str) -> str:
    """Blank comments and literals while preserving offsets and newlines."""

    output: list[str] = []
    index = 0
    state = "code"
    while index < len(source):
        char = source[index]
        nxt = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if char == "/" and nxt == "/":
                output.extend((" ", " "))
                index += 2
                state = "line_comment"
                continue
            if char == "/" and nxt == "*":
                output.extend((" ", " "))
                index += 2
                state = "block_comment"
                continue
            if char == '"':
                output.append(" ")
                index += 1
                state = "string"
                continue
            if char == "'":
                output.append(" ")
                index += 1
                state = "char"
                continue
            output.append(char)
            index += 1
            continue

        if state == "line_comment":
            output.append("\n" if char == "\n" else " ")
            index += 1
            if char == "\n":
                state = "code"
            continue

        if state == "block_comment":
            if char == "*" and nxt == "/":
                output.extend((" ", " "))
                index += 2
                state = "code"
            else:
                output.append("\n" if char == "\n" else " ")
                index += 1
            continue

        quote = '"' if state == "string" else "'"
        if char == "\\" and index + 1 < len(source):
            output.extend((" ", " "))
            index += 2
        elif char == quote:
            output.append(" ")
            index += 1
            state = "code"
        else:
            output.append("\n" if char == "\n" else " ")
            index += 1

    return "".join(output)


def _inside(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def expand_ea_local_source(source_path: Path, eas_root: Path) -> tuple[str, list[str]]:
    """Expand reachable files under framework/EAs, never framework includes."""

    eas_root = eas_root.resolve()
    seen: set[Path] = set()
    included: list[str] = []

    def expand(path: Path) -> str:
        path = path.resolve()
        if path in seen or not path.is_file():
            return ""
        seen.add(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        chunks = [text]
        for raw_include in INCLUDE_RE.findall(text):
            normalized = raw_include.replace("\\", "/")
            if normalized.startswith("QM/"):
                continue
            for candidate in (path.parent / normalized, eas_root / normalized):
                candidate = candidate.resolve()
                if candidate.is_file() and _inside(candidate, eas_root):
                    included.append(candidate.relative_to(eas_root).as_posix())
                    chunks.append(expand(candidate))
                    break
        return "\n".join(chunks)

    return expand(source_path), sorted(set(included))


def find_calls(source: str, name: str) -> list[Call]:
    calls: list[Call] = []
    for match in re.finditer(rf"\b{re.escape(name)}\s*\(", source):
        open_index = source.find("(", match.start())
        depth = 0
        arg_start = open_index + 1
        args: list[str] = []
        for index in range(open_index, len(source)):
            char = source[index]
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    final = source[arg_start:index].strip()
                    if final or args:
                        args.append(final)
                    calls.append(Call(name=name, args=tuple(args)))
                    break
            elif char == "," and depth == 1:
                args.append(source[arg_start:index].strip())
                arg_start = index + 1
    return calls


def _simple_request_name(expression: str) -> str | None:
    expression = expression.strip()
    if re.fullmatch(r"[A-Za-z_]\w*", expression):
        return expression
    return None


def _field_assignments(source: str, request: str, field: str) -> list[str]:
    pattern = re.compile(
        rf"\b{re.escape(request)}\.{re.escape(field)}\s*=\s*([^;]+);"
    )
    return [re.sub(r"\s+", " ", match).strip() for match in pattern.findall(source)]


def _typed_field_assignments(source: str, type_name: str, field: str) -> list[str]:
    request_names = sorted(
        set(
            re.findall(
                rf"\b{re.escape(type_name)}\s*&?\s*([A-Za-z_]\w*)",
                source,
            )
        )
    )
    return sorted(
        {
            assignment
            for request in request_names
            for assignment in _field_assignments(source, request, field)
        }
    )


def _is_zero(expression: str) -> bool:
    compact = re.sub(r"\s+", "", expression)
    while compact.startswith("(") and compact.endswith(")"):
        compact = compact[1:-1]
    return bool(re.fullmatch(r"[+]?0(?:L)?", compact))


def _source_record(source_path: Path, eas_root: Path, repo_root: Path) -> dict:
    match = EA_ID_RE.match(source_path.name)
    if not match:
        return {
            "path": source_path.relative_to(repo_root).as_posix(),
            "classification": "unparsed_ea_id",
        }

    top_level = source_path.read_text(encoding="utf-8", errors="replace")
    expanded, included = expand_ea_local_source(source_path, eas_root)
    top_level_code = strip_comments_and_literals(top_level)
    code = strip_comments_and_literals(expanded)
    entry_slot_assignments = _typed_field_assignments(
        code, "QM_EntryRequest", "symbol_slot"
    )
    top_level_entry_slot_assignments = _typed_field_assignments(
        top_level_code, "QM_EntryRequest", "symbol_slot"
    )
    calls = [
        call
        for name in STANDARD_ENTRY_CALLS
        for call in find_calls(code, name)
    ]
    basket_calls = find_calls(code, "QM_BasketOpenPosition")
    call_records: list[dict] = []
    affected = False

    for call in calls:
        if not call.args:
            continue
        request = _simple_request_name(call.args[0])
        explicit_magic = call.args[2] if len(call.args) >= 3 else "0"
        if not _is_zero(explicit_magic):
            call_records.append(
                {
                    "boundary": call.name,
                    "request": request or call.args[0],
                    "classification": "explicit_magic",
                    "explicit_magic": re.sub(r"\s+", " ", explicit_magic).strip(),
                }
            )
            continue

        # Entry builders routinely initialize a request through a local helper
        # that receives it by reference (for example
        # Strategy_InitEntryRequest(buy_req)). A lexical per-variable check at
        # the final call misses that data flow. The relevant source-level
        # invariant is whether any reachable QM_EntryRequest builder supplies
        # a non-zero/derived slot; generated EAs use one shared initializer for
        # all host requests.
        if not entry_slot_assignments:
            classification = "default_relative_host_slot"
            affected = True
        elif all(_is_zero(value) for value in entry_slot_assignments):
            classification = "literal_zero_relative_host_slot"
            affected = True
        else:
            classification = "explicit_slot_wiring"
        call_records.append(
            {
                "boundary": call.name,
                "request": request or call.args[0],
                "classification": classification,
                "slot_assignments": entry_slot_assignments,
            }
        )

    # Basket requests only use relative host semantics when the requested leg
    # is explicitly the chart host. Foreign slot zero remains a valid absolute
    # registry slot and is not part of this defect.
    for call in basket_calls:
        if len(call.args) < 4:
            continue
        request = _simple_request_name(call.args[3])
        if not request:
            continue
        slots = _field_assignments(code, request, "symbol_slot")
        symbols = _field_assignments(code, request, "symbol")
        host_symbol = any("_Symbol" in value for value in symbols)
        if host_symbol and (not slots or all(_is_zero(value) for value in slots)):
            affected = True
            classification = "basket_relative_host_slot"
        else:
            classification = "basket_explicit_or_foreign_slot"
        call_records.append(
            {
                "boundary": call.name,
                "request": request,
                "classification": classification,
                "slot_assignments": slots,
                "symbol_assignments": symbols,
            }
        )

    if affected:
        classification = "affected_pre_fix"
    elif call_records:
        classification = "immune_explicit_identity"
    else:
        classification = "no_framework_entry_call"

    return {
        "ea_id": int(match.group(1)),
        "ea": f"QM5_{int(match.group(1))}",
        "path": source_path.relative_to(repo_root).as_posix(),
        "directory": source_path.parent.name,
        "classification": classification,
        "includes": included,
        "entry_slot_assignments": entry_slot_assignments,
        "top_level_entry_slot_assignments": top_level_entry_slot_assignments,
        "include_resolved_slot_wiring": bool(
            entry_slot_assignments
            and not top_level_entry_slot_assignments
            and not all(_is_zero(value) for value in entry_slot_assignments)
        ),
        "calls": call_records,
    }


def scan_sources(repo_root: Path) -> list[dict]:
    eas_root = repo_root / "framework" / "EAs"
    records = [
        _source_record(path, eas_root, repo_root)
        for path in sorted(eas_root.glob("QM5_*/*.mq5"))
    ]
    return records


def load_registry(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        for raw in csv.DictReader(handle):
            if (raw.get("status") or "").strip().lower() != "active":
                continue
            rows.append(
                {
                    "ea_id": int(raw["ea_id"]),
                    "ea": f"QM5_{int(raw['ea_id'])}",
                    "ea_slug": raw["ea_slug"].strip(),
                    "slot": int(raw["symbol_slot"]),
                    "symbol": raw["symbol"].strip(),
                    "magic": int(raw["magic"]),
                }
            )
    return rows


def _git_commit(repo_root: Path) -> str | None:
    completed = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=repo_root,
        check=False,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip() or None


def _pair_key(row: dict) -> tuple[str, int, str]:
    return row["ea"], int(row["slot"]), row["symbol"]


def build_report(
    repo_root: Path,
    *,
    baseline: dict | None = None,
    generated_at: str | None = None,
) -> dict:
    repo_root = repo_root.resolve()
    registry_path = repo_root / "framework" / "registry" / "magic_numbers.csv"
    sources = scan_sources(repo_root)
    registry = load_registry(registry_path)

    sources_by_ea: dict[int, list[dict]] = defaultdict(list)
    excluded_upper_bound: list[dict] = []
    for source in sources:
        if "ea_id" in source:
            sources_by_ea[source["ea_id"]].append(source)
        if (
            source["classification"] == "immune_explicit_identity"
            and source.get("include_resolved_slot_wiring")
        ):
            excluded_upper_bound.append(source)

    affected_pairs: list[dict] = []
    for row in registry:
        if row["slot"] == 0:
            continue
        candidates = sources_by_ea.get(row["ea_id"], [])
        expected_directory = f"QM5_{row['ea_id']}_{row['ea_slug']}"
        exact = [
            source for source in candidates if source["directory"] == expected_directory
        ]
        matched = exact or candidates
        affected_sources = [
            source
            for source in matched
            if source["classification"] == "affected_pre_fix"
        ]
        if not affected_sources:
            continue
        exposure_modes = sorted(
            {
                call["classification"]
                for source in affected_sources
                for call in source["calls"]
                if call["classification"]
                in {
                    "default_relative_host_slot",
                    "literal_zero_relative_host_slot",
                    "basket_relative_host_slot",
                }
            }
        )
        affected_pairs.append(
            {
                **row,
                "source_match": "registry_slug_exact" if exact else "ea_id_fallback",
                "exposure_modes": exposure_modes,
                "affected_sources": sorted(
                    source["path"] for source in affected_sources
                ),
            }
        )
    affected_pairs.sort(key=lambda row: (row["ea_id"], row["slot"], row["symbol"]))

    source_counts = Counter(source["classification"] for source in sources)
    affected_eas = sorted({row["ea"] for row in affected_pairs})
    report = {
        "schema": SCHEMA,
        "generated_at_utc": generated_at
        or datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "repo_root": str(repo_root),
        "source_commit": _git_commit(repo_root),
        "registry": {
            "path": registry_path.relative_to(repo_root).as_posix(),
            "sha256": sha256_file(registry_path),
            "active_rows": len(registry),
        },
        "method": {
            "entry_boundaries": [*STANDARD_ENTRY_CALLS, "QM_BasketOpenPosition(host only)"],
            "include_policy": "recursively expand only files beneath framework/EAs",
            "lexical_policy": "strip comments and string/char literals before call/assignment analysis",
            "affected_rule": "implicit/zero explicit magic plus omitted/literal-zero relative host slot, intersected with active non-zero registry rows",
            "v3_note": "V3 rejects a resolved magic mismatch; it does not supply the host magic. No scanned EA source calls QM_FrameworkInitV3.",
        },
        "counts": {
            "sources_scanned": len(sources),
            "source_classifications": dict(sorted(source_counts.items())),
            "affected_source_paths": sum(
                1 for source in sources if source["classification"] == "affected_pre_fix"
            ),
            "affected_eas_with_active_nonzero_slots": len(affected_eas),
            "affected_pairs": len(affected_pairs),
            "include_resolved_false_positive_sources_removed": len(excluded_upper_bound),
        },
        "affected_eas": affected_eas,
        "affected_pairs": affected_pairs,
        "affected_sources": [
            source for source in sources if source["classification"] == "affected_pre_fix"
        ],
        "upper_bound_false_positives_removed": excluded_upper_bound,
    }

    if baseline:
        old_pairs = {
            _pair_key(row) for row in baseline.get("affected_pairs", [])
        }
        new_pairs = {_pair_key(row) for row in affected_pairs}
        current_by_key = {_pair_key(row): row for row in affected_pairs}
        report["baseline_comparison"] = {
            "schema": baseline.get("schema"),
            "reported_counts": baseline.get("counts"),
            "removed_pairs": [
                {"ea": ea, "slot": slot, "symbol": symbol}
                for ea, slot, symbol in sorted(old_pairs - new_pairs)
            ],
            "added_pairs": [
                {
                    "ea": ea,
                    "slot": slot,
                    "symbol": symbol,
                    "exposure_modes": current_by_key[(ea, slot, symbol)][
                        "exposure_modes"
                    ],
                }
                for ea, slot, symbol in sorted(new_pairs - old_pairs)
            ],
        }
    return report


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Repository root (default: inferred from this script)",
    )
    parser.add_argument("--output", type=Path, help="Write JSON here; stdout if omitted")
    parser.add_argument(
        "--baseline",
        type=Path,
        help="Optional prior scan JSON for exact pair-set comparison",
    )
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    baseline = None
    if args.baseline:
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
    report = build_report(args.root, baseline=baseline)
    rendered = json.dumps(report, indent=2, sort_keys=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
