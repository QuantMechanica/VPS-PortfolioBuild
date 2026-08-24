# QM5_36006_nnfx-halftrend-jurik-coppock-engine — Strategy Spec

**EA ID:** QM5_36006
**Slug:** `nnfx-halftrend-jurik-coppock-engine`
**Source:** `nnfx-halftrend-jurik-coppock-engine-official-source` (see `strategy-seeds/sources/nnfx-halftrend-jurik-coppock-engine/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_36006_nnfx-halftrend-jurik-coppock-engine.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_36006_nnfx-halftrend-jurik-coppock-engine.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

The high-speed NNFX algorithmic framework on D1 combines HalfTrend (Baseline), Jurik Velocity (C1 Trigger), Coppock Curve (C2 Confirmation), and Chaikin Money Flow (Volume Gate):
- Baseline: the card's closed-bar `EMA(close,2) +/- 2.0 * ATR(100)` mapping. A close at/above EMA selects the lower band and direction +1; a close below EMA selects the upper band and direction -1.
- C1 Trigger: Jurik Velocity compares shift-1 and shift-2 JMA(14) values. JMA uses the standard open Jurik recurrence with conventional fixed defaults phase=0 (`phaseRatio=1.5`) and power=2; the prior TEMA surrogate is not used.
- C2 Confirmation: Coppock Curve (ROC 14, ROC 11, WMA 10) confirming long-term momentum (Coppock > 0 for Long, Coppock < 0 for Short).
- Volume Gate: Chaikin Money Flow (CMF 20) confirming volume accumulation/distribution (CMF > 0.05 for Long, CMF < -0.05 for Short).
- Long Entry: Close[1] > HalfTrend[1] AND JurikVel[1] > 0.0 AND Coppock[1] > 0.0 AND CMF(20)[1] > 0.05.
- Short Entry: Close[1] < HalfTrend[1] AND JurikVel[1] < 0.0 AND Coppock[1] < 0.0 AND CMF(20)[1] < -0.05.
- Stop Loss: Placed at 1.0 * ATR(14, D1)[1] from entry.
- TP1: At +1.0R (the entry ATR stop distance), close 50% exactly once.
- Runner protection: After TP1, move SL to Entry + 1.0 pip for a long or Entry - 1.0 pip for a short.
- Runner Exit: Close position when HalfTrend direction flips (HalfTrend flips to downtrend for Long, HalfTrend flips to uptrend for Short).
- No-Trade Filter: Dynamic spread filter, UTC-normalized rollover blackout 23:55–00:05, and 2.0% account realized-loss entry halt.
- Hard stops: Restart-safe framework daily equity stop at 2.5% and account-level total-DD signal threshold at 5.0%.
- Execution: market-order deviation is capped at the card's 3.0 ticks through `QM_EntryConfigure`; all custom D1 series are loaded in one bounded, size-guarded cache refresh after the new-bar gate.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_halftrend_amp` | 2 | 1 - 4 | HalfTrend amplitude setting |
| `strategy_halftrend_atr_period` | 100 | 50 - 150 | HalfTrend ATR period for hysteresis |
| `strategy_halftrend_atr_mult` | 2.0 | fixed | Card-declared ATR displacement around EMA(2) |
| `strategy_jurik_period` | 14 | 8 - 21 | Jurik JMA smoothing period |
| `strategy_coppock_roc1` | 14 | 10 - 20 | Coppock primary ROC period |
| `strategy_coppock_roc2` | 11 | 8 - 15 | Coppock secondary ROC period |
| `strategy_coppock_wma` | 10 | 5 - 15 | Coppock WMA smoothing period |
| `strategy_cmf_period` | 20 | 14 - 30 | Chaikin Money Flow lookback period |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.00 | 0.8 - 1.5 | Stop loss distance as ATR multiplier |
| `strategy_tp_atr_mult` | 1.00 | fixed | TP1 trigger as a multiple of entry ATR risk |
| `strategy_tp1_fraction` | 0.50 | fixed | Volume closed once at TP1 |
| `strategy_be_buffer_pips` | 1 | fixed | Runner stop offset beyond entry after TP1 |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 2.5 | Spread filter ATR multiplier |
| `strategy_daily_loss_halt_pct` | 2.0 | fixed | Closed account PnL entry-halt threshold |
| `strategy_daily_hard_stop_pct` | 2.5 | fixed | Framework daily equity hard stop |
| `strategy_total_dd_halt_pct` | 5.0 | fixed | Account-level total-DD signal threshold |
| `strategy_per_trade_risk_cap_pct` | 0.5 | fixed | Framework per-trade risk cap |
| `strategy_max_slippage_ticks` | 3.0 | fixed | Maximum market-order deviation in symbol ticks |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA (slot 0)
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA (slot 1)
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA (slot 2)

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Cadence note | "80-160 high-conviction trades per year across 3 pairs" |
| Typical hold time | Not fixed by the card; the runner remains open until the closed-D1 HalfTrend direction flips |
| Expected drawdown profile | Card prior 18%; runtime protection halts entries/positions at the declared 2.5% daily and 5.0% initial-equity limits |
| Regime preference | trend-following |
| Win rate target (qualitative) | Not assumed; source claims are explicitly excluded from gate evidence |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-halftrend-jurik-coppock-engine-official-source`
**Pointer:** `strategy-seeds/sources/nnfx-halftrend-jurik-coppock-engine/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_36006_nnfx-halftrend-jurik-coppock-engine.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`; an unconfigured sizing mode is reported as `EA_RISK_SIZER_UNCONFIGURED`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-24 | Burn-window build reconciliation from approved card | `build-QM5_36006_nnfx-halftrend-jurik-coppock-engine` |
