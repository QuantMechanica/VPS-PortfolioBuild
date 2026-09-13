"""Synthetic-stream tests for the deterministic Exit-Surgery Scan v2.

Covers the surgery-score classes (HIGH / NO_CASE / NO_DATA), adaptive bucket-set
selection by average hold, and the Tier-B MAE stop_binding flag. No real DB,
bundle manifest or MT5 report is touched: with no bundle_manifest.json in the
stream root, exit_class_source falls back to `none` and the DB is never opened.
"""
from __future__ import annotations

import csv
import json
from pathlib import Path

import pytest

from tools.strategy_farm.research import exit_surgery_scan_v2 as scan


def _write_stream(root: Path, ea_id: int, symbol: str, trades: list[dict]) -> None:
    target = root / "QM" / "q08_trades" / f"{ea_id}_{symbol.replace('.', '_')}.jsonl"
    target.parent.mkdir(parents=True, exist_ok=True)
    lines = [json.dumps({"event": "TRADE_CLOSED", "symbol": symbol, **t}) for t in trades]
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _trade(base: int, hold_h: float, net: float, mae: float = -40.0) -> dict:
    entry = base
    return {"entry_time": entry, "time": entry + int(hold_h * 3600), "net": net, "mae_acct": mae}


def _bucketed(specs: list[tuple[float, int, int, float, float]]) -> list[dict]:
    """specs: (hold_h, n, n_winners, win_net, loss_net) -> trade dicts."""
    trades: list[dict] = []
    base = 1_500_000_000
    for hold_h, n, n_win, win_net, loss_net in specs:
        for i in range(n):
            net = win_net if i < n_win else loss_net
            trades.append(_trade(base, hold_h, net))
            base += 100_000  # keep exit times strictly increasing & distinct
    return trades


def _roster(path: Path, keys: list[tuple[int, str]]) -> Path:
    path.write_text(json.dumps({
        "selected_book": [{"ea_id": ea, "symbol": sym} for ea, sym in keys],
        "selected_book_roster_sha256": "test",
    }), encoding="utf-8")
    return path


def _run(tmp_path: Path, keys: list[tuple[int, str]]) -> dict[tuple[int, str], dict]:
    root = tmp_path / "streams"
    roster = _roster(tmp_path / "roster.json", keys)
    out = tmp_path / "out"
    scan.run_scan(roster, [root], scan.DEFAULT_DB, out)
    rows = list(csv.DictReader((out / "sleeve_summary.csv").open(encoding="utf-8")))
    return {(int(r["ea_id"]), r["symbol"]): r for r in rows}, out


# --------------------------------------------------------------------------- #
def test_high_case_early_negative_late_positive(tmp_path: Path) -> None:
    root = tmp_path / "streams"
    # medium bucket set (avg hold ~22h): 2-8h early (wr 20%, net<0),
    # 8-24h mid (wr 50%), 1-3d late (wr 80%, net>0). gradient = 60 pp.
    trades = _bucketed([
        (5.0, 10, 2, 100.0, -150.0),
        (12.0, 10, 5, 100.0, -100.0),
        (48.0, 10, 8, 200.0, -100.0),
    ])
    _write_stream(root, 9101, "XAUUSD.DWX", trades)
    rows, _ = _run(tmp_path, [(9101, "XAUUSD.DWX")])
    r = rows[(9101, "XAUUSD.DWX")]
    assert r["verdict"] == "HIGH"
    assert r["bucket_set"] == "medium"
    assert float(r["gradient_pp"]) > 15.0
    assert float(r["wr_early"]) == 20.0
    assert float(r["wr_late"]) == 80.0
    assert float(r["early_net"]) < 0
    assert r["exit_class_source"] == "none"  # no bundle/report in tmp
    assert r["time_mgmt_share_early"] == ""   # unknown without a report


