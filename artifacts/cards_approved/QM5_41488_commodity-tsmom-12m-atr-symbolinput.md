---
ea_id: QM5_41488
slug: commodity-tsmom-12m-atr-symbolinput
parent_ea_id: QM5_12710
lineage: symbol_input_rebuild
type: strategy
source_id: MOP-TSMOM-2012
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. Time Series Momentum. Journal of Financial Economics, 2012. URL https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum"
source_citations:
  - type: paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics."
    location: "AQR/JFE public paper page"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MOP-TSMOM-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/commodity-trend-premium]]"
  - "[[concepts/volatility-gated-trend]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [intermediate-trend, monthly-rebalance, volatility-filter, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly WTI 12-month time-series-momentum package with an ATR% participation gate; estimate 5-9 entries/year after the volatility corridor filters out dormant and shock regimes."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-09-22
g0_approval_reasoning: "Fable 2026-09-22 symbol-input rebuild of QM5_12710 (OWNER symbols-are-inputs rule 2026-09-06; Codex 273f2de8 identity proof EQUIVALENT_EXACT 95/95 deals): mechanics, source lineage and R1-R4 verdicts inherited unchanged from the parent card of record; only the identity and the strategy_host_symbol t"
expected_pf: 1.08
expected_dd_pct: 18.0
card_sha256: e701a223f0bedb4afaa4b4428236a88b811c1cdab64fecd759d01b8feece00aa
---

# WTI 12-Month TSMOM ATR Gate

## Source

- Source: [[sources/MOP-TSMOM-2012]]
- Primary citation: Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H.,
  "Time Series Momentum", Journal of Financial Economics, 2012, URL
  https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

## Concept

Time-series-momentum research documents that an asset's own past return can
forecast its next-period directional tendency across futures markets, including
commodities. This card ports the structural premise to the DWX-tradable WTI CFD
using a 12-month trend horizon, but only participates when current D1 ATR as a
percent of price sits inside a fixed corridor. The goal is to keep the trend
signal out of dormant tape and extreme shock tape without adding external data.

This is deliberately different from:

- `QM5_12603_wti-tsmom12m`: this card is not pure 12-month return sign; it
  requires the ATR% volatility corridor before entry.
- `QM5_12616_tsmom-9m-commodity-xtiusd`: no 9-month primary signal or 3-month
  same-sign confirmation filter.
- `QM5_12708_commodity-tsmom-6m`: no six-month trend horizon.
- `QM5_12711_commodity-tsmom-dual-6-12`: no dual-horizon agreement rule.
- `QM5_12594_yang-wti-reversal` and `QM5_12621_comm-reversal-4wk-xtiusd`: this
  follows intermediate WTI trend rather than fading return extremes.
- WTI calendar/event sleeves: no weekday, month-of-year, WPSR, hurricane,
  refinery, OPEC, expiry, ETF-roll, or SPR trigger.
- XNG natural-gas sleeves and XTI/XNG ratio sleeves: this is single-symbol WTI
  oil exposure, not natural gas or an energy basket.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or short-horizon pullback
  logic.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 5-9 entries/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 D1 OHLC and broker calendar only; no futures
  curve, inventory feed, CFTC data, EIA feed, CSV, API, analyst forecast, or
  ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar month.
- Compute the prior closed D1 close and the close
  `strategy_momentum_lookback_d1` completed bars earlier.
- Compute `momentum = ln(close_recent / close_past)`.
- Compute ATR(`strategy_atr_period`) as a percent of the prior completed D1
  close.
- Long package: BUY `XTIUSD.DWX` if momentum is greater than
  `strategy_min_abs_return_pct / 100` and ATR% is between
  `strategy_min_atr_pct` and `strategy_max_atr_pct`.
- Short package: SELL `XTIUSD.DWX` if momentum is less than
  `-strategy_min_abs_return_pct / 100` and ATR% is between the same fixed
  corridor.
- No entry if the return is inside the neutral band, ATR% is outside the
  corridor, or an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit any open package on the next monthly rebalance bar before considering a
  fresh package for that month.
