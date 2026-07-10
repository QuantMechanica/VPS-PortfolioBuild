---
strategy_id: BIANCHI-MOMREV-2015_XTI_XNG_S01
source_id: BIANCHI-MOMREV-2015
ea_id: QM5_13120
slug: energy-momrev
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Bianchi, Drew, and Fan (2015), Combining Momentum with Reversal in Commodity Futures, Journal of Banking & Finance 59, 423-444, DOI 10.1016/j.jbankfin.2015.07.006."
source_citations:
  - type: peer_reviewed_paper
    citation: "Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015). Combining Momentum with Reversal in Commodity Futures. Journal of Banking & Finance 59, 423-444."
    location: "Sections 3.2 and 4.2-4.7; Tables 4-6 and 10-11; DOI https://doi.org/10.1016/j.jbankfin.2015.07.006; accepted manuscript https://research-repository.griffith.edu.au/server/api/core/bitstreams/a06d0c4b-7648-4269-a5d7-0b1f2e4e065a/content"
    quality_tier: A
    role: primary
sources:
  - "[[sources/BIANCHI-MOMREV-2015]]"
concepts:
  - "[[concepts/commodity-momentum-reversal]]"
  - "[[concepts/energy-relative-value]]"
  - "[[concepts/cross-sectional-momentum]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [cross-sectional-rank, momentum, reversal, market-neutral-basket, monthly-rebalance, symmetric-long-short, atr-hard-stop]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [commodities, energy, crude_oil, natural_gas]
single_symbol_only: false
logical_symbol: QM5_13120_ENERGY_MOMREV_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 5-9 eligible monthly packages/year after warm-up; Q02 retires the carrier below five completed packages/year."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.05
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds a monthly energy momentum-reversal interaction package; realized orthogonality to the XAU/SP500/NDX/XNG book remains unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, narrow_cross_section]
g0_approval_reasoning: "Mission-directed G0 2026-07-10: R1 peer-reviewed JBF DOI/full institutional manuscript with explicit crude-oil and natural-gas contracts; R2 locked synchronized 12/18-month opposite-rank gate; R3 native registered XTI/XNG D1; R4 no ML/banned/external/grid/martingale; exact pre-allocation dedup CLEAN."
---

# XTI/XNG Momentum-Reversal Double Sort

## Hypothesis

Medium-horizon commodity winners can retain momentum, while a longer horizon
captures overreaction and reversal. The source combines both states rather
than trading either alone: buy a recent winner only when it is also a
long-horizon loser, and short a recent loser only when it is a long-horizon
winner. Opposite directions and equal fixed-risk allocation make this an
energy relative-value package, not a directional XTI or XNG trend port.

Market neutrality here means a simultaneous long/short package. It does not
guarantee dollar, beta, volatility, or factor neutrality. Q09 alone may judge
correlation to the certified book.

## Source And Evidence Boundary

Bianchi, Drew, and Fan (2015), *Journal of Banking & Finance* 59, use 27 S&P
commodity futures plus an independent 26-contract Dow Jones-UBS dataset. The
complete accepted manuscript was read. Its preferred double sort ranks past
12-month momentum first and past 18-month reversal second, uses no skipped
month, and holds one month.

The authors conclude that the strategy "jointly exploits momentum and reversal
signals cross-sectionally" and say it "has the potential to reduce overall
risk." These are bounded source claims about a diversified futures portfolio,
not performance claims for this two-CFD carrier.

## Concept And Non-Duplicate Decision

At the first tradable D1 bar of each broker month, compute synchronized log
returns from completed month-end closes for both energy legs:

- `mom_XTI`, `mom_XNG`: prior 12 completed months.
- `rev_XTI`, `rev_XNG`: prior 18 completed months.
- If `mom_XTI > mom_XNG` and `rev_XTI < rev_XNG`, buy XTI and sell XNG.
- If `mom_XTI < mom_XNG` and `rev_XTI > rev_XNG`, sell XTI and buy XNG.
- If both horizons agree, either comparison ties, or an endpoint is invalid,
  remain flat for that month.

This is not the XAU 3-month/4-week confirmation filter in `QM5_12623`, raw
relative momentum in `QM5_12733`, return-spread reversion in `QM5_12840`,
carry in `QM5_13089`, momentum-IVol in `QM5_13113`, same-calendar seasonality
in `QM5_13115`, or skewness in `QM5_13118`. It also contains no RSI or
pullback logic from `QM5_12567`. Repository-wide pre-allocation search found
no 12/18 cross-sectional commodity momentum-contrarian implementation.

## Markets And Timeframe

