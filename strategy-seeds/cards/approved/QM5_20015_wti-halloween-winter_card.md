---
ea_id: QM5_20015
slug: wti-halloween-winter
type: strategy
strategy_id: BURAKOV-WTI-HALLOWEEN-2018_S01
source_id: BURAKOV-WTI-HALLOWEEN-2018
status: APPROVED
created: 2026-07-20
created_by: Research
last_updated: 2026-07-20
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: R1 tier-B complete peer-reviewed source; R2 deterministic WTI November-May long regime with disclosed monthly renewal and V5 risk; R3 registered XTI D1 route; R4 structural calendar/ATR only, no ML or banned indicator; exact WTI mechanic audit CLEAN."
source_citation: "Burakov, D., Freidin, M. and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy, 8(2), 121-126."
source_citations:
  - type: academic_paper
    citation: "Burakov, Dmitry, Max Freidin and Yuriy Solovyev (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Section 3 alternative-two definition; Tables 2-3 West Texas row; official article https://www.econjournals.com/index.php/ijeep/article/view/6092; complete text https://www.econjournals.com/index.php/ijeep/article/download/6092/3608/15549"
    quality_tier: B
    role: primary
sources:
  - "[[sources/BURAKOV-WTI-HALLOWEEN-2018]]"
concepts:
  - "[[concepts/energy-calendar-seasonality]]"
  - "[[concepts/halloween-effect]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, monthly-renewal, long-only, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
expected_trade_frequency: "Seven long WTI monthly packages/year, one at each November-May month boundary; Q02 must verify at least five completed packages/year after execution gates."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.02
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify the source-defined WTI November-May direction after monthly fixed-risk renewal, financing, gaps and CFD basis; realized book correlation is unproven."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, low_frequency, cfd_source_basis, portfolio_correlation]
---

# WTI November-May Winter-Season Sleeve

## Hypothesis

Burakov, Freidin and Solovyev report a statistically significant seasonal
return split in West Texas crude over 1985-2016. Under their alternative-two
calendar, the return from the last October close through the last May close
exceeded the May-October return in 23 of 32 years. A sparse long-only WTI
carrier can test whether that structural winter-season premium survives on the
Darwinex continuous CFD after explicit costs and fixed-risk controls.

This card is a diversification candidate, not a correlation or certification
claim. Q02 and later portfolio analysis must measure its realized relationship
to XAU, SP500, NDX, XNG and the rest of the book. Nothing in this card changes
the portfolio gate.

## Source and interpretation boundary

The sole source lineage is the complete open 2018 article cited above. Section
3 defines alternative two as the last trading-day close of October through the
last trading-day close of May for winter, and end-May through end-October for
summer. Table 2 reports the West Texas winter average at `16.65%`, summer at
`-5.3%`, and winter superiority in `23/32` years (`72%`). Table 3 reports
`p=0.0096` for the t-test and `p=0.0031` for the preferred Wilcoxon test.

The duplicated month captions above Table 2 conflict with the methods prose.
This card locks the explicit algorithm and equations: long November through
May, flat June through October. It does not short the summer leg and does not
import the paper's historical returns as a Darwinex forecast.

The paper evaluates one continuous seasonal holding interval. The V5 carrier
closes and renews exposure at every month boundary inside November-May. That
monthly renewal is a predeclared implementation adaptation: it preserves the
source's direction and exposure window while creating seven non-overlapping,
fixed-risk packages with explicit financing/gap/cost realization. It is not
described as a source-authored result.

## Concept and non-duplicate decision

On the first tradable D1 bar of each broker-calendar month:

- if the month is November, December, January, February, March, April or May,
  close any prior-month package and open one new WTI long package;
- if the month is June through October, close any residual package and remain
  flat; and
- after a stop or failed order, do not retry inside that calendar month.

Repository-wide searches found no WTI implementation with this exact
November-May long / June-October flat regime and monthly renewal.

- `QM5_20008_wti-month-ch3` is a symmetric price-conditioned channel that may
  be long, short or flat in any month.
- `QM5_12726_wti-nov-fade` and adjacent month-specific WTI cards isolate a
  single month rather than the complete winter interval.
- `QM5_12813_eia-energy-switch` pairs summer oil with winter natural gas;
  this carrier is WTI-only and uses the paper's direct West Texas result.
- Equity-index Halloween EAs `QM5_1047`, `QM5_1080` and `QM5_1573` do not
  trade WTI and do not use this energy-market evidence.

The exact mechanic is new for WTI. A different underlying does not guarantee
decorrelation, so realized overlap remains a later kill test.

## Markets, timeframe and cadence

- Target: `XTIUSD.DWX`, magic slot 0 only.
- Host/signal timeframe: D1.
- Decision cadence: first D1 bar of each broker month.
- Expected frequency: seven completed long packages per full year.
- Expected hold: one broker month, with a 35-calendar-day stale guard.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: MT5 calendar, D1 ATR, spread, deal history and position state.

## Entry rules

