---
strategy_id: FUERTES-MOMIVOL-2015_XTI_XNG_S02
source_id: FUERTES-MOMIVOL-2015
ea_id: QM5_13133
slug: energy-ivol
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citation: "Fuertes, Miffre, and Fernandez-Perez (2015), Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility, Journal of Futures Markets 35(3), 274-297."
source_citations:
  - type: peer_reviewed_paper
    citation: "Fuertes, Ana-Maria; Miffre, Joelle; and Fernandez-Perez, Adrian (2015). Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility. Journal of Futures Markets 35(3), 274-297."
    location: "Complete open accepted manuscript; Sections 2-6, especially equation (1) and Sections 3.1-3.2 pp. 6-10, Tables 1-3 pp. 28-30, Table 6 p. 33, Table 9 p. 36, and Appendices A-B pp. 40-41; DOI https://doi.org/10.1002/fut.21656; https://openaccess.city.ac.uk/id/eprint/6418/1/JFM_SSRN_13Jan2014.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/FUERTES-MOMIVOL-2015]]"
concepts:
  - "[[concepts/idiosyncratic-volatility]]"
  - "[[concepts/energy-relative-value]]"
  - "[[concepts/commodity-factor-residual]]"
indicators:
  - "[[indicators/ols-residual-volatility]]"
  - "[[indicators/equal-weight-commodity-factor]]"
  - "[[indicators/atr]]"
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop, signal-reversal-exit]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
factor_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, energy, crude_oil, natural_gas]
single_symbol_only: false
logical_symbol: QM5_13133_XTI_XNG_IVOL_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "One monthly XTI/XNG package after the 253-close warm-up; approximately 12 completed packages/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.03
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Source-specified pure commodity IVol translated to an equal-notional XTI/XNG package; Q02 must falsify the narrow carrier and Q09 alone may establish realized decorrelation from XAU/SP500/NDX/XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, narrow_cross_section]
g0_approval_reasoning: "OWNER mission 2026-07-11: R1 peer-reviewed Journal of Futures Markets source and complete open manuscript read end-to-end; R2 locked 12-month OLS residual-volatility rank, monthly lifecycle, equal-notional paired sizing, ATR stops, and restart-safe attempt guard; R3 native registered XTI/XNG/XAU/XAG D1 inputs; R4 no ML, banned indicator, external runtime feed, grid, martingale, or pyramiding; manual repository dedup CLEAN before atomic CEO+CTO allocation."
---

# XTI/XNG Pure Idiosyncratic-Volatility Spread

## Hypothesis

Commodity-specific risk that is not explained by a broad commodity factor can
carry a cross-sectional premium. The source's standalone IVol rule buys low
residual-volatility commodities and sells high residual-volatility commodities.
This card tests a bounded energy carrier: buy the lower-IVol XTI/XNG leg and
short the higher-IVol leg, sized toward equal dollar notional.

The opposite energy positions are intended to reduce common commodity
direction, but neither neutrality nor portfolio decorrelation is assumed. Q02
tests whether the two-CFD package trades and has acceptable economics; Q09 alone
may establish correlation to the certified XAU/SP500/NDX/XNG book.

## Source And Evidence Boundary

The primary source is Fuertes, Miffre, and Fernandez-Perez (2015), *Journal of
Futures Markets* 35(3), 274-297, DOI `10.1002/fut.21656`. The complete
42-page open accepted manuscript was read end-to-end, including the data,
individual and combined strategy definitions, robustness analysis, references,
tables, figures, and both appendices.

The paper studies 27 commodity futures, explicitly including light sweet crude
oil and natural gas. It estimates rolling OLS residual volatility, ranks the
cross-section monthly, buys the lowest IVol quintile, and shorts the highest
IVol quintile for one month. It tests 1-, 3-, 6-, and 12-month windows and an
equal-weight commodity factor as a traditional benchmark alternative. No paper
performance value is imported into the QM gate or forecast.

## Concept And Non-Duplicate Decision

On the first tradable XTI D1 bar of each broker month:

1. Load 253 synchronized completed D1 closes for XTI, XNG, XAU, and XAG.
2. Form 252 log returns and their equal-weight commodity-factor return.
3. Regress XTI and XNG returns separately on an intercept and that factor.
4. Rank the OLS residual standard deviations.
5. Buy the lower-IVol energy leg and short the higher-IVol leg.
6. Translate the fixed package risk budget through per-leg ATR stops so the
   intended dollar notionals are equal; reject excessive rounding mismatch.
