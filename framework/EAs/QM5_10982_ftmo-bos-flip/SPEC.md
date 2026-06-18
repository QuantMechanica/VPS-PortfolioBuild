# QM5_10982_ftmo-bos-flip - Strategy Spec

**EA ID:** QM5_10982
**Slug:** ftmo-bos-flip
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA builds H1 swing highs and lows with a 3-left / 3-right fractal definition. A long setup starts only after the two most recent confirmed swing highs and lows show bearish structure, then an H1 candle closes above the most recent lower high by at least 0.15 x ATR(14); the EA waits up to 12 H1 bars for a retest of the broken level and a bullish rejection candle. A short setup is the mirror image from bullish structure, a close below the most recent higher low, and a bearish retest rejection. Stops sit 0.25 x ATR beyond the retest candle, targets are 2.0R, SL moves to breakeven after 1.0R, and discretionary exit closes on a zone failure or after 40 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fractal_left | 3 | 1-10 | Bars to the left of a pivot in the fractal swing definition. |
| strategy_fractal_right | 3 | 1-10 | Bars to the right of a pivot required for confirmation. |
| strategy_atr_period | 14 | 1-100 | ATR period for BOS threshold, retest zone width, and stop buffer. |
| strategy_bos_atr_mult | 0.15 | 0.01-2.0 | Minimum close-through distance beyond the broken swing level. |
| strategy_zone_atr_mult | 0.25 | 0.01-2.0 | Retest zone half-width and stop buffer as ATR multiple. |
| strategy_retest_window | 12 | 1-100 | Maximum H1 bars allowed between BOS and retest entry. |
| strategy_wick_frac | 0.40 | 0.01-1.0 | Required rejection wick fraction of candle range. |
| strategy_maxbreak_atr_mult | 3.0 | 0.5-10.0 | Rejects exhausted break candles larger than this ATR multiple. |
| strategy_tp_rr | 2.0 | 0.1-10.0 | Fixed take-profit multiple of initial risk. |
| strategy_be_trigger_rr | 1.0 | 0.1-10.0 | Profit multiple that triggers SL to breakeven. |
| strategy_time_exit_bars | 40 | 1-500 | Maximum H1 bars to hold a position. |
| strategy_structure_scan | 120 | 20-1000 | Bounded swing scan window for market-structure detection. |
| strategy_spread_median_bars | 20 | 1-200 | Median spread lookback used by the card spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX major with full DWX availability.
- GBPUSD.DWX - card-listed liquid FX major with full DWX availability.
- XAUUSD.DWX - card-listed gold instrument with DWX availability.
- GDAXI.DWX - DWX matrix DAX instrument used as the nearest available port for card-listed GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Up to 40 H1 bars |
| Expected drawdown profile | Breakout/retest false-break losses clustered in range-bound conditions. |
| Regime preference | Breakout / market-structure reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO blog
**Pointer:** https://ftmo.com/en/blog/how-to-read-market-structure-and-price-action-patterns/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10982_ftmo-bos-flip.md`

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
| v1 | 2026-06-18 | Initial build from card | bca8df86-328f-4ec4-ac92-0a119a757d3e |
