"""Combine FTMO preset inventory, strict qualification, and reconciliation."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Mapping

try:
    from .ftmo_phase1_mae import load_ftmo_book
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_phase1_mae import load_ftmo_book  # type: ignore


def _numeric_ea(value: Any) -> int:
    raw = str(value or "").upper().removeprefix("QM5_")
    return int(raw)


def _key(ea_id: Any, symbol: Any) -> tuple[int, str]:
    return _numeric_ea(ea_id), str(symbol or "").upper()


def build_readiness(
    book: Mapping[tuple[int, str], Mapping[str, Any]],
    qualification: Mapping[str, Any],
    reconciliation: Mapping[str, Any],
) -> dict[str, Any]:
    qmap = {
        _key(row.get("ea_id"), row.get("symbol")): row
        for row in qualification.get("candidates") or []
    }
    rmap = {
        _key(row.get("ea_id"), row.get("symbol")): row
        for row in reconciliation.get("results") or []
    }
    sleeves: list[dict[str, Any]] = []
    for (ea_id, symbol), meta in sorted(book.items()):
        key = (int(ea_id), str(symbol).upper())
        qrow = qmap.get(key)
        rrow = rmap.get(key)
        blockers: list[str] = []
        if qrow is None:
            blockers.append("qualification_evidence_missing")
        elif qrow.get("challenge_ready") is not True:
            blockers.append(f"qualification_not_ready:{qrow.get('state') or 'UNKNOWN'}")
        if rrow is None:
            blockers.append("stream_reconciliation_missing")
        elif rrow.get("status") != "PASS":
            blockers.append("stream_reconciliation_fail")
        sleeves.append({
            "ea_id": ea_id,
            "symbol": symbol,
            "timeframe": meta.get("tf"),
            "risk_fixed": float(meta.get("risk_fixed") or 0.0),
            "ready": not blockers,
            "blockers": blockers,
            "qualification_state": qrow.get("state") if qrow else None,
            "qualification_blockers": qrow.get("blockers") if qrow else None,
            "reconciliation_status": rrow.get("status") if rrow else None,
            "reconciliation_reasons": rrow.get("reasons") if rrow else None,
        })
    ready_count = sum(row["ready"] for row in sleeves)
    return {
        "schema_version": 1,
        "status": "READY" if sleeves and ready_count == len(sleeves) else "NO_GO",
        "contract": {
            "all_sleeves_strictly_qualified": True,
            "all_streams_report_reconciled": True,
            "partial_book_approval": False,
        },
        "sleeve_count": len(sleeves),
        "ready_count": ready_count,
        "nominal_risk_fixed_sum": round(sum(row["risk_fixed"] for row in sleeves), 2),
        "qualification_ready_count": sum(
            row["qualification_state"] == "CHALLENGE_READY" for row in sleeves
        ),
        "reconciliation_pass_count": sum(
            row["reconciliation_status"] == "PASS" for row in sleeves
        ),
        "sleeves": sleeves,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qualification", type=Path, required=True)
    parser.add_argument("--reconciliation", type=Path, required=True)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    qualification = json.loads(args.qualification.read_text(encoding="utf-8-sig"))
    reconciliation = json.loads(args.reconciliation.read_text(encoding="utf-8-sig"))
    artifact = build_readiness(load_ftmo_book(), qualification, reconciliation)
    rendered = json.dumps(artifact, indent=2, sort_keys=True) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered, encoding="utf-8")
        print(f"wrote {args.out} status={artifact['status']}")
    else:
        print(rendered, end="")
    return 0 if artifact["status"] == "READY" else 2


if __name__ == "__main__":
    raise SystemExit(main())
