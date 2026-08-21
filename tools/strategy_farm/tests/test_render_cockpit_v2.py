"""Tests for the Mission Control v2 SHADOW renderer (render_cockpit_v2).

The renderer makes zero data decisions, so these tests drive it entirely from a
synthetic contract fixture (the emitter's schema shape) and prove the seven
acceptance properties from docs/ops/MISSION_CONTROL_V2_RENDER_SPEC.md §Tests:

  1. all 10 terminals rendered, idle cards carry a reason;
  2. no ``\\bP[0-9]\\b`` gate token in the rendered HTML (Qxx only);
  3. factory traffic-light mapping — the four cases;
  4. decision queue caps at 5 with a "… n weitere" affordance;
  5. STALE badge appears for ``staleness=STALE`` and for ``--from-json`` mode;
  6. no ``<button>`` / ``<form>`` / ``onclick`` action element (read-only page);
  7. queue subtotals shown add up to the totals.
"""
from __future__ import annotations

import re

import pytest

from tools.strategy_farm import render_cockpit_v2 as r


# ---------------------------------------------------------------------------
# fixture: a complete, schema-shaped contract
# ---------------------------------------------------------------------------
def _meta(staleness="FRESH", degraded_reason=None, as_of="2026-08-21T14:00:00+00:00"):
    return {
        "source": "fixture",
        "source_as_of": as_of,
        "age_seconds": 120,
        "staleness": staleness,
        "degraded_reason": degraded_reason,
    }


def _kpi(completed=100, distinct=80, gate_pass=30, econ=25, infra=20, other=25,
         infra_rate=0.2):
    return {
        "completed": completed, "distinct_ea_symbol": distinct,
        "gate_pass": gate_pass, "economic_fail": econ, "infra_transient": infra,
        "other": other, "infra_rate": infra_rate,
    }


def _terminals(n_running=4):
    out = []
    for i in range(1, 11):
        term = f"T{i}"
        if i <= n_running:
            out.append({
                "terminal": term, "state": "RUNNING",
                "work_item_id": f"wi-{i}-abcdef012345",
                "ea_id": f"QM5_1000{i}", "ea_slug": f"slug-{i}",
                "symbol": "AUDCAD.DWX", "phase_qid": "Q07",
                "phase_name": "Multi-Seed",
                "start_utc": "2026-08-21T13:00:00+00:00",
                "elapsed_seconds": 3600, "reservation": None, "idle_reason": None,
            })
        else:
            out.append({
                "terminal": term, "state": "IDLE",
                "work_item_id": None, "ea_id": None, "ea_slug": None,
                "symbol": None, "phase_qid": None, "phase_name": None,
                "start_utc": None, "elapsed_seconds": None,
                "reservation": None,
                "idle_reason": "no active farm claim",
            })
    running = n_running
    idle = 10 - n_running
    return {
        "meta": _meta(),
        "counts": {"running": running, "reserved": 0, "idle": idle, "fleet_size": 10},
        "terminals": out,
        "notes": "state=RUNNING is authoritative from the farm claim.",
    }


