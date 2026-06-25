# QM5_11828_carter-m5-s18-ema20-macd-10pip-m5 - Strategy Spec

**EA ID:** QM5_11828
**Slug:** carter-m5-s18-ema20-macd-10pip-m5
**Source:** f4430cee-7efb-592e-bf0f-e469ef156b2d (see local Carter PDF source)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades the M5 chart when the last closed candle is at least 10 pips beyond EMA(20) in the direction of the trend and MACD(12,26,9) histogram agrees with that direction. It buys when close[1] is above EMA(20)[1] plus 10 pips and the MACD histogram is positive. It sells when close[1] is below EMA(20)[1] minus 10 pips and the MACD histogram is negative. Initial protection is 2x ATR(14), maximum take profit is 4x ATR(14), and open positions trail the stop against EMA(20) plus or minus 15 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 20 | >= 1 | EMA period used for trend filter and trailing stop reference. |
| strategy_macd_fast | 12 | >= 1 and < slow | MACD fast EMA period. |
| strategy_macd_slow | 26 | > fast | MACD slow EMA period. |
| strategy_macd_signal | 9 | >= 1 | MACD signal period. |
| strategy_offset_pips | 10 | >= 1 | Required price distance from EMA(20) before entry. |
| strategy_atr_period | 14 | >= 1 | ATR period for initial stop and maximum take profit. |
| strategy_atr_sl_mult | 2.0 | > 0 | Initial stop distance in ATR multiples. |
| strategy_atr_tp_mult | 4.0 | > 0 | Maximum take-profit distance in ATR multiples. |
| strategy_trail_pips | 15 | >= 1 | EMA-referenced trailing stop offset in pips. |
| strategy_spread_cap_pips | 5 | >= 1 | Blocks entries only when live spread is wider than this cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card target; major liquid FX pair in the DWX matrix.
- GBPUSD.DWX - card target; major liquid FX pair in the DWX matrix.
- USDJPY.DWX - card target; major liquid FX pair in the DWX matrix.
- USDCHF.DWX - card target; major liquid FX pair in the DWX matrix.
- AUDUSD.DWX - card target; major liquid FX pair in the DWX matrix.

**Explicitly NOT for:**
- Non-FX index symbols - the card targets five major forex pairs, not index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Not specified in card; expected intraday M5 holds with EMA trailing stop. |
| Expected drawdown profile | Not specified in card; trend-following pullback/continuation risk profile. |
| Regime preference | Trend-following momentum. |
| Win rate target (qualitative) | Not specified in card; medium assumed for an M5 momentum continuation system. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Source type:** local PDF
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 2014, Strategy 18.
**R1-R4 verdict (Q00):** frontmatter all PASS / see `artifacts/cards_approved/QM5_11828_carter-m5-s18-ema20-macd-10pip-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | 17bca214-f67b-4174-816d-2f658f5308e4 |
