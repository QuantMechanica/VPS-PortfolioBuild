#!/usr/bin/env python3
"""Shared read-only data model for operator-facing pipeline surfaces.

The module deliberately imports the rebaseline census rather than recreating
``highest_contiguous_valid_gate`` in dashboards.  Gate bands and names come
from the manifest loader.  While v3 remains active, band membership is derived
through the v4 contract-equivalence table so operators see the same three
macro phases before and after activation.
"""
from __future__ import annotations

import csv
import dataclasses
import html
import sys
from pathlib import Path
from typing import Any, Iterable

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import (
    backfill_planner,
    book_build_guard,
    gate_manifest,
    rebaseline_census,
)
from tools.strategy_farm.phase_ids import (
    ACTIVE_GATE_CONTRACT_VERSION,
    phase_label,
    phase_qid,
)


MACRO_PHASE_NAMES = {
    "1_STRATEGIEBEWEIS": "Strategie beweist sich",
    "2_OPTIMIERUNG": "Strategie wird optimiert / requalifiziert",
    "3_BUCHBEWERTUNG": "Strategie wird zum Buch bewertet",
}


def _short_version(manifest: gate_manifest.GateManifest) -> str:
    return str(manifest.schema_version).rsplit("/", 1)[-1].lower()


def macro_phase_bands(
    manifest: gate_manifest.GateManifest | None = None,
) -> list[dict[str, Any]]:
    """Return three manifest-derived phase bands in v4 linear order."""

    active = manifest or gate_manifest.load_gate_manifest()
    active_version = _short_version(active)
    v4 = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    v4_rank = {gate.id: gate.ordinal for gate in v4.gates}
    bands: dict[str, list[dict[str, str]]] = {
        macro_id: [] for macro_id in MACRO_PHASE_NAMES
    }

    for gate in active.gates:
        macro_id = active.macro_phase(gate.id)
        linear_id = gate.id
        if macro_id is None:
            linear_id = v4.equivalent_gate(gate.id, active_version, "v4")
            macro_id = v4.macro_phase(linear_id)
        if macro_id not in bands:
            continue
        bands[macro_id].append({
            "gate_id": gate.id,
            "linear_gate_id": linear_id,
            "label": phase_label(
                gate.id, active_version, include_name=True
            ),
        })

    # v3's baseline full run is a display-only stage. It still belongs in the
    # Phase-2 widget because v4 promotes it to the real Q09 gate.
    if active.baseline_stage:
        source_id = str(active.baseline_stage["id"])
        linear_id = v4.equivalent_gate(source_id, active_version, "v4")
        macro_id = v4.macro_phase(linear_id)
        bands[macro_id].append({
            "gate_id": source_id,
            "linear_gate_id": linear_id,
            "label": phase_label(source_id, active_version, include_name=True),
        })

    return [
        {
            "id": macro_id,
            "name": MACRO_PHASE_NAMES[macro_id],
            "gates": sorted(
                gates,
                key=lambda row: v4_rank[row["linear_gate_id"]],
            ),
        }
        for macro_id, gates in bands.items()
    ]


def _qualified_rows(pair_rows: Iterable[dict[str, Any]], terminal_gate: str) -> list[dict]:
    return [
        {"ea_id": row["ea_id"], "symbol": row["symbol"]}
        for row in pair_rows
        if row.get("highest_contiguous_valid_gate") == terminal_gate
    ]


def build_pair_frontier_rows(
    db_path: str | Path,
    *,
    pair_limit: int | None = None,
    backfill_plan_path: str | Path | None = None,
) -> list[dict[str, Any]]:
    """Return the shared census/planner model for read-only operator surfaces."""

    connection = rebaseline_census.open_ro(str(Path(db_path)))
    try:
        pair_rows = rebaseline_census.compute(connection, limit=pair_limit)["pair_rows"]
    finally:
        connection.close()

    rows = _with_backfill_actions(pair_rows)
    if backfill_plan_path is None:
        return rows
    plan_path = Path(backfill_plan_path)
    if not plan_path.is_file():
        return rows
    by_pair = {(str(row["ea_id"]), str(row["symbol"])): row for row in rows}
    with plan_path.open(encoding="utf-8", newline="") as handle:
        for plan in csv.DictReader(handle):
            if plan.get("record_type") != "PAIR":
                continue
            row = by_pair.get((str(plan.get("ea_id") or ""), str(plan.get("symbol") or "")))
            if row is None:
                continue
            row["backfill_action"] = str(plan.get("action") or "")
            row["backfill_action_reason"] = str(plan.get("reason") or "")
            row["earliest_missing_prerequisite"] = str(plan.get("target_gate") or "")
            row["highest_contiguous_valid_gate"] = str(
                plan.get("highest_contiguous_valid_gate") or ""
            )
    return rows


