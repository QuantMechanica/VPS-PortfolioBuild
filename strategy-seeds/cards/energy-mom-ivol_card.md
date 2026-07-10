---
ea_id: QM5_13113
slug: energy-mom-ivol
type: strategy
strategy_id: FUERTES-MOMIVOL-2015_XTI_XNG_S01
source_id: FUERTES-MOMIVOL-2015
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Fuertes, Miffre, and Fernandez-Perez (2015), Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility, Journal of Futures Markets 35(3), 274-297."
source_citations:
  - type: paper
    citation: "Fuertes, Ana-Maria; Miffre, Joelle; and Fernandez-Perez, Adrian (2015). Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility. Journal of Futures Markets 35(3), 274-297."
    location: "Complete open accepted manuscript; especially Sections 3.1-4.1 and 5.1, Table 7 p.34, Appendix A p.40; DOI https://doi.org/10.1002/fut.21656; https://openaccess.city.ac.uk/id/eprint/6418/1/JFM_SSRN_13Jan2014.pdf"
    quality_tier: A
    role: primary
strategy_type_flags: [market-neutral-basket, momentum, vol-regime-gate, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
factor_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13113_ENERGY_MOM_IVOL_D1
period: D1
expected_trade_frequency: "Monthly XTI/XNG two-leg packages only when the 3-month momentum winner is also the lower-IVol energy leg; estimate 6-10 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds a market-neutral cross-energy momentum/IVol risk premium to an XAU/SP500/NDX/XNG book; it is neither an outright index/metal signal nor another commodity RSI pullback. Q09 alone may establish realized orthogonality."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis]
g0_approval_reasoning: "OWNER mission-directed approval on 2026-07-10: R1 PASS peer-reviewed full open paper; R2 PASS deterministic 3-month momentum plus rolling OLS residual-volatility rank agreement, monthly rebalance, ATR stops, and stale close; R3 PASS four DWX commodity factor members and both traded energy legs are registered; R4 PASS native OHLC only, no ML, external feed, grid, or martingale. Repository dedup was CLEAN before allocation."
---

# Energy Momentum–Idiosyncratic-Volatility Double Screen

## Hypothesis

Commodity momentum and idiosyncratic volatility are distinct return signals.
The source's double-screen evidence says a long-short allocation is stronger
when it combines them than when it uses either signal alone. This card tests a
bounded market-neutral energy carrier: buy the XTI/XNG momentum winner only if
it is also the lower residual-volatility leg, short the other leg, and remain
flat when the two rankings disagree.

The economic exposure is relative WTI-versus-natural-gas selection rather than
an outright metal/index beta. The common factor removes part of broad commodity
movement before the volatility rank is formed. Portfolio correlation is not
assumed; only Q09 can measure it after a surviving return stream exists.

## Source

Fuertes, Miffre, and Fernandez-Perez (2015), *Journal of Futures Markets*
35(3), 274-297, DOI `10.1002/fut.21656`. The complete open accepted manuscript
is stored by City Research Online.

The paper specifies:

- rolling OLS residual standard deviation as the IVol signal;
- 1, 3, 6, and 12-month ranking windows;
- monthly portfolio formation and one-month holding periods;
- combined scores that reward high momentum and low IVol;
- a momentum-IVol double-screen robustness portfolio;
- a sensitivity case with one top and one bottom commodity.

The bounded author claim retained here is: "the three signals are non-overlapping."
No paper return, Sharpe ratio, drawdown, or constituent frequency is imported as
a QM gate or forecast.

## Concept And Translation Boundary

The source uses 27 exchange futures and prefers S&P-GSCI as the common factor.
The EA cannot reproduce that universe or its futures rolls. It uses the
source-tested equal-weight benchmark alternative constructed from four native
DWX commodity returns: XTI, XNG, XAU, and XAG. Only XTI and XNG are traded; XAU
and XAG are read-only factor members.

At each monthly rebalance, both energy legs receive:

- a momentum rank from their completed 63-D1 log return; and
- an IVol rank from the residual standard deviation of a 63-D1 OLS regression
  on the equal-weight four-commodity factor.

The higher-momentum leg must also have lower IVol. Rank conflict means flat.
This is a strict two-signal agreement rule, not an optimized weighted score.

## Markets And Timeframes

- Logical symbol: `QM5_13113_ENERGY_MOM_IVOL_D1`.
- Host: `XTIUSD.DWX`, D1, magic slot 0.
- Traded hedge leg: `XNGUSD.DWX`, magic slot 1.
- Read-only factor members: `XAUUSD.DWX`, `XAGUSD.DWX`.
- Expected density: 6-10 completed two-leg packages/year before Q02.
- Backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Rules

### Monthly Signal

- Evaluate once on the first available D1 bar of each broker-calendar month.
- Load 64 completed D1 closes for all four factor members.
- For each of the latest 63 return observations, compute four log returns and
  their equal-weight mean as the common commodity-factor return.
- For XTI and XNG separately, fit `return = alpha + beta * factor + residual`
  by closed-window OLS and set IVol to sample standard deviation of residuals.
