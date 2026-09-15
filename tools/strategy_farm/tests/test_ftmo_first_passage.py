"""Tests for the FTMO first-passage / breach model.

Slice i1_ftmo_first_passage (directive 3 section 34). Covers: rule parameters read
from the bound rulepack (never hardcoded), breach detection on hand-built paths,
determinism from a frozen manifest, probability stability across two seeds, the
intraday-low proxy, and the FTMO->DWX symbol resolver.
"""
from __future__ import annotations

import datetime as dt
import json
from zoneinfo import ZoneInfo

import numpy as np

from tools.strategy_farm.ftmo import first_passage as fp


TZ = ZoneInfo("Europe/Prague")


# --------------------------------------------------------------------------- #
# Rulepack binding
# --------------------------------------------------------------------------- #
def test_rules_come_from_rulepack_not_hardcoded():
    rules = fp.load_rules()
    assert rules["id"] == "FTMO_2S_100K_STANDARD_V2"
    assert rules["initial_equity"] == 100_000.0
    assert rules["target_fraction"] == 0.10
    assert rules["daily_loss_fraction"] == 0.05
    assert rules["total_loss_fraction"] == 0.10
    assert rules["min_trading_days"] == 4
    assert rules["timezone"] == "Europe/Prague"
    assert rules["canonical_sha256"]  # non-empty hash recorded


def test_symbol_resolver_maps_broker_symbols():
    assert fp.resolve_dwx_symbol("USOIL.cash") == "XTIUSD.DWX"
    assert fp.resolve_dwx_symbol("GBPUSD") == "GBPUSD.DWX"
    assert fp.resolve_dwx_symbol("US100") == "NDX.DWX"
    assert fp.resolve_dwx_symbol("XAGUSD") == "XAGUSD.DWX"


def test_calendar_to_business_days():
    assert fp.calendar_to_business_days(30) == 21
    assert fp.calendar_to_business_days(60) == 43


# --------------------------------------------------------------------------- #
# Intraday-low proxy
# --------------------------------------------------------------------------- #
def test_sleeve_daily_intraday_low_from_mae():
    day = dt.datetime(2026, 1, 5, 12, tzinfo=dt.timezone.utc)
    trades = [
        {"close": day, "entry": day, "net": 100.0, "mae": -400.0, "lots": 1.0, "commission": 5.0},
        {"close": day.replace(hour=13), "entry": day, "net": -50.0, "mae": -200.0, "lots": 1.0, "commission": 5.0},
    ]
    daily = fp.sleeve_daily(trades, TZ)
    rec = daily[day.astimezone(TZ).date()]
    assert rec["net"] == 50.0            # 100 - 50
    # trough: first trade cum_before 0 + mae -400 = -400; second cum_before 100 + mae -200 = -100
    assert rec["low"] == -400.0
    assert rec["lots"] == 2.0
    assert rec["commission"] == 10.0
    assert rec["opened"] == 1.0


# --------------------------------------------------------------------------- #
# Breach / pass detection on hand-built paths
# --------------------------------------------------------------------------- #
def _grid(net, low, opened):
    n = len(net)
    net = np.array(net, dtype=float)
    low = np.array(low, dtype=float)
    opened = np.array(opened, dtype=bool)
    sleeve = fp.SleeveInput(ea_id=1, ftmo_symbol="X", dwx_symbol="X.DWX", magic=1,
                            risk_pct=1.0, stream_path="mem", stream_sha256="0",
                            trades=[], daily={})
    return {
        "ok": True,
        "active_sleeves": [sleeve],
        "grid": [dt.date(2026, 1, 1) + dt.timedelta(days=i) for i in range(n)],
        "net": net,
        "low": low,
        "lots": np.zeros(n),
        "commission": np.zeros(n),
        "opened": opened,
        "dom_idx": np.zeros(n, dtype=int),
        "weekday": np.zeros(n, dtype=int),
    }


def _rules():
    return fp.load_rules()


