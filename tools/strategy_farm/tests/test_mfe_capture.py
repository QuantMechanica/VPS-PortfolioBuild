"""Tests for the MFE (maximum favourable excursion) capture added 2026-09-13.

Covers the two Python readers touched alongside the framework include change:

* ``tools/strategy_farm/research/exit_surgery_scan_v2.py`` -- loads ``mfe_acct`` and
  produces the symmetric winners'-MFE / giveback-ratio summary.
* ``tools/strategy_farm/portfolio/portfolio_common.py`` -- the shared sealed-stream
  ``Trade`` loader that ``book_builder_common`` and the other portfolio tools delegate to.

The binding property is backward compatibility: a pre-capture stream (no ``mfe_acct``
field) must parse exactly as before, and a new stream carrying ``mfe_acct`` must parse and
feed the giveback math. No DB, bundle manifest or MT5 report is touched.
"""
from __future__ import annotations

import csv
import json
import math
from pathlib import Path

from tools.strategy_farm.portfolio.commission import CommissionModel
from tools.strategy_farm.portfolio.portfolio_common import load_streams
from tools.strategy_farm.research import exit_surgery_scan_v2 as scan

REPO = Path(__file__).resolve().parents[3]


# --------------------------------------------------------------------------- #
# exit_surgery_scan_v2 reader tolerance
# --------------------------------------------------------------------------- #
def _write_stream(root: Path, ea_id: int, symbol: str, trades: list[dict]) -> Path:
    target = root / "QM" / "q08_trades" / f"{ea_id}_{symbol.replace('.', '_')}.jsonl"
    target.parent.mkdir(parents=True, exist_ok=True)
    lines = [json.dumps({"event": "TRADE_CLOSED", "symbol": symbol, **t}) for t in trades]
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return target


def test_scan_load_trades_parses_old_and_new_records(tmp_path: Path) -> None:
    """A legacy row (no mfe_acct) defaults to 0.0; a new row carries the value."""
    stream = _write_stream(
        tmp_path / "streams", 9201, "XAUUSD.DWX",
        [
            # legacy row: entry_time / time / net / mae_acct only
            {"entry_time": 1_500_000_000, "time": 1_500_003_600, "net": 40.0, "mae_acct": -10.0},
            # new row: also carries mfe_acct
            {"entry_time": 1_500_100_000, "time": 1_500_103_600, "net": 40.0,
             "mae_acct": -10.0, "mfe_acct": 100.0},
        ],
    )
    trades = scan.load_trades(stream)
    assert len(trades) == 2
    # sorted by exit time -> legacy first, new second
    assert trades[0].mfe_acct == 0.0          # absent -> tolerant default, no KeyError
    assert trades[1].mfe_acct == 100.0
    assert trades[0].mae_acct == -10.0        # unchanged behaviour


# --------------------------------------------------------------------------- #
# giveback ratio math
# --------------------------------------------------------------------------- #
def _t(net: float, mfe: float) -> "scan.Trade":
    return scan.Trade(entry_time=0, exit_time=3600, net=net, mae_acct=-1.0, hold_h=1.0, mfe_acct=mfe)


def test_giveback_ratio_math() -> None:
    # winners: (mfe=100,net=60)->0.4  (mfe=100,net=50)->0.5  (mfe=100,net=90)->0.1
    # excluded: loser (net<=0) and a winner with mfe==0 (the >0 guard).
    trades = [
        _t(60.0, 100.0),
        _t(50.0, 100.0),
        _t(90.0, 100.0),
        _t(-20.0, 0.0),   # loser, excluded
        _t(80.0, 0.0),    # mfe==0, excluded by the mfe>0 guard
    ]
    n, mfe_med, gb_med, gb_p75, gb_p90, gb_mean = scan.mfe_giveback(trades)
    assert n == 3
    assert mfe_med == 100.0
    assert math.isclose(gb_med, 0.4, rel_tol=0, abs_tol=1e-12)
    # percentile over sorted [0.1, 0.4, 0.5]: p75 = 0.45, p90 = 0.48
    assert math.isclose(gb_p75, 0.45, abs_tol=1e-12)
    assert math.isclose(gb_p90, 0.48, abs_tol=1e-12)
    assert math.isclose(gb_mean, (0.1 + 0.4 + 0.5) / 3.0, abs_tol=1e-12)


def test_giveback_exit_at_peak_is_zero() -> None:
    # net == mfe -> nothing given back
    n, _mfe_med, gb_med, _p75, _p90, gb_mean = scan.mfe_giveback([_t(100.0, 100.0), _t(100.0, 100.0)])
    assert n == 2
    assert gb_med == 0.0
    assert gb_mean == 0.0


