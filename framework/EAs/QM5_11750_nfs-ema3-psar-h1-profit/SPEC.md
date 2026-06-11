# QM5_11750_nfs-ema3-psar-h1-profit - Strategy Spec

**EA ID:** QM5_11750
**Slug:** `nfs-ema3-psar-h1-profit`
**Source:** `781e6542-cf6d-5b05-b351-2c769d7fb926` (see `strategy-seeds/sources/781e6542-cf6d-5b05-b351-2c769d7fb926/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades an H1 trend breakout through three exponential moving averages. A long entry is allowed when the last closed bar was at or below EMA(10), the new closed bar is above EMA(10), EMA(25), and EMA(50), and Parabolic SAR is below that close. A short entry follows the card's implementation note: the prior close is at or above EMA(10), the new closed bar is below EMA(50), and Parabolic SAR is above the close. Exits occur when the last closed bar crosses back through EMA(10) against the open position, or by the 2x ATR(14) stop, 3x ATR(14) cap target, Friday close, kill-switch, or news gate.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for EMA, PSAR, ATR, entries, and exits. |
| `strategy_ema_fast_period` | `10` | `>=1` | Fast EMA used for initial cross and exit. |
| `strategy_ema_mid_period` | `25` | `>=1` | Middle EMA that must be cleared by long entries. |
| `strategy_ema_slow_period` | `50` | `>=1` | Slow EMA that must be cleared by entries. |
| `strategy_psar_step` | `0.02` | `>0` | Parabolic SAR acceleration step. |
| `strategy_psar_maximum` | `0.20` | `>0` | Parabolic SAR maximum acceleration. |
| `strategy_atr_period` | `14` | `>=1` | ATR period for stop and cap target. |
| `strategy_atr_sl_mult` | `2.0` | `>0` | Initial stop distance in ATR multiples. |
| `strategy_atr_tp_mult` | `3.0` | `>0` | Hard target distance in ATR multiples. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major in the card's target basket and present in the DWX matrix.
- `GBPUSD.DWX` - FX major in the card's target basket and present in the DWX matrix.
- `USDCHF.DWX` - FX major in the card's target basket and present in the DWX matrix.
- `USDJPY.DWX` - FX major in the card's target basket and present in the DWX matrix.

**Explicitly NOT for:**
- Non-FX `.DWX` indices, metals, and energies - the source system is a Forex Profit System with FX-major targets only.

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
| Typical hold time | H1 trend hold, source example around multi-day trend continuation. |
| Expected drawdown profile | Trend-following whipsaw risk around EMA stack recrosses, bounded by 2x ATR stop. |
| Regime preference | Trend-following. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `781e6542-cf6d-5b05-b351-2c769d7fb926`
**Source type:** `book`
**Pointer:** Anonymous, "Forex Profit System", in local Source PDF `452915895-9-Forex-Systems-pdf.pdf`, pages 6-7.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11750_nfs-ema3-psar-h1-profit.md`

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
| v1 | 2026-06-11 | Initial build from card | 65aa5d44-90ae-4efb-b683-e67d514d2fe2 |