- Exit any stale package after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when D1 history is shorter than `strategy_momentum_lookback_d1`
  plus warmup bars.
- Skip entries when ATR or close data is unavailable.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_momentum_lookback_d1
  default: 252
  sweep_range: [210, 252, 294]
- name: strategy_min_abs_return_pct
  default: 1.0
  sweep_range: [0.5, 1.0, 2.0, 3.5]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.5
  sweep_range: [2.5, 3.5, 4.5]
- name: strategy_min_atr_pct
  default: 0.75
  sweep_range: [0.5, 0.75, 1.0]
- name: strategy_max_atr_pct
  default: 7.5
  sweep_range: [5.0, 7.5, 10.0]
- name: strategy_max_hold_days
  default: 31
  sweep_range: [21, 31, 45]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No source performance number is imported into QM. The source is used only for
structural lineage around time-series momentum across futures and commodity
markets. The Q02+ pipeline tests the mechanical WTI port on Darwinex
`XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 18
- expected_trade_frequency: approximately 5-9 entries/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: published Journal of Financial Economics/AQR paper
  page with single-source lineage.
- [x] R2 mechanical: fixed monthly rebalance, one fixed return lookback, fixed
  ATR% volatility corridor, ATR hard stop, and deterministic time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: volatility-gated 12-month WTI trend, not pure 12-month
  WTI TSMOM, 9-month/3-month confirmed TSMOM, pure 6-month TSMOM, dual-horizon
  TSMOM, WTI reversal, WTI calendar/event logic, XNG, ratio basket, or RSI
  commodity pullback.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` setfile.
Live risk is intentionally not configured here; any future live allocation must
come from the portfolio process. The EA does not touch `T_Live`, AutoTrading,
deploy manifests, or the portfolio gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard,
  spread cap, monthly rebalance gate, and ATR% corridor.
- trade_entry: monthly 12-month D1 return-sign long/short package gated by
  current ATR as percent of price.
- trade_management: monthly package flattening and max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural WTI volatility-gated TSMOM build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |

## Symbol-input rebuild lineage (Fable, 2026-09-22)

This card is the card of record for `QM5_41488` (`commodity-tsmom-12m-atr-symbolinput`), the symbol-input rebuild of `QM5_12710` under the OWNER rule of
2026-09-06 (symbols are inputs, never code literals). Mechanics, parameters, source lineage and the R1-R4 verdicts above are inherited
unchanged from the parent card of record; the only source differences are the identity values and the `strategy_host_symbol` transport
input (canonical comparison against the chart symbol). Identity proof: `EQUIVALENT_EXACT` on the governed Q02 window (Codex task
273f2de8, evidence `docs/ops/evidence/2026-09-22_oil_symbol_input_rebuilds/README.md`, proofs under
`D:/QM/reports/identity_equivalence/QM5_12710__QM5_41488/XTIUSD.DWX/proof.json`). The rebuilt identity runs its own Q-chain;
it never reopens or edits the parent's verdicts.

## Approved Amendment (2026-09-16) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916`, OWNER receipt `d59b2277…` (staged-cohort approval; parent decision `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`).
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact XTIUSD.DWX/D1 configuration used by Q08 (set file `QM5_41488_commodity-tsmom-12m-atr-symbolinput_XTIUSD.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_41488",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "41488",
    "qm_friday_close_enabled": "true",
    "qm_friday_close_hour_broker": "21",
    "qm_magic_slot_offset": "0",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "20",
    "strategy_atr_sl_mult": "3.5",
    "strategy_host_symbol": "XTIUSD",
    "strategy_max_atr_pct": "7.50",
    "strategy_max_hold_days": "31",
    "strategy_max_spread_points": "1000",
    "strategy_min_abs_return_pct": "1.0",
    "strategy_min_atr_pct": "0.75",
    "strategy_momentum_lookback_d1": "252"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "a35b4a893452ffd2b97f477aac637cc7b61708c40608329cda69ab394ece6406",
  "symbol": "XTIUSD.DWX",
  "timeframe": "D1"
}
```