def make_contract(*, factory_state="NOMINAL", n_decisions=3,
                  control_meta=None, terminals_meta_stale=False,
                  n_running=4):
    terminals = _terminals(n_running=n_running)
    if terminals_meta_stale:
        terminals["meta"] = _meta(staleness="STALE")
    decisions = [
        {"source": "curated_feed", "category": f"CAT{i}", "title": f"Decision {i}",
         "detail": f"detail {i}", "due": "2026-08-25",
         "severity": ("alert" if i % 2 == 0 else "info"),
         "alert": (i % 2 == 0)}
        for i in range(n_decisions)
    ]
    alert_count = sum(1 for d in decisions if d["alert"])
    return {
        "schema_version": "qm.mission_control.v2",
        "generated_at": "2026-08-21T14:00:00+00:00",
        "source_db": r"D:\QM\strategy_farm\state\farm_state.sqlite",
        "control_strip": {
            "meta": control_meta or _meta(),
            "factory_state": factory_state,
            "factory_state_reason": "mt5_worker_saturation: 4/10 daemons alive",
            "health_overall": "FAIL",
            "health_fail_count": 9,
            "data_freshness": {
                "youngest_age_seconds": 60,
                "oldest_age_seconds": 7186,
                "any_stale": False,
                "critical_readmodels": [
                    {"name": "health.json", "as_of": "2026-08-21T13:58:00+00:00",
                     "age_seconds": 120, "sla_sec": 1200, "staleness": "FRESH"},
                    {"name": "owner_decisions.json", "as_of": "2026-08-21T12:00:00+00:00",
                     "age_seconds": 7186, "sla_sec": 172800, "staleness": "FRESH"},
                    {"name": "terminal_reservations.json", "as_of": "2026-08-21T14:00:00+00:00",
                     "age_seconds": 0, "sla_sec": 1800, "staleness": "FRESH"},
                ],
            },
            "queue_total": 2236,
            "queue_pending_executable": 2206,
            "queue_active": 4,
            "clear_eta_hours_p50": 226.26,
            "clear_eta_hours_p90": 377.09,
            "terminals": terminals["counts"],
            "owner_decisions_open": len(decisions),
            "owner_decisions_alert": alert_count,
        },
        "queue": {
            "meta": _meta(staleness="N/A"),
            "pending_total": 2232,
            "pending_executable": 2206,
            "pending_parked": 26,
            "active": 4,
            "by_phase_executable": [
                {"phase_qid": "Q04", "phase_name": "Walk-Forward + Commission",
                 "pending": 1436, "oldest_created_at": "2026-08-02T16:54:19"},
                {"phase_qid": "Q02", "phase_name": "Baseline Screening",
                 "pending": 700, "oldest_created_at": "2026-06-08T03:45:57"},
            ],
            "by_phase_parked": [
                {"phase_qid": "Q09_NEWS", "phase_name": "",
                 "pending": 24, "oldest_created_at": "2026-08-06T09:04:22"},
            ],
            "eta_to_empty": {
                "basis": "drainable executable backlog / measured 24h throughput; "
                         "drain-only (no upstream arrivals modelled) -> lower bound",
                "pending_executable": 2206,
                "throughput_per_hour_24h": 9.75,
                "throughput_count_24h": 234,
                "eta_hours_p50": 226.26,
                "eta_hours_p90": 377.09,
                "eta_empty_utc_p50": "2026-08-30T00:00:00+00:00",
            },
            "notes": "pending_parked (e.g. Q09_NEWS) is excluded from ETA.",
        },
        "progress": {
            "meta": _meta(staleness="N/A"),
            "phase_set": ["P2", "P3", "P8", "Q02", "Q03", "Q04", "Q07", "Q10"],
            "today": _kpi(),
            "yesterday": _kpi(completed=122, distinct=55),
            "seven_day_average": {**_kpi(completed=197.86, distinct=143.43),
                                  "_basis": "mean of the 7 per-day KPIs (day 0..6)"},
            "total": {"completed": 107646, "distinct_ea_symbol": 14288,
                      "gate_pass": 26498, "economic_fail": 23365,
                      "infra_transient": 57341, "infra_rate": 0.5327,
                      "since": "2026-05-23T15:26:28"},
            "counting_basis": "Terminal work_items_clean rows (done|failed) in "
                              "MT5-tester phases, counted by updated_at.",
            "caveats": ["TOTAL mixes contract eras.",
                        "infra_transient is re-labelled residue."],
        },
        "terminals": terminals,
        "owner_decisions": {
            "meta": _meta(),
            "count": len(decisions),
            "alert_count": alert_count,
            "q12_review_ready": 30,
            "items": decisions,
            "notes": "Agent work queues are excluded by construction.",
        },
    }


# ---------------------------------------------------------------------------
# 1. all 10 terminals rendered, idle cards carry a reason
# ---------------------------------------------------------------------------
def test_all_ten_terminals_with_idle_reason():
    html = r.render(make_contract(n_running=4))
    for i in range(1, 11):
        assert f'>T{i}<' in html, f"terminal T{i} missing"
    # every idle terminal (T5..T10) surfaces an explicit reason, no empty fields
    assert html.count("no active farm claim") == 6


