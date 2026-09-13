"""Tests for tlive_journal_execution_quality (synthetic journals, read-only parse)."""

from __future__ import annotations

import csv
import json
from pathlib import Path

import tools.strategy_farm.portfolio.tlive_journal_execution_quality as eq


ACC = "4000090541"


def _journal_lines():
    """Broker-time tab-separated Trades lines mirroring the real grammar."""
    return [
        # pending buy-stop placement: trigger P=162.534, latency 100.4 ms
        f"AA\t0\t10:00:00.100\tTrades\t'{ACC}': order #111 buy stop 0.30 / 0.30 USDJPY at 162.534 done in 100.454 ms",
        # its fill: F=162.535 -> buy adverse = (162.535-162.534)/0.001 = +1.0 pt
        f"BB\t0\t10:05:00.200\tTrades\t'{ACC}': deal #9001 buy 0.30 USDJPY at 162.535 done (based on order #111)",
        # pending sell-stop placement: trigger P=162.303
        f"CC\t0\t11:00:00.300\tTrades\t'{ACC}': order #112 sell stop 0.30 / 0.30 USDJPY at 162.303 done in 120.000 ms",
        # its fill: F=162.286 -> sell adverse = (162.303-162.286)/0.001 = +17.0 pt
        f"DD\t0\t11:05:00.400\tTrades\t'{ACC}': deal #9002 sell 0.30 USDJPY at 162.286 done (based on order #112)",
        # zero-slippage pending fill on GDAXI: trigger 24917.1, fill 24917.1
        f"EE\t0\t12:00:00.000\tTrades\t'{ACC}': order #113 buy stop 0.03 / 0.03 GDAXI at 24917.1 done in 55.000 ms",
        f"FF\t0\t12:01:00.000\tTrades\t'{ACC}': deal #9003 buy 0.03 GDAXI at 24917.1 done (based on order #113)",
        # market/close order form: no reference price -> not slippage-eligible
        f"GG\t0\t13:00:00.000\tTrades\t'{ACC}': order #114 sell 0.38 / 0.38 GDAXI at market done in 149.501 ms",
        f"HH\t0\t13:00:00.050\tTrades\t'{ACC}': market sell 0.38 GDAXI, close #113 buy 0.38 GDAXI 24917.1",
        f"II\t0\t13:00:00.100\tTrades\t'{ACC}': deal #9004 sell 0.38 GDAXI at 25048.0 done (based on order #114)",
        # unmatched deal: references an order with no 'order ... done' line (e.g. server SL/TP exit)
        f"JJ\t0\t14:00:00.000\tTrades\t'{ACC}': deal #9005 sell 0.06 GDAXI at 26360.1 done (based on order #999)",
        # rejections / failures
        f"KK\t0\t15:00:00.000\tTrades\t'{ACC}': failed market buy 0.35 USDJPY [Position doesn't exist]",
        f"LL\t0\t15:01:00.000\tTrades\t'{ACC}': failed cancel order #112 sell stop 0.30 USDJPY at 162.303 sl: 162.5 [Market closed]",
        # completed cancel of a pending order
        f"MM\t0\t15:02:00.000\tTrades\t'{ACC}': cancel #113 buy stop 0.03 GDAXI at market done in 40.000 ms",
    ]


def _write_utf16_journal(dirp: Path, datestr: str, lines):
    text = "\r\n".join(lines) + "\r\n"
    (dirp / f"{datestr}.log").write_bytes(b"\xff\xfe" + text.encode("utf-16-le"))


def _write_ea_log(dirp: Path, ea_id: int, entries):
    lines = []
    for e in entries:
        lines.append(json.dumps({
            "ea_id": ea_id, "slug": f"ea-{ea_id}", "symbol": e["symbol"],
            "event": "TM_OPEN",
            "payload": {"symbol": e["symbol"], "type": e["type"],
                        "ok": e["ok"], "ticket": e["ticket"]},
        }))
    (dirp / f"QM5_{ea_id}_ea-{ea_id}.log").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _run(tmp_path, since="20260701"):
    jd = tmp_path / "logs"; jd.mkdir()
    ed = tmp_path / "ea"; ed.mkdir()
    sd = tmp_path / "streams"; sd.mkdir()
    out = tmp_path / "out"
    _write_utf16_journal(jd, "20260702", _journal_lines())
    _write_ea_log(ed, 13213, [
        {"symbol": "USDJPY", "type": "QM_BUY_STOP", "ok": True, "ticket": 111},
        {"symbol": "USDJPY", "type": "QM_SELL_STOP", "ok": True, "ticket": 112},
    ])
    # Q08 backtest stream for sleeve 13213 (net values -> mean |net|)
    (sd / "13213_USDJPY_DWX.jsonl").write_text(
        "\n".join(json.dumps({
            "net": n, "profit": n, "swap": 0.0,
            "entry_commission": 0.0, "exit_commission": 0.0,
            "volume": 0.3, "symbol": "USDJPY.DWX", "magic": 132130001,
        }) for n in (-100.0, 200.0, -50.0)) + "\n", encoding="utf-8")
    eq.main([
        "--journal-dir", str(jd), "--ea-log-dir", str(ed),
        "--stream-root", str(sd), "--out-dir", str(out), "--since", since,
    ])
    return out


