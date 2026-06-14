# QM5_10861_tv-fli-stc - Strategy Spec

**EA ID:** QM5_10861
**Slug:** tv-fli-stc
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades closed-bar Follow Line direction flips built from Bollinger Band break state with ATR availability required. A long entry requires a bullish Follow Line flip plus at least two bullish confirmations from Schaff Trend Cycle slope or threshold cross, MACD cross or histogram slope, and close above EMA(200). A short entry mirrors the same logic with bearish Follow Line, bearish STC, bearish MACD, and close below EMA(200). Exits occur through the initial ATR stop, ATR target, opposite Follow Line flip, opposite MACD cross, or a 36-hour time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | >= 2 | Bollinger Band period for Follow Line break state. |
| strategy_bb_deviation | 2.0 | > 0 | Bollinger Band deviation multiplier. |
| strategy_follow_lookback | 80 | >= 3 | Closed bars scanned to recover current Follow Line direction. |
| strategy_stc_cycle | 10 | >= 2 | MACD stochastic cycle used for the STC confirmation proxy. |
| strategy_stc_bull_level | 25.0 | 0-100 | Bullish STC threshold level. |
| strategy_stc_bear_level | 75.0 | 0-100 | Bearish STC threshold level. |
| strategy_macd_fast | 12 | >= 1 | Fast MACD EMA period. |
| strategy_macd_slow | 26 | > fast | Slow MACD EMA period. |
| strategy_macd_signal | 9 | >= 1 | MACD signal EMA period. |
| strategy_ema_period | 200 | >= 2 | EMA bias period. |
| strategy_atr_period | 14 | >= 1 | ATR period for stop and target. |
| strategy_atr_sl_mult | 1.5 | > 0 | Initial stop distance in ATR multiples. |
| strategy_atr_tp_mult | 2.5 | > 0 | Initial target distance in ATR multiples. |
| strategy_time_exit_hours | 36 | >= 0 | Maximum hold time in hours; 0 disables the time exit. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair listed in the card R3 basket.
- GBPUSD.DWX - liquid major FX pair listed in the card R3 basket.
- USDJPY.DWX - liquid major FX pair listed in the card R3 basket.
- XAUUSD.DWX - liquid metal CFD listed in the card R3 basket.
- GDAXI.DWX - verified DWX DAX custom symbol used as the canonical port for the card's GER40 target.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 36 H1 bars unless ATR stop/target or opposite signal exits first |
| Expected drawdown profile | Medium-cadence confluence trend strategy; main risk is over-filtering |
| Regime preference | trend-following with momentum confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script "FLI + STC + MACD + EMA Strategy v1", author `wikitrader1`, Apr 3; approved card at `artifacts/cards_approved/QM5_10861_tv-fli-stc.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10861_tv-fli-stc.md`

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
| v1 | 2026-06-14 | Initial build from card | 270b5791-af23-424b-96e0-b23570d6f27b |
