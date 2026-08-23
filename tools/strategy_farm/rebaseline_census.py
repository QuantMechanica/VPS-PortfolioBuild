#!/usr/bin/env python3
"""rebaseline_census.py -- historical test census for the 2026-08-23 pipeline rebaseline.

READ-ONLY. Opens the farm state DB with a ``mode=ro`` URI and a short busy timeout;
it never writes to the database, never enqueues, never touches verdict rows.

For every ``(ea_id, symbol)`` pair (and the finer key
``(ea_id, symbol, build_hash, setfile_hash)``) it summarises every phase ever run
against the active gate contract and assigns a rebaseline disposition.
Thresholds/criteria are NOT redefined here -- this is a classification of
*existing* evidence, not a new gate.

Outputs:
  * D:/QM/reports/rebaseline/census_<date>.csv    (one row per (ea_id, symbol) pair)
  * D:/QM/reports/rebaseline/census_<date>.json   (summary + counts)
  * D:/QM/reports/rebaseline/census_finer_<date>.csv (one row per exact hash key x gate)
  * docs/ops/rebaseline/DB_TEST_CENSUS_<date>.md  (markdown summary, written separately)

The markdown summary is written by --write-md (default on) to the repo docs tree.

Design notes (evidence):
  * work_items columns: id, kind, phase, ea_id, symbol, setfile_path, status,
    verdict, ... payload_json (PRAGMA table_info work_items).
  * build_hash / setfile_hash are NOT columns; they live in payload_json under a
    handful of keys (see farmctl.py enqueue-backtest / artifact binding, e.g.
    expected_ex5_sha256 @ farmctl.py:6128, expected_setfile_sha256 @ 6130,
    build_hash / setfile_build_hash). Coverage is partial (~11% of rows).
  * INFRA vs economic split follows the verdict column, which already carries
    'INFRA_FAIL' as its own value (see health.py:2205 chk_phase_infra_graveyard and
    farmctl.py:5144 infra_reasons). Economic FAIL is kept separate from INFRA/INVALID.
"""
from __future__ import annotations

import argparse
import csv
import datetime as _dt
import json
import os
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm.phase_ids import (
    ACTIVE_GATE_CONTRACT_VERSION,
    ACTIVE_GATE_MANIFEST,
    phase_label,
    phase_qid,
)

DEFAULT_DB = "D:/QM/strategy_farm/state/farm_state.sqlite"
DEFAULT_OUT_DIR = "D:/QM/reports/rebaseline"
DEFAULT_MD_PATH = "docs/ops/rebaseline"

# ---------------------------------------------------------------------------
# Automated contiguity chain. v3 retains its main chain plus optimization fork;
# v4 is strictly linear from Q02 through its declared terminal requalification
# gate. Q00/Q01 and post-qualification OWNER/book gates are not part of it.
# ---------------------------------------------------------------------------
if ACTIVE_GATE_CONTRACT_VERSION == "v4":
    terminal = ACTIVE_GATE_MANIFEST.terminal_requalification_gate
    terminal_ordinal = next(
        gate.ordinal for gate in ACTIVE_GATE_MANIFEST.gates if gate.id == terminal
    )
    GATE_CHAIN = [
        gate.id
        for gate in ACTIVE_GATE_MANIFEST.gates
        if 2 <= gate.ordinal <= terminal_ordinal
    ]
else:
    GATE_CHAIN = [
        "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q10",
        "Q14", "Q15", "Q16",
    ]
GATE_ORDINAL = {g: i for i, g in enumerate(GATE_CHAIN)}
NEWS_GATE = ACTIVE_GATE_MANIFEST.gate_for_role("NEWS")
NEWS_STORAGE_PHASES = {
    ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS", "NEWS"),
    ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS", "PORTFOLIO"),
}

# Legacy P* aliases mapped to canonical Qxx (gate_manifest.v3 legacy_aliases,
# in-chain subset only). Out-of-chain legacy keys map to None.
LEGACY_ALIAS = {
    "G0": None, "P1": None, "P2": "Q02", "P3": "Q03", "P3.5": "Q03",
    "P4": "Q04", "P5": "Q05", "P5B": "Q05", "P5C": "Q05", "P6": "Q07",
    "P7": "Q08", "P8": "Q08", "P9": None, "P9B": None, "P10": None,
}
# storage phases that are not gates on the contiguity chain
NONCHAIN_PHASES = {
    "OPT_CENSUS", "COMPILE_EA", "HARNESS_PP_FIXTURE",
    "Q00", "Q01", "Q11", "Q12", "Q13",
}