def _rows(path):
    return list(csv.DictReader(open(path, encoding="utf-8")))


def test_utf16_decode_and_pending_join_sign_convention(tmp_path):
    out = _run(tmp_path)
    fills = {r["deal_id"]: r for r in _rows(out / "fills.csv")}
    # UTF-16 decoded and parsed: all four deals present
    assert {"9001", "9002", "9003", "9004", "9005"} <= set(fills)
    # buy adverse = +1.0 point (F above trigger)
    assert abs(float(fills["9001"]["slippage_points"]) - 1.0) < 1e-6
    # sell adverse = +17.0 points (F below trigger)
    assert abs(float(fills["9002"]["slippage_points"]) - 17.0) < 1e-6
    # zero-slippage pending fill
    assert abs(float(fills["9003"]["slippage_points"])) < 1e-9
    # point inferred from decimals
    assert abs(float(fills["9001"]["point"]) - 0.001) < 1e-12
    assert fills["9001"]["point_source"] == "inferred_from_price_decimals"


def test_market_order_has_no_reference_and_unmatched_deal(tmp_path):
    out = _run(tmp_path)
    fills = {r["deal_id"]: r for r in _rows(out / "fills.csv")}
    # market/close order fill: matched but no reference price -> not eligible
    assert fills["9004"]["matched_order"] == "True"
    assert fills["9004"]["ref_price"] == ""
    assert fills["9004"]["slippage_eligible"] == "False"
    # deal referencing an unlogged order -> unmatched
    assert fills["9005"]["matched_order"] == "False"
    assert fills["9005"]["slippage_eligible"] == "False"
    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    cov = manifest["parse_coverage"]
    assert cov["matched_pending_with_ref"] == 3
    assert cov["matched_market_no_ref"] == 1
    assert cov["unmatched_deal_lines"] == 1


def test_sleeve_attribution_and_rejections(tmp_path):
    out = _run(tmp_path)
    fills = {r["deal_id"]: r for r in _rows(out / "fills.csv")}
    # ticket join -> ea_id 13213 for the two USDJPY pending fills
    assert fills["9001"]["ea_id"] == "13213"
    assert fills["9001"]["sleeve_attribution"] == "ticket_join"
    rej = _rows(out / "rejections.csv")
    kinds = {r["kind"] for r in rej}
    assert "failed_market_buy" in kinds
    assert "failed_cancel_order" in kinds
    assert "cancel_completed" in kinds


def test_minimum_sample_marking(tmp_path):
    out = _run(tmp_path)
    by_symbol = {r["group"]: r for r in _rows(out / "by_symbol.csv")}
    # USDJPY has only 2 slippage samples < 30 -> UNDERPOWERED
    assert by_symbol["USDJPY"]["n_slippage_samples"] == "2"
    assert by_symbol["USDJPY"]["power"] == "UNDERPOWERED"
    # money impact not computable without tick values
    assert by_symbol["USDJPY"]["execution_drag"] == "NOT_COMPUTABLE_NO_TICK_VALUE"
    # backtest reference wired in from Q08 stream (mean |net| of 100,200,50 = 116.67)
    assert abs(float(by_symbol["USDJPY"]["bt_mean_abs_net_per_trade"] or 0) - 0) < 1  # symbol has no bt ref
    by_sleeve = {r["group"]: r for r in _rows(out / "by_sleeve.csv")}
    assert abs(float(by_sleeve["13213"]["bt_mean_abs_net_per_trade"]) - (350.0 / 3)) < 1e-6


def test_since_filter_excludes_earlier_days(tmp_path):
    out = _run(tmp_path, since="20270101")
    fills = _rows(out / "fills.csv")
    assert fills == []