7. Close and renew at the next broker-month transition.

This is mechanically distinct from:

- `QM5_13113_energy-mom-ivol`, which uses a 63-D1 momentum-plus-IVol agreement
  rule and stays flat on rank conflict; this card has no momentum input;
- `QM5_12404_stock-lowvol`, a long-only total-volatility rank over a mixed
  index/metal/oil universe;
- `QM5_12530_chan-xsec-lowvol`, a short-horizon contrarian score filtered by
  total close dispersion over an FX/index/metal universe;
- XTI/XNG ratio or residual-spread reversion, carry, trend, calendar,
  volatility-breakout, skew, kurtosis, MAX, BAB, RSJ, and momentum baskets; and
- `QM5_12567_cum-rsi2-commodity`, which buys oscillator pullbacks and contains
  no cross-sectional residual-volatility rank.

The source itself distinguishes total volatility from IVol: residual standard
deviation after factor removal is the signal here. The shared source and factor
estimator with `QM5_13113` are lineage, not duplicate mechanics; standalone
IVol and momentum-IVol double screening are separately specified strategies.

## Markets And Timeframe

- Logical basket: `QM5_13133_XTI_XNG_IVOL_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Read-only factor members: `XAUUSD.DWX`, `XAGUSD.DWX`, D1.
- Formation: 252 completed D1 log returns.
- Signal cadence: first tradable D1 bar of each broker month.
- Expected density: approximately 12 completed packages/year after warm-up;
  retire below five completed packages/year.
- Runtime data: native MT5 D1 closes, ATR, spread, contract metadata, broker
  calendar, framework position/deal state, and no external source.

## Rules

The locked rule is monthly low-IVol-long/high-IVol-short selection based on
rolling OLS residual standard deviation against a four-proxy equal-weight
commodity factor. Detailed entry, exit, filter, and management rules follow.

## 4. Entry Rules

- Evaluate only on the first XTI D1 bar whose broker-month key differs from the
  preceding D1 bar.
- Require 253 synchronized completed D1 closes for XTI, XNG, XAU, and XAG.
- Reject nonpositive prices, incomplete history, nonfinite arithmetic, or a
  commodity-factor sample variance at or below zero.
- Compute 252 log returns for each factor member and set each observation's
  factor return to the equal-weight mean of the four returns.
- For XTI and XNG separately, fit
  `return = alpha + beta * factor_return + residual` by OLS.
- Set IVol to `sqrt(sum(residual^2) / (252 - 2))`.
- Buy the leg with lower IVol and sell the leg with higher IVol; reject an exact
  numerical tie rather than inventing a direction.
- Attach a frozen `ATR(20) * 3.0` hard stop to both legs; no take-profit.
- For each leg compute relative stop distance `ATR * 3.0 / entry_price`. Split
  the fixed package stop-risk budget in proportion to those relative stop
  distances, which targets equal pre-rounding dollar notionals.
- After broker volume-step rounding, estimate each leg's dollar-notional proxy
  from tick size/value and reject entry if relative mismatch exceeds 20%.
- Require both spreads, prices, ATRs, volume metadata, magics, and news checks
  to pass. A failed second order immediately flattens the first leg.
- Current positions and current-month entry-deal history enforce at most one
  package attempt per broker month, including across EA restarts and stop-outs.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after 35 calendar days as a stale-package guard.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source's monthly hold.

## 6. Filters (No-Trade Module)

- Exact host guard: XTIUSD.DWX, D1, magic slot 0.
- Locked 252-return formation, four-symbol equal-weight benchmark, low/high IVol
  direction, monthly lifecycle, and one-attempt-per-month rule.
- Parameter, history, price, covariance, OLS, residual, ATR, spread, tick-value,
  volume-step, notional-mismatch, magic, and package checks fail closed.
- Framework kill switch remains authoritative; two-axis news compliance gates
  entries only, never package management or exits.

## 7. Trade Management Rules

- A valid package contains exactly one XTI leg and one XNG leg, with opposite
  directions and this EA's registered magics.
- Close both legs on a new broker month, after 35 days, or whenever package
  composition becomes invalid.
- Do not repair an orphan into temporary directional exposure.
- No TP, trailing stop, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external data, adaptive fit, banned indicator, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_ivol_lookback_d1` | 252 | [21, 63, 126, 252] | source 1/3/6/12-month IVol windows; 12-month baseline |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg hard-stop ATR |
| `strategy_atr_sl_mult` | 3.0 | [2.5, 3.0, 4.0] | frozen stop distance |
| `strategy_max_notional_mismatch_pct` | 20.0 | [10.0, 20.0, 30.0] | post-rounding neutrality guard |
| `strategy_max_hold_days` | 35 | [35] | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The four-symbol equal-weight factor, OLS residual-standard-deviation signal,
low-IVol-long/high-IVol-short direction, equal-notional target, monthly renewal,
paired carrier, and no same-month re-entry are locked. Changing them requires a
new card and full pipeline run.

