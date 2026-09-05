from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import numpy as np

from tools.strategy_farm.portfolio import ftmo_v4_tail_certification as certification


def _stream(path: Path, *, offset: int, scale: float = 1.0) -> None:
    start = dt.datetime(2020, 1, 1, tzinfo=dt.UTC)
    rows = []
    for index in range(40):
        opened = start + dt.timedelta(days=index * 7 + offset)
        closed = opened + dt.timedelta(days=2)
        rows.append({
            "event": "TRADE_CLOSED", "entry_time": int(opened.timestamp()),
            "time": int(closed.timestamp()), "net": scale * (100 if index % 2 else -80),
            "side": "BUY" if index % 2 else "SELL", "notional": 10000,
        })
    path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")


def _support_files(tmp_path: Path) -> tuple[Path, Path, Path, Path]:
    receipt = tmp_path / "receipt.md"
    receipt.write_text("V2 max_pairwise_correlation = 0.50 account_weight_budget = 10.0\nV4 (c)\n", encoding="utf-8")
    standard = tmp_path / "standard.md"
    standard.write_text("two-layer V4", encoding="utf-8")
    policy = tmp_path / "policy.json"
    policy.write_text(json.dumps({
        "status": "OWNER_RATIFIED",
        "tail": {"per_sleeve_worst_fraction": 0.05, "joint_sleeve_divisor": 3,
                 "venue_daily_loss_limit_pct": 5.0, "maximum_fraction_of_daily_limit": 0.8},
    }), encoding="utf-8")
    interval = tmp_path / "interval.json"
    interval.write_text(json.dumps({
        "schema": "qm.interval-equity-export/v1",
        "ftmo_readiness": {"daily_loss": "ABSTAIN_MISSING_INTERVAL_MIN_EQUITY",
                           "flat_at_target": "ABSTAIN_MISSING_PENDING_ORDERS_AND_ENDPOINT_EQUITY"},
    }), encoding="utf-8")
    return receipt, standard, policy, interval


def _spec(tmp_path: Path) -> dict[str, object]:
    receipt, standard, policy, interval = _support_files(tmp_path)
    sleeves = []
    for index in range(2):
        stream = tmp_path / f"stream{index}.jsonl"
        tail = tmp_path / f"tail{index}.json"
        # Keep both synthetic closes on business days so Layer A has a defined
        # zeros-kept correlation sample.  Final certification still abstains on
        # the deliberately incomplete interval-equity evidence below.
        _stream(stream, offset=0, scale=1.0 if index == 0 else -0.5)
        tail.write_text(json.dumps({
            "status": "PASS", "detail": "no_portfolio_peers_trivial_pass",
        }), encoding="utf-8")
        sleeves.append({
            "sleeve_id": f"{index}:EURUSD", "symbol": "EURUSD", "weight": 1,
            "trade_stream_path": str(stream), "q08_tail_path": str(tail),
        })
    return {
        "schema": certification.SPEC_SCHEMA, "account_initial_balance": 100000,
        "currency": "USD", "bootstrap": {"replicates": 200, "seed": 7, "alpha": 0.05},
        "sleeves": sleeves, "v2_owner_receipt_path": str(receipt),
        "v4_standard_path": str(standard), "tail_policy_path": str(policy),
        "interval_export_path": str(interval),
    }


def test_synthetic_streams_emit_two_layers_hashes_and_abstention(tmp_path: Path) -> None:
    result = certification.evaluate(_spec(tmp_path))
    assert result["status"] == "ABSTAIN"
    assert len(result["pairs"]) == 1
    assert result["pairs"][0]["layer_a"]["replicates_valid"] >= 190
    assert result["pairs"][0]["layer_b"]["p_upper_exact_all_circular_shifts"] >= 0
    assert result["candidates"][0]["verdict"] == "ABSTAIN"
    assert len(result["candidates"][0]["stream"]["sha256"]) == 64
    assert result["tail"]["certification"].startswith("ABSTAIN")


def test_stationary_bootstrap_is_deterministic() -> None:
    x = np.arange(100, dtype=float)
    y = x + np.sin(x)
    first = certification._stationary_bootstrap_ci(x, y, block_length=5, replicates=200, alpha=0.05, seed=11)
    second = certification._stationary_bootstrap_ci(x, y, block_length=5, replicates=200, alpha=0.05, seed=11)
    assert first == second
    assert first[0] is not None and first[1] is not None


def test_auto_block_and_circular_shift_controls(tmp_path: Path) -> None:
    assert certification._auto_block_length(np.zeros(100)) == 1
    spec = _spec(tmp_path)
    result = certification.evaluate(spec)
    layer_b = result["pairs"][0]["layer_b"]
    assert layer_b["co_occupied_days"] >= 0
    assert layer_b["flag_b"] == "UNRESOLVED_OWNER_NUMERIC_THRESHOLDS_ADVISORY_ONLY"
