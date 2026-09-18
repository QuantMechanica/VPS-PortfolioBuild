"""Tests for the read-only live sleeve drift monitor.

Covers the deterministic statistics (Poisson lower/upper tail, Mann-Whitney U,
mean-percentile) on known inputs and an end-to-end run over synthetic EA-log +
journal + backtest-stream fixtures exercising each alarm class:
  dark sleeve      -> ALARM_DARK
  healthy sleeve   -> OK
  silent EA log    -> ALARM_SILENT
  basket warmup=0  -> ALARM_WARMUP_EMPTY
"""

import json
import math
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import live_sleeve_drift_monitor as m  # noqa: E402


# --------------------------------------------------------------------------- #
# Pure statistics
# --------------------------------------------------------------------------- #
def test_poisson_cdf_zero_equals_exp_neg_lambda():
    for lam in (0.5, 3.0, 5.0, 4.585, 9.0):
        assert math.isclose(m.poisson_cdf(0, lam), math.exp(-lam), rel_tol=1e-12)


def test_poisson_cdf_known_small_case():
    # P(X<=1 | 1.0) = e^-1 (1 + 1) = 2/e
    assert math.isclose(m.poisson_cdf(1, 1.0), 2.0 / math.e, rel_tol=1e-12)
    # monotone non-decreasing in k, capped at 1
    assert m.poisson_cdf(0, 3.0) < m.poisson_cdf(3, 3.0) <= 1.0


def test_poisson_dark_thresholds_match_metric_spec():
    # 12969-like: expected ~6.94 -> ALARM_DARK ; 13117-like: ~4.585 -> WARN_LOW
    assert m.poisson_cdf(0, 6.94) < m.POISSON_ALARM_DARK_P
    assert m.POISSON_ALARM_DARK_P < m.poisson_cdf(0, 4.585) < m.POISSON_WARN_LOW_P


def test_poisson_sf_inclusive_upper_tail():
    # P(X>=1 | 1.0) = 1 - e^-1
    assert math.isclose(m.poisson_sf_inclusive(1, 1.0), 1.0 - math.exp(-1.0), rel_tol=1e-12)
    assert m.poisson_sf_inclusive(0, 3.0) == 1.0
    # heavy over-trading (obs=42, expected=2.5) is astronomically unlikely
    assert m.poisson_sf_inclusive(42, 2.5) < m.POISSON_WARN_HIGH_P


def test_mann_whitney_disjoint_samples():
    res = m.mann_whitney([1, 2, 3, 4], [5, 6, 7, 8], alternative="less")
    assert res["u1"] == 0.0
    assert res["u2"] == 16.0
    assert res["p"] < 0.05  # live strictly below backtest


def test_mann_whitney_identical_distributions_not_significant():
    res = m.mann_whitney([1, 2, 3, 4], [1, 2, 3, 4], alternative="less")
    assert res["u1"] == 8.0  # n1*n2/2
    assert res["p"] > 0.05


def test_mean_percentile_known_inputs():
    assert m.mean_percentile([5], [1, 2, 3, 4, 5]) == 0.9  # (4 below + 0.5 eq)/5
    assert m.mean_percentile([0], [1, 2, 3, 4]) == 0.0
    assert m.mean_percentile([10], [1, 2, 3, 4]) == 1.0
    assert m.mean_percentile([], [1, 2, 3]) is None


def test_trading_days_between():
    from datetime import date
    # Mon 2026-09-07 .. Fri 2026-09-11 inclusive = 5 weekdays
    assert m.trading_days_between(date(2026, 9, 7), date(2026, 9, 11)) == 5
    # spanning a weekend
    assert m.trading_days_between(date(2026, 9, 11), date(2026, 9, 14)) == 2  # Fri + Mon


# --------------------------------------------------------------------------- #
# End-to-end fixtures
# --------------------------------------------------------------------------- #
NOW = datetime(2026, 9, 13, 20, 0, 0, tzinfo=timezone.utc)


def _log_line(ea_id, symbol, event, payload, ts_utc, tf="H1"):
    return json.dumps({
        "ts_utc": ts_utc, "ts_broker": ts_utc.replace("Z", ""),
        "level": "INFO", "ea_id": ea_id, "slug": f"ea-{ea_id}",
        "symbol": symbol, "tf": tf, "magic": ea_id * 10000,
        "event": event, "payload": payload,
    })