- Consume only the first `XTIUSD.DWX` D1 bar of a new broker month.
- Require current month in `{11,12,1,2,3,4,5}`.
- Close any position opened in a previous month before considering renewal.
- Require no same-magic open position and no same-month entry deal.
- Require exact baseline parameters and spread no greater than 1500 points.
- Read completed-bar D1 `ATR(20)` and open BUY with a frozen
  `4.0 * ATR(20)` broker hard stop; no take-profit.
- Record the in-memory/month-history attempt boundary so a stop, rejected
  order or restart cannot create an extra package in the same month.
- News and framework kill-switch gates remain authoritative for new entries.

## Exit and management rules

- On the first D1 bar of the next broker month, close the old package before
  evaluating a new one.
- In November-May, a new monthly package may open only after the old package
  is fully absent; a failed close means fail closed for that boundary.
- In June-October, close any residual exposure and remain flat.
- Close any package at 35 calendar days if a month boundary is unavailable.
- The frozen broker hard stop remains active intramonth.
- No summer short, trailing stop, break-even, partial close, scale-in,
  pyramiding, grid, martingale or discretionary exit.

## Filters and state safety

- Exact host/timeframe/slot: `XTIUSD.DWX`, D1, slot 0.
- Strategy constants are locked to months 11 and 5, ATR 20, multiplier 4.0,
  stale guard 35 days and spread cap 1500 points.
- One position per registered magic and at most one entry package per broker
  month, including after restart.
- Zero modeled `.DWX` spread is valid; invalid/negative price, spread, ATR or
  stop arithmetic fails closed.
- Friday close is disabled because the source exposure spans weekends. The
  monthly boundary, hard stop and stale guard remain active.
- No external data, banned indicator, ML, adaptive parameter or PnL fit.

## Parameters to test

| parameter | default | authorized baseline | role |
|---|---:|---:|---|
| `strategy_first_long_month` | 11 | 11 | first month after the source's October boundary |
| `strategy_last_long_month` | 5 | 5 | final month ending at the source's May boundary |
| `strategy_atr_period` | 20 | 20 | completed D1 ATR hard-stop estimate |
| `strategy_atr_sl_mult` | 4.0 | 4.0 | frozen stop distance |
| `strategy_max_hold_days` | 35 | 35 | stale guard around monthly renewal |
| `strategy_max_spread_points` | 1500 | 1500 | WTI entry spread cap |

The calendar window, long-only direction, monthly renewal and no-retry rule
are locked. A summer short, continuous multi-month position, price/trend
filter or different seasonal boundary requires a new card.

## Initial risk profile and kill criteria

- `expected_pf: 1.02` is a conservative queue-order prior, not evidence.
- `expected_dd_pct: 30.0` reflects WTI gaps, leverage reset, financing and
  futures/CFD basis risk.
- Retire at Q02 for fewer than five completed packages/year, zero trades,
  invalid month logic, repeated initialization failure, risk-mode mismatch,
  nondeterminism or unacceptable PF/DD after realistic costs.
- Later gates must kill the sleeve if realized correlation does not add the
  requested commodity diversification. Correlation is never a G0 waiver.

## Strategy allowability check

- [x] R1 reputable: one peer-reviewed, named-author article with official page
  and complete open text; source statistics and inconsistencies disclosed.
- [x] R2 mechanical: fixed seasonal months, direction, renewal, ATR stop,
  spread cap, state guard and exits.
- [x] R3 testable: registered `XTIUSD.DWX` D1 route; no external runtime feed.
- [x] R4 compliant: deterministic calendar/ATR only; no ML, banned indicator,
  adaptive fit, grid, martingale, pyramiding or multi-position magic.
- [x] Exact WTI mechanic dedup search is clean; index Halloween and adjacent
  WTI designs are disclosed.

## Framework alignment

- no_trade: exact symbol/D1/slot and locked baseline parameters.
- trade_entry: first monthly D1 bar in November-May, same-month history guard,
  long market order and frozen ATR stop.
- trade_management: prior-month, out-of-season and 35-day stale closure before
  the entry-news gate.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` plus broker stop.

`hard_rules_at_risk`:

- `friday_close`: disabled for the source-aligned month-spanning exposure.
- `risk_mode_dual`: this build creates only a `RISK_FIXED` backtest setfile.
- `low_frequency`: seven packages/year is a prior; Q02 must prove at least five.
- `cfd_source_basis`: the paper's IMF West Texas series is not assumed equal
  to the Darwinex continuous CFD.
- `portfolio_correlation`: diversification is an objective to test, not a
  claim and not authorization to alter the portfolio gate.

## Risk and safety boundary

The build may create one `RISK_FIXED` WTI backtest setfile only. It must not
create or modify a live setfile, T_Live, AutoTrading, deploy/T_Live manifest,
portfolio admission or the portfolio gate.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-20 | initial source-backed WTI winter-season build | Q01 | pending |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-20 | APPROVED under OWNER commodity-sleeve mission | this card |
| Q01 Build Validation | 2026-07-20 | pending | compile/build evidence pending |
| Q02 Baseline Screening | 2026-07-20 | not enqueued | build record pending |
