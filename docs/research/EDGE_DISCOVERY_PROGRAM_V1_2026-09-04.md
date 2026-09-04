# Edge-Discovery Program v1 — 2026-09-04

Status: CEO program design (router task f93220de, Claude lane), commissioned by the OWNER
goal stated 2026-09-04 ~02:00Z: *Fable and Astra are the strongest models available; with
the tick and news data on hand (and more purchasable) they should find edges and design
strategies and frameworks that succeed on FTMO.* Doctrine anchor:
`docs/ops/MODEL_ROUTING_DOCTRINE_2026-09-04.md` §7.

Binding constraints (unchanged, hard-bounded): the models design, the pipeline judges
(Q02–Q13 is the only verdict); no ML libraries in V5 EAs; evidence over claims (every
number below has a file path or is marked as a target); no invented commission, swap or
DST values; `RISK_FIXED` for backtests; orthogonality over addition (long-term plan
2026-08-03, sparse-D1 standard V4 in `portfolio_correlation.py`).

## 1. Data inventory (measured 2026-09-04 02:45–03:15Z)

| Asset | Location | Coverage | Size | Notes |
|---|---|---|---|---|
| Darwinex `.DWX` tick archives, 37 symbols | `D:/QM/archive/Custom_master/ticks/<SYMBOL>.DWX/YYYYMM.tkc` (signed master, per-terminal copies under `D:/QM/mt5/T*/Bases/Custom`) | FX/metals/energy 2017-10 → 2025-12; indices (GDAXI, NDX, SP500, UK100, WS30) 2018-07 → 2025-12 | 36 GB | 28 FX pairs, XAUUSD, XAGUSD, XTIUSD, XNGUSD, 5 indices. JPN225 / XBRUSD exist in terminals with 5 files only (not usable). |
| Dukascopy ticks, NDX only | `D:/QM/data/dukascopy/USATECHIDXUSD/` (.bi5) | 2018 → 2026 | 2.76 GB | Source of the 2026-07-19 NDX rebuild; cross-check reference for the DWX NDX archive. |
| News calendar (Forex Factory, cleaned) | `D:/QM/data/news_calendar/forex_factory_calendar_clean.csv` (48,636 rows; header Date, DateTime_UTC, DateTime_EET, Currency, Impact, Event, Actual, Forecast); bundles under `.news_calendar_bundles/` (Q09 approved bundle receipt 2026-08-04) | 2015-01-01 → 2026-09-03 | 0.34 GB | Same taxonomy the news gate uses (Q10_NEWS). Actual/Forecast present → surprise measures possible. |
| Pipeline evidence | `D:/QM/reports/work_items/**` (per-run reports, aggregates, sealed Q08 daily-PnL streams), `D:/QM/strategy_farm/state/farm_state.sqlite` | 2026-05 → now | — | Thousands of finished backtests: the largest *negative* dataset the program has (what did NOT work, by symbol/timeframe/family). |

Gaps (do not fill by guessing): no order-book / depth data; no cross-venue prices except
NDX; index tick archives start 2018-07 (six years, not eight); no crypto; no options
implied-volatility series. Purchases are considered only when a hypothesis names the
missing series and its refutation test cannot run without it.

## 2. Hypothesis protocol (every idea passes through this, no exceptions)

1. **Statement.** One mechanical rule set in V5 terms (entry, exit, position sizing =
   `RISK_FIXED`, session/timeframe, symbol universe). Parameter count declared; ≤ 4 free
   parameters for a first card, each with a coarse grid (3–5 values) to keep Q14
   optimization honest.
2. **Mechanism.** One paragraph on *why* the effect should exist (who is the counterparty,
   what constraint produces the mispricing) and *why it should persist* (structural,
   not a 2020 artefact).
3. **Refutation criterion (written before any test).** The exact statistic and threshold
   that kills the idea: e.g. "conditional 4-hour forward return after the trigger is not
   larger than the unconditional mean by ≥ 0.5 σ over 2018–2023 with n ≥ 200 triggers, or
   the 2024–2025 holdout sign flips". A hypothesis without a refutation criterion is not
   accepted into the queue.
4. **Frequency floor.** Expected triggers per symbol-year ≥ 5 (Q02 rate floor); ideas
   below the floor are basket ideas or are dropped.
5. **Orthogonality.** Stated return source; expected daily-PnL correlation to the five
   terminal pairs (`docs/ops/evidence/2026-09-04_newsgate_readjudication_wave1.md`
   Q14 list) must be < 0.5 by construction (different driver), verified later with the
   V4 sparse-D1 screen.
6. **Measurement plan.** The summary statistics needed, which script computes them, and
   the output CSV path under `docs/research/edge_lab/<hypothesis_id>/`. Raw ticks never
   enter a model context; models reason over the CSV tables.
7. **Card.** Only after the refutation test *fails to refute* does the hypothesis become
   a Strategy Card (`cards_approved` on D: and C:, literal timeframe token), then Q02.

Decision rule for the models: Fable/Astra may *propose* and *critique*; the summary
tables are produced by deterministic scripts (Sonnet/Terra headless); the pipeline
verdicts are the only truth. A model claim that is not backed by a table row is a claim.

