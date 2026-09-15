"""FTMO Challenge readiness read-model + living doc (directive sections 62-63).

Assembles a many-dimensional readiness picture - never one number - from the
demo-cycle ledger, demo journal metrics, the FUND_SCORE cache, FTMO fitness, and
the official-rule snapshot freshness. Emits:

  * D:/QM/reports/state/ftmo_challenge_readiness.json  (qm.ftmo-challenge-readiness/v1)
  * docs/ops/FTMO_CHALLENGE_READINESS.md               (living doc)

Deterministic. Reads only; writes only its two output artifacts. There is no code
path that acts on a paid Challenge - the recommendation is advisory for the OWNER
(directive sections 13-14, 64).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
import sys
from typing import Any

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.strategy_farm.ftmo import demo_cycle as demo_cycle_mod
from tools.strategy_farm.ftmo import demo_metrics as demo_metrics_mod
from tools.strategy_farm.ftmo import ftmo_fitness as fitness_mod
from tools.strategy_farm.ftmo import policy_config
from tools.strategy_farm.ftmo import rules_snapshot as rules_mod

SCHEMA = "qm.ftmo-challenge-readiness/v1"
REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUT = Path(r"D:\QM\reports\state\ftmo_challenge_readiness.json")
DEFAULT_DOC = REPO_ROOT / "docs" / "ops" / "FTMO_CHALLENGE_READINESS.md"
FUND_SCORE_CACHE = Path(r"D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json")

RECOMMENDATIONS = (
    "NOT_READY",
    "CONTINUE_DEMO",
    "RECOMPOSE",
    "READY_FOR_OWNER_REVIEW",
    "BUY_100K_2STEP_RECOMMENDED",
)

_MISSING = "EVIDENCE_MISSING"


def _iso(ts: dt.datetime) -> str:
    return ts.strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_json(path: Path) -> Any:
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _worst_across_cycles(cycles: Any, field: str) -> Any:
    """Most-adverse (minimum, i.e. most-negative) value of ``field`` across all demo
    cycles.  Loss/drawdown fields are negative, so the worst is the minimum.  Returns
    EVIDENCE_MISSING when no cycle carries the field (F1 review M2)."""
    if not isinstance(cycles, list):
        return _MISSING
    vals = []
    for c in cycles:
        if isinstance(c, dict) and isinstance(c.get(field), (int, float)):
            vals.append(float(c[field]))
    return round(min(vals), 4) if vals else _MISSING


def _trade_density_per_day(latest_cycle: dict[str, Any]) -> Any:
    """Closed trades per entry-trading-day for the latest cycle (F1 review M1).

    ``trade_density_per_day`` is the shared-contract density metric; it is derived from
    the same journal fields as the kept ``trade_density_entry_days`` alias.  Returns
    EVIDENCE_MISSING when the inputs are absent, never invents a rate on zero days."""
    trades = latest_cycle.get("closed_trades")
    days = latest_cycle.get("entry_trading_days")
    if not isinstance(trades, (int, float)) or not isinstance(days, (int, float)) or not days:
        return _MISSING
    return round(float(trades) / float(days), 4)


def map_recommendation(
    *,
    blockers: list[str],
    fitness: dict[str, Any],
    representative: bool,
    demo_metrics: dict[str, Any] | None,
    first_passage: dict[str, Any] | None,
) -> tuple[str, str]:
    """Deterministic recommendation enum + rationale.

    Precedence (honest, success-probability-first, directive section 15):
      1. hard blockers                                   -> NOT_READY
      2. no fit candidate exists at all (0 admitted AND  -> NOT_READY
         best FUND_SCORE below floor, or realized breach)
      3. fitness NOT_FIT but candidates exist            -> RECOMPOSE
      4. not representative                               -> CONTINUE_DEMO
      5. representative + FIT, first-passage short of go  -> CONTINUE_DEMO
      6. representative + FIT + go-criteria met (point)   -> READY_FOR_OWNER_REVIEW
      7. representative + FIT + go strongly met           -> BUY_100K_2STEP_RECOMMENDED
    """
    if blockers:
        return "NOT_READY", "Hard blockers present: " + "; ".join(blockers)

    overall = fitness.get("overall_verdict")
    admitted = fitness.get("admitted_pairs")
    best = fitness.get("best_fund_score")
    floor = fitness.get("fund_score_floor", 1.0)
    no_candidate = (
        (isinstance(admitted, int) and admitted == 0) and (best is None or best < floor)
    )
    breach = False
    if isinstance(demo_metrics, dict):
        latest = demo_metrics.get("latest_cycle") or {}
        cycles = demo_metrics.get("cycles") or []
        breach = any(
            abs(float(c.get("realized_max_dd_pct") or 0.0)) >= 10.0 for c in cycles
        )

    if no_candidate or breach:
        why = []
        if no_candidate:
            why.append(
                f"no candidate passes FTMO admission or the FUND_SCORE floor "
                f"(admitted={admitted}, best={best} vs floor {floor})"
            )
        if breach:
            why.append("a demo cycle realized a >=10% total-loss breach")
        return "NOT_READY", "; ".join(why)

    if overall == "NOT_FIT":
        return "RECOMPOSE", "Current book is not FTMO-fit but fit candidates may exist; recompose the demo book."

    if not representative:
        return "CONTINUE_DEMO", "Demo not yet representative for the intended frozen book (need >=14 rep days, no material change)."

    fp = first_passage or {}
    p_pass = fp.get("p_pass_60d") if isinstance(fp, dict) else None
    if p_pass is None:
        return "CONTINUE_DEMO", "Representative + fit, but first-passage pass probability not yet evidenced."
    try:
        p = float(p_pass)
    except (TypeError, ValueError):
        return "CONTINUE_DEMO", "First-passage evidence unparseable; continue demo."
    if p >= 0.80:
        return "BUY_100K_2STEP_RECOMMENDED", f"Representative, fit, P(pass<=60d)={p:.2f} above the 0.80 go-criterion."
    if p >= 0.70:
        return "READY_FOR_OWNER_REVIEW", f"Representative, fit, P(pass<=60d)={p:.2f} in the OWNER-review band."
    return "CONTINUE_DEMO", f"Representative, fit, but P(pass<=60d)={p:.2f} below the 0.70 review floor."


def _strongest_failure_mode(
    fitness: dict[str, Any], demo_metrics: dict[str, Any] | None, blockers: list[str]
) -> str:
    axes = fitness.get("fitness_axes", {})
    if any("rule snapshot" in b.lower() for b in blockers):
        return "Stale/missing official FTMO rule snapshot (cannot verify current rules)."
    # Realized total-loss breach in ANY demo cycle is the loudest signal.
    if isinstance(demo_metrics, dict):
        worst = None
        for c in demo_metrics.get("cycles") or []:
            dd = c.get("realized_max_dd_pct")
            if dd is not None and (worst is None or float(dd) < worst):
                worst = float(dd)
        if worst is not None and abs(worst) >= 10.0:
            return f"Total-loss breach in a demo cycle: realized max-DD {worst:.2f}% vs 10% limit."
    if axes.get("max_loss_survival", {}).get("status") == "FAIL":
        v = axes["max_loss_survival"].get("value", {})
        return f"Total-loss breach: realized max-DD {v.get('realized_max_dd_pct')}% vs 10% limit."
    admitted = fitness.get("admitted_pairs")
    best = fitness.get("best_fund_score")
    floor = fitness.get("fund_score_floor", 1.0)
    if isinstance(admitted, int) and admitted == 0:
        return "No candidate carries a positive FTMO admission (Q10 = 0) and no sleeve clears the FUND_SCORE floor."
    if best is not None and best < floor:
        return f"No sleeve clears the FUND_SCORE floor (best {best} vs floor {floor})."
    if axes.get("daily_loss_survival", {}).get("status") == "FAIL":
        return "Daily-loss survival failure vs 5% limit."
    if axes.get("density", {}).get("status") == _MISSING:
        return "Trade density unknown / too low for the 4-trading-day + target progression requirement."
    return "Insufficient decision-grade FTMO fitness evidence for a frozen intended book."


def build_readiness(
    *,
    out: Path = DEFAULT_OUT,
    fund_score_cache: Path = FUND_SCORE_CACHE,
    demo_cycle_path: Path | None = None,
    terminal_dir: Path = demo_cycle_mod.DEFAULT_TERMINAL,
    journal_path: Path = demo_metrics_mod.DEFAULT_JOURNAL,
    q10_admission: dict[str, Any] | None = None,
    first_passage: dict[str, Any] | None = None,
    now: dt.datetime | None = None,
    write: bool = True,
) -> dict[str, Any]:
    now = now or dt.datetime.now(dt.timezone.utc)

    # Prefer the persisted demo-cycle ledger (written by demo_cycle.py build) so
    # cycle_start / validation_days stay stable across readiness runs. If a
    # specific path was given, honour it; otherwise use the canonical ledger, and
    # only observe live as a last resort when no ledger exists yet.
    ledger_path = demo_cycle_path if demo_cycle_path is not None else demo_cycle_mod.DEFAULT_OUT
    ledger = _load_json(ledger_path)
    if ledger is None:
        try:
            obs = demo_cycle_mod.observe_demo_terminal(terminal_dir)
            ledger = demo_cycle_mod.build_demo_cycle(obs, None, now)
        except Exception:  # pragma: no cover - terminal not present
            ledger = None

    demo_metrics = demo_metrics_mod.build(journal_path)

    fs_cache = _load_json(fund_score_cache)
    fund_rows = fs_cache.get("rows") if isinstance(fs_cache, dict) else None

    # newest demo cycle metrics feed the fitness snapshot
    latest_cycle = demo_metrics.get("latest_cycle") if isinstance(demo_metrics, dict) else None

    fitness = fitness_mod.compute_ftmo_fitness(
        {
            "fund_scores": fund_rows,
            "q10_admission": q10_admission,
            "demo_metrics": latest_cycle,
            "first_passage": first_passage,
        }
    )

    snapshot = rules_mod.load_latest_snapshot()
    freshness = rules_mod.freshness_blocker(snapshot, now)

    # blockers
    blockers: list[str] = []
    if freshness["blocker"]:
        blockers.append(freshness["reason"])
    if ledger is None or ledger.get("roster_hash") in (None, _MISSING):
        blockers.append("No FTMO demo roster observed (cannot identify the book under validation).")

    representative = bool(ledger and ledger.get("representative"))

    recommendation, rationale = map_recommendation(
        blockers=blockers,
        fitness=fitness,
        representative=representative,
        demo_metrics=demo_metrics if isinstance(demo_metrics, dict) else None,
        first_passage=first_passage,
    )
    strongest = _strongest_failure_mode(fitness, demo_metrics, blockers)

    # metrics block (§16 selection).
    #
    # F1 review M1+M2: the shared read-model contract names trade density as
    # ``trade_density_per_day`` and swap cost as ``swap_cost``; the pre-existing
    # ``trade_density_entry_days`` / ``swap_cost_usd`` names are kept as aliases so no
    # consumer breaks.  Worst-across-cycles risk metrics sit next to the current-cycle
    # ones so a demo that already breached in an EARLIER cycle is not hidden by a
    # benign latest cycle.
    lc = latest_cycle or {}
    cycles = demo_metrics.get("cycles") if isinstance(demo_metrics, dict) else None
    worst_dd_across = _worst_across_cycles(cycles, "realized_max_dd_pct")
    worst_daily_across = _worst_across_cycles(cycles, "worst_day_pct")
    metrics = {
        "target_progress_pct": lc.get("target_progress_pct", _MISSING),
        "net_pct": lc.get("net_pct", _MISSING),
        "worst_daily_loss_pct": lc.get("worst_day_pct", _MISSING),
        "worst_daily_loss_pct_worst_cycle": worst_daily_across,
        "max_dd_pct": lc.get("realized_max_dd_pct", _MISSING),
        "max_dd_pct_worst_cycle": worst_dd_across,
        # Canonical shared-contract name + kept alias.
        "trade_density_per_day": _trade_density_per_day(lc),
        "trade_density_entry_days": lc.get("entry_trading_days", _MISSING),
        "losing_streak_max": lc.get("losing_streak_max", _MISSING),
        "median_holding_hours": lc.get("median_holding_hours", _MISSING),
        # Canonical shared-contract name + kept alias.
        "swap_cost": lc.get("swap_total_usd", _MISSING),
        "swap_cost_usd": lc.get("swap_total_usd", _MISSING),
        "commission_cost_usd": lc.get("commission_total_usd", _MISSING),
        "recovery_days": "NOT_EVALUATED",
        "spread_cost": "NOT_EVALUATED",
        "session_exposure": "NOT_EVALUATED",
    }

    rs_fields = {}
    rs_url = _MISSING
    rs_fetched = _MISSING
    if isinstance(snapshot, dict):
        rs_fields = snapshot.get("fields", {})
        rs_url = snapshot.get("source_url", _MISSING)
        rs_fetched = snapshot.get("fetched_utc") or snapshot.get("retrieved_at_utc", _MISSING)

    would_buy = recommendation == "BUY_100K_2STEP_RECOMMENDED"
    result = {
        "schema": SCHEMA,
        "generated_at_utc": _iso(now),
        "account": {
            "type": policy_config.DEFAULT_ACCOUNT_TYPE,
            "size": policy_config.DEFAULT_ACCOUNT_SIZE_USD,
            "product": policy_config.DEFAULT_PRODUCT,
            "terminal": str(terminal_dir),
        },
        "policy": {
            "one_paid_challenge_at_a_time": policy_config.ONE_PAID_CHALLENGE_AT_A_TIME,
            "default_size_usd": policy_config.DEFAULT_ACCOUNT_SIZE_USD,
            "default_product": policy_config.DEFAULT_PRODUCT,
            "paid_decision_authority": policy_config.PAID_DECISION_AUTHORITY,
            "priority": policy_config.FTMO_PRIORITY,
        },
        "demo_cycle": {
            "roster_hash": (ledger or {}).get("roster_hash", _MISSING),
            "roster": (ledger or {}).get("roster", []),
            "roster_source": (ledger or {}).get("roster_source", _MISSING),
            "start_utc": (ledger or {}).get("cycle_start_utc", "UNKNOWN"),
            "validation_days": (ledger or {}).get("validation_days", "UNKNOWN"),
            "validation_min_days": policy_config.VALIDATION_MIN_DAYS,
            "state": (ledger or {}).get("state", _MISSING),
            "material_changes": (ledger or {}).get("material_changes", []),
            "representative": representative if ledger else "UNKNOWN",
        },
        "metrics": metrics,
        "demo_metrics_detail": demo_metrics,
        "simulations": {
            "first_passage": first_passage if first_passage else _MISSING,
            "fund_score_by_sleeve": fitness.get("fund_score_by_sleeve", {}),
            "best_fund_score": fitness.get("best_fund_score"),
            "fund_score_floor": fitness.get("fund_score_floor"),
        },
        "fitness": fitness,
        "rules_snapshot": {
            "source_url": rs_url,
            "fetched_utc": rs_fetched,
            "fields": rs_fields,
            "freshness_days": freshness.get("freshness_days"),
            "freshness_severity": freshness.get("severity"),
        },
        "strongest_failure_mode": strongest,
        "blockers": blockers,
        "recommendation": recommendation,
        "rationale": rationale,
        "would_fable_buy_today": {
            "answer": would_buy,
            "why": rationale if would_buy else f"No. {strongest} Recommendation: {recommendation}.",
        },
    }

    if write:
        out = Path(out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        _render_doc(result, DEFAULT_DOC)
    return result


def _render_doc(model: dict[str, Any], doc_path: Path) -> None:
    dc = model["demo_cycle"]
    m = model["metrics"]
    fit = model["fitness"]
    rs = model["rules_snapshot"]
    lines = [
        "# FTMO Challenge Readiness (living)",
        "",
        f"Generated {model['generated_at_utc']} by `tools/strategy_farm/ftmo/challenge_readiness.py`.",
        "OWNER-DEC-CBE-20260915 (directive 2026-09-15 sections 62-63). Read-model: "
        "`D:/QM/reports/state/ftmo_challenge_readiness.json`.",
        "",
        "This is not one number. Readiness is a multi-axis picture; the paid decision is "
        "OWNER-only and cannot be taken by automation.",
        "",
        f"## Recommendation: **{model['recommendation']}**",
        "",
        f"{model['rationale']}",
        "",
        f"**Would Fable buy a 100k 2-Step Challenge today?** "
        f"{'YES' if model['would_fable_buy_today']['answer'] else 'NO'} - "
        f"{model['would_fable_buy_today']['why']}",
        "",
        f"**Strongest current failure mode:** {model['strongest_failure_mode']}",
        "",
        "## Demo cycle",
        "",
        f"- Roster under validation: `{dc['roster_hash']}` ({dc.get('roster_source')}), "
        f"{len(dc.get('roster') or [])} sleeves",
        f"- Cycle start: {dc['start_utc']}  ·  validation days: {dc['validation_days']} "
        f"(min {dc['validation_min_days']})  ·  state: {dc['state']}  ·  representative: {dc['representative']}",
        f"- Material changes this cycle: {len(dc.get('material_changes') or [])}",
        "",
        "## Metrics (latest demo cycle)",
        "",
        f"- Target progress: {m['target_progress_pct']}%  ·  net: {m['net_pct']}%",
        f"- Worst daily loss: {m['worst_daily_loss_pct']}% (limit 5%; worst across cycles "
        f"{m['worst_daily_loss_pct_worst_cycle']}%)  ·  realized max-DD: {m['max_dd_pct']}% "
        f"(limit 10%; worst across cycles {m['max_dd_pct_worst_cycle']}%)",
        f"- Trade density: {m['trade_density_per_day']}/day over {m['trade_density_entry_days']} "
        f"entry days  ·  max losing streak: {m['losing_streak_max']}",
        f"- Swap: {m['swap_cost']} USD  ·  commission: {m['commission_cost_usd']} USD  ·  median holding: {m['median_holding_hours']} h",
        "",
        "## Fitness",
        "",
        f"- Overall verdict: **{fit.get('overall_verdict')}**  ·  admitted pairs: {fit.get('admitted_pairs')}",
        f"- Best FUND_SCORE: {fit.get('best_fund_score')} vs floor {fit.get('fund_score_floor')}",
        "",
        "## Rules snapshot",
        "",
        f"- Source: {rs['source_url']}  ·  fetched: {rs['fetched_utc']}  ·  freshness: "
        f"{rs['freshness_days']} days ({rs['freshness_severity']})",
        "",
    ]
    if model["blockers"]:
        lines += ["## Blockers", ""] + [f"- {b}" for b in model["blockers"]] + [""]
    lines += [
        "## How it is computed",
        "",
        "- Demo cycle + material-change state machine: `tools/strategy_farm/ftmo/demo_cycle.py` "
        "(contract `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md`).",
        "- Account/sleeve metrics from the demo journal: `tools/strategy_farm/ftmo/demo_metrics.py`.",
        "- FTMO fitness (separate from DXZ): `tools/strategy_farm/ftmo/ftmo_fitness.py`, reusing the "
        "FUND_SCORE cache and, when present, first-passage outputs.",
        "- Rule freshness: `tools/strategy_farm/ftmo/rules_snapshot.py` against "
        "`docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json`.",
        "",
    ]
    doc_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="FTMO Challenge readiness")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_build = sub.add_parser("build", help="build the readiness read-model + living doc")
    p_build.add_argument("--out", default=str(DEFAULT_OUT))
    p_build.add_argument("--no-write", action="store_true")
    args = parser.parse_args(argv)
    if args.cmd == "build":
        model = build_readiness(out=Path(args.out), write=not args.no_write)
        print(
            json.dumps(
                {
                    "recommendation": model["recommendation"],
                    "would_fable_buy_today": model["would_fable_buy_today"]["answer"],
                    "strongest_failure_mode": model["strongest_failure_mode"],
                    "blockers": model["blockers"],
                },
                indent=2,
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