def test_no_case_flat_gradient(tmp_path: Path) -> None:
    root = tmp_path / "streams"
    # every bucket ~50% WR -> gradient ~0 -> NO_CASE
    trades = _bucketed([
        (5.0, 10, 5, 100.0, -100.0),
        (12.0, 10, 5, 100.0, -100.0),
        (48.0, 10, 5, 100.0, -100.0),
    ])
    _write_stream(root, 9102, "EURUSD.DWX", trades)
    rows, _ = _run(tmp_path, [(9102, "EURUSD.DWX")])
    r = rows[(9102, "EURUSD.DWX")]
    assert r["verdict"] == "NO_CASE"
    assert abs(float(r["gradient_pp"])) <= scan.GRADIENT_WEAK_PP


def test_no_data_below_min_trades(tmp_path: Path) -> None:
    root = tmp_path / "streams"
    trades = _bucketed([(5.0, 5, 2, 100.0, -100.0), (48.0, 5, 4, 100.0, -100.0)])  # 10 trades
    _write_stream(root, 9103, "NDX.DWX", trades)
    rows, _ = _run(tmp_path, [(9103, "NDX.DWX")])
    r = rows[(9103, "NDX.DWX")]
    assert r["verdict"] == "NO_DATA"
    assert r["n_trades"] == "10"


def test_bucket_set_selection() -> None:
    assert scan.choose_bucket_set(4.0) == "short"
    assert scan.choose_bucket_set(7.99) == "short"
    assert scan.choose_bucket_set(8.0) == "medium"
    assert scan.choose_bucket_set(48.0) == "medium"
    assert scan.choose_bucket_set(48.01) == "long"
    assert scan.choose_bucket_set(600.0) == "long"


def test_bucket_set_reflects_short_hold_sleeve(tmp_path: Path) -> None:
    root = tmp_path / "streams"
    # all holds < 8h -> short bucket set
    trades = _bucketed([
        (0.5, 10, 3, 100.0, -100.0),
        (2.0, 10, 5, 100.0, -100.0),
        (6.0, 10, 6, 100.0, -100.0),
    ])
    _write_stream(root, 9104, "USDJPY.DWX", trades)
    rows, _ = _run(tmp_path, [(9104, "USDJPY.DWX")])
    assert rows[(9104, "USDJPY.DWX")]["bucket_set"] == "short"


def test_mae_flag_stop_binding_true() -> None:
    # anchor = median losers |mae| = 100; 3/4 winners at 0.6x -> share_ge_0_5 = 0.75
    mk = lambda net, mae: scan.Trade(entry_time=0, exit_time=3600, net=net, mae_acct=mae, hold_h=1.0)
    trades = [
        mk(-50.0, -100.0),
        mk(-50.0, -100.0),
        mk(+50.0, -60.0),
        mk(+50.0, -60.0),
        mk(+50.0, -60.0),
        mk(+50.0, -10.0),
    ]
    anchor, nw, med, p75, p90, s5, s7, s9, binding = scan.mae_tier_b(trades)
    assert anchor == 100.0
    assert nw == 4
    assert s5 == 0.75
    assert binding is True


def test_mae_flag_stop_binding_false() -> None:
    # winners never go adverse near the stop -> share_ge_0_5 = 0 -> not binding
    mk = lambda net, mae: scan.Trade(entry_time=0, exit_time=3600, net=net, mae_acct=mae, hold_h=1.0)
    trades = [
        mk(-50.0, -100.0),
        mk(-50.0, -100.0),
        mk(+50.0, -5.0),
        mk(+50.0, -5.0),
    ]
    anchor, nw, med, p75, p90, s5, s7, s9, binding = scan.mae_tier_b(trades)
    assert anchor == 100.0
    assert s5 == 0.0
    assert binding is False


def test_missing_stream_marked_no_stream(tmp_path: Path) -> None:
    # roster references a sleeve with no stream file anywhere
    rows, out = _run(tmp_path, [(9999, "GBPUSD.DWX")])
    r = rows[(9999, "GBPUSD.DWX")]
    assert r["verdict"] == "NO_STREAM"
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["n_missing_streams"] == 1
    assert manifest["missing_streams"] == ["9999:GBPUSD.DWX"]