def test_pass_requires_target_and_min_days():
    rules = _rules()
    # +3000 four days -> +12000 after 4 opening days -> pass on day index 3
    grid = _grid([3000, 3000, 3000, 3000, 0, 0], [0] * 6, [True] * 6)
    idx = np.array([[0, 1, 2, 3, 4, 5]])
    res = fp.simulate(grid, rules, idx=idx, attribute=False)
    assert res["p_target_hit"] == 1.0
    assert res["p_daily_loss_breach"] == 0.0
    assert res["p_max_loss_breach"] == 0.0
    assert res["time_to_target_business_days"]["p50"] == 4.0  # 1-based day count


def test_min_trading_days_blocks_early_pass():
    rules = _rules()
    # target reached on day 1 (+11000) but only ONE opening day -> cannot pass until 4
    grid = _grid([11000, 500, 500, 500, 0, 0], [0] * 6,
                 [True, False, False, False, False, False])
    idx = np.array([[0, 1, 2, 3, 4, 5]])
    res = fp.simulate(grid, rules, idx=idx, attribute=False)
    # never accrues 4 opening days -> not a pass within the path
    assert res["p_target_hit"] == 0.0
    assert res["p_censored"] == 1.0


def test_daily_loss_breach_detected():
    rules = _rules()
    # day 1 intraday low -6000 (< -5000) -> daily-loss breach before any target
    grid = _grid([0, -3000, 0, 0], [0, -6000, 0, 0], [True] * 4)
    idx = np.array([[0, 1, 2, 3]])
    res = fp.simulate(grid, rules, idx=idx, attribute=False)
    assert res["p_daily_loss_breach"] == 1.0
    assert res["p_max_loss_breach"] == 0.0
    assert res["p_target_hit"] == 0.0


def test_max_loss_breach_detected():
    rules = _rules()
    # cumulative closes -4000, -4000 then day2 intraday low -3000 => equity -11000 (< -10000)
    # but each single-day low stays > -5000 so it is a TOTAL-loss breach, not daily.
    grid = _grid([-4000, -4000, 0, 0], [-4000, -4000, -3000, 0], [True] * 4)
    idx = np.array([[0, 1, 2, 3]])
    res = fp.simulate(grid, rules, idx=idx, attribute=False)
    assert res["p_max_loss_breach"] == 1.0
    assert res["p_daily_loss_breach"] == 0.0


def test_censored_when_unresolved():
    rules = _rules()
    grid = _grid([100, 100, 100, 100], [0] * 4, [True] * 4)  # +400 never hits +10000
    idx = np.array([[0, 1, 2, 3]])
    res = fp.simulate(grid, rules, idx=idx, attribute=False)
    assert res["p_censored"] == 1.0
    assert res["p_target_hit"] == 0.0


def test_cost_sensitivity_reduces_pass_or_raises_breach():
    rules = _rules()
    grid = _grid([3000, 3000, 3000, 3000, 0, 0], [0] * 6, [True] * 6)
    grid["commission"] = np.array([100.0] * 6)
    grid["lots"] = np.array([10.0] * 6)
    idx = np.array([[0, 1, 2, 3, 4, 5]])
    base = fp.simulate(grid, rules, idx=idx, attribute=False)
    # heavy slippage erodes the edge: 3000 - 2*10*... per day; still passes here but later
    heavy = fp.simulate(grid, rules, idx=idx, cost_mult=1.0, slippage_usd_per_lot=50.0, attribute=False)
    assert heavy["p_target_hit"] <= base["p_target_hit"] + 1e-9


# --------------------------------------------------------------------------- #
# Determinism and seed stability (fixture streams)
# --------------------------------------------------------------------------- #
def _write_fixture_stream(path, seed, n=400):
    """Deterministic synthetic TRADE_CLOSED stream with a small positive drift."""
    rng = np.random.default_rng(seed)
    base = dt.datetime(2020, 1, 1, tzinfo=dt.timezone.utc)
    lines = []
    day = 0
    for i in range(n):
        day += int(rng.integers(1, 4))
        close = base + dt.timedelta(days=day, hours=15)
        entry = close - dt.timedelta(hours=3)
        net = float(rng.normal(120.0, 800.0))
        mae = -abs(float(rng.normal(300.0, 200.0)))
        lines.append(json.dumps({
            "event": "TRADE_CLOSED", "time": int(close.timestamp()),
            "entry_time": int(entry.timestamp()), "net": round(net, 2),
            "mae_acct": round(mae, 2), "volume": 1.0, "commission": -5.0,
            "symbol": "GBPUSD.DWX",
        }))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _fixture_roster(tmp_path):
    s1 = tmp_path / "1001_GBPUSD_DWX.jsonl"
    s2 = tmp_path / "1002_GBPUSD_DWX.jsonl"
    _write_fixture_stream(s1, seed=1)
    _write_fixture_stream(s2, seed=2)
    spec = [
        {"ea_id": 1001, "symbol": "GBPUSD", "risk_pct": 0.5, "stream_path": str(s1)},
        {"ea_id": 1002, "symbol": "GBPUSD", "risk_pct": 0.5, "stream_path": str(s2)},
    ]
    return fp.roster_from_spec(spec, TZ)