# ---------------------------------------------------------------------------
# Verdict classification. The verdict column is authoritative for the
# INFRA/economic split. PASS-class = economic pass used for gate validity.
# ---------------------------------------------------------------------------
PASS_ECON = {
    "PASS",
    "PASS_SOFT",
    "PASS_LOWFREQ",
    "PASS_PORTFOLIO",
    # Terminal requalification outcomes are successful contiguous evidence,
    # not ordinary PASS tokens.  Preserve both the current v3 spelling and the
    # v4 proposal spelling; ADMIT_BOTH remains a valid historical v3 outcome.
    "PROMOTE_CHALLENGER",
    "CHALLENGER_PROMOTED",
    "KEEP_INCUMBENT",
    "ADMIT_BOTH",
}
ECON_FAIL = {
    "FAIL", "FAIL_HARD", "FAIL_SOFT", "ZERO_TRADES", "RETIRE",
    "RETIRED_LOW_FREQ", "FAIL_PORTFOLIO", "FAIL_DD_PORTFOLIO_REVIEW",
    "NEED_MORE_DATA", "OPT_REJECTED",
}
INFRA_CLS = {"INFRA_FAIL"}
INVALID_CLS = {
    "INVALID", "INVALID_BUILD_STATIC_FIDELITY", "INVALID_EVIDENCE",
    "COMPILE_FAIL", "DRAFT_DEFECT", "REVIEW_REQUIRED", "PENDING_RUNNER",
    "BLOCKED_FACTORY_OFF",
}
STALE_CLS = {
    "SUPERSEDED", "SUPERSEDED_BY_LOGICAL_BASKET", "SUPERSEDED_DUPLICATE",
    "BLOCKED_STALE_BUILD_RESULT", "RETIRED_ARCHIVED", "RETIRED_WITHOUT_BUILD",
    "CANCELLED_DUPLICATE_REQUEUE", "CHALLENGER_SPAWNED", "CONFIG_LOCKED",
}
NA_CLS = {"OBSOLETE_NON_DWX_SYMBOL"}

# priority order when a gate carries several non-pass verdict classes
_FRONTIER_PRIORITY = ["ECON_FAIL", "NA", "STALE", "INFRA", "INVALID", "OTHER"]

# payload keys, in priority order, from which build/setfile hashes are extracted
BUILD_HASH_KEYS = [
    "expected_ex5_sha256", "ex5_sha256", "compiled_ex5_sha256",
    "staged_ex5_sha256", "expected_current_ex5_sha256", "build_hash",
    "expected_mq5_sha256", "mq5_sha256",
]
SETFILE_HASH_KEYS = [
    "expected_setfile_sha256", "setfile_sha256", "setfile_build_hash",
]


def canonical_gate(
    phase: str | None, gate_contract_version: str | None = None
) -> str | None:
    """Map a versioned storage phase to the active v3 census gate.

    ``phase_qid`` performs the explicit v3/v4 contract translation first.  The
    small lane collapse below is storage normalization only (NEWS/PORTFOLIO are
    both evidence for their parent gate), never an ordinal guess.
    """
    p = phase_qid(phase, gate_contract_version).strip().upper()
    if p in GATE_ORDINAL:
        return p
    if p in NEWS_STORAGE_PHASES:
        return NEWS_GATE
    if p in NONCHAIN_PHASES:
        return None
    if p in LEGACY_ALIAS:
        return LEGACY_ALIAS[p]
    return None


def vclass(verdict: str | None) -> str:
    """Classify a verdict string into a coarse class."""
    v = (verdict or "").strip().upper()
    if v in PASS_ECON:
        return "PASS"
    if v in NA_CLS:
        return "NA"
    if v in STALE_CLS:
        return "STALE"
    if v in ECON_FAIL:
        return "ECON_FAIL"
    if v in INFRA_CLS:
        return "INFRA"
    if v in INVALID_CLS:
        return "INVALID"
    return "OTHER"  # None / pending / OPT_ELIGIBLE / MEASURED / HARNESS_OK / ...


# ---------------------------------------------------------------------------
# DB access
# ---------------------------------------------------------------------------