def test_giveback_empty_on_legacy_stream() -> None:
    # legacy: every mfe_acct defaults to 0.0 -> no qualifying winner -> n=0, all NaN
    n, mfe_med, gb_med, gb_p75, gb_p90, gb_mean = scan.mfe_giveback([_t(40.0, 0.0), _t(-5.0, 0.0)])
    assert n == 0
    for value in (mfe_med, gb_med, gb_p75, gb_p90, gb_mean):
        assert math.isnan(value)


# --------------------------------------------------------------------------- #
# run_scan writes the symmetric mfe_winners.csv
# --------------------------------------------------------------------------- #
def _run_scan(tmp_path: Path, ea_id: int, symbol: str, trades: list[dict]) -> dict:
    root = tmp_path / "streams"
    _write_stream(root, ea_id, symbol, trades)
    roster = tmp_path / "roster.json"
    roster.write_text(json.dumps({"selected_book": [{"ea_id": ea_id, "symbol": symbol}]}), encoding="utf-8")
    out = tmp_path / "out"
    scan.run_scan(roster, [root], scan.DEFAULT_DB, out)
    rows = list(csv.DictReader((out / "mfe_winners.csv").open(encoding="utf-8")))
    return {(int(r["ea_id"]), r["symbol"]): r for r in rows}


def test_mfe_winners_csv_new_stream(tmp_path: Path) -> None:
    trades = [
        {"entry_time": 1_500_000_000 + i, "time": 1_500_003_600 + i, "net": net,
         "mae_acct": -10.0, "mfe_acct": 100.0}
        for i, net in enumerate((60.0, 50.0, 90.0))
    ] + [
        {"entry_time": 1_500_200_000, "time": 1_500_203_600, "net": -20.0,
         "mae_acct": -30.0, "mfe_acct": 0.0}
    ]
    rows = _run_scan(tmp_path, 9202, "EURUSD.DWX", trades)
    r = rows[(9202, "EURUSD.DWX")]
    assert r["n_winners_mfe"] == "3"
    assert float(r["mfe_winner_med"]) == 100.0
    assert math.isclose(float(r["giveback_med"]), 0.4, abs_tol=1e-9)


def test_mfe_winners_csv_legacy_stream_degrades(tmp_path: Path) -> None:
    # no mfe_acct anywhere -> n_winners_mfe=0, blank stats, no crash
    trades = [
        {"entry_time": 1_500_000_000 + i, "time": 1_500_003_600 + i, "net": 40.0, "mae_acct": -10.0}
        for i in range(3)
    ]
    rows = _run_scan(tmp_path, 9203, "USDJPY.DWX", trades)
    r = rows[(9203, "USDJPY.DWX")]
    assert r["n_winners_mfe"] == "0"
    assert r["mfe_winner_med"] == ""
    assert r["giveback_med"] == ""


# --------------------------------------------------------------------------- #
# portfolio_common shared stream loader tolerance
# --------------------------------------------------------------------------- #
def test_portfolio_common_stream_loader_old_and_new(tmp_path: Path) -> None:
    common_dir = tmp_path / "common"
    stream_dir = common_dir / "QM" / "q08_trades"
    stream_dir.mkdir(parents=True)
    rows = [
        {   # new row: mfe_acct present
            "event": "TRADE_CLOSED", "symbol": "EURUSD.DWX", "time": 1_704_153_600,
            "entry_time": 1_704_150_000, "mae_acct": -123.45, "mfe_acct": 456.78,
            "net": 250.0, "profit": 250.0, "swap": 0.0, "commission": 0.0,
            "volume": 1.0, "notional": 10000.0,
        },
        {   # legacy row: no mfe_acct (and no mae_acct)
            "event": "TRADE_CLOSED", "symbol": "EURUSD.DWX", "time": 1_704_240_000,
            "net": -50.0, "profit": -50.0, "swap": 0.0, "commission": 0.0,
            "volume": 1.0, "notional": 10000.0,
        },
    ]
    stream_path = stream_dir / "100_EURUSD_DWX.jsonl"
    with stream_path.open("w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, sort_keys=True) + "\n")

    model = CommissionModel(REPO / "framework" / "registry" / "live_commission.json")
    streams = load_streams(common_dir, commission_model=model)
    trades = streams[(100, "EURUSD.DWX")]

    assert len(trades) == 2
    assert trades[0].mfe_acct == 456.78     # parsed
    assert trades[0].mae_acct == -123.45    # unchanged behaviour
    assert trades[1].mfe_acct is None       # absent -> None, no KeyError
    assert trades[1].mae_acct is None
