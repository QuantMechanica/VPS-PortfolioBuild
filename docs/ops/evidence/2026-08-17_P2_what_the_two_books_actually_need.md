# P2 — What the two books actually need, in named quantities

Both builders refuse. Read literally, their refusals are a requirements document. This is that
document, and it replaces further architecture discussion.

---

## DXZ: the refusal is not about sleeves at all

The first thing the manifest says, and the thing that reframes everything:

```
roster.mode                  EXPLICIT_FROZEN_Q10_ROSTER_MANIFEST
roster.input.path            portfolio_manifest_live_24sleeve_20260724.json
roster.q16_outcomes_applied  []
incumbent.n_sleeves          24
proposal.n_sleeves           24
```

**Incumbent and proposal are the same 24 sleeves from the same frozen file, over the same 1349
days.** The builder is not proposing a new roster — it is proposing a **reweighting**, and no
optimisation outcomes have been fed in (`q16_outcomes_applied: []`).

So "what must change for the bar to fall?" is **not** "more qualifying sleeves". It is a
weighting question on a fixed roster.

### The three legs, with distances

| Check | Result | Incumbent | Proposal | Gap |
|---|---|---:|---:|---:|
| `maxdd_not_worse` (proposal ≤ incumbent) | **FAIL** | 2.238353 % | 2.269930 % | **+0.031577 pp** |
| `return_to_maxdd_not_worse` (≥ incumbent) | **FAIL** | 4.526114 | 4.500513 | **−0.025601** |
| `worst_day_not_worse` (≥ incumbent) | PASS | −0.857107 % | −0.828051 % | +0.029 pp better |

And what it gives up those two legs *for*:

| | Incumbent | Proposal | Change |
|---|---:|---:|---:|
| annual_return_pct | 10.131043 | 10.215851 | **+0.085 pp** |
| sharpe | 2.5360519 | 2.5675902 | **+0.0315** |
| net profit | 54,233.24 | 54,687.24 | **+454.00** |

**The requirement, exactly:** a reweighting of these 24 sleeves that raises return and Sharpe
*without* increasing MaxDD by even 0.032 pp and without reducing return/maxDD by 0.026. The rule
is `ALL:` — three legs, no trade-off permitted. Nothing about the candidate pool changes this;
the entire question lives in the weighting method.

**The one number that would move it:** the proposal needs its MaxDD reduced by **0.0316 pp**
(2.2699 → ≤2.2384) while keeping the Sharpe and return gains. That is a weighting-search
problem on a frozen roster, not a sourcing problem.

**Policy note, not a change:** this gate is a **ratchet**, not a trade-off. A proposal that
improves Sharpe *and* return is refused for 0.03 pp of drawdown. Whether that is the intended
form is P1's open question for OWNER.

---

## FTMO: the refusal has two layers, and the first one is a data gap

`BAR_NOT_MET`, **0 sleeves**, `measured_gap: 0.8`. Five checks:

| Check | Result | What it actually says |
|---|---|---|
| `fund_score_each_at_least_1` | **FAIL** | see below — **nothing is scorable** |
| `density` | **FAIL** | consequence of 0 sleeves, not an independent failure |
| `bootstrap_lower_bound_at_least_0p80` | **FAIL** | `status: MISSING` — never run |
| `cost_and_swap_snapshot_coverage` | PASS | but only **3 symbols** are covered |
| `one_ea_per_symbol` | PASS | trivially, with 0 sleeves |

### Layer 1 — 195 of 216 sleeves cannot be scored at all

All 24 roster sleeves come back `FUND_SCORE_UNSCORABLE` with `fund_score: None`. That is **not**
"scored below the floor". Across the full 216-row scoring input:

| Reason | Rows |
|---|---:|
| `challenge_engine_ineligible` | **117** |
| `entry_time_incomplete` | **78** |
| `SCORED` | **21** |

`entry_time_incomplete` rows show `records: 255/392/513` but `entry_time_records: 0` — the trade
records exist, the **entry timestamps do not**. FUND_SCORE needs intraday attribution (its
worst-day term), so no timestamps means no score. **This is a data-capture gap, and closing it
would take the scorable pool from 21 to potentially 99.** That is the cheapest single move
available on the FTMO side, and it buys information rather than merit.

### Layer 2 — of the 21 that are scorable, the best is 0.4085 against a floor of 1.0

```
9936:USDJPY   fund_score 0.4085   med60 3.3425   worst_day 1.7644   wdd_p90 8.1822   denom 8.1822
13301:GDAXI   fund_score 0.3441   med60 1.7701   worst_day 1.8530   wdd_p90 5.1437   denom 5.1437
10700:XAUUSD  fund_score 0.2223   med60 1.1058   worst_day 2.0160   wdd_p90 4.9744   denom 4.9744
13213:USDJPY  fund_score 0.1900   med60 1.7965   worst_day 1.9006   wdd_p90 9.4541   denom 9.4541
```