def open_ro(db_path: str) -> sqlite3.Connection:
    """Open the DB strictly read-only via a mode=ro URI with a short busy timeout."""
    norm = db_path.replace("\\", "/")
    uri = f"file:{norm}?mode=ro"
    con = sqlite3.connect(uri, uri=True, timeout=5)
    con.execute("PRAGMA busy_timeout=3000")
    con.row_factory = sqlite3.Row
    return con


def _has_column(con: sqlite3.Connection, table: str, column: str) -> bool:
    return any(str(row[1]).lower() == column.lower() for row in con.execute(
        f"PRAGMA table_info({table})"
    ))


def _iter_pair_rows(con: sqlite3.Connection, limit: int | None):
    """Yield (ea_id, symbol, phase, status, verdict) rows.

    When ``limit`` is set, restrict to the first ``limit`` distinct pairs (smoke).
    Set-based: pair-level census needs no payload parse at all.
    """
    contract_expr = (
        "gate_contract_version" if _has_column(con, "work_items", "gate_contract_version")
        else "NULL AS gate_contract_version"
    )
    if limit:
        sql = (
            f"SELECT ea_id, symbol, phase, status, verdict, {contract_expr} FROM work_items "
            "WHERE (ea_id, symbol) IN ("
            "  SELECT ea_id, symbol FROM ("
            "    SELECT DISTINCT ea_id, symbol FROM work_items "
            "    WHERE ea_id IS NOT NULL AND ea_id <> '' "
            "      AND symbol IS NOT NULL AND symbol <> '' "
            "    ORDER BY ea_id, symbol LIMIT ?))"
        )
        cur = con.execute(sql, (limit,))
    else:
        sql = (
            f"SELECT ea_id, symbol, phase, status, verdict, {contract_expr} FROM work_items "
            "WHERE ea_id IS NOT NULL AND ea_id <> '' "
            "  AND symbol IS NOT NULL AND symbol <> ''"
        )
        cur = con.execute(sql)
    yield from cur


def _iter_hash_rows(con: sqlite3.Connection, limit: int | None):
    """Yield (ea_id, symbol, phase, status, verdict, payload_json) for the subset
    of rows whose payload plausibly carries a build/setfile hash. Substring
    pre-filter keeps this far below the full 111k-row table."""
    contract_expr = (
        "gate_contract_version" if _has_column(con, "work_items", "gate_contract_version")
        else "NULL AS gate_contract_version"
    )
    base = (
        f"SELECT ea_id, symbol, phase, status, verdict, payload_json, {contract_expr} FROM work_items "
        "WHERE ea_id IS NOT NULL AND ea_id <> '' "
        "  AND symbol IS NOT NULL AND symbol <> '' "
        "  AND payload_json IS NOT NULL "
        "  AND (payload_json LIKE '%sha256%' OR payload_json LIKE '%build_hash%')"
    )
    if limit:
        sql = base + (
            " AND (ea_id, symbol) IN (SELECT ea_id, symbol FROM ("
            "   SELECT DISTINCT ea_id, symbol FROM work_items "
            "   WHERE ea_id IS NOT NULL AND ea_id <> '' "
            "     AND symbol IS NOT NULL AND symbol <> '' "
            "   ORDER BY ea_id, symbol LIMIT ?))"
        )
        cur = con.execute(sql, (limit,))
    else:
        cur = con.execute(base)
    yield from cur


def _extract_hash(payload: dict, keys: list[str]) -> str:
    for k in keys:
        v = payload.get(k)
        if v:
            v = str(v).strip().lower()
            if v and v not in ("none", "null"):
                return v
    return ""


# ---------------------------------------------------------------------------
# Per-pair aggregation model
# ---------------------------------------------------------------------------

def _new_gate() -> dict:
    return {
        "rows": 0,
        "valid_canonical": False,  # done + PASS via canonical Qxx phase
        "valid_legacy": False,     # done + PASS via legacy P* phase
        "classes": Counter(),      # non-pass class -> count (for frontier)
        "verdicts": Counter(),     # raw verdict -> count
        "statuses": Counter(),
        "observed_labels": set(),
        "valid_labels": set(),
    }