- Compute each energy leg's 63-D1 log return.
- If XTI return is higher and XTI IVol is lower, target long XTI / short XNG.
- If XNG return is higher and XNG IVol is lower, target short XTI / long XNG.
- If either rank ties or the momentum and IVol rankings conflict, target flat.

## 4. Entry Rules

- Exact host guard: `XTIUSD.DWX`, D1, magic slot 0.
- Enter only on a new monthly key after the prior package has been flattened.
- Require all four factor histories, OLS variance, residual degrees of freedom,
  both ATR values, spreads, prices, volume metadata, and magics to be valid.
- Open both legs as one package with equal fixed-risk weights.
- A failed second leg immediately flattens any orphaned first leg.
- No second package during the same month.

## 5. Exit Rules

- At the next monthly rebalance, close both legs before evaluating the new
  target, including when the direction would remain unchanged.
- Close both legs after `strategy_max_hold_days=35` as a stale safeguard.
- Immediately flatten an orphan package or a package whose XTI leg has an
  unknown side.
- Each leg carries a broker-side ATR(20) times 3.0 hard stop.
- Friday close is disabled because the approved source holds the market-neutral
  allocation for one month; weekly flattening would replace the source horizon.

## 6. Filters (No-Trade Module)

- Fail closed on wrong symbol, timeframe, or magic slot.
- Fail closed on invalid parameter domains, missing history, zero factor
  variance, invalid OLS residuals, invalid ATR/price/volume metadata, or spread
  above the per-leg cap.
- Standard kill-switch and connection protections remain active.
- Q02 news axes are explicitly off in the backtest setfile; later news phases
  remain framework-controlled.

## 7. Trade Management Rules

- Exactly two traded legs, equally split fixed-risk budget.
- XAU and XAG are never ordered and have no magic rows for this EA.
- No pyramiding, grid, martingale, trailing stop, break-even move, partial
  close, or discretionary override.
- A broken package is flattened rather than repaired into directional exposure.

## Parameters To Test

- name: strategy_signal_lookback_d1
  default: 63
  sweep_range: [21, 63, 126, 252]
  source_basis: "The paper's R = 1, 3, 6, or 12 month ranking windows; 63 D1 bars is the locked Q02 baseline because Table 7 reports the strongest momentum-IVol double-screen risk-adjusted result at R=3."
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 35
  sweep_range: [28, 35, 42]
- name: strategy_xti_max_spread_pts
  default: 1500
  sweep_range: [1000, 1500, 2000]
- name: strategy_xng_max_spread_pts
  default: 3000
  sweep_range: [2000, 3000, 4000]

The equal-weight factor, XTI/XNG traded pair, rank-agreement rule, monthly
rebalance, and absence of a term-structure input are locked. They are not sweep
axes.

## Author Claims

The source reports that momentum and IVol contain sufficiently distinct
information to improve combined long-short commodity portfolios and that the
double screens outperform the individual signals in its futures sample. It
does not validate this four-proxy factor, two-energy CFD carrier, Darwinex
spread model, V5 risk split, or 2017+ test window.

## Initial Risk Profile

- `expected_pf: 1.08` is a queue-ordering prior, not evidence.
- `expected_dd_pct: 18.0` is a risk prior, not a forecast.
- `expected_trade_frequency: 6-10 packages/year` must clear the binding Q02
  minimum of five completed trades/year.
- `risk_class: medium-high` due to two-leg execution, factor translation, and
  potential energy-regime divergence.
- `ml_required: false`.

## Strategy Allowability Check

- [x] Structural commodity risk-premium thesis with deterministic rules.
- [x] Peer-reviewed primary source and complete open manuscript.
- [x] No ML, banned indicator, external runtime feed, futures curve, API, CSV,
  grid, martingale, or pyramiding.
- [x] D1/monthly, expected above the five-trades/year Q02 floor.
- [x] Backtests use `RISK_FIXED`; no live setfile is created.
- [x] Non-duplicate versus XTI/XNG relative momentum, ratio reversion,
  return-spread reversion, volatility-compression breakout, carry ranking, and
  fixed seasonal switching because this package requires independent momentum
  and rolling residual-volatility ranks to agree.

## Framework Alignment

- no_trade: exact host/slot, parameter, history, factor-variance, residual,
  spread, ATR, price, lot, and monthly de-duplication guards.
- trade_entry: monthly two-score agreement; open equal-risk XTI/XNG package.
- trade_management: monthly package reset, stale exit, and orphan cleanup.
- trade_close: per-leg ATR hard stops and deterministic package flattening.

Friday-close exception: `qm_friday_close_enabled=false` is intentional and
card-authorized because the source's holding period is one month and the
exposure is a two-leg relative-value package. Q02 must reject the edge if
weekend gaps make the economics unacceptable.

## Risk

This card is a carrier test, not a paper replication. Q02 falsifies it if
density is below five completed packages/year, either leg cannot be valued,
the logical-basket report is invalid, or economics/drawdown fail. Q09 alone may
establish portfolio correlation.

No live setfile, deploy manifest, portfolio gate, portfolio admission file,
`T_Live` path, or AutoTrading setting is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial energy momentum-IVol double-screen | Q02 | PLANNED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PENDING | `artifacts/qm5_13113_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | PENDING | enqueue evidence TBD |

