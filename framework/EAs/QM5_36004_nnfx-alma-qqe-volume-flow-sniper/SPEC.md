# QM5_36004_nnfx-alma-qqe-volume-flow-sniper — Strategy Spec

**EA ID:** QM5_36004
**Slug:** `nnfx-alma-qqe-volume-flow-sniper`
**Source:** `nnfx-alma-qqe-volume-flow-sniper-official-source` (see `strategy-seeds/sources/nnfx-alma-qqe-volume-flow-sniper/`)
**Author of this spec:** Development (Gemini)
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card `artifacts/cards_approved/QM5_36004_nnfx-alma-qqe-volume-flow-sniper.md`. See that card's body for the full entry/exit/stop/sizing rules; this SPEC summarises the implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in `QM5_36004_nnfx-alma-qqe-volume-flow-sniper.mq5`. Framework wiring (risk, magic, news, Friday close) is inherited from `QM_Common.mqh` and is not redocumented here.

The official NNFX trend-following momentum algorithm on D1 combines Arnaud Legoux Moving Average (ALMA Baseline), Qualitative Quantitative Estimation (QQE C1 Trigger), Detrended Price Oscillator (DPO C2 Confirmation), and Volume Flow Indicator (VFI Volume Gate):
- Baseline: ALMA(20, sigma=6.0, offset=0.85) evaluated on completed D1 bars (Shift=1).
- C1 Trigger: QQE(14, 5, 27, 4.236) Fast ATR trail line crossover (+1 for Long, -1 for Short).
- C2 Confirmation: DPO(20) (> 0 for Long, < 0 for Short).
- Volume Gate: Volume Flow Indicator(130) (> 0 for Long, < 0 for Short).
- Long Entry: Close[1] > ALMA[1] AND QQE == UP (+1) AND DPO[1] > 0 AND VFI[1] > 0.
- Short Entry: Close[1] < ALMA[1] AND QQE == DOWN (-1) AND DPO[1] < 0 AND VFI[1] < 0.
- Stop Loss: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Take Profit: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Break-Even: Move SL to Entry + 1.0 pip when open profit reaches +1.0R (1.0x ATR).
- Indicator Exit: Close position when QQE flips against trade (DOWN for Long, UP for Short) or Close crosses opposite ALMA.
- No-Trade Filter: Dynamic spread filter (Spread > 1.8 * ATR(14, D1)[1]) and rollover blackout 23:55–00:05 GMT.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_alma_period` | 20 | 15 - 30 | ALMA baseline window period |
| `strategy_alma_sigma` | 6.0 | 4.0 - 8.0 | ALMA Gaussian distribution width |
| `strategy_alma_offset` | 0.85 | 0.70 - 0.95 | ALMA Gaussian offset parameter |
| `strategy_qqe_rsi_period` | 14 | 10 - 21 | QQE RSI smoothing period |
| `strategy_qqe_sf` | 5 | 3 - 8 | QQE smoothing factor (RSI EMA) |
| `strategy_qqe_wilder` | 27 | 14 - 35 | QQE Wilder smoothing period |
| `strategy_qqe_mult` | 4.236 | 2.5 - 5.0 | QQE fast ATR multiplier |
| `strategy_dpo_period` | 20 | 14 - 30 | Detrended Price Oscillator period |
| `strategy_vfi_period` | 130 | 50 - 200 | Volume Flow Indicator lookback period |
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
- `AUDUSD.DWX` — registered in magic_numbers.csv for this EA (slot 1)
- `USDCAD.DWX` — registered in magic_numbers.csv for this EA (slot 2)
- `USDCHF.DWX` — registered in magic_numbers.csv for this EA (slot 3)

**Explicitly NOT for:** any symbol not in the list above (no implicit universe expansion at runtime; the `QM_SymbolGuard` framework helper rejects foreign symbols).

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
| Cadence note | "80-160 high-conviction trades per year across 4 pairs" |
| Typical hold time | Daily swing (several D1 bars, up to 1-3 weeks) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Multi-indicator trend consensus with confirmed volume expansion |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-alma-qqe-volume-flow-sniper-official-source`
**Pointer:** `strategy-seeds/sources/nnfx-alma-qqe-volume-flow-sniper/`
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_36004_nnfx-alma-qqe-volume-flow-sniper.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