## 3. Roles and budget

| Seat | Role in the program | Pace |
|---|---|---|
| Fable (CEO) | program owner; writes and critiques hypotheses; enforces the protocol; reviews cards | continuous |
| Astra (when available) | one message per fully specified brief (template §6): design a mechanical rule set for a stated mechanism, or refute a hypothesis from its tables | ≤ 1 message per hypothesis per stage; hold when the 5h window is spent |
| Sonnet headless / Terra | measurement scripts over tick archives and the news calendar → CSV tables; no interpretation | as needed, cheap |
| Pipeline (T1–T10) | Q02–Q14 verdicts | unchanged priorities: census first |

Budget rule: the program never takes factory time from the 25-pair counter; Q02 seeds
from this program carry no `priority_track` until the counter stands.

## 4. First five hypotheses (with refutation criteria)

Each hypothesis id `EDGE-1..5`; tables to be written under
`docs/research/edge_lab/EDGE-n/` by the named script (to be created per hypothesis; the
first script is `tools/strategy_farm/research/edge_lab_stats.py`, not yet written).

### EDGE-1 — Scheduled-news post-release drift on FX majors (surprise-conditioned)
- **Mechanism.** High-impact releases with a large Actual–Forecast surprise produce a
  first move within seconds and a slower repricing over 30–120 minutes as slower money
  (asset managers, model funds) re-hedge; dealers fade the first move, creating a
  measurable drift in the surprise direction. This is orthogonal to the trend / mean-
  reversion / momentum pairs already terminal (their return source is price-only).
