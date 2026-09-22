from __future__ import annotations

import datetime as dt
import json

from tools.strategy_farm.research import cross_symbol_scanner as scan


def _record(ret: float, atr: float = 1.0, confirm: float | None = None):
    return {
        "start": 0, "end": 3600, "open": 100.0, "high": 101.0, "low": 99.0,
        "close": 100.0 + ret, "ret": ret, "range": 2.0,
        "confirm_ret": ret if confirm is None else confirm,
        "post_confirm_open": 100.0, "post_confirm_ret": ret,
        "n": 60, "hold_min": 60.0, "post_confirm_hold_min": 45.0,
        "atr": atr, "vol_state": "MID",
    }


def _fixture(planted: bool):
    ref_sessions = {name: {} for name in scan.SESSION_ORDER}
    exe_sessions = {name: {} for name in scan.SESSION_ORDER}
    daily_ref, daily_exe = {}, {}
    days = []
    for year, n in ((2020, 80), (2024, 80)):
        day = dt.date(year, 1, 2)
        made = 0
        while made < n:
            if day.weekday() < 5:
                days.append(day)
                made += 1
            day += dt.timedelta(days=1)
    for i, day in enumerate(days):
        key = day.isoformat()
        sign = 1 if i % 2 == 0 else -1
        lead = 1.2 * sign
        if planted:
            response = 0.45 * sign + (0.03 if i % 3 == 0 else -0.03)
        else:
            response = 0.20 * (1 if (i // 2) % 2 == 0 else -1)
        for name in scan.SESSION_ORDER:
            ref_sessions[name][key] = _record(lead if name == "LONDON" else 0.1 * sign, confirm=0.2 * sign)
            exe_sessions[name][key] = _record(response if name == "NY_PREOPEN" else 0.0)
        daily_ref[key] = daily_exe[key] = {"open": 99.0, "high": 101.0, "low": 98.0, "close": 100.0, "close_location": 0.5}
    prior = {"spread_rt": 0.01, "slip_rt": 0.0, "tick": 0.01, "source": "synthetic"}
    return {
        "REF.DWX": {"symbol": "REF.DWX", "sessions": ref_sessions, "daily": daily_ref, "cost_prior": prior},
        "EXE.DWX": {"symbol": "EXE.DWX", "sessions": exe_sessions, "daily": daily_exe, "cost_prior": prior},
    }


def test_planted_lead_lag_survives_fdr_and_locked_holdout():
    prepared = _fixture(planted=True)
    cells = scan.build_cells(prepared, ("REF.DWX", "EXE.DWX"), thresholds=(0.5,), sessions=("NY_PREOPEN",), include_single=False)
    bh = scan.apply_bh(cells, q=0.10, min_sample=30)
    scan.attach_neighbor_robustness(cells, (0.5,))
    target = next(c for c in cells if c["reference_symbol"] == "REF.DWX" and c["execution_symbol"] == "EXE.DWX"
                  and c["confirmation"] == "LEAD_ONLY" and c["relation"] == "CONTINUATION")
    assert bh["cutoff_rank"] > 0
    assert target["fdr_reject_10pct"] is True
    assert target["validation_same_sign_half_effect"] is True
    assert target["state"] == "WORTH_MT5_TEST"


def test_null_fixture_has_no_survivor_after_fdr():
    prepared = _fixture(planted=False)
    cells = scan.build_cells(prepared, ("REF.DWX", "EXE.DWX"), thresholds=(0.5,), sessions=("NY_PREOPEN",), include_single=False)
    scan.apply_bh(cells, q=0.10, min_sample=30)
    assert not any(c["state"] == "WORTH_MT5_TEST" for c in cells)


def test_canonical_json_is_deterministic():
    obj = {"b": [2, 1], "a": {"z": 3, "x": 1}}
    first = scan.canonical_json(obj)
    second = scan.canonical_json(obj)
    assert first == second
    assert json.loads(first) == obj
    assert scan.canonical_json(obj, compact=True) == scan.canonical_json(obj, compact=True)

    prepared = _fixture(planted=True)
    runs = []
    for _ in range(2):
        cells = scan.build_cells(prepared, ("REF.DWX", "EXE.DWX"), thresholds=(0.5,), sessions=("NY_PREOPEN",), include_single=False)
        scan.apply_bh(cells, q=0.10, min_sample=30)
        scan.attach_neighbor_robustness(cells, (0.5,))
        runs.append(scan.canonical_json([{k: v for k, v in c.items() if k != "_observations"} for c in cells], compact=True))
    assert runs[0] == runs[1]


def test_session_epochs_round_trip_through_dst_divergence_weeks():
    # US is already on DST while London is not on 2026-03-16; both helpers
    # still round-trip each local contract boundary exactly.
    for day in (dt.date(2026, 3, 16), dt.date(2026, 3, 30), dt.date(2026, 10, 26)):
        for name in ("LONDON", "NY_PREOPEN", "LONDON_NY_OVERLAP"):
            tz, hm, _end = scan.SESSION_SPECS[name]
            start, _ = scan._window_epochs(day, scan.SESSION_SPECS[name])
            utc = dt.datetime.fromtimestamp(scan.F1.utc_from_server(start), dt.timezone.utc)
            local = utc.astimezone(tz)
            assert (local.date(), local.hour, local.minute) == (day, hm[0], hm[1])