def _write_ea_log(ea_dir, ea_id, lines):
    (ea_dir / f"QM5_{ea_id}_ea-{ea_id}.log").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_stream(stream_root, ea_id, symbol_norm, entry_days, nets):
    """entry_days: list of 'YYYY-MM-DD' entry dates; nets: list of net $ per trade."""
    recs = []
    for d, net in zip(entry_days, nets):
        ts = int(datetime.fromisoformat(d + "T00:00:00+00:00").timestamp())
        recs.append(json.dumps({
            "event": "TRADE_CLOSED", "magic": ea_id * 10000, "symbol": f"{symbol_norm}.DWX",
            "entry_time": ts, "time": ts + 3600, "net": net, "volume": 1.0,
        }))
    (stream_root / f"{ea_id}_{symbol_norm}_DWX.jsonl").write_text("\n".join(recs) + "\n", encoding="utf-8")


def _build_env(tmp_path):
    ea_dir = tmp_path / "ea"
    journal_dir = tmp_path / "journals"
    stream_root = tmp_path / "streams"
    for p in (ea_dir, journal_dir, stream_root):
        p.mkdir(parents=True, exist_ok=True)

    # 10 weekday span 2026-01-05(Mon)..2026-01-16(Fri) for controllable lambda.
    span = ["2026-01-05", "2026-01-06", "2026-01-07", "2026-01-08", "2026-01-09",
            "2026-01-12", "2026-01-13", "2026-01-14", "2026-01-15", "2026-01-16"]

    # DARK 9001: lambda=1.0 (10 trades/10 wd); deploy 2026-09-01 -> days_live=9 -> exp=9 -> ALARM_DARK
    _write_stream(stream_root, 9001, "EURUSD", span, [100.0] * 10)
    _write_ea_log(ea_dir, 9001, [
        _log_line(9001, "EURUSD", "INIT_OK", {}, "2026-09-01T06:00:00Z"),
        _log_line(9001, "EURUSD", "EQUITY_SNAPSHOT", {"equity": 100000}, "2026-09-11T20:00:00Z"),
    ])

    # low-lambda entry days spanning the full 10-weekday window (3 trades/10wd
    # => lambda 0.3 => expected ~2.7 over 9 days_live => NOT dark)
    span3 = ["2026-01-05", "2026-01-09", "2026-01-16"]
    # 5 trades spanning the full window => lambda 0.5 => expected ~4.5
    span5 = ["2026-01-05", "2026-01-07", "2026-01-09", "2026-01-13", "2026-01-16"]

    # HEALTHY 9002: lambda=0.5 -> exp=4.5 ; observed=5 TM_OPEN ok -> OK
    _write_stream(stream_root, 9002, "GBPUSD", span5, [50.0] * 5)
    healthy = [_log_line(9002, "GBPUSD", "INIT_OK", {}, "2026-09-01T06:00:00Z")]
    healthy_deals = []
    for i in range(5):
        healthy.append(_log_line(9002, "GBPUSD", "TM_OPEN",
                                 {"symbol": "GBPUSD", "type": "QM_BUY", "ok": True, "ticket": 500 + i,
                                  "entry_result": "QM_ENTRY_OK"}, f"2026-09-0{i + 4}T10:00:00Z"))
        # each placement FILLS -> a journal deal based on that order ticket
        healthy_deals.append(
            f"AA\t0\t10:00:0{i}.100\tTrades\t'40001': deal #{60000 + i} buy 1.00 GBPUSD "
            f"at 1.30000 done (based on order #{500 + i})")
    healthy.append(_log_line(9002, "GBPUSD", "EQUITY_SNAPSHOT", {"equity": 100000}, "2026-09-11T20:00:00Z"))
    _write_ea_log(ea_dir, 9002, healthy)

    # SILENT 9003: lambda small (exp~2.7 not dark); last line 2026-09-08 -> 3 trading days old
    _write_stream(stream_root, 9003, "USDJPY", span3, [10.0] * 3)
    _write_ea_log(ea_dir, 9003, [
        _log_line(9003, "USDJPY", "INIT_OK", {}, "2026-09-01T06:00:00Z"),
        _log_line(9003, "USDJPY", "EQUITY_SNAPSHOT", {"equity": 100000}, "2026-09-08T20:00:00Z"),
    ])

    # WARMUP-EMPTY 9004: basket, loaded=0; lambda small (exp~2.7 not dark); fresh heartbeat
    _write_stream(stream_root, 9004, "AUDUSD", span3, [10.0] * 3)
    _write_ea_log(ea_dir, 9004, [
        _log_line(9004, "AUDUSD", "SYMBOL_GUARD_INIT",
                  {"mode": "basket", "n_symbols": 4,
                   "symbols": ["AUDUSD.DWX", "EURJPY.DWX", "EURUSD.DWX", "EURAUD.DWX"]}, "2026-09-01T06:00:00Z"),
        _log_line(9004, "AUDUSD", "BASKET_WARMUP", {"requested": 4, "loaded": 0, "skipped": 4}, "2026-09-01T06:00:01Z"),
        _log_line(9004, "AUDUSD", "INIT_OK", {}, "2026-09-01T06:00:02Z"),
        _log_line(9004, "AUDUSD", "EQUITY_SNAPSHOT", {"equity": 100000}, "2026-09-11T20:00:00Z"),
    ])

    # journal: the healthy sleeve's 5 fills (perf stays n<10 for all)
    (journal_dir / "20260904.log").write_text("\n".join(healthy_deals) + "\n", encoding="utf-8")

    manifest = {
        "sleeves": [
            {"ea_id": 9001, "symbol": "EURUSD.DWX", "ex5_deployed_mtime": "2026-09-01T06:00:00"},
            {"ea_id": 9002, "symbol": "GBPUSD.DWX", "ex5_deployed_mtime": "2026-09-01T06:00:00"},
            {"ea_id": 9003, "symbol": "USDJPY.DWX", "ex5_deployed_mtime": "2026-09-01T06:00:00"},
            {"ea_id": 9004, "symbol": "AUDUSD.DWX", "ex5_deployed_mtime": "2026-09-01T06:00:00"},
        ]
    }
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    pulse = {
        "effective_state": "RUNNING",
        "generated_at_utc": "2026-09-13T20:00:02Z",
        "book_manifest": {
            "path": str(manifest_path),
            "sleeves": [
                {"ea_id": 9001, "symbol": "EURUSD.DWX", "symbol_norm": "EURUSD", "key": "9001|EURUSD", "magic": 90010000, "ea_label": "dark"},
                {"ea_id": 9002, "symbol": "GBPUSD.DWX", "symbol_norm": "GBPUSD", "key": "9002|GBPUSD", "magic": 90020000, "ea_label": "healthy"},
                {"ea_id": 9003, "symbol": "USDJPY.DWX", "symbol_norm": "USDJPY", "key": "9003|USDJPY", "magic": 90030000, "ea_label": "silent"},
                {"ea_id": 9004, "symbol": "AUDUSD.DWX", "symbol_norm": "AUDUSD", "key": "9004|AUDUSD", "magic": 90040000, "ea_label": "warmup"},
            ],
        },
    }
    pulse_path = tmp_path / "pulse.json"
    pulse_path.write_text(json.dumps(pulse), encoding="utf-8")
    return pulse_path, ea_dir, journal_dir, stream_root