- Logical basket: `QM5_13120_ENERGY_MOMREV_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Cadence: one decision at the first tradable D1 bar of each broker month.
- Expected density: approximately 5-9 eligible paired packages/year; Q02 must
  retire below five completed packages/year rather than loosen the gate.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across the two legs.
- Runtime data: native MT5 D1 closes, ATR, spread, broker calendar, and
  framework position state only.

## Rules

### Entry Rules

- Detect a broker-month transition on the XTI D1 host.
- Use the last completed D1 close strictly before the current month boundary.
- Use the last completed D1 closes strictly before the 12- and 18-month-back
  boundaries. Require each boundary close to be no more than ten calendar days
  before its boundary and require all endpoints to be ordered and positive.
- Compute log returns for both horizons and both symbols from synchronized
  calendar boundaries; no current-month price enters the signal.
- Require finite values and strict rank disagreement at the two horizons.
- Open both legs as one package, one long and one short, splitting the fixed
  risk budget equally and attaching a frozen per-leg `ATR(20) * 3.5` hard stop.
- Do not enter on same-rank states, ties, stale history, invalid ATR/volume,
  excessive spread, an existing package, or a month already attempted.

### Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month, then
  recompute and open a new package only if the opposite-rank gate is valid.
- Close both legs if the package exceeds `strategy_max_hold_days=35`.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten any unexpected magic, side, or package composition.
- Friday close is disabled to preserve the source's one-month holding period.

## Filters And Trade Management

- Exact host guard: XTIUSD.DWX, D1, magic slot 0.
- Parameter, history, endpoint freshness/order, arithmetic, ATR, volume-step,
  spread, and package checks fail closed.
- One package per month; no re-entry after a stop in the same month.
- No take-profit, trailing stop, break-even, partial close, scale-in, grid,
  martingale, pyramiding, banned indicator, external data, adaptive fit, or ML.
- Framework kill switch and news entry compliance remain authoritative.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_momentum_months` | 12 | [12] | source first-sort horizon |
| `strategy_reversal_months` | 18 | [18] | source second-sort horizon |
| `strategy_history_bars` | 520 | [450, 520, 600] | bounded D1 endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | [7, 10] | fail-closed month-end freshness |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 12/18 completed-month horizons, overlapping returns, opposite-rank gate,
one-month hold, two-leg carrier, and no same-month re-entry are locked.
Changing a horizon, adding a skip month, trading an agreeing rank, adding a
magnitude threshold, or using a standalone time-series direction requires a
new card.

## Risk

### Initial Risk Profile And Kill Criteria

- `expected_pf: 1.05` is a conservative queue prior, not source evidence.
- `expected_dd_pct: 30.0` reflects XNG gaps, legging, rank sparsity, and the
  loss of broad cross-sectional diversification. Risk class is high.
- Retire at Q02 below five completed packages/year, on zero trades, invalid
  endpoint reconstruction, non-deterministic reruns, orphan packages, repeated
  initialization failure, or risk-mode mismatch.
- Do not shorten horizons, relax the opposite-rank gate, add a directional
  filter, or widen the universe after a poor baseline.
- Treat two-leg narrowing and futures/CFD basis mismatch as falsification
  risks, not waiver grounds.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed Journal of Banking & Finance paper, DOI, and
  complete institutional accepted manuscript.
- [x] R2 mechanical: fixed synchronized 12/18 completed-month ranks, monthly
  decision/exit, paired orders, and ATR hard stops.
- [x] R3 testable: registered XTIUSD.DWX and XNGUSD.DWX D1 history.
- [x] R4 compliant: no banned indicator, ML, external feed, adaptive fit,
  grid, martingale, or pyramiding.
- [x] Expected density is at or above the Q02 floor with a hard retirement rule.
- [x] Exact dedup was clean before atomic EA-ID allocation.

## Framework Alignment And Implementation Notes

- no_trade: exact host/slot, parameter domain, monthly-attempt, synchronized
  endpoint, freshness/order, spread, ATR, and package guards.
- trade_entry: source-defined 12-month winner/18-month loser paired against
  the 12-month loser/18-month winner; equal fixed risk and ATR stops.
- trade_management: next-month rollover, 35-day stale close, side/orphan repair.
- trade_close: framework close helper plus broker stops.
- estimated_complexity: medium.
- estimated_test_runtime: one logical XTI/XNG D1 Q02 baseline.
- data_requirements: standard native DWX D1 history only.

Risks at the hard-rule boundary are basket execution, the documented Friday
close exception, fixed-risk setfile enforcement, magic slots, futures-to-CFD
basis, and the narrow cross-section. No source performance or correlation is
imported. No T_Live, AutoTrading setting, live setfile, deploy manifest,
portfolio gate, portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-07-10 | initial build | Q02 | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED | this card |
| P1 Build Validation | 2026-07-10 | IN_PROGRESS | pending strict build evidence |
| P2 Baseline Screening | 2026-07-10 | QUEUED | pending Q02 worker |