def build_pairs(con: sqlite3.Connection, limit: int | None) -> dict:
    pairs: dict[tuple[str, str], dict] = {}
    for ea_id, symbol, phase, status, verdict, contract_version in _iter_pair_rows(con, limit):
        key = (ea_id, symbol)
        rec = pairs.get(key)
        if rec is None:
            rec = pairs[key] = {
                "gates": defaultdict(_new_gate),
                "phases_run": Counter(),
                "all_verdicts": Counter(),
                "offchain_phases": Counter(),
            }
        rec["phases_run"][(phase or "")] += 1
        rec["all_verdicts"][(verdict or "")] += 1
        g = canonical_gate(phase, contract_version)
        if g is None:
            rec["offchain_phases"][(phase or "")] += 1
            continue
        gd = rec["gates"][g]
        gd["rows"] += 1
        gd["statuses"][(status or "")] += 1
        gd["verdicts"][(verdict or "")] += 1
        label = phase_label(phase, contract_version, include_name=True)
        gd["observed_labels"].add(label)
        cls = vclass(verdict)
        is_done = (status or "").strip().lower() == "done"
        if cls == "PASS" and is_done:
            gd["valid_labels"].add(label)
            raw = (phase or "").strip().upper()
            if raw in GATE_ORDINAL or raw.startswith("Q09"):
                gd["valid_canonical"] = True
            else:
                gd["valid_legacy"] = True
        else:
            gd["classes"][cls] += 1
    return pairs


def summarise_pair(rec: dict) -> dict:
    gates = rec["gates"]

    # highest observed gate (any row)
    observed = [g for g in gates if gates[g]["rows"] > 0]
    highest_observed = max(observed, key=lambda g: GATE_ORDINAL[g]) if observed else ""

    def preferred_label(gate: str, key: str) -> str:
        labels = list((gates.get(gate) or {}).get(key) or [])
        # Prefer a provenance-bearing form when a mixed-contract fixture has
        # more than one representation of the same active gate.
        return max(labels, key=lambda value: ("(" in value, value)) if labels else ""

    # contiguous validity walk
    hcvg = ""
    legacy_only_valid = False
    frontier = None
    for g in GATE_CHAIN:
        gd = gates.get(g)
        valid = bool(gd) and (gd["valid_canonical"] or gd["valid_legacy"])
        if valid:
            hcvg = g
            if gd["valid_legacy"] and not gd["valid_canonical"]:
                legacy_only_valid = True
        else:
            frontier = g
            break
    else:
        frontier = None  # fully valid through Q16

    # frontier classification
    if frontier is None:
        frontier_class = "COMPLETE"
    else:
        gd = gates.get(frontier)
        if not gd or gd["rows"] == 0:
            frontier_class = "MISSING"
        else:
            frontier_class = "OTHER"
            for c in _FRONTIER_PRIORITY:
                if gd["classes"].get(c):
                    frontier_class = c
                    break

    frontier_infra = frontier_class == "INFRA"

    # disposition
    if frontier is None:
        disposition = "RENUMBER_ONLY" if legacy_only_valid else "REUSABLE"
    elif frontier_class == "NA":
        disposition = "NOT_APPLICABLE"
    elif frontier_class == "ECON_FAIL":
        disposition = "ECONOMIC_FAIL"
    elif hcvg:  # reusable lower evidence, frontier is a continuable rerun
        disposition = "RENUMBER_ONLY" if legacy_only_valid else "REUSABLE"
    elif frontier_class == "STALE":
        disposition = "STALE"
    elif frontier_class in ("INFRA", "INVALID"):
        disposition = "INVALID"
    else:  # OTHER / MISSING with no valid gate at all
        disposition = "MISSING"

    # macro phase (rebaseline directive: 1 Strategiebeweis Q02-Q10,
    # 2 Optimierung/Requalifikation Q14-Q16, 3 Buchbewertung Q11-Q13)
    if highest_observed in ("Q14", "Q15", "Q16"):
        macro = "2_OPTIMIERUNG"
    elif highest_observed:
        macro = "1_STRATEGIEBEWEIS"
    else:
        macro = "0_NONE"

    return {
        "highest_observed_gate": highest_observed,
        "highest_observed_label": preferred_label(highest_observed, "observed_labels") if highest_observed else "",
        "highest_contiguous_valid_gate": hcvg,
        "highest_contiguous_valid_label": preferred_label(hcvg, "valid_labels") if hcvg else "",
        "earliest_missing_prerequisite": frontier or "",
        "frontier_class": frontier_class,
        "frontier_infra": frontier_infra,
        "disposition": disposition,
        "macro_phase": macro,
        "n_rows": sum(gates[g]["rows"] for g in gates),
        "phases_run": ";".join(sorted(p for p in rec["phases_run"] if p)),
        "verdicts_seen": ";".join(
            f"{v}:{c}" for v, c in rec["all_verdicts"].most_common() if v
        ),
    }


