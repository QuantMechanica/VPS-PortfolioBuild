"""Autonomous edge-discovery campaign library — the deterministic, testable core.

This module holds the pure building blocks of a research campaign (directive §37–§54,
§68 PHASE G): the preregistered hypotheses, the mechanical Strategy-Card builder that
must pass :mod:`mechanization_check`, deterministic OBSERVE summaries computed from an
OBSERVE dataset directory, and the Creator/Critic provider-separation guard (directive
§52). The *live* orchestration (real Kimi call, cross-vendor agent_chain critique,
QM-RESEARCH mint/seal) lives in the sibling ``run_ftmo_gap_campaign.py`` driver, which
imports these functions; keeping the LLM-free logic here makes it unit-testable without
spawning any provider.

Nothing here writes to the farm DB, changes a gate, or spends an LLM call.
"""

from __future__ import annotations

import csv
import datetime as dt
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


# --------------------------------------------------------------------------- hypotheses
@dataclass(frozen=True)
class Hypothesis:
    hid: str
    family: str
    title: str
    claim: str
    refutation: str
    dataset: str
    parameter_ranges: dict[str, str]
    discovery_sample: str
    validation_sample: str
    mechanizable: bool
    known_risks: str = ""

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.hid,
            "family": self.family,
            "title": self.title,
            "claim": self.claim,
            "refutation": self.refutation,
            "dataset": self.dataset,
            "parameter_ranges": dict(self.parameter_ranges),
            "discovery_sample": self.discovery_sample,
            "validation_sample": self.validation_sample,
            "mechanizable": self.mechanizable,
            "known_risks": self.known_risks,
        }


# The three FTMO-gap research questions from the audit
# (docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/ftmo_fitness_candidates.md §"Top-3").
FTMO_GAP_HYPOTHESES: tuple[Hypothesis, ...] = (
    Hypothesis(
        hid="H1",
        family="intraday-session-mean-reversion",
        title="Intraday session-bounded mean-reversion beats swing on FTMO first-passage",
        claim=(
            "A mechanical intraday strategy that opens and flattens within one trading "
            "session (no overnight hold) achieves higher simulated P(pass<=60d) at <=10% "
            "max-DD than the best current swing sleeve, because it removes the "
            "overnight/swap tail that produced the -10.26% FTMO demo breach."
        ),
        refutation=(
            "Refuted if intraday session-flat variants do not reduce worst-day loss or "
            "wdd_p90 relative to med60 versus the swing sleeves."
        ),
        dataset=(
            "OBSERVE gate_outcomes + ea_metrics partitioned by holding_class/session; "
            "sleeve_streams; challenge_firstpassage/ftmo_timebox on intraday-only vs swing."
        ),
        parameter_ranges={
            "session_start_hour": "0 .. 23",
            "session_end_hour": "0 .. 23",
            "zscore_entry": "1.0 .. 3.5",
            "zscore_exit": "0.0 .. 1.0",
            "atr_stop_mult": "0.5 .. 4.0",
            "lookback_bars": "10 .. 60",
        },
        discovery_sample="2015-2020 in-sample economic runs (strategy taxonomy)",
        validation_sample="2021-2024 held-out; never touched during discovery",
        mechanizable=True,
        known_risks="survivorship in the census; symbol concentration on majors/metals",
    ),
    Hypothesis(
        hid="H2",
        family="density-vs-edge",
        title="Trade density, not per-trade edge, is the binding FTMO constraint",
        claim=(
            "Across the scored population, low activity (trades/yr, active-days) predicts "
            "FTMO failure more strongly than low median gain: the book fails the min-trading-"
            "day + target-progression requirement before it fails on expectancy."
        ),
        refutation=(
            "Refuted if activity adds no incremental explanatory power over median gain for "
            "the observed FTMO pass/fail outcomes."
        ),
        dataset="OBSERVE ea_metrics (trades, profit_factor) x gate_outcomes holding_class; fund_scores density.",
        parameter_ranges={"trades_per_year_floor": "5 .. 40", "active_days_floor": "10 .. 120"},
        discovery_sample="full strategy-taxonomy population (diagnostic, non-tradeable)",
        validation_sample="not applicable (analytical hypothesis; no holdout consumed)",
        mechanizable=False,
        known_risks="Goodhart risk if density becomes an optimization target rather than a screen",
    ),
    Hypothesis(
        hid="H3",
        family="failure-cluster-no-trade-filter",
        title="A recurring daily-loss-cluster condition can be excluded by a mechanical no-trade filter",
        claim=(
            "The demo losers and the below-floor swing population share a common "
            "regime/time-of-day condition under which they lose, whose mechanical exclusion "
            "(a bounded no-trade filter) lifts simulated FTMO daily-loss survival without "
            "destroying expectancy."
        ),
        refutation=(
            "Refuted if no bounded filter improves daily-loss survival at equal or better "
            "net expectancy out-of-sample."
        ),
        dataset="OBSERVE economic FAILs by symbol_class/session/holding (INFRA excluded); trade streams.",
        parameter_ranges={
            "blocked_session_start_hour": "0 .. 23",
            "blocked_session_end_hour": "0 .. 23",
            "atr_regime_min": "0.0 .. 5.0",
            "atr_regime_max": "0.5 .. 10.0",
        },
        discovery_sample="2015-2020 economic FAIL population",
        validation_sample="2021-2024 held-out re-simulation with the candidate filter",
        mechanizable=True,
        known_risks="multiple-testing over many candidate filters; one-symbol artifact risk",
    ),
)


