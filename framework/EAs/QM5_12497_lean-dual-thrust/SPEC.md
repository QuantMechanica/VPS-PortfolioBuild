# QM5_12497_lean-dual-thrust - Strategy Spec

**EA ID:** QM5_12497
**Slug:** lean-dual-thrust
**Source:** 0c46ae4f-60c5-56c3-92ed-17b4db7ef318 (see `strategy-seeds/sources/0c46ae4f-60c5-56c3-92ed-17b4db7ef318/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the Dual Thrust breakout rule from the approved Lean card. On each closed 30-minute bar it reads a 20-bar consolidated range, computes `range = max(highest_high - lowest_close, highest_close - lowest_low)`, and sets an upper and lower breakout line from the latest closed consolidated close. It enters long when current price is above the upper line and short when current price is below the lower line. Positions use an ATR hard stop, close after five days, and close on an opposite breakout or the standard V5 Friday flatten.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_k1 | 0.63 | 0.4-1.0 | Upper breakout coefficient applied to the rolling range. |
| strategy_k2 | 0.63 | 0.4-1.0 | Lower breakout coefficient applied to the rolling range. |
| strategy_range_period | 20 | 10-40 | Number of consolidated bars in the rolling Dual Thrust range window. |
| strategy_consolidator_minutes | 30 | 15, 30, 60 | Consolidated bar length used for the range and line calculation. |
| strategy_hold_days | 5 | 2-8 | Maximum calendar-day holding period before strategy exit. |
| strategy_atr_period | 14 | 7-30 | ATR lookback used for the hard stop distance. |
| strategy_atr_stop_mult | 2.5 | 1.5-3.0 | ATR multiplier for the initial hard stop. |
| strategy_atr_floor_points | 0.0 | 0 or positive | Optional ATR floor in points; zero disables the low-volatility filter. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 proxy named directly in the card; backtest-only per DWX discipline.
- NDX.DWX - US large-cap technology index proxy from the card's portable basket.
- WS30.DWX - US large-cap Dow proxy from the card's portable basket.
- GDAXI.DWX - liquid index DWX symbol for the card's generic liquid-index wording.
- UK100.DWX - liquid index DWX symbol for the card's generic liquid-index wording.
- AUDCAD.DWX - liquid forex pair in the DWX matrix.
- AUDCHF.DWX - liquid forex pair in the DWX matrix.
- AUDJPY.DWX - liquid forex pair in the DWX matrix.
- AUDNZD.DWX - liquid forex pair in the DWX matrix.
- AUDUSD.DWX - liquid forex pair in the DWX matrix.
- CADCHF.DWX - liquid forex pair in the DWX matrix.
- CADJPY.DWX - liquid forex pair in the DWX matrix.
- CHFJPY.DWX - liquid forex pair in the DWX matrix.
- EURAUD.DWX - liquid forex pair in the DWX matrix.
- EURCAD.DWX - liquid forex pair in the DWX matrix.
- EURCHF.DWX - liquid forex pair in the DWX matrix.
- EURGBP.DWX - liquid forex pair in the DWX matrix.
- EURJPY.DWX - liquid forex pair in the DWX matrix.
- EURNZD.DWX - liquid forex pair in the DWX matrix.
- EURUSD.DWX - liquid forex pair in the DWX matrix.
- GBPAUD.DWX - liquid forex pair in the DWX matrix.
- GBPCAD.DWX - liquid forex pair in the DWX matrix.
- GBPCHF.DWX - liquid forex pair in the DWX matrix.
- GBPJPY.DWX - liquid forex pair in the DWX matrix.
- GBPNZD.DWX - liquid forex pair in the DWX matrix.
- GBPUSD.DWX - liquid forex pair in the DWX matrix.
- NZDCAD.DWX - liquid forex pair in the DWX matrix.
- NZDCHF.DWX - liquid forex pair in the DWX matrix.
- NZDJPY.DWX - liquid forex pair in the DWX matrix.
- NZDUSD.DWX - liquid forex pair in the DWX matrix.
- USDCAD.DWX - liquid forex pair in the DWX matrix.
- USDCHF.DWX - liquid forex pair in the DWX matrix.
- USDJPY.DWX - liquid forex pair in the DWX matrix.
- XAUUSD.DWX - metal DWX symbol matching the card's metals portability.
- XAGUSD.DWX - metal DWX symbol matching the card's metals portability.

**Explicitly NOT for:**
- XTIUSD.DWX - energy commodity, not an index, forex pair, or metal.
- XNGUSD.DWX - energy commodity, not an index, forex pair, or metal.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Up to 5 days |
| Expected drawdown profile | TBD, medium risk class with ATR hard stops. |
| Regime preference | Breakout / range expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0c46ae4f-60c5-56c3-92ed-17b4db7ef318
**Source type:** other
**Pointer:** https://github.com/QuantConnect/Lean/blob/261366a7e26ae942df858ab20df4fef8fa07de67/Algorithm.Python/Alphas/VIXDualThrustAlpha.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12497_lean-dual-thrust.md`

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
| v1 | 2026-06-11 | Initial build from card | d725840b-ad34-44a4-9a81-56ca29bf7b71 |
