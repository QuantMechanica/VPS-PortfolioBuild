---
strategy_id: PAPAILIAS-RSM-2021_XTI_S02
source_id: PAPAILIAS-RSM-2021
ea_id: QM5_13150
slug: wti-signmom
status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
g0_status: APPROVED
source_citation: "Papailias, Liu, and Thomakos (2021), Return Signal Momentum, Journal of Banking & Finance 124, 106063, DOI 10.1016/j.jbankfin.2021.106063."
source_citations:
  - type: paper
    citation: "Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, Article 106063."
    location: "Sections 2.1, 2.2, 4.1-4.2; Equations 7 and 10; Tables 1 and G.1-G.3; DOI https://doi.org/10.1016/j.jbankfin.2021.106063; accepted manuscript https://pureadmin.qub.ac.uk/ws/files/229452162/RSM_011220.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/PAPAILIAS-RSM-2021]]"
concepts:
  - "[[concepts/return-sign-persistence]]"
  - "[[concepts/crude-oil-trend]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/atr]]"
strategy_type_flags: [momentum, time-stop, symmetric-long-short, atr-hard-stop]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "One renewed WTI position per broker month after warm-up; approximately 12 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.02
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify the WTI-specific count-of-monthly-signs carrier. It is not cumulative-return TSMOM; the source's adverse WTI drawdown evidence and CFD basis remain kill risks, while realized book orthogonality remains unclaimed."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_futures_basis, low_frequency]
g0_approval_reasoning: "APPROVED under the 2026-07-12 OWNER commodity-sleeve mission: R1 complete peer-reviewed accepted manuscript with WTI-specific Tables G.1-G.3; R2 locked 12 completed monthly binary signs, equal-weight positive-sign fraction, fixed 0.40 threshold, monthly renewal, frozen ATR stop, and no same-month re-entry; R3 registered native XTIUSD.DWX D1 data; R4 no ML, banned indicator, adaptive fit, external runtime feed, grid, martingale, or pyramiding. Exact slug and strategy-ID dedup is clean; the only fuzzy match is the source-authorized XNG sibling, while WTI cumulative-return TSMOM uses a different statistic. The individual-source drawdown, futures-to-CFD translation, and unproven book correlation are binding pipeline risks."
---

# WTI Return-Sign Momentum

## Hypothesis

Monthly return direction may persist even when return magnitude is noisy. The
source estimates that persistence by counting the signs of the prior monthly
returns, not by summing those returns. This card applies the paper's fixed
return-signal-momentum rule to WTI, an explicit source instrument, to add crude
oil exposure that is structurally separate from the current index, metal, and
natural-gas book.

## Source And Evidence Boundary

The primary source is the peer-reviewed 2021 *Journal of Banking & Finance*
paper "Return Signal Momentum," DOI
https://doi.org/10.1016/j.jbankfin.2021.106063. Its complete 83-page accepted
manuscript, including Appendices A-I, was reviewed. WTI is explicit in Table 1
and Appendix C as the CL1 commodity-futures series.

For WTI, Table G.1 reports source-sample annualised mean return of 0.113 for
RSM0.4 versus 0.093 for conventional TSM, and Table G.2 reports Sharpe ratios
of 0.302 versus 0.247. Table G.3 is adverse: RSM0.4 has a larger WTI maximum
drawdown than TSM. These individual historical futures statistics justify only
a low-prior falsification test. They do not validate `XTIUSD.DWX`, the ATR
overlay, costs, future efficacy, or book correlation.

## Concept And Non-Duplicate Decision

On the first tradable `XTIUSD.DWX` D1 bar of each broker month, reconstruct
the last 13 completed month-end closes. Convert the 12 intervening monthly
returns to binary signs and calculate:

`positive_probability = non_negative_months / 12`.

- If `positive_probability >= 0.40`, hold long WTI for the new month.
- Otherwise, hold short WTI for the new month.

This statistic is mechanically different from:

- `QM5_12603_wti-tsmom12m` and `QM5_12710_commodity-tsmom-12m-atr`,
  which take the sign of one cumulative start-to-end 12-month return.
- `QM5_12708_commodity-tsmom-6m` and
  `QM5_12616_tsmom-9m-commodity-xtiusd`, which use cumulative return over
  other horizons.
- `QM5_13100_wti-dmac16`, which uses a daily moving-average crossover.
- `QM5_13108_xti-mtsm-s2`, which uses partial moments of D1 returns.
- WTI calendar, inventory/event, carry, channel, price-level, ratio, RSI,
  reversal, and relative-value cards, which do not count completed monthly
  return signs.

The automated pre-allocation check found no exact slug, strategy-ID, or
registry duplicate. It found one same-source fuzzy match:
`QM5_13116_xng-signmom`. Manual review classifies this as an authorized
symbol-specific source extraction: the WTI carrier and source evidence are new,
but the underlying RSM anomaly is not renamed or claimed as new. Verdict:
`FUZZY_SAME_SOURCE_SYMBOL_EXTENSION_MANUALLY_RESOLVED`.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Host and signal timeframe: D1.
- Signal cadence: first D1 bar of each broker-calendar month.
- Expected frequency: approximately 12 completed positions/year after warm-up,
  above the Q02 floor of five trades/year.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: native MT5 D1 closes, ATR, broker spread, broker calendar, and
  position state only.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Evaluate only on the first new `XTIUSD.DWX` D1 bar of a broker month.
