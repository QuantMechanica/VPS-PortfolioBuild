# QM5_9271_mql5-ifvg-reversal - Strategy Spec

**EA ID:** QM5_9271
**Slug:** `mql5-ifvg-reversal`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA detects a three-candle fair value gap on closed M30 bars, requiring the gap width to be at least the larger of 5 points or 0.20 ATR(14), and no more than 1.50 ATR(14). A gap remains active until price trades back into it; if a bearish gap then closes beyond its upper edge, the EA waits for the next candle to close above the midpoint and enters long. If a bullish gap closes beyond its lower edge, the EA waits for the next candle to close below the midpoint and enters short. Each gap is traded once, with a 2.0R target, an ATR-buffered stop beyond the IFVG edge, an early close on a closed-bar midpoint failure, and a 48-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1-200 | ATR period used for gap-size filtering and the stop buffer. |
| `strategy_min_gap_points` | 5.0 | >0 | Minimum absolute FVG width in symbol points. |
| `strategy_min_gap_atr_mult` | 0.20 | >0 | ATR fraction used as the volatility-scaled minimum FVG width. |
| `strategy_max_gap_atr_mult` | 1.50 | >0 | Maximum allowed FVG width as an ATR multiple. |
| `strategy_stop_atr_mult` | 0.50 | >0 | ATR buffer placed beyond the IFVG low for longs or high for shorts. |
| `strategy_target_r_multiple` | 2.00 | >0 | Fixed reward-to-risk target multiple. |
| `strategy_max_hold_bars` | 48 | 1-500 | Maximum hold time measured in base-timeframe bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with DWX OHLC and ATR data.
- `GBPJPY.DWX` - card-listed FX cross with DWX OHLC and ATR data.
- `XAUUSD.DWX` - card-listed metal symbol with DWX OHLC and ATR data.
- `NDX.DWX` - card-listed liquid index symbol with DWX OHLC and ATR data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no validated DWX data source for build registration.

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
| Trades / year / symbol | `100` |
| Typical hold time | Up to 48 M30 bars; earlier exits on midpoint failure, stop, target, or framework Friday close. |
| Expected drawdown profile | Bounded per-trade risk from ATR-buffered IFVG stops and fixed 2R target. |
| Regime preference | Price-action reversal after mitigated fair value gaps invert. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 45): Inverse Fair Value Gap (IFVG)", MQL5 Articles, 2025-12-08, https://www.mql5.com/en/articles/20361
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9271_mql5-ifvg-reversal.md`

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
| v1 | 2026-06-10 | Initial build from card | 54c51c9d-d802-4f98-a330-ff4c2982c332 |
