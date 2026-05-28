# QM5_10485_mql5-exec-ac - Strategy Spec

**EA ID:** QM5_10485
**Slug:** `mql5-exec-ac`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

This EA trades the Acceleration/Deceleration Oscillator on closed H1 bars. It buys when AC is rising in the source-defined positive or negative zone sequence, or when AC crosses above zero; it sells when AC is falling in the source-defined positive or negative zone sequence, or when AC crosses below zero. Each trade uses a 1.5 x ATR(14) protective stop, a 2R take-profit, and closes early on an opposite AC signal or after 72 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_work_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for AC, ATR, entry, exit, and time-stop bar counting. |
| `strategy_ao_fast_period` | `5` | `1+` | Fast median-price SMA period used to derive AO before AC. |
| `strategy_ao_slow_period` | `34` | `> fast period` | Slow median-price SMA period used to derive AO before AC. |
| `strategy_ac_smooth_period` | `5` | `1+` | AO smoothing period subtracted from AO to compute AC. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | `1.5` | `> 0` | ATR multiplier for initial stop distance. |
| `strategy_target_rr` | `2.0` | `> 0` | Take-profit distance in multiples of initial risk. |
| `strategy_time_stop_bars` | `72` | `0+` | Maximum H1 bars to hold a position; `0` disables the time stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 lists this major FX pair in the primary portable P2 basket.
- `GBPUSD.DWX` - Card R3 lists this major FX pair in the primary portable P2 basket.
- `USDJPY.DWX` - Card R3 lists this major FX pair in the primary portable P2 basket.
- `XAUUSD.DWX` - Card R3 lists this liquid metal symbol in the primary portable P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - build-time registration is restricted to canonical DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | `up to 72 H1 bars` |
| Expected drawdown profile | Momentum oscillator reversal system with ATR-defined loss per trade. |
| Regime preference | Momentum-reversal conditions where AC bends or crosses zero. |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/23086`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10485_mql5-exec-ac.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | 0718a781-88bc-4a9f-815c-6f253c8f703c |
