---
ea_id: QM5_13020
slug: audnzd-coint-reversion
type: strategy
strategy_id: QM-EDGELAB-FXCOINT-2026-06-09_AUDNZD
source_id: QM-EDGELAB-FXCOINT-2026-06-09
source_citation: "QM cross-asset FX cointegration screen, 2026-06-09 (AUDUSD~NZDUSD sole surviving cointegrated pair); Engle and Granger (1987), Co-integration and Error Correction, Econometrica."
source_citations:
  - type: internal_research
    citation: "QM cross-asset FX cointegration screen, 2026-06-09 (AUDUSD~NZDUSD sole surviving cointegrated pair)."
    location: "docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md"
    quality_tier: B
    role: primary
  - type: academic_journal
    citation: "Engle, Robert F. and C. W. J. Granger. Co-integration and Error Correction: Representation, Estimation, and Testing. Econometrica, 55(2), 1987."
    location: "https://www.jstor.org/stable/1913236"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/QM-EDGELAB-FXCOINT-2026-06-09]]"
concepts:
  - "[[concepts/cointegration]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/commodity-currency-twins]]"
indicators:
  - "[[indicators/zscore]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [cointegration-reversion, zscore-reversion, atr-hard-stop, time-stop, fx-cross]
target_symbols: [AUDNZD.DWX]
primary_target_symbols: [AUDNZD.DWX]
markets: [AUDNZD.DWX]
single_symbol_only: true
logical_symbol: QM5_13020_AUDNZD_COINT_REV_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 AUDNZD log-price z-score reversion at +/-2.0 entry bands; estimate 10-15 entries/year after the z-band, spread, and framework filters."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-06
expected_pf: 1.12
expected_dd_pct: 15.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-06 (Claude, Fable program #5): R1 internal QM cross-asset FX cointegration screen 2026-06-09 (AUDUSD~NZDUSD sole surviving cointegrated pair) plus Engle/Granger Econometrica methodology; R2 deterministic rules below; R3 symbols verified in DWX matrix; R4 no ML/grid/martingale/external runtime data."
---

# AUDNZD D1 Cointegration Reversion

## Source

- Source: [[sources/QM-EDGELAB-FXCOINT-2026-06-09]]
- Primary citation (internal research): QM cross-asset FX cointegration
  screen, 2026-06-09 — AUDUSD~NZDUSD was the sole surviving cointegrated
  pair (OOS net Sharpe 1.29, ~7 trades/yr, low-freq cost-friendly). Evidence:
  `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.
- Methodological supplement: Engle, Robert F. and C. W. J. Granger.
  "Co-integration and Error Correction: Representation, Estimation, and
  Testing." Econometrica, 55(2), 1987. URL:
  https://www.jstor.org/stable/1913236.

## Hypothesis

AUD and NZD are commodity-currency twins driven by shared fundamentals
(China demand, commodity cycle, risk sentiment, rate differentials), which
makes their relative value mean-reverting. The internal cross-asset screen
found AUDUSD~NZDUSD to be the one cointegrated FX pair that survived net of
costs. This card trades that same relative-value edge directly on the
`AUDNZD.DWX` cross: when the cross's log price is stretched far from its
slow mean (z at +/-2.0), it reverts.

## Mechanism

- Trading the cross directly captures the AUD-vs-NZD relative value in one
  instrument — one leg, one spread, no basket execution or broken-package
  risk.
- z-score construction on D1: `z = (log close - SMA(100) of log close) /
  stdev(20) of log close`, i.e. a slow mean with a fast dispersion estimate,
  so the entry band adapts to current cross volatility.
- Entry at the +/-2.0 band, exit when z crosses 0, with ATR hard stop and
  max-hold time stop bounding every trade.

This is deliberately different from:

- `QM5_12532_edgelab-audnzd-cointegration`: that EA is a two-leg
  AUDUSD.DWX/NZDUSD.DWX basket with a hedge-ratio return-spread; this card
  is a single-symbol z-score reversion on the AUDNZD.DWX cross itself —
  different instrument, different z construction, no basket legs.
- The edge-lab cointegration basket family (12768-12803, 13003): all two-leg
  packages on other pairs; none trades the AUDNZD cross single-symbol.

## Markets And Timeframe

- Symbol: `AUDNZD.DWX`.
- Period: `D1`.
- Expected trade frequency: approximately 10-15 entries/year before Q02
  validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker time, and V5
  framework state only. No external cointegration re-estimation, CSV, API,
  or ML input is consumed at runtime.

## Rules

### Entry

- Evaluate only on a new `AUDNZD.DWX` D1 bar, using completed bars.
- Compute `log_close = ln(close)` on completed D1 bars.
- Compute `z = (log_close - SMA(strategy_sma_lookback_d1) of log_close) /
  stdev(strategy_stdev_lookback_d1) of log_close` (defaults 100 and 20).
- Entry Long: `z <= -strategy_entry_z` (default 2.0), on bar close.
- Entry Short: `z >= +strategy_entry_z` (default 2.0), on bar close.
- One position at a time: no entry while a position is open for this magic.
- No entry if `AUDNZD.DWX` spread exceeds `strategy_max_spread_points`.

### Exit & Stops

- Mean exit: close the position when z crosses 0 (long: z rises to >= 0;
  short: z falls to <= 0; `strategy_exit_z` default 0.0).
- Hard stop: fixed SL at ATR(`strategy_atr_period`, default 14) times
  `strategy_atr_sl_mult` (default 2.5) from entry price.
- Time stop: close after `strategy_max_hold_days` D1 bars (default 30).
- Friday close remains enabled by the V5 framework.

## Risk & Filters

- Only trade `AUDNZD.DWX` on D1 with `qm_magic_slot_offset=0`.
- Skip entries when D1 history, the SMA/stdev series, ATR, or spread data
  are unavailable.
- Skip entries when spread exceeds the configured cap.
- Multi-day holds incur swap in live trading; the tester is swap-free
  (.DWX), so Q04+ cost gates and the deferred swap-injection work remain the
  honest judge.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_sma_lookback_d1
  default: 100
  sweep_range: [70, 100, 140]
- name: strategy_stdev_lookback_d1
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.7, 2.0, 2.3]
- name: strategy_exit_z
  default: 0.0
  sweep_range: [0.0, 0.2, 0.4]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_max_hold_days
  default: 30
  sweep_range: [20, 30, 45]
- name: strategy_max_spread_points
  default: 80
  sweep_range: [50, 80, 120]

## Expected Behavior

- Entries only at genuine two-sigma stretches of the cross; most of the time
  the EA is flat waiting for the band.
- Winners decay back to the mean over days to weeks and exit at z = 0;
  losers are regime breaks (structural AUD/NZD divergence) cut at the ATR
  hard stop or the 30-bar time stop.
- expected_pf 1.12, expected_dd_pct 15, approximately 12 trades/year. The
  internal screen's honest caveat carries over: the pair edge was
  regime-sensitive (DEV weak, OOS strong) — Q02-Q04 on full 2017-2026
  history are the arbiter.

## Author Claims

The internal screen evidences the AUD~NZD relative-value edge net of costs
in basket form; this card imports no performance number for the cross
realization. Q02 and later phases must validate or reject the mechanical
`AUDNZD.DWX` realization on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.12.
- expected_dd_pct: 15.
- expected_trade_frequency: approximately 10-15 entries/year.
- risk_class: medium — a tightly cointegrated cross with bounded ATR stop
  and time stop; the main risk is a structural divergence regime.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: internal QM cross-asset FX cointegration screen
  (2026-06-09) with repo evidence artifact, plus Engle/Granger Econometrica
  cointegration methodology.
- [x] R2 mechanical: fixed log-price z-score with SMA(100)/stdev(20), fixed
  +/-2.0 entry bands, zero-cross exit, ATR hard stop, and time stop.
- [x] R3 testable: `AUDNZD.DWX` exists in the DWX symbol matrix with D1
  history 2017-2026.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: single-symbol AUDNZD cross z-score reversion, not the
  QM5_12532 AUDUSD/NZDUSD two-leg basket or any other edge-lab
  cointegration package.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `AUDNZD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the
portfolio gate.

## Framework Alignment

- no_trade: AUDNZD/D1 host guard, magic-slot guard, parameter guard, spread
  cap, and valid data checks.
- trade_entry: D1 log-price z-score band reversion, long and short.
- trade_management: max-hold tracking.
- trade_close: z zero-cross mean exit, ATR hard stop, time stop, and
  framework Friday close.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce the card-scaled minimum trade
count, if Q02 PF is below 1.0 after costs, or if the z-band never triggers /
degenerates on Darwinex AUDNZD history 2017-2026.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-06 | initial AUDNZD cross cointegration-reversion card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-06 | APPROVED | this card |
| Q01 Build Validation | 2026-07-06 | PENDING | `artifacts/qm5_13020_build_result.json` |
| Q02 Baseline Screening | 2026-07-06 | PENDING | enqueue after compile |
