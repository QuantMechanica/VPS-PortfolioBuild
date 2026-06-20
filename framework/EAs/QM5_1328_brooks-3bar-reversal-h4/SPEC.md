# QM5_1328_brooks-3bar-reversal-h4 - Strategy Spec

**EA ID:** QM5_1328
**Slug:** brooks-3bar-reversal-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the Brooks/ForexFactory three-bar reversal pattern on closed H4 bars. A buy requires a dominant bearish trend bar, a small-bodied contained stall bar, and a bullish reversal bar closing above the trend bar close; the three-bar cluster must contain the 10-bar swing low and the reversal close must be no more than half an ATR below SMA(50). A sell mirrors the same rules around a bullish trend bar, contained stall bar, bearish reversal bar, 10-bar swing high, and SMA(50) plus half-ATR filter. Entries are market orders on the next H4 bar with a structure stop one pip beyond the cluster, a 3.5R final target, 50% partial close at 2R with the remainder moved to break-even, and a 12-bar time stop before TP1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_tf | PERIOD_H4 | H4 intended | Base timeframe for pattern, ATR, SMA, and swing tests. |
| strategy_atr_period | 14 | >=1 | ATR period for wick-poke tolerance and SMA buffer. |
| strategy_sma_period | 50 | >=1 | Macro-trend SMA period. |
| strategy_swing_lookback | 10 | >=3 | Closed-bar window for swing-low/swing-high validation. |
| strategy_trend_body_min | 0.50 | 0.0-1.0 | Minimum trend-bar body as a fraction of full range. |
| strategy_stall_body_max | 0.40 | 0.0-1.0 | Maximum stall-bar body as a fraction of full range. |
| strategy_stall_atr_poke | 0.25 | >=0.0 | ATR allowance for the stall bar to poke beyond the trend bar. |
| strategy_sma_atr_buffer | 0.50 | >=0.0 | ATR buffer around SMA(50) for the macro-trend gate. |
| strategy_tp1_rr | 2.0 | >0.0 | Initial-risk multiple for 50% partial close and break-even shift. |
| strategy_tp2_rr | 3.5 | >0.0 | Initial-risk multiple for the final take-profit. |
| strategy_tp1_close_fraction | 0.50 | 0.0-1.0 | Fraction of the open position to close at TP1. |
| strategy_time_stop_bars | 12 | >=0 | H4 bars to hold without TP1 before market close. |
| strategy_rearm_bars | 3 | >=0 | Fresh H4 bars required before same-direction re-entry after close. |
| strategy_spread_mult | 2.0 | >=0.0 | Blocks only genuinely wide spread above the median multiple. |
| strategy_spread_lookback | 20 | >=1 | Closed-bar spread samples for median spread. |

---

## 3. Symbol Universe

**Designed for:**
- AUDCAD.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- AUDCHF.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- AUDJPY.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- AUDNZD.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- AUDUSD.DWX - DWX FX major; card allows FX H4 price-action reversals.
- CADCHF.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- CADJPY.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- CHFJPY.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- EURAUD.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- EURCAD.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- EURCHF.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- EURGBP.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- EURJPY.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- EURNZD.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- EURUSD.DWX - DWX FX major; card allows FX H4 price-action reversals.
- GBPAUD.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- GBPCAD.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- GBPCHF.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- GBPJPY.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- GBPNZD.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- GBPUSD.DWX - DWX FX major; card allows FX H4 price-action reversals.
- GDAXI.DWX - DWX index CFD; card allows index CFDs on H4.
- NDX.DWX - DWX index CFD; card allows index CFDs on H4.
- NZDCAD.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- NZDCHF.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- NZDJPY.DWX - DWX FX cross; card allows FX H4 price-action reversals.
- NZDUSD.DWX - DWX FX major; card allows FX H4 price-action reversals.
- SP500.DWX - DWX custom S&P 500 backtest symbol; card allows index CFDs on H4.
- UK100.DWX - DWX index CFD; card allows index CFDs on H4.
- USDCAD.DWX - DWX FX major; card allows FX H4 price-action reversals.
- USDCHF.DWX - DWX FX major; card allows FX H4 price-action reversals.
- USDJPY.DWX - DWX FX major; card allows FX H4 price-action reversals.
- WS30.DWX - DWX index CFD; card allows index CFDs on H4.
- XAGUSD.DWX - DWX metal symbol registered in the portable matrix.
- XAUUSD.DWX - DWX gold symbol explicitly listed by the card.
- XNGUSD.DWX - DWX commodity symbol registered in the portable matrix.
- XTIUSD.DWX - DWX commodity symbol registered in the portable matrix.

**Explicitly NOT for:**
- Non-DWX symbols - V5 backtests use the `.DWX` registry and deploy stripping happens outside the EA build.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/tester matrix is the full allowed universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate; setfiles run H4. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Not specified in card frontmatter. |
| Typical hold time | Up to 12 H4 bars before TP1; remainder exits at 3.5R, break-even, SL, or Friday close. |
| Expected drawdown profile | Not specified in card frontmatter. |
| Regime preference | H4 price-action reversal at swing extremes with trend-buffer confirmation. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum/book attribution
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1328_brooks-3bar-reversal-h4.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1328_brooks-3bar-reversal-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | 835caf78-4e9d-402c-88bc-bfccffbded43 |