def test_determinism_same_seed_identical(tmp_path):
    roster = _fixture_roster(tmp_path)
    rules = _rules()
    now = dt.datetime(2026, 9, 15, tzinfo=dt.timezone.utc)
    kw = dict(roster=roster, rules=rules, seed=123, n_paths=2000, horizon=300, now=now)
    a = fp.build(**kw)
    b = fp.build(**kw)
    assert a["status"] == "OK"
    assert a["headline"] == b["headline"]
    assert a["input_manifest_sha256"] == b["input_manifest_sha256"]


def test_probabilities_stable_across_seeds(tmp_path):
    roster = _fixture_roster(tmp_path)
    rules = _rules()
    now = dt.datetime(2026, 9, 15, tzinfo=dt.timezone.utc)
    a = fp.build(roster=roster, rules=rules, seed=11, n_paths=8000, horizon=300, now=now)
    b = fp.build(roster=roster, rules=rules, seed=99, n_paths=8000, horizon=300, now=now)
    ha, hb = a["headline"], b["headline"]
    for key in ("p_target_hit", "p_daily_loss_breach", "p_max_loss_breach", "p_censored"):
        assert abs(ha[key] - hb[key]) < 0.03, (key, ha[key], hb[key])


def test_build_from_manifest_matches(tmp_path):
    """Re-running from the frozen manifest's pinned streams reproduces the result."""
    roster = _fixture_roster(tmp_path)
    rules = _rules()
    now = dt.datetime(2026, 9, 15, tzinfo=dt.timezone.utc)
    a = fp.build(roster=roster, rules=rules, seed=7, n_paths=2000, horizon=300, now=now)
    # rebuild roster from the same stream paths recorded in the manifest
    streams = a["input_manifest"]["streams"]
    spec = []
    for row in streams:
        ea, dwx = row["sleeve"].split(":")
        spec.append({"ea_id": int(ea), "dwx_symbol": dwx, "risk_pct": row["risk_pct"],
                     "stream_path": row["stream_path"]})
    roster2 = fp.roster_from_spec(spec, TZ)
    b = fp.build(roster=roster2, rules=rules, seed=7, n_paths=2000, horizon=300, now=now)
    assert a["headline"]["p_target_hit"] == b["headline"]["p_target_hit"]
    assert a["input_manifest_sha256"] == b["input_manifest_sha256"]


def test_missing_roster_degrades_not_invents(tmp_path):
    rules = _rules()
    roster = fp.roster_from_spec([{"ea_id": 999, "symbol": "NOPE", "risk_pct": 1.0,
                                   "stream_path": str(tmp_path / "absent.jsonl")}], TZ)
    model = fp.build(roster=roster, rules=rules, n_paths=100, horizon=50)
    assert model["status"] == fp.MISSING
    assert model["headline"] == fp.MISSING
    assert fp.load_for_readiness  # symbol exists


def test_conditional_failure_modes_present(tmp_path):
    roster = _fixture_roster(tmp_path)
    rules = _rules()
    model = fp.build(roster=roster, rules=rules, seed=5, n_paths=4000, horizon=400,
                     now=dt.datetime(2026, 9, 15, tzinfo=dt.timezone.utc))
    modes = model["headline"]["conditional_failure_modes"]
    assert "by_type" in modes and "dominant_sleeve" in modes and "by_weekday" in modes
    assert modes["by_type"]["daily_loss"] + modes["by_type"]["max_loss"] == modes["n_breach"]