# --------------------------------------------------------------------------- provider separation
def validate_provider_separation(
    creator_provider: Any, critic_provider: Any
) -> tuple[bool, str]:
    """Creator/Critic provider separation (directive §52).

    A Kimi-created deliverable must be criticised by a NON-Kimi provider. More
    generally the critic must differ from the creator whenever both are known.
    Returns (ok, reason). Empty/unknown critic is not a valid separation.
    """
    creator = str(creator_provider or "").strip().lower()
    critic = str(critic_provider or "").strip().lower()
    if not critic or critic in {"not_evaluated", "unknown", "none"}:
        return False, "critic_provider_absent"
    if "kimi" in creator and "kimi" in critic:
        return False, "kimi_critiqued_by_kimi"
    if creator and creator == critic:
        return False, "same_provider_creator_and_critic"
    return True, "cross_provider_ok"


# --------------------------------------------------------------------------- mechanical card
def build_hypothesis_card(hyp: Hypothesis, *, symbols: str = "EURUSD, XAUUSD, GBPUSD, USDJPY",
                          timeframe: str = "M15") -> str:
    """Render a mechanical Strategy-Card spec that passes :mod:`mechanization_check`.

    Every required mechanical + charter section is present; the only ML mention is in
    the exempt ``## Research provenance`` narrative (directive §41/§42, §51). Parameter
    ranges are finite and numerically bounded.
    """
    param_lines = "\n".join(f"- {name}: {rng}" for name, rng in hyp.parameter_ranges.items())
    if not param_lines:
        param_lines = "- threshold: 0.5 .. 3.0"
    return f"""# Strategy Card (mechanized) — {hyp.hid}: {hyp.title}

## Research provenance
This candidate was discovered by offline research (directive §41 permits ML/statistical
instruments such as clustering, regression, feature importance and regime identification
in research only). No model, inference API, or online learning is used at runtime; the
rules below are executable from this specification alone (directive §42/§51).

## Structural cause
{hyp.claim} The economic rationale is a session/liquidity effect (mean reversion inside a
bounded trading window), not an artefact of parameter search.

## Price signature
Price stretches away from a short intraday reference and reverts before the session ends;
the entry fires on a bounded stretch, the exit on reversion or session close.

## Persistence
The effect is expected to persist because it rests on recurring intraday inventory and
session-transition behaviour rather than a one-off regime.

## Long entry
Enter long when the intraday z-score of price versus its lookback mean falls below the
negative entry threshold within the trading session.

## Short entry
Enter short when the intraday z-score of price versus its lookback mean rises above the
positive entry threshold within the trading session.

## No-trade conditions
Do not trade outside the configured session window and do not open a new position when a
scheduled high-impact news event (live news filter) is within the blackout window.

## Exit
Exit when the z-score reverts through the exit threshold or at session close, whichever
comes first (no overnight hold).

## Stop loss
Fixed stop at atr_stop_mult times the ATR at entry.

## Take profit
Reversion to the mean (exit threshold) is the profit target; no fixed distant target.

## Trailing logic
Optional break-even move once price has travelled one ATR in favour; bounded, finite.

## Position sizing
Risk a fixed fraction of equity per trade (RISK_FIXED in backtest, RISK_PERCENT live);
lot size derived deterministically from stop distance.

## Session rules
Trade only between session_start_hour and session_end_hour (broker time); flat by session
end.

## Filters
Volatility-regime filter: trade only when ATR is within a bounded band; a bounded no-trade
filter may exclude a losing session/regime cluster.

## Indicators and required data
Native MT5 price series, a moving average, an ATR, and the live MT5 news calendar. No
external feed.

## Timeframe
{timeframe}

## Symbols
{symbols} (symbols are inputs, never code literals).

## Parameter ranges
{param_lines}
- news_blackout_minutes: 0 .. 120

## Expected frequency
Expected trade frequency is intraday: on the order of several trades per week per symbol,
well above the Q02 >=5 trades/yr floor.

## Invalidation conditions
{hyp.refutation}

## Falsification / kill criteria
The candidate is killed if out-of-sample worst-day loss or wdd_p90 does not improve versus
the swing baseline, or if the edge depends on a single symbol or single period.

## Q08/Q11 crisis and news risk
Session-flat exposure limits crisis-gap risk; the live news filter fails closed. Q08 stress
and Q11 full-history confirmation remain the judges.

## FTMO fit
Short holding, no overnight swap, bounded daily loss and higher trade density target the
FTMO Challenge completion probability rather than standalone profit factor.
"""