# ---------------------------------------------------------------------------
# Finer key (ea_id, symbol, build_hash, setfile_hash)
# ---------------------------------------------------------------------------

def build_finer(con: sqlite3.Connection, limit: int | None) -> dict:
    finer: dict[tuple, dict] = {}
    for (ea_id, symbol, phase, status, verdict, payload_json,
         contract_version) in _iter_hash_rows(con, limit):
        try:
            payload = json.loads(payload_json)
        except (ValueError, TypeError):
            continue
        if not isinstance(payload, dict):
            continue
        bh = _extract_hash(payload, BUILD_HASH_KEYS)
        sh = _extract_hash(payload, SETFILE_HASH_KEYS)
        if not bh and not sh:
            continue
        g = canonical_gate(phase, contract_version)
        if g is None:
            continue
        key = (ea_id, symbol, bh, sh, g)
        rec = finer.get(key)
        if rec is None:
            rec = finer[key] = {
                "phase": phase, "n": 0, "pass": 0, "econ_fail": 0,
                "infra": 0, "invalid": 0, "stale": 0, "other": 0, "valid": False,
            }
        rec["n"] += 1
        cls = vclass(verdict)
        is_done = (status or "").strip().lower() == "done"
        if cls == "PASS":
            rec["pass"] += 1
            if is_done:
                rec["valid"] = True
        elif cls == "ECON_FAIL":
            rec["econ_fail"] += 1
        elif cls == "INFRA":
            rec["infra"] += 1
        elif cls == "INVALID":
            rec["invalid"] += 1
        elif cls == "STALE":
            rec["stale"] += 1
        else:
            rec["other"] += 1
    return finer


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

PAIR_CSV_COLUMNS = [
    "ea_id", "symbol", "macro_phase", "disposition",
    "highest_observed_gate", "highest_observed_label",
    "highest_contiguous_valid_gate", "highest_contiguous_valid_label",
    "earliest_missing_prerequisite", "frontier_class", "frontier_infra",
    "n_rows", "phases_run", "verdicts_seen",
]

FINER_CSV_COLUMNS = [
    "ea_id", "symbol", "build_hash", "setfile_hash", "gate", "phase",
    "n", "pass", "econ_fail", "infra", "invalid", "stale", "other", "valid",
]


def compute(con: sqlite3.Connection, limit: int | None) -> dict:
    pairs = build_pairs(con, limit)
    pair_rows = []
    for (ea_id, symbol), rec in pairs.items():
        s = summarise_pair(rec)
        row = {"ea_id": ea_id, "symbol": symbol}
        row.update(s)
        pair_rows.append(row)
    pair_rows.sort(key=lambda r: (r["ea_id"], r["symbol"]))

    finer = build_finer(con, limit)
    finer_rows = []
    for (ea_id, symbol, bh, sh, g), rec in finer.items():
        finer_rows.append({
            "ea_id": ea_id, "symbol": symbol, "build_hash": bh,
            "setfile_hash": sh, "gate": g, "phase": rec["phase"],
            "n": rec["n"], "pass": rec["pass"], "econ_fail": rec["econ_fail"],
            "infra": rec["infra"], "invalid": rec["invalid"],
            "stale": rec["stale"], "other": rec["other"],
            "valid": int(rec["valid"]),
        })
    finer_rows.sort(key=lambda r: (r["ea_id"], r["symbol"], r["build_hash"],
                                   r["setfile_hash"], GATE_ORDINAL.get(r["gate"], 99)))

    summary = build_summary(pair_rows, finer_rows)
    return {"pair_rows": pair_rows, "finer_rows": finer_rows, "summary": summary}