- **Rule sketch.** Trigger: FF `Impact = High`, currency ∈ {USD, EUR, GBP}, |surprise z| ≥
  1 (z over the event's own 3-year surprise history). Entry: at release + 5 min in the
  surprise direction on the currency's two most liquid crosses; exit: time stop 90 min or
  1.0×ATR(5m) stop. Parameters: surprise threshold, entry delay, holding time (3).
- **Refutation.** Over 2018–2023, mean 90-min forward return in surprise direction after
  entry delay must exceed the unconditional 90-min mean by ≥ 0.4 σ with n ≥ 300; 2024–2025
  holdout mean must have the same sign; otherwise dead. Frequency: ~8–12 qualifying
  events per month across the three currencies → above floor.
- **Tables.** Event-window returns at +1, +5, +15, +30, +60, +90, +120 min per event with
  surprise z, currency, year; unconditional baseline sampled at the same weekday/hour.

### EDGE-2 — Pre-event volatility compression and expansion in indices (event-day open)
- **Mechanism.** Ahead of scheduled US macro releases (CPI, NFP, FOMC) index futures
  liquidity thins and realised volatility compresses in the 60 minutes before release;
  the post-release expansion is directional only rarely, but the *range* expansion is
  reliable. A breakout of the pre-release range in the first 15 minutes after release,
  traded with a range-based stop, monetises expansion rather than direction.
- **Rule sketch.** Symbols NDX, SP500 (tick archives from 2018-07). Trigger: release day
  of the top-5 US events; define pre-release range (release − 60 min → release). Entry:
  stop orders at both range edges from release to release + 15 min; exit: 2×range target
  or range-midpoint stop or 60-min time stop. Parameters: pre-range length, breakout
  window, target multiple (3).
- **Refutation.** Post-release 60-min range must be ≥ 1.8× the pre-release range in ≥ 70 %
  of events (2018–2023, n ≥ 150) and the breakout trade's expectancy after 1 pt round-trip
  cost must be > 0 with t ≥ 2; the holdout 2024–2025 must keep the expansion ratio ≥ 1.5.
- **Tables.** Per event: pre-range, post-range, breakout direction, MFE/MAE at 15/30/60 min.
- **Constraint.** Index tester runs are currently blocked by the 44 GB `single_index_tick`
  reservation (n = 1 measurement); the measurement tables do not need the tester, but the
  Q02 seed will wait for the calibration run or the RAM decision.

### EDGE-3 — Intraday seasonality of the London fix in XAUUSD and EURUSD
- **Mechanism.** Benchmark-fix hedging (10:30 and 15:00 London gold fixes; 16:00 London
  WM/R FX fix) concentrates order flow at known times; academic and practitioner evidence
  documents pre-fix drift and post-fix reversal patterns driven by fix-referenced orders.
  Return source is *time-of-day flow*, orthogonal to price-pattern strategies.
- **Rule sketch.** Trigger: every trading day; measure the 30-minute pre-fix move; entry at
  the fix against the pre-fix move when it exceeds 0.6×ATR(30m); exit 45 min later or
  0.5×ATR stop. Parameters: pre-fix window, threshold multiple, holding time (3).
- **Refutation.** Post-fix 45-min return conditional on the pre-fix move sign must revert
  by ≥ 0.15×ATR on average (2018–2023, n ≥ 800 days per symbol) and hold sign in the
  2024–2025 holdout; if the 2022–2023 subsample already shows decay to zero, dead.
- **Tables.** Per day and fix: pre-fix move, post-fix returns at 15/30/45/60 min, ATR.

### EDGE-4 — Cross-asset lead–lag: WTI shocks into USDCAD and NOK-free proxies
- **Mechanism.** Large intraday crude moves transmit to commodity currencies with a lag
  because FX dealers update quotes on price, not on the oil tape; the lag is short but
  structural. Return source: cross-asset information transmission.
- **Rule sketch.** Trigger: XTIUSD 15-minute return beyond 2 σ (rolling 60-day); entry in
  USDCAD in the implied direction at the next 1-minute bar; exit after 30 min or at
  0.5×ATR(15m) stop. Parameters: shock threshold, holding time (2).
- **Refutation.** Conditional 30-min USDCAD return after WTI shocks must have the expected
  sign with mean ≥ 0.2 σ (2018–2023, n ≥ 400) and survive the holdout; if the effect is
  fully priced within 1 minute (no lag), dead.
- **Tables.** Shock events with USDCAD returns at +1, +5, +15, +30 min.

### EDGE-5 — Weekend-gap fill in FX majors conditioned on Friday close position
- **Mechanism.** Weekend gaps in FX reflect thin Sunday liquidity and news repricing; gap
  fills are well documented but decaying. The conditioning that may still carry an edge:
  gaps *against* the prior week's trend (position in the weekly range) fill more often
  because they are liquidity events rather than information events.
- **Rule sketch.** Trigger: Sunday-open gap ≥ 0.3×ATR(D1) on EURUSD, GBPUSD, USDJPY,
  AUDUSD; condition: gap direction opposite to Friday close position in the 5-day range
  (upper/lower third). Entry at Sunday open toward the Friday close; exit at gap fill or
  Monday 12:00 UTC time stop or 1×gap stop. Parameters: gap threshold, range-position
  cutoff (2). Frequency: ~10–20 per symbol-year → above floor.
- **Refutation.** Fill rate within the time stop ≥ 65 % and expectancy > 0 after spread
  for the conditioned subset (2018–2023, n ≥ 80 per symbol), holdout fill rate ≥ 55 %;
  otherwise dead. If the unconditioned fill rate is as good, the conditioning is noise
  and the idea collapses to a known, likely decayed effect → dead.
- **Tables.** Per weekend and symbol: gap size, range position, fill time, MAE.

Priority: EDGE-1 and EDGE-3 first (FX, data complete, no tester constraint), then EDGE-4,
EDGE-5, EDGE-2 last (index tester constraint).

## 5. Measurement tooling (to be built, Sonnet/Terra, standard implementation class)

`tools/strategy_farm/research/edge_lab_stats.py` — reads `.tkc` archives through the
existing tick reader used by the rebuild tooling (no new parser), resamples to 1-minute
bars, joins the news calendar by `DateTime_UTC`, and emits per-hypothesis CSV tables with
a manifest (`inputs`, `sha256`, `rows`, `period`). Requirements: deterministic, no
plotting, no model calls, runs under `python -X utf8` from `C:/QM/repo`, tests with a
synthetic tick fixture. Output root `docs/research/edge_lab/` (hash-bound evidence).

## 6. Astra brief template (one message per hypothesis per stage)

```
ROLE: strategy mechanization for QuantMechanica V5 (MT5, mechanical EAs, no ML).
HYPOTHESIS: <EDGE-n statement, mechanism, rule sketch>
EVIDENCE TABLES: <paths + sha256 + row counts> (attached CSV excerpts, ≤ 200 rows)
CONSTRAINTS: RISK_FIXED sizing; ≤ 4 parameters; frequency ≥ 5 trades/symbol-year;
  no invented costs (commission/swap per framework/registry/tester_defaults.json);
  entry/exit expressible in the V5 framework (framework/V5_FRAMEWORK_DESIGN.md).
TASK (choose one): (a) refute the hypothesis from the tables — name the statistic that
  kills it or state that it survives with the observed effect size; (b) design the
  minimal mechanical rule set and parameter grid; (c) list the three most likely ways
  the backtest will lie (look-ahead, session boundary, tick-model artefacts).
OUTPUT: JSON {verdict, effect_size, n, refutation_statistic, rule_set, parameters,
  parameter_grid, expected_trades_per_year, failure_modes, open_questions}.
NEVER: propose ML, propose parameters without a grid, claim numbers not in the tables.
```

## 7. Governance and cadence

- Program items are `agent_tasks` rows; hypotheses without a router task are notes.
- Weekly: Fable reviews the table results, kills refuted hypotheses in writing (append an
  entry to this file's §8 log), promotes survivors to cards. Target: 2 new hypotheses per
  week, 1 card per fortnight while the counter is below 25; no factory time before then.
- Costs are reported in `OPEN_ITEMS_STATUS.md` addenda like every other order.

## 8. Log

- 2026-09-04 05:10Z — v1 written (inventory measured, protocol, five hypotheses, tooling
  spec, Astra template). Next: commission `edge_lab_stats.py` (Sonnet/Terra) and the
  EDGE-1 / EDGE-3 tables.
