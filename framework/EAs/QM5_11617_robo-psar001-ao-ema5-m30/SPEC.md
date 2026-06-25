# QM5_11617_robo-psar001-ao-ema5-m30 - Strategy Spec

**EA ID:** QM5_11617
**Slug:** `robo-psar001-ao-ema5-m30`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (see `sources/362359657-robo-forex-strategy`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades the M30 Parabolic SAR and Awesome Oscillator trend state from the approved RoboForex strategy card. It buys when the last closed bar has PSAR(0.01,0.10) below price, AO is above zero, and price is above EMA(5). It sells when PSAR is above price, AO is below zero, and price is below EMA(5). Initial stop loss is the PSAR value at entry, take profit is 4 x ATR(14), and open trades trail the stop to the closed-bar PSAR value when that improves protection.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sar_step` | 0.01 | >0 and < `strategy_sar_max` | Parabolic SAR step from the card. |
| `strategy_sar_max` | 0.10 | > `strategy_sar_step` | Parabolic SAR maximum acceleration from the card. |
| `strategy_ema_period` | 5 | >0 | EMA period used for the price filter. |
| `strategy_ao_fast_period` | 5 | >0 and < slow period | Fast median-price SMA for AO. |
| `strategy_ao_slow_period` | 34 | > fast period | Slow median-price SMA for AO. |
| `strategy_atr_period` | 14 | >0 | ATR period for take-profit distance. |
| `strategy_atr_tp_mult` | 4.0 | >0 | ATR multiple for take profit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed M30 DWX FX major.
- `GBPUSD.DWX` - card-listed M30 DWX FX major.
- `USDJPY.DWX` - card-listed M30 DWX FX major.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline runs require canonical `.DWX` symbols.
- Symbols outside `dwx_symbol_matrix.csv` - unavailable to the DWX tester.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | intraday to multi-session, bounded by PSAR trail or 4 x ATR(14) TP |
| Expected drawdown profile | trend-following drawdowns during choppy AO/PSAR state changes |
| Regime preference | trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** educational PDF
**Pointer:** RoboForex Educational Team, "Forex Strategy Collection", strategy "Parabolic SAR & Awesome", pages 48-49.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11617_robo-psar001-ao-ema5-m30.md`

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
| v1 | 2026-06-25 | Initial build from card | e21e27ab-9b10-478b-8c23-0b8e34468362 |