def _with_backfill_actions(pair_rows: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    rows = []
    for row in pair_rows:
        action, action_reason = backfill_planner.action_for_census(row)
        item = dict(row)
        item["backfill_action"] = action
        item["backfill_action_reason"] = action_reason
        rows.append(item)
    return rows


def _observed_frontiers(db_path: Path) -> tuple[dict[tuple[str, str], dict], dict[str, int]]:
    """Find the highest observed row in the v4 linear display topology."""

    v4 = gate_manifest.load_gate_manifest(gate_manifest.V4_DRAFT_MANIFEST)
    rank = {gate.id: gate.ordinal for gate in v4.gates}
    observed: dict[tuple[str, str], dict] = {}
    by_macro = {macro_id: 0 for macro_id in MACRO_PHASE_NAMES}
    connection = rebaseline_census.open_ro(str(db_path))
    try:
        columns = {
            str(row[1]).lower()
            for row in connection.execute("PRAGMA table_info(work_items)")
        }
        version_expr = (
            "gate_contract_version" if "gate_contract_version" in columns else "NULL"
        )
        rows = connection.execute(
            f"SELECT ea_id, symbol, phase, {version_expr} AS gate_contract_version "
            "FROM work_items WHERE ea_id IS NOT NULL AND ea_id<>'' "
            "AND symbol IS NOT NULL AND symbol<>''"
        )
        for ea_id, symbol, phase, contract_version in rows:
            source_version = str(contract_version or "").strip().lower()
            active_id = phase_qid(phase, contract_version).upper()
            # Collapse a storage lane to its top-level gate after the explicit
            # contract translation performed by phase_qid.
            top_id = active_id[:3] if len(active_id) >= 3 and active_id[0] == "Q" else active_id
            if source_version == "v4":
                linear_id = str(phase).strip().upper()[:3]
            else:
                try:
                    linear_id = v4.equivalent_gate(top_id, "v3", "v4")
                except gate_manifest.GateManifestError:
                    continue
            if linear_id not in rank:
                continue
            key = (str(ea_id), str(symbol))
            prior = observed.get(key)
            candidate = {
                "linear_gate": linear_id,
                "rank": rank[linear_id],
                "label": phase_label(phase, contract_version, include_name=True),
                "macro_phase": v4.macro_phase(linear_id),
            }
            if prior is None or candidate["rank"] > prior["rank"]:
                observed[key] = candidate
    finally:
        connection.close()

    for item in observed.values():
        by_macro[item["macro_phase"]] += 1
    return observed, by_macro


def build_operator_snapshot(
    db_path: str | Path,
    *,
    order_dir: str | Path | None = None,
    pair_limit: int | None = None,
) -> dict[str, Any]:
    """Build the common read-only operator surface for one farm database."""

    db_path = Path(db_path)
    connection = rebaseline_census.open_ro(str(db_path))
    try:
        census = rebaseline_census.compute(connection, limit=pair_limit)
    finally:
        connection.close()
    pair_rows = _with_backfill_actions(census["pair_rows"])

    manifest = gate_manifest.load_gate_manifest()
    observed, by_macro = _observed_frontiers(db_path)
    qualified = _qualified_rows(pair_rows, manifest.terminal_requalification_gate)
    guard_dir = Path(order_dir) if order_dir is not None else book_build_guard.DEFAULT_ORDER_DIR
    venue_status = {}
    for venue in ("dxz", "ftmo"):
        result = book_build_guard.check_book_build_allowed(
            venue,
            db_path,
            guard_dir,
            qualified_rows=qualified,
        )
        payload = dataclasses.asdict(result)
        payload["owner_order_present"] = bool(result.order_artifact)
        venue_status[venue] = payload

    rows = []
    for row in pair_rows:
        observed_row = observed.get((str(row["ea_id"]), str(row["symbol"])), {})
        rows.append({
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "highest_observed_gate": (
                observed_row.get("linear_gate") or row["highest_observed_gate"]
            ),
            "highest_observed_label": (
                observed_row.get("label")
                or row.get("highest_observed_label")
                or phase_label(row.get("highest_observed_gate"), include_name=True)
            ),
            "highest_contiguous_valid_gate": row["highest_contiguous_valid_gate"],
            "highest_contiguous_valid_label": (
                row.get("highest_contiguous_valid_label")
                or phase_label(
                    row.get("highest_contiguous_valid_gate"), include_name=True
                )
            ),
            "earliest_missing_prerequisite": row["earliest_missing_prerequisite"],
            "frontier_class": row["frontier_class"],
            "disposition": row["disposition"],
            "backfill_action": row["backfill_action"],
            "backfill_action_reason": row["backfill_action_reason"],
        })

    return {
        "gate_contract_version": ACTIVE_GATE_CONTRACT_VERSION,
        "progress_metric": "highest_contiguous_valid_gate",
        "phase_bands": macro_phase_bands(manifest),
        "pair_count": len(rows),
        "pairs": rows,
        "counts": census["summary"],
        "pairs_by_macro_phase": by_macro,
        "book_guard": {
            "minimum_qualified_pairs": book_build_guard.MIN_QUALIFIED_PAIRS,
            "qualified_pairs": len(qualified),
            "distinct_eas": venue_status["dxz"]["distinct_eas"],
            "strategy_families": venue_status["dxz"]["strategy_families"],
            "venues": venue_status,
        },
    }


def render_operator_surface_html(snapshot: dict[str, Any]) -> str:
    """Render the shared bands/frontier/guard block without legacy phase keys."""

    esc = lambda value: html.escape(str(value)) if value is not None else ""  # noqa: E731
    bands = []
    for band in snapshot.get("phase_bands") or []:
        gates = "".join(
            f'<span class="op-gate" title="{esc(gate["label"])}">'
            f'{esc(gate["linear_gate_id"])}</span>'
            for gate in band.get("gates") or []
        )
        bands.append(
            '<div class="op-band">'
            f'<div class="op-band-id">{esc(band.get("id"))}</div>'
            f'<div class="op-band-name">{esc(band.get("name"))}</div>'
            f'<div class="op-band-gates">{gates}</div>'
            '</div>'
        )

    guard = snapshot.get("book_guard") or {}
    venues = guard.get("venues") or {}
    order_bits = []
    for venue in ("dxz", "ftmo"):
        status = venues.get(venue) or {}
        order_bits.append(
            f'{venue.upper()} order {"present" if status.get("owner_order_present") else "missing"}'
        )
    guard_html = (
        '<div class="op-guard">'
        '<div class="op-guard-title">Book guard</div>'
        f'<strong>{int(guard.get("qualified_pairs") or 0)} / '
        f'{int(guard.get("minimum_qualified_pairs") or 25)}</strong>'
        f'<span>{int(guard.get("distinct_eas") or 0)} distinct EAs · '
        f'{int(guard.get("strategy_families") or 0)} families · '
        f'{esc(" · ".join(order_bits))}</span>'
        '</div>'
    )

    pair_rows = []
    for row in snapshot.get("pairs") or []:
        observed = row.get("highest_observed_label") or "none"
        contiguous = row.get("highest_contiguous_valid_label") or "none"
        pair_rows.append(
            '<tr>'
            f'<td><code>{esc(row.get("ea_id"))}</code></td>'
            f'<td><code>{esc(row.get("symbol"))}</code></td>'
            f'<td>{esc(observed)}</td>'
            f'<td>{esc(contiguous)}</td>'
            f'<td>{esc(row.get("disposition"))}</td>'
            '</tr>'
        )
    if not pair_rows:
        pair_rows.append('<tr><td colspan="5">No pair evidence.</td></tr>')

    return (
        '<style>'
        '.operator-gates{margin:18px 0;padding:16px;border:1px solid var(--border,#334155);'
        'border-radius:10px;background:var(--surface-1,#111827)}'
        '.op-contract,.op-band-id,.op-guard span{color:var(--text-3,#94a3b8)}'
        '.op-bands{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin:12px 0}'
        '.op-band,.op-guard{padding:12px;border:1px solid var(--border-2,#475569);border-radius:8px}'
        '.op-band-name,.op-guard-title{font-weight:700;margin:4px 0 8px}'
        '.op-band-gates{display:flex;flex-wrap:wrap;gap:5px}'
        '.op-gate{padding:2px 5px;border-radius:4px;background:var(--surface-2,#1e293b);font-family:monospace}'
        '.op-guard{display:flex;align-items:center;gap:12px;margin:10px 0}'
        '.op-pairs table{width:100%;margin-top:10px;border-collapse:collapse}'
        '.op-pairs th,.op-pairs td{padding:6px;text-align:left;border-bottom:1px solid var(--border-2,#334155)}'
        '@media(max-width:900px){.op-bands{grid-template-columns:1fr}.op-guard{align-items:flex-start;flex-direction:column}}'
        '</style>'
        '<section class="operator-gates" id="operator-gates">'
        '<h2>Linear gate frontier</h2>'
        f'<div class="op-contract">contract {esc(snapshot.get("gate_contract_version"))} · '
        'progress = highest_contiguous_valid_gate</div>'
        f'<div class="op-bands">{"".join(bands)}</div>'
        f'{guard_html}'
        '<details class="op-pairs" open><summary>'
        f'{int(snapshot.get("pair_count") or 0)} EA/symbol frontiers</summary>'
        '<table><thead><tr><th>EA</th><th>Symbol</th>'
        '<th>Highest observed gate</th><th>Highest contiguous valid gate</th>'
        '<th>Disposition</th></tr></thead>'
        f'<tbody>{"".join(pair_rows)}</tbody></table></details>'
        '</section>'
    )
