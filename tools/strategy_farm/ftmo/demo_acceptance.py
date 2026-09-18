"""FTMO Demo acceptance verdict (read-only).

Implements the decision rule of `docs/ftmo/FTMO_DEMO_ACCEPTANCE_CONTRACT_v1.md` (directive
OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917 section 51). Pure read-model: it consumes
`ftmo_demo_cycle.json`, `demo_metrics.build()` and the first-passage read-model and emits the
sidecar `qm.ftmo-demo-acceptance/v1`. Everything it cannot measure is UNMEASURED, never assumed.
No DB write, no MT5, no trading, no purchase path.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

SCHEMA = "qm.ftmo-demo-acceptance/v1"
CONTRACT_VERSION = "v1"
CONTRACT_DOC = "docs/ftmo/FTMO_DEMO_ACCEPTANCE_CONTRACT_v1.md"
DEFAULT_CYCLE = Path(r"D:\QM\reports\state\ftmo_demo_cycle.json")
DEFAULT_FIRST_PASSAGE = Path(r"D:\QM\reports\state\ftmo_first_passage.json")
DEFAULT_OUT = Path(r"D:\QM\reports\state\ftmo_demo_acceptance.json")

# Frozen configuration this contract binds (contract section 1).
FROZEN_ROSTER_LABEL = "D2g6"
FROZEN_ROSTER_HASH = "5432d3db11b02c64a3c5357d94d9f59b425c270e600b87ad65ddf42310771e53"
FROZEN_BOOK_RISK_PCT = 1.71875
DENSITY_CARRIER_EA_ID = 13213
MIN_DAYS = 14.0

# Modelled reference distributions, D2g6 @ 1.71875% on 100k, 14 calendar days (contract section 2/4).
MODEL: dict[str, Any] = {
    "book_entries": {"mean": 13.37, "p10": 10, "p05": 9, "poisson_reject_at": 7},
    "carrier_entries": {"mean": 7.42, "p05": 5, "p01": 3, "poisson_reject_at": 2},
    "sleeves_active": {"mean": 4.49, "p10": 3},
    "entry_days": {"mean": 8.67, "p10": 7},
    "worst_day_closed": {"p95": -797.0, "model_min": -862.0, "recompose_at": -1293.0},
    "max_dd_closed": {"p95": -1706.0, "p99": -2310.0, "model_min": -3902.0},
    "net_pnl": {"p01": -2242.0, "p05": -1481.0, "p50": 194.0, "p_negative": 0.434},
    "financing_drag_usd_per_14d": -71.91,
    "joint": {"max_concurrent_sleeves": 6, "max_joint_risk_pct": FROZEN_BOOK_RISK_PCT},
    "lcb": {"full": 0.8839, "holdout_2023": 0.9759, "buy_floor": 0.80, "recompose_below": 0.70},
}
BREACH_DAILY_USD = -5000.0
BREACH_TOTAL_USD = -10000.0
RULES_STALE_BLOCKER_DAYS = 30
RULES_FRESH_DAYS = 7
_ORDER = {"NOT_READY": 0, "RECOMPOSE": 1, "EXTEND_DEMO": 2, "BUY_RECOMMENDED": 3}
_WINDOW_CHECKS = {"A2", "A3", "A4", "A5", "A10"}
UNMEASURED = "UNMEASURED"


def _ck(cid, metric, status, observed, reference, critical, escalation, note="",
        attention_escalates=False) -> dict[str, Any]:
    return {
        "id": cid, "metric": metric, "status": status, "observed": observed,
        "reference": reference, "decision_critical": bool(critical),
        "escalation": escalation, "attention_escalates": bool(attention_escalates),
        "note": note,
    }


def _grade(value, pass_at, attn_at):
    """Higher-is-better grading. Returns PASS / ATTENTION / FAIL."""
    if value is None:
        return UNMEASURED
    if value >= pass_at:
        return "PASS"
    return "ATTENTION" if value >= attn_at else "FAIL"


def evaluate(
    cycle: dict[str, Any] | None,
    metrics: dict[str, Any] | None,
    first_passage: dict[str, Any] | None = None,
    rules_age_days: float | None = None,
    sleeve_entries: dict[int, int] | None = None,
    joint: dict[str, Any] | None = None,
    runtime_stable: bool | None = None,
) -> list[dict[str, Any]]:
    """Build the full check list. Missing inputs yield UNMEASURED, never a pass."""
    cycle = cycle or {}
    lc = (metrics or {}).get("latest_cycle") or {}
    ok = (metrics or {}).get("status") == "OK"
    days = cycle.get("validation_days")
    checks = [
        _ck("A1", "representative_days", _grade(days, MIN_DAYS, MIN_DAYS), days,
            {"min_days": MIN_DAYS}, True, "EXTEND_DEMO",
            "" if (days or 0) >= MIN_DAYS else "cycle window not complete"),
    ]
    m = MODEL["book_entries"]
    entries = lc.get("entries", lc.get("closed_trades")) if ok else None
    st = _grade(entries, m["p10"], m["p05"])
    if st == "FAIL" and entries is not None and entries <= m["poisson_reject_at"]:
        checks.append(_ck("A2", "book_entries", "FAIL", entries, m, True, "RECOMPOSE",
                          "at or below the Poisson alpha=0.045 rejection point"))
    else:
        checks.append(_ck("A2", "book_entries", st, entries, m, True, "EXTEND_DEMO",
                          "" if ok else "demo journal unreadable"))
    ce = (sleeve_entries or {}).get(DENSITY_CARRIER_EA_ID)
    mc = MODEL["carrier_entries"]
    st = _grade(ce, mc["p05"], mc["p01"])
    checks.append(_ck("A3", f"entries_{DENSITY_CARRIER_EA_ID}", st, ce, mc, False,
                      "RECOMPOSE" if (ce is not None and ce <= mc["poisson_reject_at"]) else "EXTEND_DEMO",
                      "" if sleeve_entries else "per-sleeve counts need ftmo_trial_pulse EXPECTED_MAGICS re-pin (GAPS G2)"))
    active = len([1 for v in (sleeve_entries or {}).values() if v > 0]) if sleeve_entries else None
    ms = MODEL["sleeves_active"]
    checks.append(_ck("A4", "sleeves_active", _grade(active, 4, ms["p10"]), active, ms, False,
                      "EXTEND_DEMO", "" if sleeve_entries else "same exporter gap as A3"))
    ed = lc.get("entry_trading_days") if ok else None
    me = MODEL["entry_days"]
    checks.append(_ck("A5", "entry_days", _grade(ed, me["p10"], 5), ed, me, False, "EXTEND_DEMO"))
    wd = lc.get("worst_day_usd") if ok else None
    mw = MODEL["worst_day_closed"]
    st = _grade(wd, mw["p95"], mw["model_min"])
    esc = "RECOMPOSE" if (wd is not None and wd < mw["recompose_at"]) else "EXTEND_DEMO"
    if wd is not None and wd <= BREACH_DAILY_USD:
        st, esc = "FAIL", "NOT_READY"
    checks.append(_ck("A6a", "worst_day_closed_usd", st, wd, mw, True, esc))
    dd = lc.get("realized_max_dd_usd") if ok else None
    md = MODEL["max_dd_closed"]
    st = _grade(dd, md["p95"], md["p99"])
    esc = "RECOMPOSE" if (dd is not None and dd < md["model_min"]) else "EXTEND_DEMO"
    if dd is not None and dd <= BREACH_TOTAL_USD:
        st, esc = "FAIL", "NOT_READY"
    checks.append(_ck("A7a", "max_dd_closed_usd", st, dd, md, True, esc))
    checks.append(_ck("A6b", "worst_day_intraday_usd", UNMEASURED, None, None, False, "EXTEND_DEMO",
                      "needs the intratrade_equity exporter"))
    checks.append(_ck("A7b", "max_dd_intraday_usd", UNMEASURED, None, None, False, "EXTEND_DEMO",
                      "needs the intratrade_equity exporter"))
    net = lc.get("net_usd") if (ok and lc.get("closed_trades")) else None
    mn = MODEL["net_pnl"]
    checks.append(_ck("A8", "net_pnl_usd", _grade(net, mn["p05"], mn["p01"]), net, mn, False, None,
                      "informational only: modelled P(14d net<0)=0.434"))
    checks.append(_ck("A9", "commission_per_lot", UNMEASURED, None, None, False, "EXTEND_DEMO",
                      "needs the spread/commission specification export; XAUUSD sleeves model 0.00 commission"))
    swap = lc.get("swap_total_usd") if ok else None
    exp = MODEL["financing_drag_usd_per_14d"] * max(days or 0.0, 0.0) / MIN_DAYS
    thin = swap is None or (entries or 0) < 5 or (days or 0.0) < 3.0
    st = UNMEASURED if thin else _grade(swap, 2.0 * exp, 3.0 * exp)
    checks.append(_ck("A10", "financing_drag_usd", st, swap, {"expected_usd": round(exp, 2)}, False,
                      "EXTEND_DEMO", "" if not thin else "fewer than 5 closed trades or under 3 cycle days"))
    mj = MODEL["joint"]
    if joint:
        bad = (joint.get("max_concurrent_sleeves", 0) > mj["max_concurrent_sleeves"]
               or joint.get("max_joint_risk_pct", 0.0) > mj["max_joint_risk_pct"] + 1e-9)
        st = "FAIL" if bad else "PASS"
    else:
        st = UNMEASURED
    checks.append(_ck("A11", "joint_exposure", st, joint, mj, True, "NOT_READY"))
    st = UNMEASURED if runtime_stable is None else ("PASS" if runtime_stable else "FAIL")
    checks.append(_ck("A12", "runtime_stability", st, runtime_stable, None, True, "NOT_READY"))
    st = UNMEASURED if rules_age_days is None else (
        "PASS" if rules_age_days <= RULES_FRESH_DAYS
        else ("ATTENTION" if rules_age_days <= RULES_STALE_BLOCKER_DAYS else "FAIL"))
    checks.append(_ck("A13", "rules_snapshot_age_days", st, rules_age_days,
                      {"fresh": RULES_FRESH_DAYS, "blocker": RULES_STALE_BLOCKER_DAYS}, True, "NOT_READY"))
    rh = cycle.get("roster_hash")
    bound = rh == FROZEN_ROSTER_HASH and abs(
        (cycle.get("total_book_risk_pct") or 0.0) - FROZEN_BOOK_RISK_PCT) < 1e-9
    checks.append(_ck("A14", "config_identity", "PASS" if bound else ("FAIL" if rh else UNMEASURED),
                      rh, {"roster_hash": FROZEN_ROSTER_HASH, "book_risk_pct": FROZEN_BOOK_RISK_PCT},
                      True, "NOT_READY"))
    fp = first_passage or {}
    fp_label = fp.get("roster_label")
    # A first-passage read-model for a DIFFERENT roster must never score this book.
    aligned = fp_label == FROZEN_ROSTER_LABEL
    lcb = ((fp.get("compact_for_readiness") or {}).get("p_first_net_ftmo_payout_lcb")) if aligned else None
    ml = MODEL["lcb"]
    st = _grade(lcb, ml["buy_floor"], ml["recompose_below"])
    if not aligned:
        checks.append(_ck("A15", "first_passage_lcb", UNMEASURED, None, ml, True, "EXTEND_DEMO",
                          f"first-passage read-model is roster_label={fp_label!r}, not "
                          f"{FROZEN_ROSTER_LABEL}: rebuild it for the bound roster"))
        return _finalize(checks, days)
    checks.append(_ck("A15", "first_passage_lcb", st, lcb, ml, True,
                      "RECOMPOSE" if (lcb is not None and lcb < ml["recompose_below"]) else "EXTEND_DEMO",
                      "LCB between the recompose floor and the buy floor extends the demo",
                      attention_escalates=True))
    return _finalize(checks, days)


def _finalize(checks: list[dict[str, Any]], days: float | None) -> list[dict[str, Any]]:
    """A2/A3/A4/A5/A10 are 14-day-window statistics: a partial window cannot fail them.
    (A6/A7/A11/A12 stay live throughout - a breach on day 3 is still a breach.)"""
    if (days or 0.0) < MIN_DAYS:
        for c in checks:
            if c["id"] in _WINDOW_CHECKS and c["status"] in ("FAIL", "ATTENTION"):
                c["status"] = UNMEASURED
                c["note"] = "partial cycle window: 14-day count statistics not judged yet"
    return checks


def decide(checks: list[dict[str, Any]], state: str | None = None) -> dict[str, Any]:
    """Contract section 6: exactly one verdict, with the reasons that produced it."""
    verdict, reasons, unblockers = "BUY_RECOMMENDED", [], []
    for c in checks:
        if c["status"] == "FAIL" and c["escalation"]:
            if _ORDER[c["escalation"]] < _ORDER[verdict]:
                verdict = c["escalation"]
            reasons.append(f"{c['id']} {c['metric']}=FAIL observed={c['observed']}")
        elif c["status"] == "ATTENTION" and c.get("attention_escalates"):
            if _ORDER["EXTEND_DEMO"] < _ORDER[verdict]:
                verdict = "EXTEND_DEMO"
            reasons.append(f"{c['id']} {c['metric']}=ATTENTION observed={c['observed']}")
        elif c["status"] == UNMEASURED and c["decision_critical"]:
            if _ORDER["EXTEND_DEMO"] < _ORDER[verdict]:
                verdict = "EXTEND_DEMO"
            reasons.append(f"{c['id']} {c['metric']}=UNMEASURED")
            unblockers.append(f"{c['id']}: {c['note'] or 'evidence source missing'}")
    attn = [c["id"] for c in checks if c["status"] == "ATTENTION"]
    if verdict == "BUY_RECOMMENDED" and len(attn) >= 3:
        verdict = "EXTEND_DEMO"
        reasons.append("three or more ATTENTION checks: " + ", ".join(attn))
    if verdict == "BUY_RECOMMENDED" and state and state != "REPRESENTATIVE":
        verdict = "EXTEND_DEMO"
        reasons.append(f"cycle state {state} is not REPRESENTATIVE")
    if not reasons:
        reasons.append("all decision-critical checks PASS on the bound configuration")
    return {"verdict": verdict, "reasons": reasons, "unblockers": unblockers,
            "attention": attn}


def cycle_scoped_metrics(demo_metrics: Any, cycle_start_utc: str | None) -> dict[str, Any]:
    """Realised metrics for THIS cycle only.

    `demo_metrics` splits the journal on balance deposits, so its latest cycle can still
    contain the previous roster's trades. Judging D2g6 thresholds against another book's
    deals would be exactly the evidence error this contract exists to prevent: scope the
    rows to `cycle_start_utc`, or report EVIDENCE_MISSING.
    """
    if not cycle_start_utc:
        return {"status": "EVIDENCE_MISSING", "reason": "cycle_start_utc unknown"}
    rows = demo_metrics.load_journal()
    if not rows:
        return {"status": "EVIDENCE_MISSING", "reason": "demo journal not readable"}
    start = dt.datetime.fromisoformat(cycle_start_utc.replace("Z", "+00:00"))
    scoped = [r for r in rows
              if (ts := demo_metrics._parse_ts(r.get("time_utc", ""))) and ts >= start]
    return {"status": "OK", "scoped_to_cycle_start_utc": cycle_start_utc,
            "latest_cycle": demo_metrics.compute_cycle_metrics(scoped),
            "exporter_gaps": demo_metrics._EXPORTER_GAPS}


def build(cycle_path: Path = DEFAULT_CYCLE, first_passage_path: Path = DEFAULT_FIRST_PASSAGE,
          **kw: Any) -> dict[str, Any]:
    from . import demo_metrics  # local import: keeps this module importable standalone

    def _load(p: Path) -> dict[str, Any] | None:
        try:
            return json.loads(Path(p).read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return None

    cycle = _load(cycle_path) or {}
    metrics = cycle_scoped_metrics(demo_metrics, cycle.get("cycle_start_utc"))
    checks = evaluate(cycle, metrics, _load(first_passage_path), **kw)
    d = decide(checks, cycle.get("state"))
    counts: dict[str, int] = {}
    for c in checks:
        counts[c["status"]] = counts.get(c["status"], 0) + 1
    return {
        "schema": SCHEMA, "contract_version": CONTRACT_VERSION, "contract_doc": CONTRACT_DOC,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "cycle_id": "FTMO_DEMO_BOOK_V3_D2G6_20260918",
        "roster_hash": cycle.get("roster_hash"),
        "bound": cycle.get("roster_hash") == FROZEN_ROSTER_HASH,
        "validation_days": cycle.get("validation_days"), "state": cycle.get("state"),
        "counts": counts, "checks": checks, **d,
    }


def _main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="FTMO demo acceptance verdict (read-only)")
    ap.add_argument("--out", type=Path, help=f"write the sidecar (suggested: {DEFAULT_OUT})")
    ap.add_argument("--cycle", type=Path, default=DEFAULT_CYCLE)
    ap.add_argument("--first-passage", type=Path, default=DEFAULT_FIRST_PASSAGE)
    a = ap.parse_args(argv)
    model = build(a.cycle, a.first_passage)
    text = json.dumps(model, indent=2)
    if a.out:
        a.out.parent.mkdir(parents=True, exist_ok=True)
        a.out.write_text(text, encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(_main())
