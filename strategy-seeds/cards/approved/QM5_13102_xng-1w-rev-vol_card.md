---
ea_id: QM5_13102
slug: xng-1w-rev-vol
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XNG_S02
source_id: ZHAO-ST-MOMREV-2026
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
source_citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. SSRN, 2026."
source_citations:
  - type: academic_working_paper
    citation: "Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets. DOI 10.2139/ssrn.6425598."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598"
    quality_tier: B
    role: primary
strategy_type_flags: [vol-regime-gate, signal-reversal-exit, atr-hard-stop, time-stop, friday-close-flatten, symmetric-long-short]
markets: [XNGUSD.DWX]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13102_XNG_1W_REV_VOL_D1
period: D1
status: APPROVED
g0_status: APPROVED
pipeline_phase: Q02
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.08
expected_dd_pct: 22.0
expected_trades_per_year_per_symbol: 10
expected_trade_frequency: "Weekly-gated natural gas D1 short-term reversal with high-volatility filter; estimate 8-18 entries/year."
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual, low_frequency_sample_size]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
g0_approval_reasoning: "R1 PASS single DOI-indexed academic source; R2 PASS deterministic five-D1 return fade, high-volatility percentile gate, weekly cadence, ATR stop, neutral-return exit and time exit; R3 PASS XNGUSD.DWX; R4 PASS deterministic, ML-free, one position per magic."
review_focus: "Adds a short-horizon high-volatility natural-gas reversal driver to the XAU/SP500/NDX/XNG book. Unlike QM5_12567 it does not use RSI or a two-day trend-filtered pullback; unlike longer XNG reversal sleeves it isolates five-day shocks and requires elevated realized volatility. Q09 must still reject it if realized returns remain correlated with the incumbent XNG sleeve."
---

# QM5_13102 XNG One-Week High-Volatility Reversal

This EA trades `XNGUSD.DWX` on D1 only. It fades a large prior five-D1 move
only when current 20-D1 realized volatility ranks at or above the 65th
percentile of the prior 120 observations. It uses Darwinex-native OHLC,
spread, ATR, broker calendar, and V5 framework state only.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live
setfile, deploy manifest, `T_Live`, portfolio gate, or AutoTrading setting is
part of this build.

## hypothesis

Large five-D1 natural-gas moves can partially reverse when realized volatility
is elevated. This tests an overreaction regime distinct from the incumbent
two-day RSI pullback and from the paired low-volatility continuation branch.

## Source

Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin (2026), *Momentum and
Reversal on the Short-Term Horizon: Evidence from Commodity Markets*, DOI
`10.2139/ssrn.6425598`.

The source paper uses investor-position decomposition unavailable in the
Darwinex CFD runtime. This card declares a falsifiable OHLC-only proxy and does
not inherit performance evidence from its WTI or Brent realizations.

## Non-duplicate boundary

- `QM5_12567` uses a two-day RSI pullback and slow trend filter; this card has
  neither and fades five-D1 shocks only in elevated realized volatility.
- `QM5_12620` fades 20-D1 moves and can hold 28 days; this card uses five D1
  bars and a five-calendar-day maximum hold.
- `QM5_12895` is a 120-D1 monthly reversal.
- `QM5_13101` follows five-D1 moves in low volatility; this card fades them in
  high volatility.
- `QM5_13050` and `QM5_13056` use the same locked signal on WTI and Brent;
  this is the previously unbuilt XNG carrier and inherits no test evidence.

## rules

Evaluate completed D1 bars only, require a large five-D1 move and elevated
realized-volatility percentile, then trade opposite the move at most once per
broker week.

## 4. entry rules

On each new D1 bar, using completed bars only:

1. Compute the five-D1 close-to-close return.
2. Compute 20-D1 realized volatility and its percentile rank versus the prior
   120 rolling realized-volatility observations.
3. Require absolute five-D1 return at least 2.00% and volatility percentile at
   least 65.0.
4. BUY after a negative move or SELL after a positive move.
5. Require `XNGUSD.DWX`, D1, magic slot 0, no open same-magic position,
   spread no more than 2500 points, and no accepted entry in the same broker
   week.

PARAMETERS

- strategy_reversal_lookback_days = 5
- strategy_min_week_return_pct = 2.00
- strategy_vol_window_d1 = 20
- strategy_vol_rank_lookback_d1 = 120
- strategy_min_vol_pctile = 65.0
- strategy_atr_period = 20
- strategy_atr_sl_mult = 2.25
- strategy_hold_days = 5
- strategy_exit_neutral_pct = 0.25
- strategy_max_spread_points = 2500

## 5. exit rules

- Hard stop at 2.25 times frozen ATR(20).
- Time stop after five calendar days.
- Exit a BUY when five-D1 return normalizes to at least -0.25%.
- Exit a SELL when five-D1 return normalizes to at most +0.25%.
- Framework Friday close and standard news handling remain enabled.
- No fixed take-profit.

## 6. filters (no-trade module)

Require valid completed D1 close, ATR, and realized-volatility history. Apply
the XNG/D1 host guard, magic-slot guard, parameter bounds, spread cap, standard
news controls, kill switch, and Friday-close handling.

## 7. trade management rules

One position per magic/symbol. No pyramiding, grid, martingale, partial close,
adaptive PnL fitting, external runtime feed, cross-symbol state, or ML.

## Parameters To Test

Signal parameters are locked to the approved WTI/Brent source-family
realization. Q02 uses the defaults above; only the XNG execution spread cap
differs. No rescue retune is authorized.

## Author Claims

"We document both short-term momentum and reversal in commodity futures"
(Zhao et al., 2026, abstract).

## risk

Expected frequency is 8-18 entries/year, above the binding five-trades/year
Q02 floor. The risk class is high because natural-gas gaps can continue through
a contrarian setup. Retire on Q02 frequency, PF, or DD failure.

## Strategy Allowability Check

- R1 PASS: one named-author, DOI-indexed academic source.
- R2 PASS: deterministic entry, ATR stop, neutral-return exit, and time exit.
- R3 PASS: `XNGUSD.DWX` exists in the DWX universe.
- R4 PASS: deterministic, ML-free, and one position per magic.
- Non-duplicate boundary and source-to-proxy limitation are explicit.

## Framework Alignment

- no_trade: XNG/D1, slot, parameter, spread, history, one-position, and
  one-entry-per-week guards.
- trade_entry: fade five-D1 direction only in elevated realized volatility;
  freeze ATR stop at entry.
- trade_management: five-day and neutral-return exits.
- trade_close: framework close wrapper, broker ATR stop, and Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial parameter-locked XNG high-volatility reversal build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `artifacts/qm5_13102_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | QUEUED | work item `09900431-3c61-4ecd-9da2-96fa69758cf3` |