def build_summary(pair_rows: list[dict], finer_rows: list[dict]) -> dict:
    by_macro = Counter(r["macro_phase"] for r in pair_rows)
    by_hcvg = Counter(r["highest_contiguous_valid_gate"] or "NONE" for r in pair_rows)
    by_disp = Counter(r["disposition"] for r in pair_rows)
    by_frontier = Counter(r["earliest_missing_prerequisite"] or "NONE" for r in pair_rows)
    by_frontier_class = Counter(r["frontier_class"] for r in pair_rows)
    by_highest_obs = Counter(r["highest_observed_gate"] or "NONE" for r in pair_rows)

    def ge(gate_id):
        floor = GATE_ORDINAL[gate_id]
        return sum(
            1 for r in pair_rows
            if r["highest_contiguous_valid_gate"]
            and GATE_ORDINAL.get(r["highest_contiguous_valid_gate"], -1) >= floor
        )

    def valid_at(gate_id):
        floor = GATE_ORDINAL[gate_id]
        return sum(
            1 for r in pair_rows
            if r["highest_contiguous_valid_gate"]
            and GATE_ORDINAL.get(r["highest_contiguous_valid_gate"], -1) >= floor
        )

    # INFRA vs economic split among pairs that are NOT reusable/renumber/complete
    non_reusable = [r for r in pair_rows
                    if r["disposition"] not in ("REUSABLE", "RENUMBER_ONLY")]
    infra_blocked = sum(1 for r in pair_rows if r["frontier_infra"])
    econ_fail_pairs = by_disp.get("ECONOMIC_FAIL", 0)
    invalid_pairs = by_disp.get("INVALID", 0)

    return {
        "total_pairs": len(pair_rows),
        "total_finer_keys": len({(r["ea_id"], r["symbol"], r["build_hash"],
                                  r["setfile_hash"]) for r in finer_rows}),
        "total_finer_rows": len(finer_rows),
        "by_macro_phase": dict(by_macro),
        "by_highest_contiguous_valid_gate": dict(by_hcvg),
        "by_highest_observed_gate": dict(by_highest_obs),
        "by_disposition": dict(by_disp),
        "by_earliest_missing_prerequisite": dict(by_frontier),
        "by_frontier_class": dict(by_frontier_class),
        "pairs_valid_at_least_Q08": valid_at("Q08"),
        # These public keys predate v4.  Preserve their names while resolving
        # the v3 semantic gates into the active contract (Q10->Q11 and
        # Q16->Q14 after the flip).
        "pairs_valid_at_least_Q10": valid_at(phase_qid("Q10", "v3")),
        "pairs_valid_at_least_Q16": valid_at(phase_qid("Q16", "v3")),
        "infra_vs_economic": {
            "infra_blocked_frontier_pairs": infra_blocked,
            "economic_fail_pairs": econ_fail_pairs,
            "invalid_disposition_pairs": invalid_pairs,
            "non_reusable_pairs": len(non_reusable),
        },
    }


def write_csv(path: str, rows: list[dict], columns: list[str]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=columns)
        w.writeheader()
        for r in rows:
            w.writerow({c: r.get(c, "") for c in columns})


def write_json(path: str, summary: dict, meta: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"meta": meta, "summary": summary}, fh, indent=2, sort_keys=True)