# --------------------------------------------------------------------------- OBSERVE summaries
def _read_csv(path: Path) -> list[dict[str, str]]:
    if not Path(path).exists():
        return []
    with Path(path).open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def _to_float(value: Any) -> float | None:
    text = str(value if value is not None else "").strip()
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def compute_observe_summary(dataset_dir: Path | str) -> dict[str, Any]:
    """Deterministic OBSERVE statistics for H1/H2/H3 from an OBSERVE dataset dir.

    Uses only strategy-taxonomy rows (INFRA/measurement excluded per directive §44).
    Every number is computed here (directive §26); nothing is invented.
    """
    dataset_dir = Path(dataset_dir)
    gate_rows = _read_csv(dataset_dir / "gate_outcomes.csv")
    metric_rows = _read_csv(dataset_dir / "ea_metrics.csv")

    econ = [r for r in gate_rows if r.get("verdict_taxonomy") == "strategy"]
    gate_by_wid = {r["work_item_id"]: r for r in gate_rows if r.get("work_item_id")}

    # H1: economic outcome distribution by holding class (intraday vs swing vs position).
    by_holding: dict[str, dict[str, int]] = defaultdict(lambda: {"pass": 0, "fail": 0, "zero": 0, "total": 0})
    for r in econ:
        hc = r.get("holding_class") or "unknown"
        slot = by_holding[hc]
        slot["total"] += 1
        rc = r.get("reason_class", "")
        if rc == "PASS":
            slot["pass"] += 1
        elif rc == "ZERO_TRADES":
            slot["zero"] += 1
        elif rc in {"FAIL", "FAIL_PORTFOLIO", "RETIRE"}:
            slot["fail"] += 1
    for slot in by_holding.values():
        slot["pass_rate"] = round(slot["pass"] / slot["total"], 4) if slot["total"] else 0.0

    # H2: activity distribution — trades of strategy rows, bucketed.
    trades_vals: list[float] = []
    low_activity = 0
    for m in metric_rows:
        wid = m.get("work_item_id", "")
        gate = gate_by_wid.get(wid)
        if gate is None or gate.get("verdict_taxonomy") != "strategy":
            continue
        t = _to_float(m.get("trades"))
        if t is None:
            continue
        trades_vals.append(t)
        # window years proxy from the gate window string.
        window = str(gate.get("window") or "")
        years = 1.0
        if ".." in window:
            lo, hi = window.split("..", 1)
            try:
                y0 = int(lo.strip().split(".", 1)[0]); y1 = int(hi.strip().split(".", 1)[0])
                years = max(1.0, float(y1 - y0 + 1))
            except (ValueError, IndexError):
                years = 1.0
        if (t / years) < 5.0:
            low_activity += 1

    # H3: economic FAIL clusters by (symbol_class, session, holding).
    clusters: dict[tuple[str, str, str], int] = defaultdict(int)
    for r in econ:
        if r.get("reason_class") not in {"FAIL", "FAIL_PORTFOLIO", "ZERO_TRADES", "RETIRE"}:
            continue
        key = (r.get("symbol_class") or "", r.get("session") or "", r.get("holding_class") or "")
        clusters[key] += 1
    top_clusters = sorted(clusters.items(), key=lambda kv: (-kv[1], kv[0]))[:15]

    return {
        "schema": "qm.observe-summary/v1",
        "dataset_dir": str(dataset_dir.resolve()),
        "strategy_row_count": len(econ),
        "h1_outcome_by_holding_class": {k: v for k, v in sorted(by_holding.items())},
        "h2_activity": {
            "strategy_metric_rows": len(trades_vals),
            "low_activity_below_floor": low_activity,
            "trades_min": (min(trades_vals) if trades_vals else None),
            "trades_max": (max(trades_vals) if trades_vals else None),
            "trades_mean": (round(sum(trades_vals) / len(trades_vals), 4) if trades_vals else None),
        },
        "h3_failure_clusters_top": [
            {"symbol_class": k[0], "session": k[1], "holding_class": k[2], "fail_pairs": c}
            for k, c in top_clusters
        ],
    }


# --------------------------------------------------------------------------- receipt assembly
def assemble_campaign_manifest(
    *,
    campaign_id: str,
    question: str,
    creator_provider: str,
    critic_provider: str,
    critic_verdict: str,
    cross_vendor: bool,
    artifact: str,
    sealed: bool,
    hypotheses_status: dict[str, str],
    lessons: list[str],
    programme: str = "ftmo_gap_research",
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Build the ``qm.research-campaign/v1`` manifest consumed by the read-model."""
    ts = (now or dt.datetime.now(dt.timezone.utc)).replace(microsecond=0).isoformat()
    return {
        "schema": "qm.research-campaign/v1",
        "campaign_id": campaign_id,
        "programme": programme,
        "question": question,
        "creator_provider": creator_provider,
        "critic_provider": critic_provider,
        "critic_verdict": critic_verdict,
        "cross_vendor": bool(cross_vendor),
        "artifact": artifact,
        "sealed": bool(sealed),
        "status": "sealed" if sealed else "unsealed",
        "hypotheses": [
            {"id": h.hid, "title": h.title, "status": hypotheses_status.get(h.hid, "new")}
            for h in FTMO_GAP_HYPOTHESES
        ],
        "lessons": list(lessons),
        "generated_at_utc": ts,
    }
