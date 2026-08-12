"""WS-F round-2 production snapshot driver (read-only).

Runs the five WS-F vacuousness detectors against the LIVE factory DB + live
filesystem + live QM event logs, strictly read-only (health._connect uses URI
mode=ro + PRAGMA query_only=ON; live logs are tailed open('rb') only), and writes
`production_snapshot.json` + a machine-timed runtime budget. This is a reviewer
utility, NOT wired into ALL_CHECKS. It exists so the two-tier CANDIDATE/AUTHENTICATED
output can be reproduced from the live DB without mutating anything.

Usage:  python wsf_production_snapshot.py <out_dir>
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import health  # noqa: E402


def enumerate_stress_candidates(con) -> list:
    """Reproduce detector (a)'s full flagged list (not just its top-6 detail slice),
    tagging each with its provenance tier. Uses only health's read-only helpers — this
    is reviewer reproduction, not new production logic."""
    cutoff = health._window_cutoff_ts(health.VACUOUSNESS_WINDOW_DAYS)

    def latest(phase):
        out = {}
        for r in con.execute(
            "SELECT ea_id, symbol, profit_factor, trades, evidence_path, evidence_mtime "
            "FROM ea_metrics WHERE phase=? AND evidence_mtime IS NOT NULL "
            "AND evidence_mtime >= ? ORDER BY evidence_mtime ASC", (phase, cutoff)):
            out[(r["ea_id"], r["symbol"])] = r
        return out

    q05, q06 = latest("Q05"), latest("Q06")
    flagged = []
    for key in sorted(set(q05) & set(q06)):
        a, b = q05[key], q06[key]
        if a["profit_factor"] is None or b["profit_factor"] is None:
            continue
        if not (a["profit_factor"] == b["profit_factor"] and a["trades"] == b["trades"]):
            continue
        ev5 = health._read_json_path(a["evidence_path"])
        ev6 = health._read_json_path(b["evidence_path"])
        if not ev5 or not ev6 or ev5.get("pf") is None or ev6.get("pf") is None:
            continue
        if not (ev5.get("pf") == ev6.get("pf") and ev5.get("dd_money") == ev6.get("dd_money")
                and ev5.get("trades") == ev6.get("trades")):
            continue
        rp6 = ev6.get("rejection_probability")
        if not rp6 or float(rp6) <= 0:
            continue
        if int(ev6.get("trades") or 0) < health.STRESS_IDENTITY_COHORT_MIN_TRADES:
            continue
        s5 = ev5.get("summary_path") or ev5.get("report_path")
        s6 = ev6.get("summary_path") or ev6.get("report_path")
        reason = "shared_evidence" if (s5 and s5 == s6) else "harsh_reject_no_effect"
        tier, missing = health._provenance_tier((ev5, ev6), unrounded_ok=True, telemetry_ok=True)
        flagged.append({
            "ea_id": health._ea_id_int(key[0]), "symbol": key[1],
            "pf": ev6.get("pf"), "trades": ev6.get("trades"), "reason": reason,
            "tier": tier, "unbound_provenance": missing,
            "q05_summary": s5, "q06_summary": s6,
        })
    return flagged


def _tier_counts(detail: str) -> dict:
    out = {}
    for k in ("stress_identity", "flagged", "candidates", "authenticated"):
        m = re.search(rf"\b{k}=(\d+)", detail)
        if m:
            out[k] = int(m.group(1))
    m = re.search(r"unbound_provenance=(\[[^\]]*\])", detail)
    if m:
        out["unbound_provenance"] = m.group(1)
    return out


def main(out_dir: str) -> int:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    con = health._connect()
    resolved_db = str(health.DB)
    query_only = con.execute("PRAGMA query_only").fetchone()[0]
    print(f"resolved_db={resolved_db} query_only={query_only}")
    assert query_only == 1, "DB handle is NOT query_only — refusing to proceed"

    results = {}
    for name, fn, needs_con in [
        ("a_stress_identity", health.chk_q05_q06_stress_identity, True),
        ("b_zero_variance", health.chk_q07_zero_variance, True),
        ("c_phase_invalid_rate_7d", health.chk_phase_invalid_rate_7d, True),
        ("d_ks_dormancy", health.chk_ks_baseline_dormancy, False),
        ("e_seed_auth_failure_rate", health.chk_seed_auth_failure_rate, True),
    ]:
        r = fn(con) if needs_con else fn()
        results[name] = {
            "status": r["status"], "value": r["value"], "threshold": r["threshold"],
            "detail": r["detail"], "tiers": _tier_counts(r["detail"]),
        }
        print(f"{name}: status={r['status']} value={r['value']} tiers={_tier_counts(r['detail'])}")

    # full flagged list for (a) — the 12 candidates, each with tier + unbound facets
    stress_candidates = enumerate_stress_candidates(con)
    results["a_stress_identity"]["candidates_full"] = stress_candidates
    print(f"a_stress_identity full candidates: {len(stress_candidates)}")

    # runtime budget: 7 consecutive full passes of all five detectors
    budget = []
    for _ in range(7):
        t0 = time.perf_counter()
        health.chk_q05_q06_stress_identity(con)
        health.chk_q07_zero_variance(con)
        health.chk_phase_invalid_rate_7d(con)
        health.chk_ks_baseline_dormancy()
        health.chk_seed_auth_failure_rate(con)
        budget.append(time.perf_counter() - t0)
    con.close()

    payload = {
        "generated_at": health._utc_now().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "resolved_db": resolved_db,
        "query_only": query_only,
        "detectors": results,
        "runtime_budget_wsf5_secs": {
            "runs": [round(x, 4) for x in budget],
            "min": round(min(budget), 4),
            "mean": round(sum(budget) / len(budget), 4),
            "max": round(max(budget), 4),
        },
    }
    (out / "production_snapshot.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    print("WROTE", out / "production_snapshot.json")
    print("runtime mean", payload["runtime_budget_wsf5_secs"]["mean"], "s")
    return 0


_USAGE = (
    "usage: python wsf_production_snapshot.py <out_dir>\n"
    "  Read-only reproduction of the five WS-F detectors against the live factory DB.\n"
    "  Writes <out_dir>/production_snapshot.json. Never mutates the DB or T_Live.\n"
)

if __name__ == "__main__":
    args = sys.argv[1:]
    # Non-executing help path (Codex review-integrity): -h/--help / no arg must NOT run
    # the detectors or create any output directory — just print usage and exit.
    if not args or args[0] in ("-h", "--help"):
        print(_USAGE)
        sys.exit(0)
    sys.exit(main(args[0]))