- Copy a bounded completed-D1 history and retain the most recent completed close
  for each distinct broker-calendar month.
- Require `strategy_lookback_months + 1` valid month-end closes.
- For each of the 12 completed monthly returns, assign `1` when the return is
  non-negative and `0` when negative.
- Set `positive_probability = positive_count / strategy_lookback_months`.
- BUY when probability is at least
  `strategy_positive_threshold=0.40`; otherwise SELL.
- Require a valid ATR, acceptable spread, no existing same-magic position, and
  no prior attempt in the current broker month.
- Place a frozen `3.5 * ATR(20)` hard stop; no take-profit.

## 5. Exit Rules

- On the first tradable D1 bar of the next broker month, close the prior
  position before evaluating the renewed signal.
- Close if the position exceeds `strategy_max_hold_days=35` as a stale guard.
- The broker hard stop remains active within the month.
- No sign flip, intramonth return, RSI, target-profit, or discretionary exit.

## 6. Filters (No-Trade Module)

- Exact host guard: `XTIUSD.DWX`, D1, magic slot 0.
- Parameter, history, close, arithmetic, ATR, and spread checks fail closed.
- Framework kill switch and news-entry compliance remain authoritative.

## 7. Trade Management Rules

- One position per EA magic; no same-month re-entry after a stop.
- No trailing stop, break-even move, partial close, scale-in, grid, martingale,
  pyramiding, adaptive threshold, optimization at runtime, external feed, or
  ML.
- Friday close is disabled to preserve the source's one-month holding period.

## Parameters To Test

| parameter | default | source/card range | role |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | [12] | source formation window |
| `strategy_positive_threshold` | 0.40 | [0.30, 0.40, 0.50] | fixed source thresholds; no adaptive threshold |
| `strategy_history_bars` | 500 | [400, 500, 650] | bounded D1 month-end reconstruction |
| `strategy_atr_period` | 20 | [14, 20, 30] | V5 hard-stop estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly reset |
| `strategy_max_spread_points` | 1500 | [1000, 1500, 2500] | WTI entry spread cap |

The binary monthly-sign definition, equal weighting, non-negative sign rule,
12-month default, fixed threshold, monthly renewal, and no same-month re-entry
are locked. Magnitude momentum, an adaptive threshold, daily signs, breakout,
RSI, event data, or calendar ownership requires a new card.

## Initial Risk Profile

- `expected_pf: 1.02` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 30.0` reflects crude-oil gap/basis risk and the adverse
  individual WTI drawdown reported in source Table G.3.
- Risk class: high.
- The source uses portfolio volatility scaling without this broker stop. The V5
  carrier uses `RISK_FIXED=1000` plus a frozen ATR hard stop; no source
  portfolio-volatility result is imported.

## Kill Criteria

- Retire at Q02 if realized frequency is below five trades/year.
- Fail on zero trades, invalid month-end reconstruction, repeated `OnInit`
  failure, non-deterministic reruns, or risk-mode mismatch.
- Do not widen thresholds, shorten the 12-month lookback, add an intramonth
  trigger, or sweep outside this card after a poor baseline.
- Treat source-futures versus DWX-CFD roll/basis mismatch as a falsification
  risk, never as justification for a waiver.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed *Journal of Banking & Finance* paper, DOI,
  complete institutional accepted manuscript, and WTI-specific appendix rows.
- [x] R2 mechanical: fixed completed-month binary signs, equal-weight
  probability, fixed threshold, monthly renewal, and deterministic ATR stop.
- [x] R3 testable: registered `XTIUSD.DWX` D1 history is available.
- [x] R4 compliant: no ML, banned indicator, external runtime feed, adaptive
  fit, grid, martingale, or pyramiding.
- [x] Expected frequency exceeds the five-trades/year Q02 floor.
- [x] Exact repository dedup is clean; same-source XNG sibling manually
  resolved and explicitly linked.

## Framework Alignment

- no_trade: exact WTI/D1/slot, parameter domain, monthly attempt, bounded
  history, arithmetic, spread, ATR, and one-position guards.
- trade_entry: source-defined 12-month positive-sign probability and fixed 0.40
  threshold, with V5 fixed-risk ATR stop.
- trade_management: month reset, stale close, no same-month re-entry.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` plus broker stop.

`hard_rules_at_risk`:

- `friday_close`: disabled only for the source-aligned one-month hold; monthly
  and stale exits plus the broker hard stop remain active.
- `risk_mode_dual`: the build creates only a RISK_FIXED backtest setfile.
- `cfd_futures_basis`: the source uses rolled futures while Q02 uses a
  continuous Darwinex CFD; equivalence is not assumed.

## Risk And Safety Boundary

The build may create one `RISK_FIXED` WTI backtest setfile only. It must not
create or modify a live setfile, `T_Live`, AutoTrading, deploy manifest,
T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-12 | initial source-backed WTI return-sign momentum build | Q02 | Q01 PASS; Q02 ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-12 | APPROVED under OWNER commodity-sleeve mission | this card |
| Q01 Build Validation | 2026-07-12 | PASS | `artifacts/qm5_13150_build_result.json` |
| Q02 Baseline Screening | 2026-07-12 | ENQUEUED | work item `a88b8890-3cb2-4ec7-bff0-bc72325057dd` |
