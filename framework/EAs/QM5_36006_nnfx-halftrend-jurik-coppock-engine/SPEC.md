# QM5_36006_nnfx-halftrend-jurik-coppock-engine — Strategy Spec

**EA ID:** QM5_36006
**Slug:** `nnfx-halftrend-jurik-coppock-engine`
**Source:** `nnfx-halftrend-jurik-coppock-engine-official-source` (see `strategy-seeds/sources/nnfx-halftrend-jurik-coppock-engine/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-17

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
- Baseline: HalfTrend (amplitude 2, ATR 100) non-repainting step baseline evaluated on completed D1 bars (Shift=1).
- C1 Trigger: Jurik Velocity (14-period JMA derivative) comparing current JMA to previous JMA (JurikVel > 0 for Long, JurikVel < 0 for Short).
- C2 Confirmation: Coppock Curve (ROC 14, ROC 11, WMA 10) confirming long-term momentum (Coppock > 0 for Long, Coppock < 0 for Short).
- Volume Gate: Chaikin Money Flow (CMF 20) confirming volume accumulation/distribution (CMF > 0.05 for Long, CMF < -0.05 for Short).
- Long Entry: Close[1] > HalfTrend[1] AND JurikVel[1] > 0.0 AND Coppock[1] > 0.0 AND CMF(20)[1] > 0.05.
- Short Entry: Close[1] < HalfTrend[1] AND JurikVel[1] < 0.0 AND Coppock[1] < 0.0 AND CMF(20)[1] < -0.05.
- Stop Loss: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Take Profit: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Break-Even: Move SL to Entry + 1.0 pip when open profit reaches +1.0R (1.0x ATR).
- Runner Exit: Close position when HalfTrend direction flips (HalfTrend flips to downtrend for Long, HalfTrend flips to uptrend for Short).
- No-Trade Filter: Dynamic spread filter (Spread > 1.8 * ATR(14, D1)[1]) and rollover blackout 23:55–00:05 GMT.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_halftrend_amp` | 2 | 1 - 4 | HalfTrend amplitude setting |
| `strategy_halftrend_atr_period` | 100 | 50 - 150 | HalfTrend ATR period for hysteresis |
| `strategy_jurik_period` | 14 | 8 - 21 | Jurik JMA smoothing period |
| `strategy_coppock_roc1` | 14 | 10 - 20 | Coppock primary ROC period |
| `strategy_coppock_roc2` | 11 | 8 - 15 | Coppock secondary ROC period |
| `strategy_coppock_wma` | 10 | 5 - 15 | Coppock WMA smoothing period |
| `strategy_cmf_period` | 20 | 14 - 30 | Chaikin Money Flow lookback period |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.00 | 0.8 - 1.5 | Stop loss distance as ATR multiplier |
| `strategy_tp_atr_mult` | 1.00 | 0.8 - 1.5 | Take profit distance as ATR multiplier |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 2.5 | Spread filter ATR multiplier |

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
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Cadence note | "80-160 high-conviction trades per year across 3 pairs" |
| Typical hold time | Daily swing (several D1 bars, up to 1-3 weeks) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Multi-indicator trend consensus with confirmed fast momentum |
| Win rate target (qualitative) | high |

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

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
