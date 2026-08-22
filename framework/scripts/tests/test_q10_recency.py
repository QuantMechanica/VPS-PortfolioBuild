"""Tests for Q10 recency metrics and dated-cohort enforcement.

Three guarantees are proven here:
  1. The Q10 full-history base verdict remains independently locked (fixture
     battery on `_decide_verdict`; signature has no recency parameter). The DD ceiling is the
     ratified 25% (decisions/2026-07-15_dd_ceiling_25pct_portfolio_rationale.md):
     16% PASSES, 25% is the pass/fail boundary, 25.01%/26% FAIL. (Round-1 tests
     asserted an obsolete 15% ceiling; corrected here to current policy.)
  2. The recency classifier flips CURRENT/WATCH/DECAYED at the documented
     boundaries, tested at 19.9/20.0/20.1 and 24.9/25.0/25.1 percent, plus the
     UNKNOWN coverage gates and the Q08 40 % / trailing-PF<1 overrides.
  3. The evidence-identity block binds report/set/EX5 SHA-256 + window endpoint +
     manifest reference, with an explicit "UNKNOWN" for every unresolvable hash.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import inspect
from pathlib import Path

import pytest

from framework.scripts import q10_recency as R
from framework.scripts.q10_confirmation import (
    _apply_recency_gate, _decide_verdict, _resolve_ex5_source,
    Q10_RECENCY_ENFORCEMENT_CREATED_AT, RECENCY_AXIS_ENFORCED, DD_PCT_MAX, PF_FLOOR,
)


# ---------------------------------------------------------------------------
# 1. Verdict invariance — current ratified policy (PF floor 1.0, DD ceiling 25%)
# ---------------------------------------------------------------------------
def test_ceiling_is_current_25pct_policy():
    # Guards against a silent regression back to the obsolete 15% ceiling.
    assert DD_PCT_MAX == 25.0
    assert PF_FLOOR == 1.0


VERDICT_CASES = [
    # (kwargs, expected_verdict, expected_reason)
    (dict(timed_out=True, invalid_reason=None, pf=1.3, dd_money=100.0, dd_pct=2.0, timeout_sec=3600),
     "INVALID", "timeout_expired:timeout_sec=3600"),
    (dict(timed_out=True, invalid_reason="NO_HISTORY", pf=None, dd_money=None, dd_pct=None, timeout_sec=900),
     "INVALID", "timeout_expired:timeout_sec=900"),   # timed_out precedes invalid_reason
    (dict(timed_out=False, invalid_reason="NO_HISTORY", pf=1.3, dd_money=1.0, dd_pct=1.0, timeout_sec=3600),
     "INVALID", "NO_HISTORY"),
    (dict(timed_out=False, invalid_reason=None, pf=None, dd_money=100.0, dd_pct=2.0, timeout_sec=3600),
     "INVALID", "missing_pf_or_dd_in_summary"),
    (dict(timed_out=False, invalid_reason=None, pf=1.3, dd_money=None, dd_pct=None, timeout_sec=3600),
     "INVALID", "missing_pf_or_dd_in_summary"),
    (dict(timed_out=False, invalid_reason=None, pf=1.0, dd_money=100.0, dd_pct=2.0, timeout_sec=3600),
     "FAIL", "pf_below_floor:pf=1.000:floor=1.0"),     # pf == floor still fails
    (dict(timed_out=False, invalid_reason=None, pf=0.95, dd_money=100.0, dd_pct=2.0, timeout_sec=3600),
     "FAIL", "pf_below_floor:pf=0.950:floor=1.0"),
    # DD ceiling is 25% now (was 15% in the stale round-1 suite):
    (dict(timed_out=False, invalid_reason=None, pf=1.24, dd_money=26000.0, dd_pct=26.0, timeout_sec=3600),
     "FAIL", "dd_above_ceiling:dd_pct=26.00:max=25.0"),
    (dict(timed_out=False, invalid_reason=None, pf=1.24, dd_money=25010.0, dd_pct=25.01, timeout_sec=3600),
     "FAIL", "dd_above_ceiling:dd_pct=25.01:max=25.0"),   # just over the ceiling
    (dict(timed_out=False, invalid_reason=None, pf=1.24, dd_money=25000.0, dd_pct=25.0, timeout_sec=3600),
     "PASS", "pf=1.240:dd_pct=25.00"),                    # dd == ceiling passes (> not >=)
    # The exact case Codex flagged: 16% FAILED under the old 15% ceiling, PASSES at 25%.
    (dict(timed_out=False, invalid_reason=None, pf=1.24, dd_money=16000.0, dd_pct=16.0, timeout_sec=3600),
     "PASS", "pf=1.240:dd_pct=16.00"),
    (dict(timed_out=False, invalid_reason=None, pf=1.31, dd_money=2248.0, dd_pct=2.25, timeout_sec=3600),
     "PASS", "pf=1.310:dd_pct=2.25"),
]


@pytest.mark.parametrize("kwargs,verdict,reason", VERDICT_CASES)
def test_decide_verdict_byte_identical(kwargs, verdict, reason):
    assert _decide_verdict(**kwargs) == (verdict, reason)


def test_decide_verdict_has_no_recency_parameter():
    params = set(inspect.signature(_decide_verdict).parameters)
    assert params == {"timed_out", "invalid_reason", "pf", "dd_money", "dd_pct", "timeout_sec"}
    for bad in ("recency", "recency_decline_pct", "recency_shadow", "trailing24m_pf"):
        assert bad not in params


def test_recency_axis_policy_switch_is_enabled():
    assert RECENCY_AXIS_ENFORCED is True
    assert R.RECENCY_AXIS_ENFORCED is True
    assert Q10_RECENCY_ENFORCEMENT_CREATED_AT == "2026-09-01T00:00:00+00:00"


def _recency_record(*, trailing_pf=1.2, trailing_trades=20,
                    half_status="PASS", half_decline=10.0,
                    endpoint=202608):
    return {
        "status": "OK",
        "endpoint_yyyymm": endpoint,
        "trailing_24m": {"pf": trailing_pf, "trades": trailing_trades},
        "q08_half_vs_half": {"status": half_status, "decline_pct": half_decline},
    }


def test_recency_gate_is_shadow_only_before_cutoff_even_for_a_breach():
    verdict, reason, gate = _apply_recency_gate(
        base_verdict="PASS", base_reason="base-pass",
        recency=_recency_record(trailing_pf=0.8),
        work_item_created_at="2026-08-31T23:59:59+00:00",
    )
    assert (verdict, reason) == ("PASS", "base-pass")
    assert gate["applied"] is False and gate["status"] == "SHADOW_PRE_COHORT"


def test_recency_gate_enforces_trailing_pf_at_cutoff_boundary():
    verdict, reason, gate = _apply_recency_gate(
        base_verdict="PASS", base_reason="base-pass",
        recency=_recency_record(trailing_pf=0.9999),
        work_item_created_at=Q10_RECENCY_ENFORCEMENT_CREATED_AT,
    )
    assert verdict == "FAIL" and reason.startswith("recency_trailing24m_pf_below_floor")
    assert gate["applied"] is True and gate["status"] == "FAIL"


def test_recency_gate_enforces_half_vs_half_40pct_boundary():
    verdict, _, gate = _apply_recency_gate(
        base_verdict="PASS", base_reason="base-pass",
        recency=_recency_record(half_status="FAIL", half_decline=40.0),
        work_item_created_at="2026-09-02T00:00:00Z",
    )
    assert verdict == "FAIL" and gate["status"] == "FAIL"


def test_recency_gate_keeps_unknown_verdict_but_blocks_deployment():
    verdict, reason, gate = _apply_recency_gate(
        base_verdict="PASS", base_reason="base-pass",
        recency=_recency_record(trailing_trades=9),
        work_item_created_at="2026-09-02T00:00:00+00:00",
    )
    assert (verdict, reason) == ("PASS", "base-pass")
    assert gate["status"] == "UNKNOWN" and gate["deployment_blocker"] is True


def test_recency_gate_marks_windows_older_than_nine_months_stale():
    verdict, reason, gate = _apply_recency_gate(
        base_verdict="PASS", base_reason="base-pass",
        recency=_recency_record(endpoint=202511),
        work_item_created_at="2026-09-02T00:00:00+00:00",
    )
    assert (verdict, reason) == ("PASS", "base-pass")
    assert gate["status"] == "STALE_WINDOW" and gate["deployment_blocker"] is True


# ---------------------------------------------------------------------------
# 2. Classifier boundary fixtures (documented flip points)
# ---------------------------------------------------------------------------
def _classify(decline):
    """Isolate the recency-band decision: floors met, no override triggered."""
    return R.classify(
        recency_decline_pct=decline, trailing24m_pf=1.50, trailing24m_trades=40,
        full_trades=200, q08_status="PASS", q08_decline_pct=5.0,
        parse_ok=True, has_db_row=True,
    )["verdict"]


@pytest.mark.parametrize("decline,expected", [
    (19.9, "CURRENT"),
    (20.0, "WATCH"),    # >= 20 boundary bites
    (20.1, "WATCH"),
])
def test_watch_boundary_20pct(decline, expected):
    assert _classify(decline) == expected


@pytest.mark.parametrize("decline,expected", [
    (24.9, "WATCH"),
    (25.0, "DECAYED"),  # >= 25 boundary bites
    (25.1, "DECAYED"),
])
def test_decay_boundary_25pct(decline, expected):
    assert _classify(decline) == expected


def test_negative_decline_is_current():
    assert _classify(-30.0) == "CURRENT"


# ---------------------------------------------------------------------------
# 3. UNKNOWN coverage gates + overrides
# ---------------------------------------------------------------------------
def test_unknown_no_db_row():
    r = R.classify(recency_decline_pct=5.0, trailing24m_pf=1.5, trailing24m_trades=40,
                   full_trades=200, q08_status="PASS", q08_decline_pct=5.0,
                   parse_ok=True, has_db_row=False)
    assert r["verdict"] == "UNKNOWN" and r["reason"] == "no_db_q10_row"


def test_unknown_parse_failure():
    r = R.classify(recency_decline_pct=None, trailing24m_pf=None, trailing24m_trades=0,
                   full_trades=0, q08_status=None, q08_decline_pct=None,
                   parse_ok=False, has_db_row=True)
    assert r["verdict"] == "UNKNOWN" and "parse_or_reconcile_failure" in r["reason"]


def test_unknown_insufficient_full_history():
    r = R.classify(recency_decline_pct=5.0, trailing24m_pf=1.5, trailing24m_trades=8,
                   full_trades=25, q08_status="PASS", q08_decline_pct=5.0,
                   parse_ok=True, has_db_row=True)
    assert r["verdict"] == "UNKNOWN" and "insufficient_full_history_trades" in r["reason"]


def test_unknown_insufficient_trailing24m():
    r = R.classify(recency_decline_pct=5.0, trailing24m_pf=1.5, trailing24m_trades=9,
                   full_trades=120, q08_status="PASS", q08_decline_pct=5.0,
                   parse_ok=True, has_db_row=True)
    assert r["verdict"] == "UNKNOWN" and "insufficient_trailing24m_trades" in r["reason"]


def test_decayed_trailing_pf_below_one():
    r = R.classify(recency_decline_pct=5.0, trailing24m_pf=0.85, trailing24m_trades=40,
                   full_trades=200, q08_status="PASS", q08_decline_pct=5.0,
                   parse_ok=True, has_db_row=True)
    assert r["verdict"] == "DECAYED" and "trailing24m_pf_below_1.0" in r["reason"]


def test_q08_override_forces_decayed_even_when_recency_low():
    # recency band would say CURRENT (5 %), but a Q08 half-split breach forces DECAYED.
    r = R.classify(recency_decline_pct=5.0, trailing24m_pf=1.5, trailing24m_trades=40,
                   full_trades=58, q08_status="FAIL", q08_decline_pct=41.52,
                   parse_ok=True, has_db_row=True)
    assert r["verdict"] == "DECAYED" and "q08_edge_decay_breach" in r["reason"]


# ---------------------------------------------------------------------------
# 4. Window + half-split computation on synthetic trade lists
# ---------------------------------------------------------------------------
def _trade(year, month, net):
    ts = dt.datetime(year, month, 15, 12, 0, 0, tzinfo=dt.UTC)
    return R.ClosedTrade(exit_time=ts, entry_time=ts, symbol="X.DWX", side="buy",
                         net=net, profit=net, swap=0.0, commission=0.0)


def test_months_back():
    assert R._months_back(202512, 24) == 202401
    assert R._months_back(202512, 12) == 202501
    assert R._months_back(202512, 1) == 202512
    assert R._months_back(202501, 24) == 202302


def test_window_metrics_trailing():
    trades = [_trade(2023, 6, 100.0), _trade(2024, 6, -50.0), _trade(2025, 6, 200.0),
              _trade(2025, 3, -40.0)]
    t24 = R.window_metrics(trades, R._months_back(202512, 24), 202512)
    # 2024-01..2025-12 keeps the 2024 and both 2025 trades (3), drops 2023
    assert t24["trades"] == 3
    assert t24["net"] == pytest.approx(110.0)
    full = R.window_metrics(trades, None, None)
    assert full["trades"] == 4 and full["net"] == pytest.approx(210.0)


def test_window_metrics_pf():
    trades = [_trade(2025, 1, 300.0), _trade(2025, 2, -100.0)]
    m = R.window_metrics(trades, None, None)
    assert m["pf"] == pytest.approx(3.0)  # 300 / 100


def test_q08_half_vs_half_decline_and_threshold():
    # First half strong (many wins), second half weak -> positive decline.
    trades = []
    for mm in range(1, 13):   # 2020 -> strong: each month +100 win, tiny -10 loss
        trades.append(_trade(2020, mm, 100.0))
        trades.append(_trade(2020, mm, -10.0))
    for mm in range(1, 13):   # 2021 -> weak: +30 win, -25 loss (PF ~1.2)
        trades.append(_trade(2021, mm, 30.0))
        trades.append(_trade(2021, mm, -25.0))
    res = R.q08_half_vs_half(trades)
    assert res["decay_mode"] == "swing_half_vs_half"
    assert res["pf_first"] == pytest.approx(10.0)   # 1200/120
    assert res["pf_last"] == pytest.approx(1.2)      # 360/300
    # decline = (10 - 1.2)/10 * 100 = 88 % -> FAIL (>= 40)
    assert res["decline_pct"] == pytest.approx(88.0)
    assert res["status"] == "FAIL"


def test_q08_half_vs_half_invalid_below_floor():
    trades = [_trade(2025, 1, 10.0) for _ in range(10)]  # < 30 trades
    res = R.q08_half_vs_half(trades)
    assert res["status"] == "INVALID" and "insufficient_trade_count" in res["reason"]


# ---------------------------------------------------------------------------
# 5. Shadow-path robustness (never raises) + end-to-end on a real report
# ---------------------------------------------------------------------------
def test_shadow_none_and_missing_return_unknown():
    r1 = R.compute_recency_shadow(None)
    assert r1["status"] == "UNKNOWN" and r1["reason"] == "no_report_htm"
    assert r1["recency_axis_enforced"] is True
    assert "identity" in r1  # identity block present even on the UNKNOWN degrade
    r2 = R.compute_recency_shadow(r"D:\does\not\exist\report.htm")
    assert r2["status"] == "UNKNOWN" and r2["reason"] == "report_htm_missing"


def test_shadow_bad_file_returns_unknown(tmp_path):
    bad = tmp_path / "notareport.htm"
    bad.write_text("<html><body>no deals table here</body></html>", encoding="utf-8")
    r = R.compute_recency_shadow(bad)
    assert r["status"] == "UNKNOWN" and "shadow_compute_error" in r["reason"]


# ---------------------------------------------------------------------------
# 6. Evidence-identity binding (WS-C round 2)
# ---------------------------------------------------------------------------
def test_evidence_identity_all_unresolvable_is_unknown():
    idy = R.evidence_identity()
    assert idy["schema"] == "recency_identity_v1"
    assert idy["report_sha256"] == "UNKNOWN"
    assert idy["setfile_sha256"] == "UNKNOWN"
    assert idy["ex5_sha256"] == "UNKNOWN"
    assert idy["window_endpoint"] == "UNKNOWN"
    assert idy["manifest_ref"] == "UNKNOWN"
    # absent inputs keep *_path None but the hash is still an explicit UNKNOWN
    assert idy["report_htm"] is None and idy["setfile_path"] is None and idy["ex5_path"] is None


def test_evidence_identity_hashes_real_files(tmp_path):
    report = tmp_path / "report.htm"
    setf = tmp_path / "x.set"
    ex5 = tmp_path / "x.ex5"
    report.write_bytes(b"<html>report</html>")
    setf.write_bytes(b"qm_stress_reject_probability=0.0000\n")
    ex5.write_bytes(b"\x00\x01binary")
    idy = R.evidence_identity(report_htm=report, setfile_path=setf, ex5_path=ex5,
                              window_endpoint="2025.12.31",
                              manifest_ref=r"D:/QM/reports/portfolio/m.json")
    assert idy["report_sha256"] == hashlib.sha256(report.read_bytes()).hexdigest()
    assert idy["setfile_sha256"] == hashlib.sha256(setf.read_bytes()).hexdigest()
    assert idy["ex5_sha256"] == hashlib.sha256(ex5.read_bytes()).hexdigest()
    assert idy["window_endpoint"] == "2025.12.31"
    assert idy["manifest_ref"].endswith("m.json")


def test_evidence_identity_missing_file_is_unknown_not_crash(tmp_path):
    missing = tmp_path / "nope.htm"
    idy = R.evidence_identity(report_htm=missing, window_endpoint="")
    assert idy["report_htm"] == str(missing)      # path recorded
    assert idy["report_sha256"] == "UNKNOWN"       # but unresolvable -> UNKNOWN
    assert idy["window_endpoint"] == "UNKNOWN"     # empty endpoint -> UNKNOWN


def test_sha256_file_missing_returns_none(tmp_path):
    assert R.sha256_file(tmp_path / "does_not_exist") is None
    assert R.sha256_file(None) is None


def test_shadow_embeds_identity_block(tmp_path):
    setf = tmp_path / "conf.set"
    setf.write_bytes(b"env=q10\n")
    r = R.compute_recency_shadow(None, setfile_path=setf, window_endpoint="2025.12.31",
                                 manifest_ref="D:/m.json")
    idy = r["identity"]
    assert idy["setfile_sha256"] == hashlib.sha256(setf.read_bytes()).hexdigest()
    assert idy["report_sha256"] == "UNKNOWN"       # no report given
    assert idy["window_endpoint"] == "2025.12.31"
    assert idy["manifest_ref"] == "D:/m.json"


# ---------------------------------------------------------------------------
# 7. Live-path EX5 resolver (best-effort, honest None)
# ---------------------------------------------------------------------------
def test_resolve_ex5_source_none_for_junk(tmp_path):
    assert _resolve_ex5_source(tmp_path, None) is None
    assert _resolve_ex5_source(tmp_path, "QM\\") is None
    assert _resolve_ex5_source(tmp_path, "QM\\QM5_does_not_exist") is None


def test_resolve_ex5_source_finds_binary(tmp_path):
    name = "QM5_9999_demo"
    ea_dir = tmp_path / "framework" / "EAs" / name
    ea_dir.mkdir(parents=True)
    ex5 = ea_dir / f"{name}.ex5"
    ex5.write_bytes(b"\x00binary")
    got = _resolve_ex5_source(tmp_path, f"QM\\{name}")
    assert got == ex5 and got.exists()


_XNG_REPORT = Path(r"D:\QM\reports\pipeline\QM5_12567\20260724_215508\raw\run_02\report.htm")


@pytest.mark.skipif(not _XNG_REPORT.exists(), reason="live evidence report not present")
def test_shadow_end_to_end_real_report_reconciles():
    r = R.compute_recency_shadow(_XNG_REPORT)
    assert r["status"] == "OK"
    assert r["full"]["trades"] == 58
    # net = profit+swap+commission reconciles to native Total Net Profit (1791.18)
    assert r["full"]["net"] == pytest.approx(r["native_net"], abs=0.5)
    assert r["schema"] == "recency_shadow_v1"
    assert set(r).issuperset({"trailing_24m", "trailing_12m", "q08_half_vs_half",
                              "classification", "identity"})
