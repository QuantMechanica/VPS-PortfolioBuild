# QM5_11619_robo-psar01-ema6-11-34-h1 - Strategy Spec

**EA ID:** QM5_11619
**Slug:** `robo-psar01-ema6-11-34-h1`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (see `sources/362359657-robo-forex-strategy`)
**Author of this spec:** Claude
**Last revised:** 2026-07-23

---

## 1. Strategy Logic

The EA trades the H1 EMA-fan and Parabolic SAR trend state from the approved RoboForex "PSAR + EMA Trio" card. It buys when the last closed bar has a full bullish EMA fan (EMA(6) > EMA(11) > EMA(34)) and PSAR(0.1,1.0) below the closed-bar close. It sells when the fan is fully bearish (EMA(6) < EMA(11) < EMA(34)) and PSAR is above the closed-bar close. Initial stop is the tighter of the PSAR value or entry +/- 2 x ATR(14) (card's literal `MathMax(psar_value, Close[1] - 2*ATR)` formula, mirrored for shorts), take profit is 4 x ATR(14), open trades trail the stop to the closed-bar PSAR value, and the position is force-closed early whenever PSAR flips to the opposite side of price ("exit when PSAR flips against position").

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 6 | >0 and < mid period | Fast EMA of the fan. |
| `strategy_ema_mid_period` | 11 | > fast and < slow period | Mid EMA of the fan. |
| `strategy_ema_slow_period` | 34 | > mid period | Slow EMA of the fan. |
| `strategy_psar_step` | 0.1 | >0 and < `strategy_psar_max` | Parabolic SAR step from the card (fast/aggressive). |
| `strategy_psar_max` | 1.0 | > `strategy_psar_step` | Parabolic SAR maximum acceleration from the card. |
| `strategy_atr_period` | 14 | >0 | ATR period for the SL floor and TP distance. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple for the minimum-distance SL floor. |
| `strategy_atr_tp_mult` | 4.0 | >0 | ATR multiple for take profit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed H1 DWX FX major.
- `GBPUSD.DWX` - card-listed H1 DWX FX major.
- `USDJPY.DWX` - card-listed H1 DWX FX major.
- `USDCHF.DWX` - card-listed H1 DWX FX major.
- `AUDUSD.DWX` - card-listed H1 DWX FX major.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline runs require canonical `.DWX` symbols.
- Symbols outside `dwx_symbol_matrix.csv` - unavailable to the DWX tester.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | intraday to multi-session, bounded by PSAR flip/trail or 4 x ATR(14) TP |
| Expected drawdown profile | trend-following drawdowns during choppy EMA-fan/PSAR whipsaws |
| Regime preference | trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** educational PDF
**Pointer:** RoboForex Educational Team, "Forex Strategy Collection", strategy "PSAR + EMA Trio", pages 55-56.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11619_robo-psar01-ema6-11-34-h1.md`

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
| v1 | 2026-07-23 | Initial build from card | cce3fd7b-adec-4af5-b652-039dfe80ebe1 |