def _by_key(out):
    return {s["key"]: s for s in out["sleeves"]}


def test_end_to_end_alarm_classes(tmp_path):
    pulse_path, ea_dir, journal_dir, stream_root = _build_env(tmp_path)
    out = m.run(pulse_path, ea_dir, journal_dir, [stream_root], now=NOW)

    assert out["schema"] == "qm.live-sleeve-drift/v1"
    assert out["sleeve_count"] == 4
    rows = _by_key(out)

    # DARK
    dark = rows["9001|EURUSD"]
    assert dark["activity"]["observed_entries"] == 0
    assert dark["activity"]["expected"] == 9.0  # lambda 1.0 * 9 trading days
    assert "ALARM_DARK" in dark["alarm_codes"]
    assert dark["verdict"] == "ALARM"

    # HEALTHY (5 placements all filled -> observed fills == 5)
    healthy = rows["9002|GBPUSD"]
    assert healthy["activity"]["observed_entries"] == 5
    assert healthy["activity"]["placements"] == 5
    assert healthy["activity"]["observed_source"] == "journal_fill_join"
    assert healthy["alarm_codes"] == []
    assert healthy["verdict"] == "OK"

    # SILENT
    silent = rows["9003|USDJPY"]
    assert "ALARM_SILENT" in silent["alarm_codes"]
    assert silent["verdict"] == "ALARM"

    # WARMUP EMPTY
    warmup = rows["9004|AUDUSD"]
    assert "ALARM_WARMUP_EMPTY" in warmup["alarm_codes"]
    assert warmup["symbol_check"]["warmup_empty_events"] == 1
    assert warmup["verdict"] == "ALARM"

    # summary + alarm rollup
    assert set(out["summary"]["dark"]) == {"9001|EURUSD"}
    assert set(out["summary"]["silent"]) == {"9003|USDJPY"}
    assert set(out["summary"]["warmup_empty"]) == {"9004|AUDUSD"}
    assert out["verdict"] == "ALARM"


