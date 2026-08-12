"""Build a hash-frozen trend-20d entry oracle from reconciled control trades.

The oracle does not select or score a rule. It applies the already locked
``trend_20d_align`` rule to every report-reconciled control trade, including
2020, using only observed M15 closes at shifts 1 and 1921.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any, Mapping, Sequence

import pandas as pd

try:
    from . import ftmo_bar_joint_book_sim as joint
    from . import ftmo_sleeve_regime_filter_screen as regime
    from . import ftmo_stream_reconciliation as reconciliation
    from .ftmo_report_cost_reconcile import RoundTrip
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_joint_book_sim as joint  # type: ignore
    import ftmo_sleeve_regime_filter_screen as regime  # type: ignore
    import ftmo_stream_reconciliation as reconciliation  # type: ignore
    from ftmo_report_cost_reconcile import RoundTrip  # type: ignore


RULE_NAME = "trend_20d_align"
NEWEST_SHIFT = 1
OLDEST_SHIFT = 1921
REQUIRED_COMPLETED_CLOSES = 1921
_LOCKED_RULE = regime.rule_set()[RULE_NAME]


def _sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _source_record(path: Path) -> dict[str, Any]:
    resolved = path.resolve()
    payload = resolved.read_bytes()
    return {
        "path": str(resolved),
        "sha256": _sha256_bytes(payload),
        "size_bytes": len(payload),
    }


def _source_records(paths: Mapping[str, Path]) -> dict[str, dict[str, Any]]:
    return {name: _source_record(path) for name, path in paths.items()}


def _assert_sources_unchanged(
    before: Mapping[str, Mapping[str, Any]],
    after: Mapping[str, Mapping[str, Any]],
) -> None:
    if before.keys() != after.keys():
        raise ValueError("source set changed during oracle generation")
    changed = [
        name
        for name in before
        if before[name]["sha256"] != after[name]["sha256"]
        or before[name]["size_bytes"] != after[name]["size_bytes"]
    ]
    if changed:
        raise ValueError(f"sources changed during oracle generation: {changed}")


def _iso_timestamp(value: Any) -> str:
    timestamp = pd.Timestamp(value)
    if timestamp.tzinfo is None:
        timestamp = timestamp.tz_localize("UTC")
    return timestamp.isoformat()


def _locked_rule_passes(signed_return_20d: float) -> bool:
    feature = regime.FeatureTrade(
        entry_time_utc="",
        year=0,
        weekday=0,
        prague_hour=0,
        side=1,
        net_r=0.0,
        signed_return_4h=float("nan"),
        signed_return_24h=float("nan"),
        signed_return_5d=float("nan"),
        signed_return_20d=signed_return_20d,
        volatility_ratio=float("nan"),
    )
    return bool(_LOCKED_RULE(feature))


def trade_oracle_row(
    trade: RoundTrip,
    bars: pd.DataFrame,
    *,
    trade_number: int,
    timestamp_basis: str,
) -> dict[str, Any]:
    """Apply the locked rule to one trade without filling missing M15 bars."""

    entry_utc = joint.normalize_timestamp(trade.entry_time, timestamp_basis)
    exit_utc = joint.normalize_timestamp(trade.exit_time, timestamp_basis)
    entry_bucket = entry_utc.floor(joint.GRID_FREQUENCY)
    position = int(bars.index.searchsorted(entry_bucket, side="left"))
    year = int(entry_utc.tz_convert(joint.PRAGUE).year)
    base: dict[str, Any] = {
        "control_trade_number": int(trade_number),
        "entry_time_source": _iso_timestamp(trade.entry_time),
        "entry_time_utc": entry_utc.isoformat(),
        "exit_time_source": _iso_timestamp(trade.exit_time),
        "exit_time_utc": exit_utc.isoformat(),
        "entry_bar_open_utc": entry_bucket.isoformat(),
        "entry_year_prague": year,
        "side": trade.side,
        "observed_completed_closes": position,
        "feature_available": False,
        "signed_return_20d": None,
        "accepted": False,
        "decision": "unavailable",
        "reason": "insufficient_observed_history",
        "shift1": None,
        "shift1921": None,
    }

    entry_bucket_observed = position < len(bars) and bars.index[position] == entry_bucket
    if not entry_bucket_observed:
        base["reason"] = "entry_bucket_not_observed"
        return base
    if position < REQUIRED_COMPLETED_CLOSES:
        if position >= NEWEST_SHIFT:
            newest = bars.iloc[position - NEWEST_SHIFT]
            base["shift1"] = {
                "close": float(newest["close"]),
                "observed_bar_open_utc": bars.index[position - NEWEST_SHIFT].isoformat(),
            }
        return base

    newest_position = position - NEWEST_SHIFT
    oldest_position = position - OLDEST_SHIFT
    newest_close = float(bars.iloc[newest_position]["close"])
    oldest_close = float(bars.iloc[oldest_position]["close"])
    base["shift1"] = {
        "close": newest_close,
        "observed_bar_open_utc": bars.index[newest_position].isoformat(),
    }
    base["shift1921"] = {
        "close": oldest_close,
        "observed_bar_open_utc": bars.index[oldest_position].isoformat(),
    }
    if (
        not math.isfinite(newest_close)
        or not math.isfinite(oldest_close)
        or newest_close <= 0.0
        or oldest_close <= 0.0
    ):
        base["reason"] = "invalid_observed_close"
        return base

    side = 1 if trade.side == "buy" else -1
    signed_return = side * (newest_close / oldest_close - 1.0)
    accepted = _locked_rule_passes(signed_return)
    base.update(
        {
            "feature_available": True,
            "signed_return_20d": signed_return,
            "accepted": accepted,
            "decision": "accepted" if accepted else "rejected",
            "reason": "strict_positive" if accepted else "strict_nonpositive",
        }
    )
    return base


def count_decisions(rows: Sequence[Mapping[str, Any]]) -> dict[str, int]:
    decisions = Counter(str(row["decision"]) for row in rows)
    return {
        "control": len(rows),
        "accepted": decisions["accepted"],
        "rejected": decisions["rejected"],
        "unavailable": decisions["unavailable"],
    }


def annual_decision_counts(
    rows: Sequence[Mapping[str, Any]],
) -> dict[str, dict[str, int]]:
    years = sorted({int(row["entry_year_prague"]) for row in rows})
    return {
        str(year): count_decisions(
            [row for row in rows if int(row["entry_year_prague"]) == year]
        )
        for year in years
    }


def _manifest_source_paths(
    manifest: Mapping[str, Any],
    *,
    manifest_path: Path,
    data_root: Path,
) -> dict[str, Path]:
    raw_sleeves = manifest.get("sleeves")
    if not isinstance(raw_sleeves, list) or len(raw_sleeves) != 1:
        raise ValueError("trend20d oracle requires exactly one manifest sleeve")
    raw = raw_sleeves[0]
    if not isinstance(raw, Mapping):
        raise ValueError("manifest sleeve must be an object")
    symbol = str(raw.get("symbol") or "").upper()
    summary_path = Path(str(raw["summary_path"]))
    stream_path = Path(str(raw["stream_path"]))
    report = reconciliation.summarize_report(summary_path)
    report_path_value = report.get("report_canonical_path")
    if not report_path_value:
        raise ValueError("manifest summary has no usable canonical report")
    bar_path_value = raw.get("bar_path") or joint.default_bar_paths(data_root).get(symbol)
    if not bar_path_value:
        raise ValueError(f"{symbol}: no observed M15 bar path")
    bar_path = Path(str(bar_path_value))
    return {
        "sealed_manifest": manifest_path,
        "control_summary": summary_path,
        "control_report": Path(str(report_path_value)),
        "control_q08_stream": stream_path,
        "observed_m15_bars": bar_path,
    }


def build_oracle(
    manifest: Mapping[str, Any],
    *,
    manifest_path: Path,
    data_root: Path,
    control_ea_id: int,
    target_ea_id: int,
    oracle_date: str,
) -> dict[str, Any]:
    source_paths = _manifest_source_paths(
        manifest,
        manifest_path=manifest_path,
        data_root=data_root,
    )
    sources_before = _source_records(source_paths)
    cases, bars_by_symbol = joint.load_cases(
        manifest,
        bar_paths=joint.default_bar_paths(data_root),
    )
    sources_after = _source_records(source_paths)
    _assert_sources_unchanged(sources_before, sources_after)

    if len(cases) != 1:
        raise ValueError("trend20d oracle requires exactly one loaded sleeve")
    case = cases[0]
    if int(case["ea_id"]) != int(control_ea_id):
        raise ValueError(
            f"control EA mismatch: manifest={case['ea_id']} requested={control_ea_id}"
        )
    if int(target_ea_id) <= 0 or int(target_ea_id) == int(control_ea_id):
        raise ValueError("target EA ID must be positive and distinct from the control")

    symbol = str(case["symbol"]).upper()
    bars = bars_by_symbol[symbol]
    timestamp_basis = str(case["timestamp_basis"])
    rows = [
        trade_oracle_row(
            trade,
            bars,
            trade_number=number,
            timestamp_basis=timestamp_basis,
        )
        for number, trade in enumerate(case["trades"], 1)
    ]
    report_trade_count = int(case["reconciliation"]["report"]["trade_count"])
    if len(rows) != report_trade_count:
        raise ValueError(
            f"oracle/control trade count mismatch: {len(rows)}!={report_trade_count}"
        )

    semantic_paths = {
        "oracle_generator": Path(__file__),
        "bar_and_timestamp_semantics": Path(str(joint.__file__)),
        "locked_rule_semantics": Path(str(regime.__file__)),
    }
    years = sorted({int(row["entry_year_prague"]) for row in rows})
    return {
        "schema_version": 1,
        "artifact_type": "hash_frozen_entry_oracle",
        "status": "HASH_FROZEN",
        "oracle_date": oracle_date,
        "control_ea_id": int(control_ea_id),
        "target_ea_id": int(target_ea_id),
        "symbol": symbol,
        "timestamp_basis": timestamp_basis,
        "rule": RULE_NAME,
        "rule_contract": {
            "timeframe": "M15",
            "bar_source": "observed_only_no_gap_fill",
            "newest_shift": NEWEST_SHIFT,
            "oldest_shift": OLDEST_SHIFT,
            "required_completed_closes": REQUIRED_COMPLETED_CLOSES,
            "signed_return": "side * (close_shift1 / close_shift1921 - 1.0)",
            "strict_operator": ">",
            "threshold": 0.0,
            "insufficient_history": "reject",
        },
        "selection_contract": {
            "mode": "locked_rule_oracle_only",
            "selection_performed": False,
            "holdout_reselection": False,
            "control_years_included": years,
            "year_2020_included": 2020 in years,
            "control_trade_policy": "all report-reconciled control trades",
        },
        "source_freeze": {
            "algorithm": "SHA256",
            "stable_during_generation": True,
            "data_sources": sources_after,
            "semantic_sources": _source_records(semantic_paths),
        },
        "counts": count_decisions(rows),
        "annual_counts": annual_decision_counts(rows),
        "trades": rows,
    }


def render_artifact(artifact: Mapping[str, Any]) -> bytes:
    return (json.dumps(artifact, indent=2, sort_keys=True, allow_nan=False) + "\n").encode(
        "utf-8"
    )


def write_artifact(
    artifact: Mapping[str, Any],
    *,
    out_path: Path,
    sha256_path: Path,
) -> str:
    payload = render_artifact(artifact)
    digest = _sha256_bytes(payload)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sha256_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(payload)
    sha256_path.write_text(f"{digest}  {out_path.name}\n", encoding="ascii")
    return digest


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(r"D:\QM\mt5\T_Export\MQL5\Files"),
    )
    parser.add_argument("--control-ea-id", type=int, required=True)
    parser.add_argument("--target-ea-id", type=int, required=True)
    parser.add_argument("--oracle-date", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--sha256-out", type=Path)
    args = parser.parse_args(argv)

    manifest_payload = args.manifest.read_bytes()
    manifest = json.loads(manifest_payload.decode("utf-8-sig"))
    artifact = build_oracle(
        manifest,
        manifest_path=args.manifest,
        data_root=args.data_root,
        control_ea_id=args.control_ea_id,
        target_ea_id=args.target_ea_id,
        oracle_date=args.oracle_date,
    )
    sha256_path = args.sha256_out or args.out.with_suffix(".sha256")
    digest = write_artifact(artifact, out_path=args.out, sha256_path=sha256_path)
    print(
        json.dumps(
            {
                "out": str(args.out),
                "sha256_out": str(sha256_path),
                "sha256": digest,
                "counts": artifact["counts"],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