## Author Claim

The source says the IVol strategy "buys (sells) the assets with the lowest
(highest) IVol signal" (accepted manuscript, p. 6). No performance statistic is
imported.

## Initial Risk Profile And Kill Criteria

- `expected_pf: 1.03` is only a conservative queue-ordering prior.
- `expected_dd_pct: 25.0` reflects XNG gaps, legging, factor translation,
  monthly stale exposure, and a two-contract cross-section.
- Fail Q02 on fewer than five completed packages/year, zero trades, invalid
  logical-basket accounting, persistent notional mismatch, nondeterminism,
  orphan persistence, or risk-mode mismatch.
- Do not add momentum confirmation, shorten the lookback after a poor result,
  replace the factor with the XTI/XNG ratio, relax the neutrality guard, or add
  a directional overlay to rescue baseline economics.
- Treat the 27-future-to-four-factor/two-traded-CFD narrowing, equal-weight
  benchmark substitution, continuous-CFD roll/financing behavior, and volume
  rounding as falsification risks, not waiver grounds.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed Journal of Futures Markets paper, DOI, and
  complete university-hosted accepted manuscript.
- [x] R2 mechanical: fixed OLS estimator, residual-volatility rank, direction,
  sizing, stops, mismatch guard, and monthly lifecycle.
- [x] R3 testable: registered XTIUSD.DWX and XNGUSD.DWX traded history plus
  registered XAUUSD.DWX/XAGUSD.DWX native read-only factor history.
- [x] R4 compliant: no banned indicator, ML, external feed, grid, martingale,
  or pyramiding.
- [x] Source-aligned monthly density exceeds the five-trade Q02 floor.
- [x] Repository dedup was clean after manual review before ID allocation.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical-basket
setfile. The fixed package stop-risk budget is divided to target equal dollar
notionals, subject to broker rounding and a 20% mismatch ceiling. No live
setfile, T_Live change, AutoTrading action, deploy manifest, portfolio gate, or
admission artifact is authorized.

## Framework Alignment

- no_trade: exact host/slot, locked estimator, synchronized bounded history,
  factor variance, OLS residual, spread, ATR, tick-value, broker volume,
  notional mismatch, current-month attempt, and package guards.
- trade_entry: monthly pure-IVol rank, equal-notional risk translation, paired
  orders, and frozen hard stops.
- trade_management: broker-month reset, 35-day stale close, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

## Hard Rules At Risk

- `friday_close`: disabled only because forced weekly flattening conflicts with
  the source's one-month long-short hold; any later live use needs re-review.
- `risk_mode_dual`: Q02 uses only RISK_FIXED; no live setfile exists.
- `magic_schema`: two registered traded slots are required for one logical
  package; read-only factor members receive no magic.
- `dwx_suffix_discipline`: all runtime symbols retain `.DWX`.
- `enhancement_doctrine`: any factor, estimator, formation window, direction,
  or sizing change is a new entry hypothesis and invalidates prior evidence.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial source-backed pure energy IVol build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-11 | PASS | `artifacts/qm5_13133_build_result.json` |
| Q02 Baseline Screening | 2026-07-11 | ENQUEUED; pending and unclaimed | work item `964d9d79-f9a6-40f8-9027-0efc7b01a394` |

## Lessons Captured

- 2026-07-11: Standalone IVol is a source-specified signal distinct from the
  existing momentum-IVol double screen; the narrow energy carrier remains a
  strict out-of-sample translation test.