def test_ks_state_file_mtime_reads_stat(tmp_path):
    halt_dir = tmp_path / "halt"
    halt_dir.mkdir()
    state_path = halt_dir / "ks_state_1567_15670007.state"
    state_path.write_text("day_key=1\n", encoding="utf-8")
    ts = datetime(2026, 9, 17, 23, 4, 0, tzinfo=timezone.utc)
    os.utime(state_path, (ts.timestamp(), ts.timestamp()))

    got = m.ks_state_file_mtime(tmp_path, 1567, 15670007)
    assert got is not None
    assert abs((got - ts).total_seconds()) < 1

    assert m.ks_state_file_mtime(tmp_path, 1567, None) is None  # no magic -> no signal
    assert m.ks_state_file_mtime(tmp_path, 9999, 90000000) is None  # no file -> no signal


def test_ks_state_mtime_prevents_false_alarm_silent_after_reboot(tmp_path):
    """OWNER 2026-09-17 (1567/EURUSD): a VPS reboot orphans the per-EA JSONL
    logger's file handle so it never appends again, while the EA keeps trading
    (QM_KillSwitchCheck runs every OnTick and refreshes ks_state once per broker
    day). The stale log alone must not raise ALARM_SILENT once a fresher
    ks_state mtime proves the sleeve is alive."""
    pulse_path, ea_dir, journal_dir, stream_root = _build_env(tmp_path)

    # 9003 (SILENT fixture): log last line is 2026-09-08, which alone is stale
    # enough (NOW=2026-09-13) to trip ALARM_SILENT -- confirmed by the sibling
    # test_end_to_end_alarm_classes. Give it a fresh ks_state file instead.
    halt_dir = ea_dir / "halt"
    halt_dir.mkdir(parents=True, exist_ok=True)
    state_path = halt_dir / "ks_state_9003_90030000.state"
    state_path.write_text("day_key=1\n", encoding="utf-8")
    fresh = NOW - timedelta(hours=2)
    os.utime(state_path, (fresh.timestamp(), fresh.timestamp()))

    out = m.run(pulse_path, ea_dir, journal_dir, [stream_root], now=NOW)
    row = _by_key(out)["9003|USDJPY"]

    assert "ALARM_SILENT" not in row["alarm_codes"]
    assert row["heartbeat"]["liveness_source"] == "ks_state_mtime"
    assert row["heartbeat"]["age_trading_days"] == 0
    assert "9003|USDJPY" not in out["summary"]["silent"]


def test_eval_heartbeat_still_alarms_when_both_signals_stale():
    ea = {"exists": True, "last_line_ts": "2026-09-01T06:00:00Z", "first_init_ok": "2026-09-01T06:00:00Z"}
    stale_ks = datetime(2026, 9, 2, 6, 0, 0, tzinfo=timezone.utc)
    row = m.eval_heartbeat(ea, NOW, "RUNNING", ks_state_mtime=stale_ks)
    assert row["liveness_source"] == "ks_state_mtime"  # ks_state is the newer of the two
    assert "ALARM_SILENT" in row["codes"]
    assert row["verdict"] == "ALARM"


