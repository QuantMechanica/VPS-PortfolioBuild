# QM5_1328_brooks-3bar-reversal-h4 - Strategy Spec

**EA ID:** QM5_1328
**Slug:** brooks-3bar-reversal-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades the H4 Brooks three-bar reversal sequence. A buy setup requires a dominant bearish trend bar, a smaller stalling bar contained around that range, and a bullish reversal bar closing above the trend bar close while the three-bar cluster marks the 10-bar swing low and remains within the SMA(50) plus ATR buffer. A sell setup mirrors the same rules at a 10-bar swing high. The stop is placed one pip beyond the three-bar cluster, TP1 closes half at 2R and moves the rest to break-even, TP2 is 3.5R, and a 12-bar time stop exits positions that have not reached TP1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_tf | PERIOD_H4 | H4 per card | Base timeframe for pattern, ATR, SMA, and spread median. |
| strategy_atr_period | 14 | > 1 | ATR period used for stall wick allowance and SMA buffer. |
| strategy_sma_period | 50 | > 1 | SMA period used for macro-trend filter. |
| strategy_swing_lookback | 10 | >= 3 | Closed-bar lookback for swing-low or swing-high test. |
| strategy_trend_body_min | 0.50 | 0.0-1.0 | Minimum trend-bar body as a fraction of total range. |
| strategy_stall_body_max | 0.40 | 0.0-1.0 | Maximum stall-bar body as a fraction of total range. |
| strategy_stall_atr_poke | 0.25 | >= 0.0 | ATR allowance for stall-bar wick poke beyond the trend bar. |
| strategy_sma_atr_buffer | 0.50 | >= 0.0 | ATR buffer around SMA(50) for macro-trend gate. |
| strategy_tp1_rr | 2.0 | > 0.0 | First take-profit reward/risk multiple. |
| strategy_tp2_rr | 3.5 | > strategy_tp1_rr | Final take-profit reward/risk multiple. |
| strategy_tp1_close_fraction | 0.50 | 0.0-1.0 | Fraction of position closed at TP1. |
| strategy_time_stop_bars | 12 | >= 1 | H4 bars allowed without TP1 before time-stop exit. |
| strategy_rearm_bars | 3 | >= 0 | Same-direction re-arm block after a position closes. |
| strategy_spread_mult | 2.0 | >= 0.0 | Maximum current spread as a multiple of median spread. |
| strategy_spread_lookback | 20 | >= 1 | H4 bars used for median spread guard. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - active DWX FX major with H4 candle liquidity.
- GBPUSD.DWX - active DWX FX major with H4 candle liquidity.
- USDJPY.DWX - active DWX FX major with H4 candle liquidity.
- AUDUSD.DWX - active DWX FX major with H4 candle liquidity.
- USDCAD.DWX - active DWX FX major with H4 candle liquidity.
- USDCHF.DWX - active DWX FX major with H4 candle liquidity.
- NZDUSD.DWX - active DWX FX major with H4 candle liquidity.
- XAUUSD.DWX - active DWX metal with liquid H4 reversal structure.
- NDX.DWX - active DWX index CFD with liquid H4 reversal structure.
- WS30.DWX - active DWX index CFD with liquid H4 reversal structure.
- GDAXI.DWX - active DWX index CFD with liquid H4 reversal structure.
- UK100.DWX - active DWX index CFD with liquid H4 reversal structure.
- AUDCAD.DWX - active DWX FX cross with H4 candle liquidity.
- AUDCHF.DWX - active DWX FX cross with H4 candle liquidity.
- AUDJPY.DWX - active DWX FX cross with H4 candle liquidity.
- AUDNZD.DWX - active DWX FX cross with H4 candle liquidity.
- CADCHF.DWX - active DWX FX cross with H4 candle liquidity.
- CADJPY.DWX - active DWX FX cross with H4 candle liquidity.
- CHFJPY.DWX - active DWX FX cross with H4 candle liquidity.
- EURAUD.DWX - active DWX FX cross with H4 candle liquidity.
- EURCAD.DWX - active DWX FX cross with H4 candle liquidity.
- EURCHF.DWX - active DWX FX cross with H4 candle liquidity.
- EURGBP.DWX - active DWX FX cross with H4 candle liquidity.
- EURJPY.DWX - active DWX FX cross with H4 candle liquidity.
- EURNZD.DWX - active DWX FX cross with H4 candle liquidity.
- GBPAUD.DWX - active DWX FX cross with H4 candle liquidity.
- GBPCAD.DWX - active DWX FX cross with H4 candle liquidity.
- GBPCHF.DWX - active DWX FX cross with H4 candle liquidity.
- GBPJPY.DWX - active DWX FX cross with H4 candle liquidity.
- GBPNZD.DWX - active DWX FX cross with H4 candle liquidity.
- NZDCAD.DWX - active DWX FX cross with H4 candle liquidity.
- NZDCHF.DWX - active DWX FX cross with H4 candle liquidity.
- NZDJPY.DWX - active DWX FX cross with H4 candle liquidity.
- SP500.DWX - active DWX S&P 500 custom symbol, backtest-only per registry discipline.
- XAGUSD.DWX - active DWX metal with liquid H4 reversal structure.
- XNGUSD.DWX - active DWX commodity CFD with H4 reversal structure.
- XTIUSD.DWX - active DWX commodity CFD with H4 reversal structure.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX test data or registry slot.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_tf)` in `OnTick` before entry evaluation |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Not stated in card frontmatter; pattern is expected to be sparse-to-moderate on H4. |
| Typical hold time | Up to 12 H4 bars without TP1; winners can reach TP1/TP2 earlier by RR. |
| Expected drawdown profile | Reversal-pattern drawdown, bounded by fixed initial-risk stop. |
| Regime preference | Price-action mean-reversion at swing extremes with SMA/ATR macro filter. |
| Win rate target (qualitative) | Not stated in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum/book-derived strategy note
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1328_brooks-3bar-reversal-h4.md`
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
| v1 | 2026-06-05 | Initial build from card | f6f01c53-7a7d-45ec-a0b0-f4ac67028d10 |
