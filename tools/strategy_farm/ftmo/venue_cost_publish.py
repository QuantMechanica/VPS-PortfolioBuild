#!/usr/bin/env python3
"""Publish a separate venue-adjusted FTMO read-model block.

The FINANCED read model is preserved byte-for-byte at the field level.  This
writer only replaces ``venue_adjusted`` and verifies a canonical hash of every
other field before committing the atomic write.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Mapping, Sequence
from zoneinfo import ZoneInfo


SCHEMA = "qm.ftmo-venue-adjusted/v1"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    ).hexdigest()


def _without_venue(state: Mapping[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in state.items() if key != "venue_adjusted"}


def _prague_date(epoch: float) -> dt.date:
    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).astimezone(
        ZoneInfo("Europe/Prague")
    ).date()


def unit_sensitivity(
    roster: Mapping[str, Any], stream_root: Path, *, start: dt.date, end: dt.date
) -> dict[str, Any]:
    sleeves: list[dict[str, Any]] = []
    for spec in roster.get("sleeves") or []:
        symbol = str(spec.get("dwx_symbol") or spec.get("symbol")).upper()
        if not symbol.endswith(".DWX"):
            symbol += ".DWX"
        path = stream_root / f"{int(spec['ea_id'])}_{symbol.replace('.DWX', '_DWX')}.jsonl"
        factor = float(spec["risk_percent"])
        notional = volume = 0.0
        trade_count = 0
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                if not line.strip():
                    continue
                row = json.loads(line)
                if row.get("event", "TRADE_CLOSED") != "TRADE_CLOSED":
                    continue
                closed = _prague_date(float(row["time"]))
                if not start <= closed <= end:
                    continue
                notional += abs(float(row.get("notional") or 0.0)) * factor
                volume += abs(float(row.get("volume") or 0.0)) * factor
                trade_count += 1
        sleeves.append({
            "id": str(spec.get("id") or f"{spec['ea_id']}_{symbol}"),
            "ea_id": int(spec["ea_id"]),
            "symbol": symbol,
            "trade_count": trade_count,
            "additional_usd_per_1bp_spread": round(notional / 10000.0, 6),
            "additional_usd_per_1_usd_per_lot_slippage": round(volume, 6),
            "source_stream": str(path.resolve()),
            "source_sha256": sha256_file(path),
        })
    sleeves.sort(key=lambda row: (-row["additional_usd_per_1bp_spread"], row["id"]))
    by_symbol: dict[str, float] = {}
    for row in sleeves:
        by_symbol[row["symbol"]] = by_symbol.get(row["symbol"], 0.0) + float(
            row["additional_usd_per_1bp_spread"]
        )
    groups = [
        {"symbol": symbol, "additional_usd_per_1bp_spread": round(value, 6)}
        for symbol, value in sorted(by_symbol.items(), key=lambda item: (-item[1], item[0]))
    ]
    return {
        "interpretation": "mechanical exposure per hypothetical incremental unit; not a measured venue charge",
        "sleeves": sleeves,
        "symbol_groups": groups,
        "dominant_sleeve_by_1bp_spread": sleeves[0] if sleeves else None,
        "dominant_symbol_group_by_1bp_spread": groups[0] if groups else None,
    }


def build_block(
    *,
    measurement: Mapping[str, Any],
    book: Mapping[str, Any],
    marginal: Mapping[str, Any],
    sensitivity: Mapping[str, Any],
    evidence_path: str,
    measurement_sha256: str,
    book_sha256: str,
    marginal_sha256: str,
    generated_at: str,
) -> dict[str, Any]:
    probabilities = (book.get("first_passage") or {}).get("probabilities") or {}
    metrics = book.get("book_metrics") or {}
    eligible = measurement.get("eligible_spread_bps_rt_by_symbol") or {}
    multiplier_rows = [
        {
            "multiplier": multiplier,
            "P_FIRST_NET_FTMO_PAYOUT_LCB": probabilities.get(
                "P_FIRST_NET_FTMO_PAYOUT_LCB"
            ),
            "identity_reason": "eligible additive venue-delta table is empty",
        }
        for multiplier in (0.5, 1.0, 1.5)
    ]
    status = "VENUE_ADJUSTED" if eligible else "ABSTAIN_NO_ELIGIBLE_VENUE_DELTA"
    return {
        "schema": SCHEMA,
        "generated_at_utc": generated_at,
        "status": status,
        "headline_label": "VENUE_ADJUSTED",
        "P_FIRST_NET_FTMO_PAYOUT_LCB": probabilities.get(
            "P_FIRST_NET_FTMO_PAYOUT_LCB"
        ),
        "challenge_pass": probabilities.get("P_CHALLENGE_PASS"),
        "daily_loss_breach": metrics.get("BOOK_DAILY_LOSS_BREACH_PROB"),
        "max_loss_breach": metrics.get("BOOK_MAX_LOSS_BREACH_PROB"),
        "expected_progress_usd_per_day": metrics.get(
            "BOOK_EXPECTED_PROGRESS_USD_PER_DAY"
        ),
        "additional_cost_drag_usd": {
            "spread": (metrics.get("BOOK_COST_DRAG") or {}).get("spread_stress_usd"),
            "slippage": (metrics.get("BOOK_COST_DRAG") or {}).get(
                "slippage_stress_usd"
            ),
        },
        "eligible_spread_bps_rt_by_symbol": eligible,
        "slippage_usd_per_lot_rt_by_symbol": measurement.get(
            "slippage_usd_per_lot_rt_by_symbol"
        ) or {},
        "sensitivity_ladder": multiplier_rows,
        "unit_cost_sensitivity": sensitivity,
        "dominant_sleeve": sensitivity.get("dominant_sleeve_by_1bp_spread"),
        "dominant_symbol_group": sensitivity.get(
            "dominant_symbol_group_by_1bp_spread"
        ),
        "marginal_contract": {
            "replicates": (marginal.get("params") or {}).get("replicate_count"),
            "n_paths_per_replicate": (marginal.get("params") or {}).get("n_paths"),
            "seeds": (marginal.get("params") or {}).get("replicate_seeds"),
            "candidate_rows": len(marginal.get("candidates") or []),
        },
        "coverage": {
            "measurement_status": measurement.get("status"),
            "slippage": measurement.get("slippage_coverage"),
            "refusal": (
                "No numeric venue delta is claimed where exact matched Darwinex minutes "
                "or request-to-fill slippage evidence are absent."
            ),
        },
        "evidence": evidence_path,
        "bindings": {
            "measurement_sha256": measurement_sha256,
            "book_sim_sha256": book_sha256,
            "marginal_sha256": marginal_sha256,
        },
    }


def publish(state: Mapping[str, Any], block: Mapping[str, Any]) -> tuple[dict[str, Any], str]:
    if (state.get("financing") or {}).get("label") != "FINANCED":
        raise ValueError("current state is not FINANCED; refusing venue block publication")
    stable_hash = canonical_hash(_without_venue(state))
    updated = dict(state)
    updated["venue_adjusted"] = dict(block)
    if canonical_hash(_without_venue(updated)) != stable_hash:
        raise AssertionError("non-venue current-state fields changed")
    updated["venue_adjusted"]["non_venue_state_sha256"] = stable_hash
    return updated, stable_hash


def _write(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", required=True, type=Path)
    parser.add_argument("--measurement", required=True, type=Path)
    parser.add_argument("--book", required=True, type=Path)
    parser.add_argument("--marginal", required=True, type=Path)
    parser.add_argument("--roster", required=True, type=Path)
    parser.add_argument("--financed-streams", required=True, type=Path)
    parser.add_argument("--snapshot-out", required=True, type=Path)
    parser.add_argument("--evidence-path", required=True)
    parser.add_argument("--as-of", required=True)
    args = parser.parse_args(argv)
    state = json.loads(args.state.read_text(encoding="utf-8"))
    measurement = json.loads(args.measurement.read_text(encoding="utf-8"))
    book = json.loads(args.book.read_text(encoding="utf-8"))
    marginal = json.loads(args.marginal.read_text(encoding="utf-8"))
    roster = json.loads(args.roster.read_text(encoding="utf-8"))
    window = (book.get("book_metrics") or {}).get("window") or {}
    sensitivity = unit_sensitivity(
        roster,
        args.financed_streams,
        start=dt.date.fromisoformat(window["start"]),
        end=dt.date.fromisoformat(window["end"]),
    )
    block = build_block(
        measurement=measurement,
        book=book,
        marginal=marginal,
        sensitivity=sensitivity,
        evidence_path=args.evidence_path,
        measurement_sha256=sha256_file(args.measurement),
        book_sha256=sha256_file(args.book),
        marginal_sha256=sha256_file(args.marginal),
        generated_at=args.as_of,
    )
    updated, stable_hash = publish(state, block)
    _write(args.state, updated)
    _write(args.snapshot_out, updated)
    print(json.dumps({
        "status": block["status"],
        "lcb": block["P_FIRST_NET_FTMO_PAYOUT_LCB"],
        "dominant_sleeve": (block["dominant_sleeve"] or {}).get("id"),
        "non_venue_state_sha256": stable_hash,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