def test_performance_pairs_journal_exit_and_flags_drift(tmp_path):
    """A sleeve with >=10 paired round-trips whose live R is far below the
    backtest R sample must raise WARN_PERF."""
    pulse_path, ea_dir, journal_dir, stream_root = _build_env(tmp_path)

    # backtest R centred well above 0 (all winners): net 1000 -> R=+1.0
    _write_stream(stream_root, 9005, "EURUSD",
                  ["2026-01-05"] * 20, [1000.0] * 20)

    # 12 live entries, each a full -1R loss: BUY at 1.0000 SL 0.9900 (risk 0.01),
    # exit deal (sell) at 0.9900 -> R = (0.9900-1.0000)/0.01 = -1.0
    lines = [_log_line(9005, "EURUSD", "INIT_OK", {}, "2026-09-01T06:00:00Z")]
    deal_lines = []
    for i in range(12):
        ticket = 7000 + i
        entry_ts = f"2026-09-0{(i % 9) + 1}T09:00:00Z".replace("0T", "1T") if i >= 9 else f"2026-09-0{i + 1}T09:00:00Z"
        # keep timestamps valid/simple
        entry_ts = "2026-09-02T09:00:00Z"
        lines.append(_log_line(9005, "EURUSD", "ENTRY_ACCEPTED",
                               {"ticket": ticket, "symbol": "EURUSD", "type": "QM_BUY",
                                "lots": 1.0, "price": 1.0000, "sl": 0.9900}, entry_ts))
        lines.append(_log_line(9005, "EURUSD", "TM_OPEN",
                               {"symbol": "EURUSD", "type": "QM_BUY", "ok": True, "ticket": ticket,
                                "entry_result": "QM_ENTRY_OK"}, entry_ts))
        lines.append(_log_line(9005, "EURUSD", "TM_CLOSE",
                               {"ticket": ticket, "symbol": "EURUSD", "ok": True}, "2026-09-02T15:00:00Z"))
        # journal exit deal: opposite side (sell) near TM_CLOSE broker time
        deal_lines.append(
            f"XX\t0\t15:00:0{i % 10}.100\tTrades\t'40001': deal #{80000 + i} sell 1.00 EURUSD "
            f"at 0.99000 done (based on order #{9000 + i})")
    lines.append(_log_line(9005, "EURUSD", "EQUITY_SNAPSHOT", {"equity": 100000}, "2026-09-11T20:00:00Z"))
    _write_ea_log(ea_dir, 9005, lines)
    (journal_dir / "20260902.log").write_text("\n".join(deal_lines) + "\n", encoding="utf-8")

    # register 9005 in pulse + manifest
    pulse = json.loads(pulse_path.read_text(encoding="utf-8"))
    pulse["book_manifest"]["sleeves"].append(
        {"ea_id": 9005, "symbol": "EURUSD.DWX", "symbol_norm": "EURUSD", "key": "9005|EURUSD",
         "magic": 90050000, "ea_label": "perf"})
    pulse_path.write_text(json.dumps(pulse), encoding="utf-8")
    manifest_path = Path(pulse["book_manifest"]["path"])
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["sleeves"].append({"ea_id": 9005, "symbol": "EURUSD.DWX", "ex5_deployed_mtime": "2026-09-01T06:00:00"})
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    out = m.run(pulse_path, ea_dir, journal_dir, [stream_root], now=NOW)
    perf = _by_key(out)["9005|EURUSD"]["performance"]
    assert perf["n_live"] == 12
    assert perf["round_trips_paired"] == 12
    assert perf["live_r_mean"] == -1.0
    assert perf["mw_p"] is not None and perf["mw_p"] < m.PERF_ALPHA
    assert "WARN_PERF" in _by_key(out)["9005|EURUSD"]["alarm_codes"]