Formula: `FUND_SCORE = med60 / max(2, 2·|wDay|, wDD_p90)`. **In every case the denominator IS
`wdd_p90`** — neither the floor of 2 nor the worst-day term binds. So:

> **FUND_SCORE ≥ 1.0 ⟺ med60 ≥ wdd_p90** — the 60-day median must exceed the 90th-percentile
> drawdown.

**The number: the best scorable sleeve needs a 2.45× improvement in that ratio** (3.3425 →
8.1822, or the drawdown down by the same factor, or a mix). Zero of 21 reach the floor, which
matches the 2026-08-13 audit's independent 0/19.

### Layer 3 — two structural constraints worth naming

- **`supported_symbols: ['USDJPY.DWX', 'XAUUSD.DWX', 'XTIUSD.DWX']`.** The cost/swap snapshot
  covers three symbols. With `minimum_sleeves: 3` and `one_ea_per_symbol`, an FTMO book today is
  **exactly one sleeve per those three symbols** — no slack. Widening the FTMO universe requires
  a new cost/swap snapshot, not new EAs.
- **`phase1_bootstrap.status: MISSING`**, `reason: ROSTER_BOUND_BOOTSTRAP_RESULT_REQUIRED`,
  `required_engine_lineage: ae5331f67`, `ci_lower_p_phase1: 0.0`, `required_lower_bound: 0.8`. So
  `measured_gap = 0.8` is `0.8 − 0.0`: **the bootstrap was never run**, and it is roster-bound —
  it must be computed for the selected roster. It cannot be run before a roster exists, so it is
  downstream of Layer 1, not a parallel blocker.
- `density` contract: `minimum_sleeves: 3`, `minimum_active_days_per_sleeve_per_60d: 4.0`,
  `minimum_trading_days_phase1: 4`. `density_evidence_complete: True` — the evidence is there;
  the observed lists are empty only because 0 sleeves were selected.

---

## The finding that splits the objective question

P1 concluded that Sharpe contribution is the right objective because Sharpe is scale-invariant
while drawdown is basis-dependent. **That holds for DZ. It does not transfer to FTMO**, because
FTMO's own scoring formula is *drawdown-dominated by construction* — `wdd_p90` sets the
denominator for every scorable sleeve.

So the two books need **two different falsification criteria**, which is exactly what the
standing decision "one candidate pool, two objective functions" implies:

| Book | Objective the gate actually rewards |
|---|---|
| DZ | **Sharpe contribution** (scale-invariant; the not-worse ratchet then guards DD) |
| FTMO | **med60 relative to wdd_p90** — reducing deep drawdowns counts as much as raising return |

This is a correction to how I framed P6's criterion last round: "does not degrade book Sharpe" is
the DZ criterion, not a universal one. A cohort entry aimed at FTMO should be falsified on the
`med60/wdd_p90` ratio instead.

---

## Ranked shortest paths to a book

1. **Fix `entry_time` capture** (78 rows). Pure data, no strategy work, and it is the only move
   that *reveals* whether the pool is closer than 21 sleeves suggest. Cheapest information per
   unit effort of anything on this page.
2. **DZ weighting search** on the frozen 24 — find a reweighting that keeps +0.0315 Sharpe and
   +0.085 pp return while shedding 0.0316 pp of MaxDD. Bounded, offline, no pipeline.
3. **`challenge_engine_ineligible`** (117 rows): establish *why*. If it is a fixable eligibility
   condition, it is the largest single block of the pool.
4. **Raise med60/wdd_p90 by ~2.45×** on FTMO candidates. This is the genuine strategy problem and
   the only one that needs new work rather than repair.
5. **A wider FTMO cost/swap snapshot** if more than three symbols are ever wanted.

## Still open from P2's ask

- **`ftmo_rules_engine.py` dating:** the module dates itself in its own docstring —
  *"Authoritative rule snapshot (retrieved 2026-07-21): https://ftmo.com/en/trading-objectives/"*
  — and git confirms `2f70864be` (2026-07-21, "add strict current FTMO rule screens") and
  `db4de96a3` (2026-07-29). The gap is that this is not in the runbook; the fact itself is
  established.
- **Holdout:** neither builder evaluates on a window absent from selection. DXZ compares proposal
  against incumbent over the same 1349 days; FTMO applies thresholds. This remains the first
  genuine discipline gap, and it is not code — with a frozen roster and a reweighting proposal,
  the natural holdout is a time split of the same 1349 days.

## Evidence

- dry-run manifests: `.../scratchpad/book_dryrun/{dxz,ftmo}/manifest.json`
- `D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json` (sha `0a604c24…`, 216 rows)
- `D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json` (sha `8c719b08…`)
- FTMO cost snapshot: `docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json` (sha `7eab3bf8…`)
- related: `2026-08-17_P1_maxdd_scale_resolved_sharpe_is_scale_invariant.md`,
  `2026-08-17_P5_book_builders_executed.md`
