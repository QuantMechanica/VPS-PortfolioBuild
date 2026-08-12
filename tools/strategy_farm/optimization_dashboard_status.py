#!/usr/bin/env python3
"""Read-only cockpit projection for the Q14--Q16 optimization extension.

This module deliberately has no enqueue, worker, deployment, terminal, or
AutoTrading capability.  It reads already-recorded farm evidence and parked
Q11_DXZ/Q11_FTMO dry-run manifests; missing or malformed inputs are surfaced
fail-closed instead of being rendered as successful.
"""

from __future__ import annotations

import json
import re
import sqlite3
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "qm.optimization-track-dashboard/v1"
OPTIMIZATION_PHASES = ("Q14", "Q15", "Q16")
PHASE_OUTCOMES = {
    "Q14": ("OPT_ELIGIBLE", "OPT_REJECTED"),
    "Q15": ("CHALLENGER_SPAWNED", "FAIL"),
    "Q16": ("PROMOTE_CHALLENGER", "KEEP_INCUMBENT", "ADMIT_BOTH", "FAIL"),
}
BOOK_LANES = {
    "Q11_DXZ": ("book_dxz_*", {"APPLY_RECOMMENDED", "NOT_WORSE_BAR_NOT_MET"}),
    "Q11_FTMO": ("book_ftmo_*", {"BAR_MET_OWNER_REVIEW", "BAR_NOT_MET"}),
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
DATE_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
SLEEVE_REQUIRED = {"ea_id", "symbol", "magic", "setfile", "setfile_sha256", "weight"}
SLEEVE_ALLOWED = SLEEVE_REQUIRED | {
    "backtest_risk_fixed",
    "backtest_risk_percent",
    "risk_fixed",
    "risk_fixed_source",
    "risk_percent",
    "risk_percent_source",
    "fund_score",
}


def _empty_phase(phase: str) -> dict[str, Any]:
    return {
        "phase": phase,
        "total": 0,
        "open": 0,
        "outcomes": {verdict: 0 for verdict in PHASE_OUTCOMES[phase]},
    }


def _manifest_errors(
    value: dict[str, Any], lane: str, allowed_statuses: set[str]
) -> list[str]:
    errors = []
    required = {
        "schema": "qm.dual-book-manifest/v1",
        "lane": lane,
        "execution_mode": "DRY_RUN",
        "application_authority": "OWNER_ONLY",
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
    }
    errors.extend(
        f"{key}={value.get(key)!r}"
        for key, expected in required.items()
        if value.get(key) != expected
    )
    if value.get("status") not in allowed_statuses:
        errors.append(f"status={value.get('status')!r}")
    if not DATE_RE.fullmatch(str(value.get("as_of") or "")):
        errors.append("as_of must be YYYY-MM-DD")
    for key in ("roster_sha256", "sleeve_list_sha256"):
        if not SHA256_RE.fullmatch(str(value.get(key) or "")):
            errors.append(f"{key} must be lowercase SHA-256")

    lane_objects = (
        ("weighting", "comparison", "stream_basis")
        if lane == "Q11_DXZ"
        else ("fund_score", "density", "ftmo_cost_swap", "phase1_bootstrap", "bar")
    )
    for key in lane_objects:
        if not isinstance(value.get(key), dict):
            errors.append(f"{key} must be an object")
    if lane == "Q11_FTMO" and value.get("challenge_recommendation") != "NONE":
        errors.append(f"challenge_recommendation={value.get('challenge_recommendation')!r}")

    sleeves = value.get("sleeves")
    if not isinstance(sleeves, list):
        errors.append("sleeves must be an array")
        return errors
    for index, sleeve in enumerate(sleeves):
        if not isinstance(sleeve, dict):
            errors.append(f"sleeves[{index}] must be an object")
            continue
        missing = SLEEVE_REQUIRED - set(sleeve)
        extra = set(sleeve) - SLEEVE_ALLOWED
        if missing or extra:
            errors.append(
                f"sleeves[{index}] key mismatch missing={sorted(missing)} extra={sorted(extra)}"
            )
            continue
        if (
            not isinstance(sleeve["ea_id"], int)
            or isinstance(sleeve["ea_id"], bool)
            or sleeve["ea_id"] < 1
        ):
            errors.append(f"sleeves[{index}].ea_id must be a positive integer")
        if (
            not isinstance(sleeve["magic"], int)
            or isinstance(sleeve["magic"], bool)
            or sleeve["magic"] < 1
        ):
            errors.append(f"sleeves[{index}].magic must be a positive integer")
        if not SHA256_RE.fullmatch(str(sleeve.get("setfile_sha256") or "")):
            errors.append(f"sleeves[{index}].setfile_sha256 must be lowercase SHA-256")
        if not isinstance(sleeve.get("symbol"), str) or not sleeve["symbol"]:
            errors.append(f"sleeves[{index}].symbol must be non-empty")
        if not isinstance(sleeve.get("setfile"), str) or not sleeve["setfile"]:
            errors.append(f"sleeves[{index}].setfile must be non-empty")
        weight = sleeve.get("weight")
        if isinstance(weight, bool) or not isinstance(weight, (int, float)) or weight <= 0:
            errors.append(f"sleeves[{index}].weight must be positive")
    return errors


def _book_status(report_root: Path, lane: str) -> dict[str, Any]:
    pattern, allowed_statuses = BOOK_LANES[lane]
    manifests = sorted(
        report_root.glob(f"{pattern}/manifest.json"),
        key=lambda path: path.parent.name,
    )
    if not manifests:
        return {
            "lane": lane,
            "validation": "MISSING",
            "book_status": "MISSING",
            "manifest_path": None,
        }

    manifest_path = manifests[-1]
    result: dict[str, Any] = {
        "lane": lane,
        "validation": "INVALID",
        "book_status": "INVALID",
        "manifest_path": str(manifest_path),
    }
    try:
        value = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        result["error"] = f"unreadable manifest: {exc}"
        return result
    if not isinstance(value, dict):
        result["error"] = "manifest root must be an object"
        return result

    mismatches = _manifest_errors(value, lane, allowed_statuses)
    book_status = value.get("status")
    sleeves = value.get("sleeves")
    if mismatches:
        result["error"] = "; ".join(mismatches)
        return result

    result.update(
        {
            "validation": "VALID",
            "book_status": str(book_status),
            "as_of": str(value.get("as_of") or ""),
            "sleeve_count": len(sleeves),
        }
    )
    return result


def optimization_track_snapshot(db_path: Path, report_root: Path) -> dict[str, Any]:
    """Return the Q14--Q16 and dual-book read model without mutating inputs."""

    phases = {phase: _empty_phase(phase) for phase in OPTIMIZATION_PHASES}
    out: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "available": False,
        "phases": phases,
        "books": {
            lane: _book_status(Path(report_root), lane) for lane in BOOK_LANES
        },
        "authority": "READ_ONLY_NO_RUNTIME_AUTHORITY",
    }
    try:
        database = Path(db_path).resolve()
        con = sqlite3.connect(f"file:{database.as_posix()}?mode=ro", uri=True)
        con.row_factory = sqlite3.Row
        try:
            con.execute("PRAGMA query_only=ON")
            rows = con.execute(
                """
                SELECT UPPER(phase) AS phase,
                       LOWER(status) AS status,
                       UPPER(COALESCE(verdict,'')) AS verdict,
                       COUNT(*) AS row_count
                FROM work_items
                WHERE UPPER(phase) IN ('Q14','Q15','Q16')
                GROUP BY UPPER(phase), LOWER(status), UPPER(COALESCE(verdict,''))
                """
            ).fetchall()
        finally:
            con.close()
    except (OSError, sqlite3.Error) as exc:
        out["error"] = str(exc)
        return out

    for row in rows:
        phase = str(row["phase"])
        status = str(row["status"])
        verdict = str(row["verdict"])
        count = int(row["row_count"] or 0)
        phase_row = phases[phase]
        phase_row["total"] += count
        if status in {"done", "failed"} and verdict in phase_row["outcomes"]:
            phase_row["outcomes"][verdict] += count
        else:
            phase_row["open"] += count
    out["available"] = True
    return out


def successful_phase_counts(snapshot: dict[str, Any]) -> dict[str, int]:
    """Map the extension read model to compact pipeline progress counters."""

    phases = snapshot.get("phases") or {}

    def outcomes(phase: str) -> dict[str, int]:
        value = phases.get(phase) or {}
        return value.get("outcomes") or {}

    q14 = outcomes("Q14")
    q15 = outcomes("Q15")
    q16 = outcomes("Q16")
    return {
        "Q14": int(q14.get("OPT_ELIGIBLE") or 0),
        "Q15": int(q15.get("CHALLENGER_SPAWNED") or 0),
        "Q16": sum(
            int(q16.get(verdict) or 0)
            for verdict in ("PROMOTE_CHALLENGER", "KEEP_INCUMBENT", "ADMIT_BOTH")
        ),
    }