def test_observed_counts_fills_not_placements(tmp_path):
    """observed must be FILLED positions (journal deals joined by TM_OPEN ticket),
    not order placements. A sleeve that places many pending orders but fills few
    must NOT raise WARN_HIGH; a sleeve whose placements all fill must.
    """
    ea_dir = tmp_path / "ea"
    journal_dir = tmp_path / "journals"
    stream_root = tmp_path / "streams"
    for p in (ea_dir, journal_dir, stream_root):
        p.mkdir(parents=True, exist_ok=True)

    # low-lambda backtests -> small expected (like 10403/1556: many placements)
    wide = ["2026-01-05", "2026-02-16"]  # 2 trades over ~31 weekdays -> lambda ~0.065

    # ARTEFACT sleeve 9100: 20 placements, only 2 fill (tickets 1,2 in journal)
    _write_stream(stream_root, 9100, "EURUSD", wide, [10.0, 10.0])
    art = [_log_line(9100, "EURUSD", "INIT_OK", {}, "2026-09-01T06:00:00Z")]
    for i in range(1, 21):
        art.append(_log_line(9100, "EURUSD", "TM_OPEN",
                             {"symbol": "EURUSD", "type": "QM_BUY", "ok": True, "ticket": i,
                              "entry_result": "QM_ENTRY_OK"}, "2026-09-02T09:00:00Z"))
    art.append(_log_line(9100, "EURUSD", "EQUITY_SNAPSHOT", {"equity": 100000}, "2026-09-11T20:00:00Z"))
    _write_ea_log(ea_dir, 9100, art)

    # GENUINE sleeve 9101: 6 placements, all 6 fill (tickets 101..106 in journal)
    _write_stream(stream_root, 9101, "GBPUSD", wide, [10.0, 10.0])
    gen = [_log_line(9101, "GBPUSD", "INIT_OK", {}, "2026-09-01T06:00:00Z")]
    for i in range(101, 107):
        gen.append(_log_line(9101, "GBPUSD", "TM_OPEN",
                            {"symbol": "GBPUSD", "type": "QM_BUY", "ok": True, "ticket": i,
                             "entry_result": "QM_ENTRY_OK"}, "2026-09-02T09:00:00Z"))
    gen.append(_log_line(9101, "GBPUSD", "EQUITY_SNAPSHOT", {"equity": 100000}, "2026-09-11T20:00:00Z"))
    _write_ea_log(ea_dir, 9101, gen)

    deal_lines = []
    for i in (1, 2):  # only 2 of 9100's 20 placements filled
        deal_lines.append(f"AA\t0\t09:00:0{i}.100\tTrades\t'40001': deal #{i} buy 1.00 EURUSD "
                          f"at 1.10000 done (based on order #{i})")
    for i in range(101, 107):  # all 6 of 9101's placements filled
        deal_lines.append(f"AA\t0\t09:0{i - 100}:00.100\tTrades\t'40001': deal #{i} buy 1.00 GBPUSD "
                         f"at 1.30000 done (based on order #{i})")
    (journal_dir / "20260902.log").write_text("\n".join(deal_lines) + "\n", encoding="utf-8")

    manifest = {"sleeves": [
        {"ea_id": 9100, "symbol": "EURUSD.DWX", "ex5_deployed_mtime": "2026-09-01T06:00:00"},
        {"ea_id": 9101, "symbol": "GBPUSD.DWX", "ex5_deployed_mtime": "2026-09-01T06:00:00"},
    ]}
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    pulse = {"effective_state": "RUNNING", "book_manifest": {"path": str(manifest_path), "sleeves": [
        {"ea_id": 9100, "symbol": "EURUSD.DWX", "symbol_norm": "EURUSD", "key": "9100|EURUSD", "magic": 91000000},
        {"ea_id": 9101, "symbol": "GBPUSD.DWX", "symbol_norm": "GBPUSD", "key": "9101|GBPUSD", "magic": 91010000},
    ]}}
    pulse_path = tmp_path / "pulse.json"
    pulse_path.write_text(json.dumps(pulse), encoding="utf-8")

    out = m.run(pulse_path, ea_dir, journal_dir, [stream_root], now=NOW)
    rows = _by_key(out)

    art = rows["9100|EURUSD"]["activity"]
    assert art["placements"] == 20
    assert art["observed_entries"] == 2          # fills, not placements
    assert art["observed_source"] == "journal_fill_join"
    assert "WARN_HIGH_ACTIVITY" not in rows["9100|EURUSD"]["alarm_codes"]  # artefact suppressed

    gen = rows["9101|GBPUSD"]["activity"]
    assert gen["placements"] == 6
    assert gen["observed_entries"] == 6
    assert "WARN_HIGH_ACTIVITY" in rows["9101|GBPUSD"]["alarm_codes"]      # genuine over-trading


def test_out_path_refused_under_live_root(tmp_path, monkeypatch, capsys):
    # --out under T_Live must be refused (read-only contract) and still exit 0
    rc = m.main([
        "--pulse", str(tmp_path / "missing.json"),
        "--out", str(m.LIVE_ROOT / "x.json"),
    ])
    assert rc == 0
    assert "refusing to write inside live terminal tree" in capsys.readouterr().err
