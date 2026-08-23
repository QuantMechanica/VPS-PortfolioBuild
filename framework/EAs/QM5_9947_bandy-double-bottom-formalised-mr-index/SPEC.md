# QM5_9947_bandy-double-bottom-formalised-mr-index - Strategy Spec

**EA ID:** QM5_9947
**Slug:** andy-double-bottom-formalised-mr-index
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

This EA trades the bullish double-bottom (W-pattern) chart pattern on D1 bars per Howard Bandy\'s formalisation in Quantitative Technical Analysis. It scans the most recent 60 completed bars for the two most recent confirmed 3-bar swing lows, requires those lows to be 10-50 bars apart and within 2 percent of each other, then finds the highest high between them as the neckline. A long entry fires after the latest completed close breaks above the neckline, the pattern depth is at least 3 percent of the bottom price, and price is above its 200-day SMA regime filter. The stop loss is placed below the pattern\'s deepest low with a 0.5 ATR buffer capped at 3.5 ATR from entry; the target is the measured pattern height projected upward from entry, with a 20 D1-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_pivot_lookback_bars | 3 | 1-7 | Bars on each side required to confirm a swing-low pivot. |
| strategy_scan_bars | 60 | 30-120 | Completed D1 bars scanned for the two most recent pivot lows. |
| strategy_min_sep_bars | 10 | 5-25 | Minimum spacing between the two bottoms. |
| strategy_max_sep_bars | 50 | 20-80 | Maximum spacing between the two bottoms. |
| strategy_tolerance_pct | 0.02 | 0.01-0.05 | Maximum relative difference between the two bottom prices. |
| strategy_min_depth_pct | 0.03 | 0.02-0.08 | Minimum pattern depth versus the older bottom. |
| strategy_regime_sma_period | 200 | 100-300 | Bullish regime gate period; close must be above this SMA. |
| strategy_atr_period | 14 | 10-20 | ATR period used for stop buffer and cap. |
| strategy_stop_buffer_atr | 0.50 | 0.30-1.00 | ATR buffer below the pattern low. |
| strategy_stop_cap_atr | 3.50 | 2.00-5.00 | Maximum stop distance from entry in ATR units. |
| strategy_max_hold_bars | 20 | 10-40 | D1 bars before time-stop exit. |
| strategy_max_spread_points | 0 | 0-10000 | Optional spread ceiling; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - backtest-only US large-cap index port named in the approved card.
- NDX.DWX - live-routable US index proxy for the same chart-pattern substrate.
- WS30.DWX - live-routable US index proxy for broad equity index validation.
- GDAXI.DWX - European equity index CFD.
- UK100.DWX - UK equity index CFD.
- EURUSD.DWX - liquid FX major for cross-asset robustness.
- GBPUSD.DWX - liquid FX major.
- USDJPY.DWX - liquid FX major.
- USDCHF.DWX - liquid FX major.
- USDCAD.DWX - liquid FX major.
- AUDUSD.DWX - liquid FX major.
- NZDUSD.DWX - liquid FX major.
- XAUUSD.DWX - liquid metal CFD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 8 |
| Typical hold time | days to a few weeks (max 20 D1 bars) |
| Expected drawdown profile | Standard mean-reversion drawdowns in choppy consolidation regimes. |
| Regime preference | Bullish trend / breakout above neckline in uptrend. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Source type:** book / approved internal extraction
**Pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_9947_bandy-double-bottom-formalised-mr-index.md
**R1-R4 verdict (Q00):** all PASS per approved card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | ,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV to mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Initial build from approved card | Gemini build EA task |
