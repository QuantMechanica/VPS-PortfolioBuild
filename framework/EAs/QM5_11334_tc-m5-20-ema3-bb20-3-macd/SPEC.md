# QM5_11334_tc-m5-20-ema3-bb20-3-macd - Strategy Spec

**EA ID:** QM5_11334
**Slug:** `tc-m5-20-ema3-bb20-3-macd`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the M5 Thomas Carter System #20 signal. It opens long when EMA(3) crosses above the Bollinger Bands(20, 3) middle line on the latest closed bar and MACD(12, 26, 9) is either rising toward zero from below or has crossed above zero within the configured lookback. It opens short on the mirrored EMA cross below the middle line with MACD approaching or crossing zero from above. Each entry uses a fixed 12-pip stop and a fixed 12-pip target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 3 | 1+ | Fast EMA period crossing the Bollinger middle line. |
| `strategy_bb_period` | 20 | 2+ | Bollinger period; the middle line is the SMA of this period. |
| `strategy_bb_dev` | 3.0 | positive | Bollinger deviation parameter from the card. |
| `strategy_macd_fast` | 12 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | greater than fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1+ | MACD signal period. |
| `strategy_macd_lookback` | 3 | 0+ | Closed bars to search for a MACD zero-line cross. |
| `strategy_sl_pips` | 12 | 1+ | Fixed stop loss in pips, midpoint of the card's 10-15 pip range. |
| `strategy_tp_pips` | 12 | 1+ | Fixed take profit in pips, midpoint of the card's 10-15 pip range. |
| `strategy_max_spread_pips` | 8 | 0+ | Spread cap in pips; zero modeled spread is allowed. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid M5 major FX pair with DWX history.
- `GBPUSD.DWX` - card-listed liquid M5 major FX pair with DWX history.
- `USDJPY.DWX` - card-listed liquid M5 major FX pair with DWX history.

**Explicitly NOT for:**
- Non-DWX symbols - V5 backtest and registry discipline requires `.DWX` symbols.
- Indices, metals, and commodities - the card specifies a three-pair FX basket only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | Card does not specify; expected to be short M5 scalp holds governed by a 12-pip bracket. |
| Expected drawdown profile | Tight fixed SL/TP scalp profile; drawdown should be trade-frequency driven. |
| Regime preference | Trend-following / moving-average crossover with MACD zero-line confirmation. |
| Win rate target (qualitative) | Not specified by card; fixed 1R bracket implies medium target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** book/PDF
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), 5 Min Trading System #20, local PDF path `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11334_tc-m5-20-ema3-bb20-3-macd.md`

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
| v1 | 2026-06-20 | Initial build from card | 6d259c30-5665-4838-8eec-822bcfd796aa |