def render_markdown(summary: dict, meta: dict) -> str:
    L = []
    L.append("# DB Historical Test Census -- Pipeline Rebaseline")
    L.append("")
    L.append(f"Generated: {meta['generated_at']} | DB: `{meta['db_path']}` "
             f"| limit: {meta['limit']}")
    L.append("")
    L.append("Read-only census of every `(ea_id, symbol)` pair against the "
             "strictly-linear v3 gate chain "
             "(`Q02..Q10` main, `Q14,Q15,Q16` optimization fork). A gate counts "
             "**valid** only with a `done` row carrying an economic PASS-class "
             "verdict AND every earlier gate valid. Thresholds are unchanged (ROT); "
             "this classifies existing evidence only.")
    L.append("")
    s = summary
    L.append(f"- **Total (ea_id, symbol) pairs:** {s['total_pairs']}")
    L.append(f"- **Distinct finer keys** (ea_id, symbol, build_hash, setfile_hash) "
             f"with hash evidence: {s['total_finer_keys']} "
             f"({s['total_finer_rows']} hash-key x gate rows)")
    L.append(f"- **Pairs valid >= Q08:** {s['pairs_valid_at_least_Q08']}")
    L.append(f"- **Pairs valid >= Q10:** {s['pairs_valid_at_least_Q10']}")
    L.append(f"- **Pairs valid >= Q16:** {s['pairs_valid_at_least_Q16']}")
    L.append("")

    def table(title, d, order=None):
        L.append(f"### {title}")
        L.append("")
        L.append("| key | pairs |")
        L.append("|---|---:|")
        items = ([(k, d[k]) for k in order if k in d] if order
                 else sorted(d.items(), key=lambda kv: (-kv[1], str(kv[0]))))
        for k, v in items:
            L.append(f"| {k} | {v} |")
        L.append("")

    table("Pairs per macro phase", s["by_macro_phase"],
          order=["1_STRATEGIEBEWEIS", "2_OPTIMIERUNG", "0_NONE"])
    table("Pairs per highest contiguous valid gate",
          s["by_highest_contiguous_valid_gate"],
          order=["NONE"] + GATE_CHAIN)
    table("Pairs per disposition", s["by_disposition"],
          order=["REUSABLE", "RENUMBER_ONLY", "ECONOMIC_FAIL", "INVALID",
                 "STALE", "MISSING", "NOT_APPLICABLE"])
    table("Pairs per earliest missing prerequisite",
          s["by_earliest_missing_prerequisite"],
          order=["NONE"] + GATE_CHAIN)
    table("Pairs per highest observed gate (any status)",
          s["by_highest_observed_gate"], order=GATE_CHAIN + ["NONE"])

    iv = s["infra_vs_economic"]
    L.append("### INFRA vs economic split")
    L.append("")
    L.append("| bucket | pairs |")
    L.append("|---|---:|")
    L.append(f"| frontier blocked by INFRA_FAIL | {iv['infra_blocked_frontier_pairs']} |")
    L.append(f"| ECONOMIC_FAIL disposition | {iv['economic_fail_pairs']} |")
    L.append(f"| INVALID disposition (infra/invalid, no valid gate) | {iv['invalid_disposition_pairs']} |")
    L.append(f"| non-reusable pairs total | {iv['non_reusable_pairs']} |")
    L.append("")
    L.append("**Disposition legend:** `REUSABLE` = has contiguous valid evidence "
             "reusable under the new contract (frontier is a continuable rerun); "
             "`RENUMBER_ONLY` = reusable but valid evidence sits under legacy P* keys "
             "needing only renumbering; `ECONOMIC_FAIL` = frontier gate rejected on "
             "economic merit (dead on merit); `INVALID` = frontier is INFRA/INVALID with "
             "no valid gate below (rerun, not a strategy verdict); `STALE` = superseded "
             "build; `MISSING` = no evidence at frontier; `NOT_APPLICABLE` = structurally "
             "not testable/tradeable (e.g. non-DWX symbol).")
    L.append("")
    L.append("_Evidence: pair CSV and finer CSV under "
             f"`{meta['csv_path']}` / `{meta['finer_csv_path']}`; JSON summary "
             f"`{meta['json_path']}`._")
    L.append("")
    return "\n".join(L)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", default=DEFAULT_DB)
    ap.add_argument("--out-dir", default=DEFAULT_OUT_DIR)
    ap.add_argument("--md-dir", default=DEFAULT_MD_PATH)
    ap.add_argument("--date", default=_dt.date.today().isoformat())
    ap.add_argument("--limit", type=int, default=None,
                    help="restrict to first N distinct (ea_id,symbol) pairs (smoke)")
    ap.add_argument("--no-md", action="store_true", help="skip markdown output")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    con = open_ro(args.db)
    try:
        result = compute(con, args.limit)
    finally:
        con.close()

    date = args.date
    csv_path = os.path.join(args.out_dir, f"census_{date}.csv").replace("\\", "/")
    finer_csv_path = os.path.join(args.out_dir, f"census_finer_{date}.csv").replace("\\", "/")
    json_path = os.path.join(args.out_dir, f"census_{date}.json").replace("\\", "/")
    md_path = os.path.join(args.md_dir, f"DB_TEST_CENSUS_{date}.md").replace("\\", "/")

    meta = {
        "generated_at": _dt.datetime.now().isoformat(timespec="seconds"),
        "db_path": args.db,
        "limit": args.limit,
        "date": date,
        "csv_path": csv_path,
        "finer_csv_path": finer_csv_path,
        "json_path": json_path,
        "gate_chain": GATE_CHAIN,
    }

    write_csv(csv_path, result["pair_rows"], PAIR_CSV_COLUMNS)
    write_csv(finer_csv_path, result["finer_rows"], FINER_CSV_COLUMNS)
    write_json(json_path, result["summary"], meta)

    if not args.no_md:
        md = render_markdown(result["summary"], meta)
        os.makedirs(os.path.dirname(md_path), exist_ok=True)
        with open(md_path, "w", encoding="utf-8") as fh:
            fh.write(md)

    if not args.quiet:
        print(json.dumps({"meta": meta, "summary": result["summary"]},
                         indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
