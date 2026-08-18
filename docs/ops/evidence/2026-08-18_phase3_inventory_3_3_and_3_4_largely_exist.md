# Phase 3 inventory — 3.3 and 3.4 are far less green-field than the plan assumes, and (b) is 3.4's precondition

Continues `docs/ops/evidence/2026-08-18_point_3_2_inventory_before_building.md`, whose caveat was
that `portfolio_resize.py` and `book_sizing.py` had not been read. They have now, and they belong to
different numbered points than I filed them under.

## Correction to my own filing

I inventoried both as 3.2 modules because v6 §3.2 names them. Reading them shows they answer **3.3's
and 3.4's** questions, not 3.2's:

**`book_sizing.py`** recomputes the book *"at the REAL deployed per-trade risk basis"* and states the
distinction §3.3 is built around: the manifest KPIs are a risk-parity **weighted average** (weights
sum to 1), while *"the LIVE deployment is different: each sleeve runs INDEPENDENTLY at a flat
RISK_PERCENT of the full account, so the deployed book is the SUM of the sleeves, not a weighted
average."* It reports realized return, 8-year MaxDD and monthly VaR at live per-trade risk, and —
decisively — *"FTMO 2-step MC pass% across per-trade risk levels (reuses prop_challenge_sim)"*.

That last clause is §3.4's deliverable in one line.

**`portfolio_resize.py`** carries the risk-unit scaling §3.3 needs, with the units made explicit
(*"account percentage points (1.0 means one percent), not decimal returns"*) and with a provenance
discipline worth noting today of all days: *"A resize can only run from a SHA-pinned frozen stream
bundle; volatile MT5 Common\Files discovery is intentionally unavailable here."* It refuses to read
the very stream path the (b) batch is currently overwriting.

## 3.4 — most of it exists, and its declared gap is exactly what (b) is fixing

`portfolio/prop_challenge_sim.py` (24 KB, 2026-07-09) already implements:

| §3.4 requirement | status |
|---|---|
| FTMO Phase 1 rules: 10% target, 5% daily, ≥4 trading days | **implemented** — `FTMO_2STEP` preset, values match v6 §1 exactly |
| Phase 2 (5% target) | implemented as a second preset |
| **Block bootstrap** with tunable block length | **implemented** (`--block-days`) — and v6 forbids iid bootstrap, which this is not |
| risk-per-trade axis of the P(pass) curve | implemented (`--risk-scale`) |
| failure decomposition inputs | tracked: `max_closed_daily_loss_pct`, `max_total_loss_pct`, `trading_days` |
| run count / seeding / horizon | `--runs 1000`, `--seed`, `--phase-horizon-days` |

Two things are missing, and one of them is the connection to today's work:

1. **Rolling historical starts.** v6 §3.4 makes rolling 60-day windows over the 1,349 days the
   *primary* method and the block bootstrap merely the confidence band. The simulator is
   bootstrap-only — there is no start-offset parameter.
2. **The intraday floating path.** The module declares its own limitation at line 85: *"Closed daily
   PnL approximation from Q08 streams. Intraday floating …"*. That is precisely the systematic
   understatement v6 warns about twice (*"für Grid gilt das doppelt"*).

**And closing that second gap needs `side` and `entry_price` — which is exactly what the (b) batch
is regenerating.** The connection is direct: (b) is not only a provenance fix for the pool, it is the
precondition for 3.4's headline number being computed on the risk basis FTMO actually measures.

## Where Phase 3 actually stands

| point | state |
|---|---|
| 3.2 construction | **the genuine gap** — no module selects members; both optimise weights over a given roster |
| 3.3 sizing | machinery exists (`book_sizing` deployed-basis recomputation, `portfolio_resize` unit-correct scaling); needs the exit timestamps and direction (b) supplies |
| 3.4 P(pass) curve | preset, limits, bootstrap and risk axis exist; needs rolling starts, the intraday path, and the two-curve news comparison |

The plan's estimate that Phase 3 is largely construction work holds only for **3.2**. For 3.3 and
3.4 the work is extension and validation of running code, not authorship.

## Evidence

- `tools/strategy_farm/portfolio/book_sizing.py` — deployed-basis docstring, prop_challenge_sim reuse
- `tools/strategy_farm/portfolio/portfolio_resize.py` — risk units, SHA-pinned bundle discipline
- `tools/strategy_farm/portfolio/prop_challenge_sim.py` — `FTMO_2STEP` preset values, `--block-days`,
  `--risk-scale`, the line-85 closed-PnL declaration, and the absence of any start-offset argument
