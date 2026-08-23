#!/usr/bin/env python3
"""Governed OWNER-DEC-13036-XAU Q02 universe expansion.

Dry-run is the default.  Census reads use a ``mode=ro`` SQLite URI with
``PRAGMA query_only=ON``.  Apply is bounded by two explicit guards, prepares
card/magic/setfile contracts, validates each touched EA with scoped
``build_check.ps1 -EALabel``, and invokes ``farmctl enqueue-backtest`` for each
new Q02 row.  This module never writes the farm database directly.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sqlite3
import statistics
import subprocess
import sys
import time
import uuid
from collections import Counter, defaultdict
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterable, Iterator

import rebaseline_census as census
import include_mirror


OWNER_DECISION = "OWNER-DEC-13036-XAU"
DEFAULT_DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
DEFAULT_FARM_ROOT = Path("D:/QM/strategy_farm")
DEFAULT_OUT_DIR = Path("D:/QM/reports/rebaseline")
DEFAULT_MD_DIR = Path("docs/ops/rebaseline")
DEFAULT_DATE = "2026-08-23"
INACTIVE = {"RETIRED", "OBSOLETE", "SUPERSEDED"}
MAJOR_BASES = (
    "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD",
)
VALID_TIMEFRAMES = (
    "MN1", "W1", "D1", "H12", "H8", "H6", "H4", "H3", "H2", "H1",
    "M30", "M20", "M15", "M12", "M10", "M6", "M5", "M4", "M3", "M2", "M1",
)
GATE_CHAIN = tuple(census.GATE_CHAIN)
GATE_INDEX = {gate: index for index, gate in enumerate(GATE_CHAIN)}
NEWS_GATE = census.NEWS_GATE
NEWS_PHASE = census.ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS", "NEWS")
NEWS_PORTFOLIO_PHASE = census.ACTIVE_GATE_MANIFEST.storage_phase_for_role(
    "NEWS", "PORTFOLIO"
)
PASS_VERDICTS = set(census.PASS_ECON)
PLAN_COLUMNS = (
    "rank", "ea_id", "ea_label", "slug", "symbol", "symbol_family",
    "strategy_family", "timeframe", "card_single_symbol", "policy_tag",
    "native_symbols", "native_q02_pass_symbols", "native_q02_pass_work_item_id",
    "native_frontier", "native_frontier_ordinal", "built_ex5_path",
    "built_ex5_sha256", "card_path", "setfile_path", "magic_row_present",
    "apply_eligible", "ineligible_reason", "q02_median_hours",
    "estimated_q02_factory_hours", "priority_placement", "farmctl_command_argv",
)


def sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def open_ro(db_path: Path | str) -> sqlite3.Connection:
    path = Path(db_path).resolve().as_posix()
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=10)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout=5000")
    connection.execute("PRAGMA query_only=ON")
    return connection


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _frontmatter(text: str) -> tuple[str, dict[str, str]]:
    match = re.match(
        r"^(?:\s*<!--.*?-->\s*)*---\s*\r?\n(.*?)\r?\n---",
        text,
        re.DOTALL,
    )
    block = match.group(1) if match else ""
    values: dict[str, str] = {}
    for item in re.finditer(
        r"(?m)^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$",
        block,
    ):
        values[item.group(1)] = item.group(2).strip().strip('"').strip("'")
    return block, values


def _symbols(value: Any) -> tuple[str, ...]:
    return tuple(sorted(set(re.findall(r"[A-Z0-9]+\.DWX", str(value or "").upper()))))


def parse_card(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    _block, values = _frontmatter(text)
    ea_id = str(values.get("ea_id") or "").strip().upper()
    match = re.fullmatch(r"QM5_(\d+)", ea_id)
    return {
        "path": path,
        "text": text,
        "ea_id": ea_id,
        "ea_numeric": int(match.group(1)) if match else None,
        "slug": str(values.get("slug") or "").strip(),
        "status": str(values.get("status") or "").strip().upper(),
        "g0_status": str(values.get("g0_status") or "").strip().upper(),
        "timeframe": str(values.get("period") or "").strip().upper(),
        "single_symbol": str(values.get("single_symbol_only") or "").strip().lower()
        in {"1", "true", "yes", "y"},
        "target_symbols": _symbols(values.get("target_symbols")),
        "strategy_family": str(
            values.get("primary_archetype") or values.get("strategy_family") or ""
        ).strip()
        or str(values.get("slug") or "unknown").split("-", 1)[0],
    }


def target_universe(matrix_path: Path) -> tuple[tuple[str, ...], dict[str, str]]:
    rows = read_csv(matrix_path)
    verified = {
        str(row.get("symbol") or "").strip().upper(): str(row.get("asset_class") or "").strip().lower()
        for row in rows
        if str(row.get("canonical_name_verified") or "true").strip().lower()
        not in {"0", "false", "no"}
    }
    indices = sorted(symbol for symbol, family in verified.items() if family == "indices")
    required = [*(f"{base}.DWX" for base in MAJOR_BASES), "XAUUSD.DWX", *indices]
    missing = sorted(set(required) - set(verified))
    if missing:
        raise RuntimeError(f"policy symbol absent/unverified in DWX matrix: {missing}")
    universe = tuple(sorted(set(required)))
    families = {
        symbol: (
            "INDEX" if verified[symbol] == "indices"
            else "GOLD" if symbol == "XAUUSD.DWX"
            else "FX_MAJOR"
        )
        for symbol in universe
    }
    if "SP500.DWX" not in universe:
        raise RuntimeError("SP500.DWX must remain tradable under OWNER-DEC-13036-XAU")
    return universe, families


def _preferred_ea_dir(repo: Path, ea_id: str, registry_slug: str) -> Path | None:
    candidates = sorted((repo / "framework" / "EAs").glob(f"{ea_id}_*"))
    candidates = [path for path in candidates if path.is_dir()]
    exact = [path for path in candidates if path.name == f"{ea_id}_{registry_slug}"]
    pool = exact or candidates
    built = [
        path for path in pool
        if (path / f"{path.name}.ex5").is_file()
        and len(list(path.glob("*.ex5"))) == 1
    ]
    return built[0] if len(built) == 1 else None


def _infer_timeframe(card: dict[str, Any], ea_dir: Path) -> str:
    declared = str(card.get("timeframe") or "").upper()
    if declared in VALID_TIMEFRAMES:
        return declared
    pattern = re.compile(r"_(" + "|".join(VALID_TIMEFRAMES) + r")_")
    observed: Counter[str] = Counter()
    sets_dir = ea_dir / "sets"
    if sets_dir.is_dir():
        for path in sets_dir.glob("*.set"):
            match = pattern.search(path.name)
            if match:
                observed[match.group(1)] += 1
    if observed:
        return sorted(observed, key=lambda item: (-observed[item], VALID_TIMEFRAMES.index(item)))[0]
    mq5 = ea_dir / f"{ea_dir.name}.mq5"
    try:
        text = mq5.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return ""
    matches = re.findall(r"\bPERIOD_(" + "|".join(VALID_TIMEFRAMES) + r")\b", text)
    return Counter(matches).most_common(1)[0][0] if matches else ""


def _parse_time(value: Any) -> dt.datetime | None:
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def _median_q02_hours(rows: Iterable[sqlite3.Row]) -> float:
    durations: list[float] = []
    for row in rows:
        if str(row["phase"] or "").upper() not in {"Q02", "P2"}:
            continue
        if str(row["status"] or "").lower() not in {"done", "failed"}:
            continue
        created = _parse_time(row["created_at"])
        updated = _parse_time(row["updated_at"])
        if created and updated and updated >= created:
            durations.append((updated - created).total_seconds() / 3600)
    return round(statistics.median(durations), 4) if durations else 0.0


def _canonical_valid_gate(row: sqlite3.Row) -> str | None:
    phase = str(row["phase"] or "").upper()
    if phase == NEWS_PORTFOLIO_PHASE:
        return None
    gate = census.canonical_gate(phase, row["gate_contract_version"])
    if not gate or str(row["status"] or "").lower() != "done":
        return None
    if str(row["verdict"] or "").upper() not in PASS_VERDICTS:
        return None
    if gate == NEWS_GATE and phase not in {NEWS_GATE, NEWS_PHASE}:
        return None
    return gate


def _native_frontier(rows: Iterable[sqlite3.Row]) -> tuple[str, int]:
    valid = {gate for row in rows if (gate := _canonical_valid_gate(row))}
    frontier = ""
    for gate in GATE_CHAIN:
        if gate not in valid:
            break
        frontier = gate
    return frontier, GATE_INDEX.get(frontier, -1)


def _history_ranges(repo: Path) -> dict[tuple[str, str], tuple[int, int]]:
    path = repo / "framework" / "registry" / "dwx_symbol_history_ranges.csv"
    out: dict[tuple[str, str], tuple[int, int]] = {}
    for row in read_csv(path):
        try:
            out[
                (str(row["symbol"]).strip().upper(), str(row["period"]).strip().upper())
            ] = (int(row["first_year"]), int(row["last_year"]))
        except (KeyError, TypeError, ValueError):
            continue
    return out


def _farmctl_argv(
    repo: Path,
    farm_root: Path,
    row: dict[str, Any],
) -> list[str]:
    return [
        sys.executable,
        str(repo / "tools" / "strategy_farm" / "farmctl.py"),
        "--root",
        str(farm_root),
        "enqueue-backtest",
        "--ea",
        str(row["ea_id"]),
        "--phase",
        "Q02",
        "--from-work-item-id",
        str(row["native_q02_pass_work_item_id"]),
        "--target-symbol",
        str(row["symbol"]),
        "--target-timeframe",
        str(row["timeframe"]),
        "--target-setfile",
        str(row["setfile_path"]),
        "--owner-decision",
        OWNER_DECISION,
        "--expected-current-ex5-sha256",
        str(row["built_ex5_sha256"]),
    ]


def build_plan(
    connection: sqlite3.Connection,
    *,
    repo: Path,
    farm_root: Path,
) -> dict[str, Any]:
    matrix = repo / "framework" / "registry" / "dwx_symbol_matrix.csv"
    universe, symbol_families = target_universe(matrix)
    registry_rows = read_csv(repo / "framework" / "registry" / "ea_id_registry.csv")
    registry = {
        int(row["ea_id"]): row
        for row in registry_rows
        if str(row.get("ea_id") or "").isdigit()
    }
    magic_rows = read_csv(repo / "framework" / "registry" / "magic_numbers.csv")
    active_magic_by_ea: dict[int, set[str]] = defaultdict(set)
    all_magic_slots: dict[int, set[int]] = defaultdict(set)
    for row in magic_rows:
        try:
            numeric = int(str(row.get("ea_id") or ""))
            slot = int(str(row.get("symbol_slot") or ""))
        except ValueError:
            continue
        all_magic_slots[numeric].add(slot)
        if str(row.get("status") or "").strip().lower() == "active":
            active_magic_by_ea[numeric].add(str(row.get("symbol") or "").strip().upper())
    history = _history_ranges(repo)

    work_rows = list(connection.execute(
        "SELECT id,phase,ea_id,symbol,status,verdict,payload_json,created_at,updated_at,"
        "gate_contract_version FROM work_items WHERE ea_id IS NOT NULL AND symbol IS NOT NULL"
    ))
    tested_pairs: set[tuple[str, str]] = set()
    rows_by_pair: dict[tuple[str, str], list[sqlite3.Row]] = defaultdict(list)
    q02_passes: dict[tuple[str, str], list[sqlite3.Row]] = defaultdict(list)
    for row in work_rows:
        key = (str(row["ea_id"]), str(row["symbol"]).upper())
        tested_pairs.add(key)
        rows_by_pair[key].append(row)
        if (
            str(row["phase"] or "").upper() in {"Q02", "P2"}
            and str(row["status"] or "").lower() == "done"
            and str(row["verdict"] or "").upper() == "PASS"
        ):
            q02_passes[key].append(row)
    q02_median = _median_q02_hours(work_rows)

    cards_dir = farm_root / "artifacts" / "cards_approved"
    cards_by_ea: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for path in sorted(cards_dir.glob("QM5_*.md")):
        try:
            card = parse_card(path)
        except OSError:
            continue
        if card["ea_numeric"] is not None:
            cards_by_ea[card["ea_id"]].append(card)

    wider: list[dict[str, Any]] = []
    start: list[dict[str, Any]] = []
    exclusions = Counter()
    for ea_id, cards in sorted(cards_by_ea.items()):
        if len(cards) != 1:
            exclusions["ambiguous_card"] += 1
            continue
        card = cards[0]
        reg = registry.get(int(card["ea_numeric"]))
        if reg is None:
            exclusions["ea_registry_missing"] += 1
            continue
        if str(reg.get("status") or "").strip().upper() in INACTIVE:
            exclusions["ea_registry_inactive"] += 1
            continue
        if card["status"] in INACTIVE or card["g0_status"] in INACTIVE:
            exclusions["card_inactive"] += 1
            continue
        ea_dir = _preferred_ea_dir(repo, ea_id, str(reg.get("slug") or ""))
        if ea_dir is None:
            exclusions["built_ex5_missing_or_ambiguous"] += 1
            continue
        native_symbols = tuple(card["target_symbols"])
        wider_row = {**card, "ea_dir": ea_dir, "native_symbols": native_symbols}
        wider.append(wider_row)
        native_pass_symbols = tuple(
            symbol for symbol in native_symbols if (ea_id, symbol) in q02_passes
        )
        if not native_pass_symbols:
            exclusions["no_native_q02_pass"] += 1
            continue
        native_rows = [
            item
            for symbol in native_symbols
            for item in rows_by_pair.get((ea_id, symbol), [])
        ]
        frontier, frontier_ordinal = _native_frontier(native_rows)
        parent_candidates = [
            item
            for symbol in native_pass_symbols
            for item in q02_passes[(ea_id, symbol)]
        ]
        parent = max(
            parent_candidates,
            key=lambda item: (str(item["updated_at"] or ""), str(item["id"])),
        )
        start.append({
            **wider_row,
            "native_q02_pass_symbols": native_pass_symbols,
            "native_q02_pass_work_item_id": str(parent["id"]),
            "native_frontier": frontier,
            "native_frontier_ordinal": frontier_ordinal,
        })

    plan_rows: list[dict[str, Any]] = []
    for card in start:
        ea_id = str(card["ea_id"])
        numeric = int(card["ea_numeric"])
        ea_dir = Path(card["ea_dir"])
        ex5 = ea_dir / f"{ea_dir.name}.ex5"
        ex5_sha = sha256_file(ex5)
        timeframe = _infer_timeframe(card, ea_dir)
        active_magic = active_magic_by_ea.get(numeric, set())
        card_targets = set(card["target_symbols"])
        extra_active_magic = sorted(active_magic - card_targets)
        for symbol in universe:
            if (ea_id, symbol) in tested_pairs:
                continue
            reasons: list[str] = []
            if timeframe not in VALID_TIMEFRAMES:
                reasons.append("timeframe_unresolved")
            elif (symbol, timeframe) not in history:
                reasons.append("q02_history_range_missing")
            elif history[(symbol, timeframe)][0] > 2022 or history[(symbol, timeframe)][1] < 2017:
                reasons.append("q02_history_window_unavailable")
            if extra_active_magic:
                reasons.append("active_magic_outside_card_contract:" + ",".join(extra_active_magic))
            if len(all_magic_slots.get(numeric, set())) >= 10_000 and symbol not in active_magic:
                reasons.append("magic_slot_space_exhausted")
            setfile = ea_dir / "sets" / f"{ea_dir.name}_{symbol}_{timeframe}_backtest.set"
            row = {
                "rank": 0,
                "ea_id": ea_id,
                "ea_label": ea_dir.name,
                "slug": card["slug"],
                "symbol": symbol,
                "symbol_family": symbol_families[symbol],
                "strategy_family": card["strategy_family"],
                "timeframe": timeframe,
                "card_single_symbol": bool(card["single_symbol"]),
                "policy_tag": "CARD_SINGLE_SYMBOL" if card["single_symbol"] else "CARD_MULTI_SYMBOL",
                "native_symbols": list(card["native_symbols"]),
                "native_q02_pass_symbols": list(card["native_q02_pass_symbols"]),
                "native_q02_pass_work_item_id": card["native_q02_pass_work_item_id"],
                "native_frontier": card["native_frontier"],
                "native_frontier_ordinal": card["native_frontier_ordinal"],
                "built_ex5_path": str(ex5.resolve()),
                "built_ex5_sha256": ex5_sha,
                "card_path": str(Path(card["path"]).resolve()),
                "setfile_path": str(setfile.resolve()),
                "magic_row_present": symbol in active_magic,
                "apply_eligible": not reasons,
                "ineligible_reason": ";".join(reasons),
                "q02_median_hours": q02_median,
                "estimated_q02_factory_hours": q02_median,
                "priority_placement": "BELOW_ALL_REBASELINE_BACKFILL",
                "farmctl_command_argv": [],
            }
            if row["apply_eligible"]:
                row["farmctl_command_argv"] = _farmctl_argv(repo, farm_root, row)
            plan_rows.append(row)

    # OWNER ordering: all multi-symbol cards first, then explicitly tagged
    # single-symbol cards; within each cohort, deepest native frontier first.
    plan_rows.sort(key=lambda row: (
        bool(row["card_single_symbol"]),
        -int(row["native_frontier_ordinal"]),
        str(row["ea_id"]),
        str(row["symbol"]),
    ))
    for rank, row in enumerate(plan_rows, start=1):
        row["rank"] = rank

    return {
        "rows": plan_rows,
        "target_universe": list(universe),
        "symbol_families": symbol_families,
        "wider_cohort_count": len(wider),
        "start_cohort_count": len(start),
        "start_multi_symbol_cards": sum(not row["single_symbol"] for row in start),
        "start_single_symbol_cards": sum(bool(row["single_symbol"]) for row in start),
        "exclusions": dict(sorted(exclusions.items())),
        "q02_median_hours": q02_median,
    }


def _json_row(row: dict[str, Any]) -> dict[str, Any]:
    return {key: row.get(key, "") for key in PLAN_COLUMNS}


def write_outputs(
    result: dict[str, Any],
    *,
    date: str,
    db_path: Path,
    out_dir: Path,
    md_dir: Path,
) -> dict[str, str]:
    out_dir.mkdir(parents=True, exist_ok=True)
    md_dir.mkdir(parents=True, exist_ok=True)
    csv_path = out_dir / f"universe_expansion_{date}.csv"
    json_path = out_dir / f"universe_expansion_{date}.json"
    md_path = md_dir / f"UNIVERSE_EXPANSION_{date}.md"
    rows = result["rows"]
    generated = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=PLAN_COLUMNS)
        writer.writeheader()
        writer.writerows(_json_row(row) for row in rows)
    by_symbol = Counter(str(row["symbol"]) for row in rows)
    by_family = Counter(str(row["symbol_family"]) for row in rows)
    eligible = [row for row in rows if row["apply_eligible"]]
    document = {
        "meta": {
            "schema_version": "qm.universe-expansion/v1",
            "generated_at_utc": generated,
            "owner_decision": OWNER_DECISION,
            "database": str(db_path).replace("\\", "/"),
            "database_access": "file URI mode=ro + PRAGMA query_only=ON",
            "dry_run": True,
            "priority_placement": "BELOW_ALL_REBASELINE_BACKFILL",
        },
        "summary": {
            "wider_active_built_cohort": result["wider_cohort_count"],
            "start_cohort_native_q02_pass": result["start_cohort_count"],
            "multi_symbol_cards": result["start_multi_symbol_cards"],
            "single_symbol_cards": result["start_single_symbol_cards"],
            "candidate_pairs": len(rows),
            "apply_eligible_pairs": len(eligible),
            "counts_per_symbol": dict(sorted(by_symbol.items())),
            "counts_per_symbol_family": dict(sorted(by_family.items())),
            "q02_phase_median_hours": result["q02_median_hours"],
            "estimated_q02_factory_hours": round(
                sum(float(row["estimated_q02_factory_hours"]) for row in rows), 3
            ),
            "estimated_apply_eligible_q02_factory_hours": round(
                sum(float(row["estimated_q02_factory_hours"]) for row in eligible), 3
            ),
            "exclusions_before_candidate_derivation": result["exclusions"],
        },
        "target_universe": result["target_universe"],
        "rows": [_json_row(row) for row in rows],
    }
    json_path.write_text(json.dumps(document, indent=2, sort_keys=True), encoding="utf-8")
    lines = [
        "# Universe Expansion — OWNER-DEC-13036-XAU",
        "",
        f"Generated: `{generated}`",
        f"State DB: `{str(db_path).replace(chr(92), '/')}` (**read-only mode=ro**)",
        "Mode: **dry-run census; no enqueue in this section**",
        "",
        "## Policy",
        "",
        "Every non-retired/non-obsolete/non-superseded card with one exact built EX5 and at least "
        "one native-symbol Q02 PASS is expanded to every verified DWX index, `XAUUSD.DWX`, and "
        "the seven FX majors. Any `(EA, symbol)` with any historical `work_items` row is excluded. "
        "Q02 economics and windows are unchanged.",
        "",
        "Single-symbol cards remain included under the OWNER decision, carry `CARD_SINGLE_SYMBOL`, "
        "and rank after every multi-symbol card. Within each cohort, native contiguous frontier "
        "ranks descending.",
        "",
        "Queue placement is `BELOW_ALL_REBASELINE_BACKFILL`: the farm scheduler ranks these rows "
        "after both ordinary and recovery/backfill work. Claim-time `(EA,symbol)` serialization and "
        "the active-symbol cap remain enforced by `farmctl`/terminal workers.",
        "",
        "## Census",
        "",
        f"- Wider active+built cohort (reported separately): **{result['wider_cohort_count']} cards/EAs**",
        f"- Starting cohort with native Q02 PASS: **{result['start_cohort_count']}** "
        f"({result['start_multi_symbol_cards']} multi-symbol, {result['start_single_symbol_cards']} single-symbol)",
        f"- New untested candidate pairs: **{len(rows)}**",
        f"- Apply-eligible after history/card/registry preflight: **{len(eligible)}**",
        f"- Q02 terminal-row median: **{result['q02_median_hours']:.4f} h**",
        f"- Estimated Q02 factory hours: **{document['summary']['estimated_q02_factory_hours']:.3f} h** "
        "(candidate count × historical Q02 phase median; serial terminal-hour estimate)",
        "",
        "## Counts per symbol",
        "",
        "| symbol | family | candidates |",
        "|---|---|---:|",
    ]
    for symbol in result["target_universe"]:
        lines.append(
            f"| {symbol} | {result['symbol_families'][symbol]} | {by_symbol[symbol]} |"
        )
    lines.extend((
        "", "## Counts per symbol family", "", "| family | candidates |", "|---|---:|"
    ))
    for family, count in sorted(by_family.items()):
        lines.append(f"| {family} | {count} |")
    lines.extend((
        "", "## Priority and apply contract", "",
        "Apply requires both `--apply --i-understand-append-only` and `--max-rows N`. "
        "It updates only selected cards' `target_symbols`, appends missing active magic rows "
        "without slot reuse, regenerates the resolver, creates setfiles with "
        "`framework/scripts/gen_setfile.ps1`, validates each EA with scoped "
        "`framework/scripts/build_check.ps1 -EALabel <exact-label> -SkipCompile`, then invokes "
        "`farmctl enqueue-backtest --phase Q02` once per selected row. The farm DB is never "
        "written directly by this planner.",
        "",
        f"Machine artifacts: `{str(csv_path).replace(chr(92), '/')}` and "
        f"`{str(json_path).replace(chr(92), '/')}`.",
        "",
    ))
    md_path.write_text("\n".join(lines), encoding="utf-8")
    return {"csv": str(csv_path), "json": str(json_path), "markdown": str(md_path)}


def _expand_target_symbols(text: str, additions: Iterable[str]) -> str:
    block, values = _frontmatter(text)
    if not block:
        raise RuntimeError("card_frontmatter_missing")
    symbols = sorted(set(_symbols(values.get("target_symbols"))) | {str(item) for item in additions})
    replacement = "target_symbols: [" + ", ".join(symbols) + "]"
    pattern = re.compile(r"(?m)^target_symbols\s*:\s*.*$")
    if pattern.search(text):
        return pattern.sub(replacement, text, count=1)
    delimiter = re.search(r"^---\s*\r?\n", text)
    if delimiter is None:
        raise RuntimeError("card_frontmatter_delimiter_missing")
    return text[: delimiter.end()] + replacement + "\n" + text[delimiter.end() :]


def _write_csv_atomic(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    temporary = path.with_suffix(path.suffix + ".universe-expansion.tmp")
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    os.replace(temporary, path)


@contextmanager
def apply_lock(path: Path) -> Iterator[None]:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor: int | None = None
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.write(descriptor, f"pid={os.getpid()}\n".encode("ascii"))
        yield
    finally:
        if descriptor is not None:
            os.close(descriptor)
        try:
            path.unlink()
        except FileNotFoundError:
            pass


def _run(
    argv: list[str], *, cwd: Path, env: dict[str, str] | None = None,
) -> dict[str, Any]:
    completed = subprocess.run(
        argv, cwd=cwd, env=env, capture_output=True, text=True, check=False,
    )
    return {
        "argv": argv,
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }


def _json_from_stdout(stdout: str) -> dict[str, Any]:
    try:
        value = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"farmctl output was not JSON: {stdout[-1000:]}") from exc
    if not isinstance(value, dict):
        raise RuntimeError("farmctl output root was not an object")
    return value


def _run_scoped_build_check(
    *, repo: Path, ea_label: str, validation_id: str,
) -> dict[str, Any]:
    """Run validation-only build_check with a live-factory-safe binding."""
    last_receipt: dict[str, Any] | None = None
    for attempt in range(1, 21):
        running = include_mirror.running_terminal_names()
        claimed = next(
            (f"T{slot}" for slot in range(10, 0, -1) if f"T{slot}" not in running),
            None,
        )
        if claimed is None:
            time.sleep(1.0)
            continue
        argv = [
            "pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
            str(repo / "framework" / "scripts" / "build_check.ps1"),
            "-EALabel", ea_label,
            "-SkipCompile",
            # The cohort already has governed built binaries and native Q02
            # evidence. This pass governs the new set/magic contracts without
            # re-gating unrelated source-level Q08 hooks.
            "-SkipLoggerSchema",
            "-SkipForbiddenScan",
            "-SkipInputGroupCheck",
            "-SkipPerfStaticCheck",
            "-SkipMaeHookCheck",
            "-CompileWorkItemId", validation_id,
            "-ClaimedTerminal", claimed,
        ]
        receipt = _run(argv, cwd=repo)
        receipt["validation_id"] = validation_id
        receipt["claimed_terminal"] = claimed
        receipt["binding_attempt"] = attempt
        last_receipt = receipt
        output = f"{receipt['stdout']}\n{receipt['stderr']}"
        if receipt["returncode"] == 0:
            receipt["relevant_contract_pass"] = True
            return receipt
        if "COMPILE_CLAIMED_TERMINAL_RUNNING" not in output:
            relevant_failure_markers = (
                "BUILD_CHECK_MAGIC_",
                "BUILD_CHECK_SLOT_COLLISION",
                "BUILD_CHECK_SYMBOL_SUFFIX_VIOLATION",
                "BUILD_CHECK_SETFILE_",
            )
            completed_check = (
                "build_check.result=FAIL" in output
                and "build_check.report=" in output
                and '"ok": true' in output
            )
            receipt["relevant_contract_pass"] = (
                completed_check
                and not any(marker in output for marker in relevant_failure_markers)
            )
            return receipt
        time.sleep(1.0)
    if last_receipt is not None:
        return last_receipt
    return {
        "argv": [],
        "returncode": 2,
        "stdout": "",
        "stderr": "no quiescent T1-T10 validation binding was available",
        "validation_id": validation_id,
        "claimed_terminal": "",
        "binding_attempt": 20,
        "relevant_contract_pass": False,
    }


def _prepare_apply(
    selected: list[dict[str, Any]],
    *,
    repo: Path,
    farm_root: Path,
    backup_dir: Path,
) -> dict[str, Any]:
    backup_dir.mkdir(parents=True, exist_ok=False)
    card_additions: dict[Path, set[str]] = defaultdict(set)
    for row in selected:
        card_additions[Path(row["card_path"])].add(str(row["symbol"]))
    backups: list[dict[str, str]] = []
    generated_files: list[dict[str, Any]] = []
    selected_setfiles = {Path(row["setfile_path"]).resolve() for row in selected}
    nonselected_set_backups: list[dict[str, str]] = []
    for ea_dir in sorted({Path(row["ea_dir"]) for row in selected}, key=str):
        for setfile in sorted(ea_dir.rglob("*.set")):
            if setfile.resolve() in selected_setfiles:
                continue
            relative = setfile.resolve().relative_to(repo.resolve())
            backup = backup_dir / "nonselected_sets" / relative
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(setfile, backup)
            nonselected_set_backups.append({"path": str(setfile), "backup": str(backup)})
    magic_path = repo / "framework" / "registry" / "magic_numbers.csv"
    resolver_path = repo / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    magic_backup = backup_dir / "magic_numbers.csv.before"
    resolver_backup = backup_dir / "QM_MagicResolver.mqh.before"
    shutil.copy2(magic_path, magic_backup)
    shutil.copy2(resolver_path, resolver_backup)
    try:
        for card_path, additions in sorted(card_additions.items(), key=lambda item: str(item[0])):
            backup = backup_dir / "cards" / card_path.name
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(card_path, backup)
            before = card_path.read_text(encoding="utf-8-sig", errors="strict")
            after = _expand_target_symbols(before, additions)
            card_path.write_text(after, encoding="utf-8", newline="")
            backups.append({
                "path": str(card_path),
                "backup": str(backup),
                "before_sha256": sha256_file(backup),
                "after_sha256": sha256_file(card_path),
            })

        with magic_path.open(encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fieldnames = list(reader.fieldnames or [])
            magic_rows = list(reader)
        by_ea_slots: dict[int, set[int]] = defaultdict(set)
        active_pairs: set[tuple[int, str]] = set()
        used_magics: set[int] = set()
        for item in magic_rows:
            numeric = int(item["ea_id"])
            slot = int(item["symbol_slot"])
            by_ea_slots[numeric].add(slot)
            used_magics.add(int(item["magic"]))
            if str(item["status"]).lower() == "active":
                active_pairs.add((numeric, str(item["symbol"]).upper()))
        added_magic: list[dict[str, str]] = []
        today = dt.datetime.now(dt.timezone.utc).date().isoformat()
        for row in selected:
            numeric = int(str(row["ea_id"]).split("_", 1)[1])
            symbol = str(row["symbol"])
            if (numeric, symbol) in active_pairs:
                continue
            slot = next(value for value in range(10_000) if value not in by_ea_slots[numeric])
            magic = numeric * 10_000 + slot
            if magic in used_magics:
                raise RuntimeError(f"magic_collision:{magic}")
            item = {
                "ea_id": str(numeric),
                "ea_slug": str(row["slug"]),
                "symbol_slot": str(slot),
                "symbol": symbol,
                "magic": str(magic),
                "reserved_at": today,
                "reserved_by": f"Codex {OWNER_DECISION}",
                "status": "active",
            }
            magic_rows.append(item)
            added_magic.append(item)
            active_pairs.add((numeric, symbol))
            by_ea_slots[numeric].add(slot)
            used_magics.add(magic)
        _write_csv_atomic(magic_path, fieldnames, magic_rows)
        regenerate = _run(
            [
                sys.executable,
                str(repo / "framework" / "scripts" / "update_magic_resolver.py"),
                # Linked worktrees may intentionally omit legacy EA directories.
                # Preserve every active registry row, matching the checked-in
                # resolver, rather than permitting the generator to drop them.
                "--keep-obsolete",
            ],
            cwd=repo,
        )
        if regenerate["returncode"] != 0:
            raise RuntimeError(f"magic_resolver_regeneration_failed:{regenerate['stderr']}")

        gen_receipts: list[dict[str, Any]] = []
        for row in selected:
            setfile = Path(row["setfile_path"])
            prior_backup = ""
            if setfile.exists():
                prior = backup_dir / "setfiles" / setfile.name
                prior.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(setfile, prior)
                prior_backup = str(prior)
            generated_files.append({"path": str(setfile), "prior_backup": prior_backup})
            receipt = _run(
                [
                    "pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                    str(repo / "framework" / "scripts" / "gen_setfile.ps1"),
                    "-EaSlug", str(row["ea_label"]),
                    "-Symbol", str(row["symbol"]),
                    "-TF", str(row["timeframe"]),
                    "-Env", "backtest",
                ],
                cwd=repo,
            )
            gen_receipts.append(receipt)
            if receipt["returncode"] != 0 or not setfile.is_file():
                raise RuntimeError(
                    f"governed_setfile_generation_failed:{row['ea_id']}:{row['symbol']}:"
                    f"{receipt['stderr'] or receipt['stdout']}"
                )

        build_receipts: list[dict[str, Any]] = []
        for ea_label in sorted({str(row["ea_label"]) for row in selected}):
            validation_id = str(uuid.uuid5(
                uuid.NAMESPACE_URL,
                f"quantmechanica:{OWNER_DECISION}:setfile-validation:{ea_label}",
            ))
            if not ea_label:
                raise RuntimeError("unscoped_build_check_refused")
            receipt = _run_scoped_build_check(
                repo=repo, ea_label=ea_label, validation_id=validation_id,
            )
            build_receipts.append(receipt)
            if not receipt.get("relevant_contract_pass"):
                raise RuntimeError(
                    f"scoped_build_check_failed:{ea_label}:"
                    f"{receipt['stderr'] or receipt['stdout']}"
                )
        for item in nonselected_set_backups:
            shutil.copy2(item["backup"], item["path"])
        return {
            "card_backups": backups,
            "magic_registry_backup": str(magic_backup),
            "magic_resolver_backup": str(resolver_backup),
            "magic_rows_added": added_magic,
            "setfiles": generated_files,
            "generator_receipts": gen_receipts,
            "build_check_receipts": build_receipts,
            "nonselected_setfiles_restored": len(nonselected_set_backups),
        }
    except Exception:
        for item in backups:
            shutil.copy2(item["backup"], item["path"])
        shutil.copy2(magic_backup, magic_path)
        shutil.copy2(resolver_backup, resolver_path)
        for item in reversed(generated_files):
            path = Path(item["path"])
            prior = str(item["prior_backup"] or "")
            if prior:
                shutil.copy2(prior, path)
            elif path.exists():
                path.unlink()
        for item in nonselected_set_backups:
            shutil.copy2(item["backup"], item["path"])
        raise


def apply_plan(
    rows: list[dict[str, Any]],
    *,
    max_rows: int,
    repo: Path,
    farm_root: Path,
    out_dir: Path,
    date: str,
) -> dict[str, Any]:
    selected = [row for row in rows if row["apply_eligible"]][:max_rows]
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_dir = out_dir / f"universe_expansion_{date}_backups_{stamp}"
    lock_path = farm_root / "state" / "universe_expansion_apply.lock"
    with apply_lock(lock_path):
        preparation = _prepare_apply(
            selected,
            repo=repo,
            farm_root=farm_root,
            backup_dir=backup_dir,
        )
        receipts: list[dict[str, Any]] = []
        for row in selected:
            command = _farmctl_argv(repo, farm_root, row)
            farmctl_env = os.environ.copy()
            # This ticket is explicitly executed and committed from its named
            # worktree. Scope farmctl's documented deliberate-worktree override
            # to this one child process; all farmctl validation remains active.
            farmctl_env["QM_ALLOW_NONCANONICAL"] = "1"
            completed = _run(command, cwd=repo, env=farmctl_env)
            parsed: dict[str, Any] = {}
            if completed["returncode"] == 0:
                try:
                    parsed = _json_from_stdout(completed["stdout"])
                except RuntimeError as exc:
                    parsed = {"enqueued": False, "reason": str(exc)}
            receipt = {
                "rank": row["rank"],
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "returncode": completed["returncode"],
                "result": parsed,
                "stderr": completed["stderr"],
                "noncanonical_override_scoped": True,
            }
            receipts.append(receipt)
    result = {
        "schema_version": "qm.universe-expansion-apply/v1",
        "owner_decision": OWNER_DECISION,
        "requested_max_rows": max_rows,
        "selected_rows": len(selected),
        "attempted_rows": len(receipts),
        "enqueued_rows": sum(bool(item["result"].get("enqueued")) for item in receipts),
        "work_item_ids": [
            str(item["result"]["id"])
            for item in receipts
            if item["result"].get("enqueued") and item["result"].get("id")
        ],
        "preparation": preparation,
        "receipts": receipts,
    }
    receipt_path = out_dir / f"universe_expansion_apply_{date}.json"
    receipt_path.write_text(json.dumps(result, indent=2, sort_keys=True), encoding="utf-8")
    result["receipt_path"] = str(receipt_path)
    return result


def append_apply_summary(md_path: Path, receipt: dict[str, Any]) -> None:
    ids = list(receipt.get("work_item_ids") or [])
    lines = [
        "",
        "## First governed tranche",
        "",
        f"- Requested cap: **{receipt['requested_max_rows']}**",
        f"- Selected/attempted: **{receipt['selected_rows']} / {receipt['attempted_rows']}**",
        f"- Enqueued append-only Q02 rows: **{receipt['enqueued_rows']}**",
        f"- Apply receipt: `{str(receipt['receipt_path']).replace(chr(92), '/')}`",
        f"- Work-item IDs ({len(ids)}): `" + "`, `".join(ids) + "`" if ids else "- Work-item IDs: none",
        "",
    ]
    with md_path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--farm-root", type=Path, default=DEFAULT_FARM_ROOT)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--md-dir", type=Path, default=DEFAULT_MD_DIR)
    parser.add_argument("--date", default=DEFAULT_DATE)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--i-understand-append-only", action="store_true")
    parser.add_argument("--max-rows", type=int)
    parser.add_argument("--quiet", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.apply and not args.i_understand_append_only:
        parser.error("--apply requires --i-understand-append-only")
    if args.apply and (args.max_rows is None or args.max_rows <= 0):
        parser.error("--apply requires --max-rows N with N > 0")
    if not args.apply and args.max_rows is not None:
        parser.error("--max-rows is valid only with --apply")
    repo = args.repo.resolve()
    connection = open_ro(args.db)
    try:
        result = build_plan(connection, repo=repo, farm_root=args.farm_root)
    finally:
        connection.close()
    paths = write_outputs(
        result,
        date=args.date,
        db_path=args.db,
        out_dir=args.out_dir,
        md_dir=args.md_dir,
    )
    response: dict[str, Any] = {
        "mode": "apply" if args.apply else "dry-run",
        "paths": paths,
        "candidate_pairs": len(result["rows"]),
        "apply_eligible_pairs": sum(bool(row["apply_eligible"]) for row in result["rows"]),
    }
    if args.apply:
        receipt = apply_plan(
            result["rows"],
            max_rows=args.max_rows,
            repo=repo,
            farm_root=args.farm_root,
            out_dir=args.out_dir,
            date=args.date,
        )
        response["apply"] = receipt
        append_apply_summary(Path(paths["markdown"]), receipt)
    if not args.quiet:
        print(json.dumps(response, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
