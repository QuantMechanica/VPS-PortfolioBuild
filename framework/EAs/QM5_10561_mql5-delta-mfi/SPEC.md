# QM5_10561_mql5-delta-mfi - Strategy Spec

**EA ID:** QM5_10561
**Slug:** `mql5-delta-mfi`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `https://www.mql5.com/en/code/16501`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA recreates the Delta_MFI histogram color-change rule from the approved card. It computes a fast MFI(14) and slow MFI(50) from closed bars; a bullish state exists when slow MFI is above 50 and fast MFI is above slow MFI, and a bearish state exists when slow MFI is below 50 and fast MFI is below slow MFI. The EA opens long when the last closed bar changes into the bullish state and opens short when the last closed bar changes into the bearish state. It closes an open long on a bearish Delta_MFI state, closes an open short on a bullish Delta_MFI state, or exits through the ATR stop, 1.5R target, Friday close, news filter, or kill switch.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for Delta_MFI and ATR signal reads. |
| `strategy_mfi_fast_period` | `14` | `2+` | Fast MFI lookback from the Delta_MFI source default. |
| `strategy_mfi_slow_period` | `50` | `2+` | Slow MFI lookback from the Delta_MFI source default. |
| `strategy_signal_level` | `50.0` | `0-100` | Slow-MFI level used to classify bullish or bearish histogram states. |
| `strategy_atr_period` | `14` | `1+` | ATR lookback for hard stop distance. |
| `strategy_atr_sl_mult` | `2.0` | `>0` | Stop-loss distance in ATR multiples. |
| `strategy_reward_r_multiple` | `1.5` | `>0` | Take-profit distance as a multiple of stop risk. |
| `strategy_ema_filter_enabled` | `false` | `true/false` | Optional EMA200 trend-side filter from the card sweep notes. |
| `strategy_ema_period` | `200` | `1+` | EMA lookback when the optional trend-side filter is enabled. |
| `strategy_max_spread_points` | `0` | `0+` | Optional spread ceiling in points; `0` disables the filter. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card primary/source-test FX major and liquid DWX baseline symbol.
- `GBPUSD.DWX` - liquid FX major in the card's approved P2 basket.
- `GBPJPY.DWX` - liquid FX cross in the card's approved P2 basket.
- `XAUUSD.DWX` - liquid metal in the card's approved P2 basket.

**Explicitly NOT for:**
- `SP500.DWX` - not part of the card's approved FX/metals Delta_MFI P2 basket.
- `NDX.DWX` - index CFD not listed in this card's target basket.
- `XTIUSD.DWX` - energy CFD not listed in this card's target basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | Several H4 bars to a few days, bounded by opposite-color exit or ATR stop/target. |
| Expected drawdown profile | Moderate oscillator color-change drawdown, controlled by ATR(14) 2.0 stop. |
| Regime preference | MFI momentum/reversal transitions in liquid FX and metals. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `Exp_Delta_MFI`, Nikolay Kositsin, MQL5 CodeBase, published 2017-01-18, `https://www.mql5.com/en/code/16501`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10561_mql5-delta-mfi.md`

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
| v1 | 2026-05-29 | Initial build from card | d9dfebd1-2cb0-4325-be8e-e6686c99889c |