# ---------------------------------------------------------------------------
# 2. no P-gate token (Qxx only) — percentiles P50/P90 are NOT single-digit tokens
# ---------------------------------------------------------------------------
def test_no_p_gate_token_in_html():
    html = r.render(make_contract())
    hits = re.findall(r"\bP[0-9]\b", html)
    assert hits == [], f"P-gate token(s) leaked into HTML: {hits}"
    # positive control: Qxx labels are present
    assert "Q04" in html and "Q07" in html


# ---------------------------------------------------------------------------
# 3. factory traffic-light mapping — the four cases
# ---------------------------------------------------------------------------
def test_factory_light_four_cases():
    assert r.map_factory_light("NOMINAL") == {
        "level": "ok", "color": "var(--pass)", "label": "NOMINAL"}
    assert r.map_factory_light("MAINTENANCE") == {
        "level": "maintenance", "color": "var(--warn)", "label": "MAINTENANCE"}
    assert r.map_factory_light("DEGRADED") == {
        "level": "degraded", "color": "var(--warn)", "label": "DEGRADED"}
    assert r.map_factory_light("CRITICAL") == {
        "level": "critical", "color": "var(--fail)", "label": "CRITICAL"}
    # red is reserved for CRITICAL only
    for state in ("NOMINAL", "MAINTENANCE", "DEGRADED"):
        assert r.map_factory_light(state)["color"] != "var(--fail)"
    # and the render surfaces the mapped colour in the factory cell
    for state, col in (("NOMINAL", "var(--pass)"), ("MAINTENANCE", "var(--warn)"),
                       ("DEGRADED", "var(--warn)"), ("CRITICAL", "var(--fail)")):
        html = r.render(make_contract(factory_state=state))
        assert f'background:{col}' in html


# ---------------------------------------------------------------------------
# 4. decision queue caps at 5 with "… n weitere"
# ---------------------------------------------------------------------------
def test_decision_queue_caps_at_five():
    html = r.render(make_contract(n_decisions=8))
    # exactly five decision rows are rendered
    assert html.count('class="mc-dec-row"') == 5
    assert "3 weitere" in html
    # a small queue shows no overflow affordance
    html2 = r.render(make_contract(n_decisions=3))
    assert "weitere" not in html2


# ---------------------------------------------------------------------------
# 5. STALE badge for staleness=STALE and for --from-json
# ---------------------------------------------------------------------------
def test_stale_badge_appears():
    # section-level STALE (terminals meta STALE) shows a STALE chip
    html_stale = r.render(make_contract(terminals_meta_stale=True))
    assert "STALE" in html_stale
    # from_json mode always badges the header STALE
    html_json = r.render(make_contract(), from_json=True, source_path="snap.json")
    assert "STALE" in html_json and "SNAPSHOT" in html_json
    # a fully-fresh, live render carries no STALE badge
    html_fresh = r.render(make_contract())
    assert "STALE" not in html_fresh


# ---------------------------------------------------------------------------
# 6. no action elements — read-only page
# ---------------------------------------------------------------------------
def test_no_action_elements():
    html = r.render(make_contract(n_decisions=8))
    low = html.lower()
    assert "<button" not in low
    assert "<form" not in low
    assert "onclick" not in low
    assert "<input" not in low


# ---------------------------------------------------------------------------
# 7. queue subtotals add up to the totals
# ---------------------------------------------------------------------------
def test_queue_sums_consistent():
    contract = make_contract()
    br = r.queue_breakdown(contract)
    assert br["pending_executable"] + br["pending_parked"] == br["pending_total"]
    assert br["pending_total"] + br["active"] == br["queue_total"]
    # and the rendered strip shows all three components + the total
    html = r.render(contract)
    assert r._int(br["pending_executable"]) in html
    assert r._int(br["pending_parked"]) in html
    assert r._int(br["queue_total"]) in html
