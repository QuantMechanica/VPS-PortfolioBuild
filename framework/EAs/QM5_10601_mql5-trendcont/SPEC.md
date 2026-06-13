# QM5_10601_mql5-trendcont - Strategy Spec

**EA ID:** QM5_10601
**Slug:** mql5-trendcont
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA reads the source-default TrendContinuation custom indicator on completed H4 bars. It enters long when the indicator state flips from bearish to bullish, and enters short when it flips from bullish to bearish. An open long closes when the state turns bearish, an open short closes when the state turns bullish, and any position also closes after 16 completed H4 bars. Each entry receives a catastrophic stop at 2.5 x ATR(14), with no take-profit target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H4` | H4 primary | Timeframe used for TrendContinuation and ATR reads |
| `strategy_indicator_name` | `TrendContinuation` | installed MT5 indicator name | Custom indicator to load from terminal `MQL5/Indicators` |
| `strategy_tc_period` | `20` | `> 1` | TrendContinuation `NPeriod` source default |
| `strategy_tc_smooth_method` | `7` | SmoothAlgorithms enum | TrendContinuation `XMethod`; `7` is source default `MODE_T3` |
| `strategy_tc_smooth_period` | `5` | `> 0` | TrendContinuation smoothing depth source default |
| `strategy_tc_smooth_phase` | `61` | indicator-defined | TrendContinuation smoothing phase source default |
| `strategy_tc_applied_price` | `1` | Applied_price_ enum | TrendContinuation applied price; `1` is source default close |
| `strategy_atr_period` | `14` | `> 0` | ATR period for the catastrophic stop |
| `strategy_atr_sl_mult` | `2.5` | `> 0` | ATR multiple for the catastrophic stop |
| `strategy_max_hold_bars` | `16` | `> 0` | Fallback maximum holding time in H4 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source test symbol and primary FX baseline from the card
- `GBPUSD.DWX` - liquid DWX FX symbol included in the card's portable basket
- `USDJPY.DWX` - liquid DWX FX symbol included in the card's portable basket
- `XAUUSD.DWX` - liquid DWX metal CFD included in the card's portable basket

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tick-data registration target

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | H4 color-state trend holds; fallback exit after 16 H4 bars |
| Expected drawdown profile | Trend-following drawdowns during color-state whipsaws, bounded by ATR catastrophic stop |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/1596
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10601_mql5-trendcont.md`

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
| v1 | 2026-06-13 | Initial build from card | b51449e3-3cf3-490c-a02d-d6fecd9de52b |
