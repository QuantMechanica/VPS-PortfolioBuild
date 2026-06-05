# QM5_10827_tv-vol-exp - Strategy Spec

**EA ID:** QM5_10827
**Slug:** tv-vol-exp
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA builds a rolling consolidation box from the highest high and lowest low of the last `strategy_lookback_bars` closed bars. It places a buy stop at `boxHigh + strategy_outlier_mult * ATR(14)` and a sell stop at `boxLow - strategy_outlier_mult * ATR(14)` when there is no open position. The stop is based on the box midline by default, clamped between `strategy_min_stop_atr` and `strategy_max_stop_atr`, and the take profit is `strategy_rr_target` times the final stop distance. Pending stop orders expire after `strategy_stale_bars` or are cancelled when the box range expands above `strategy_max_range_atr * ATR`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_bars` | 20 | 12-32 tested | Rolling consolidation box length. |
| `strategy_atr_period` | 14 | fixed by card | ATR period used for outlier trigger and stop clamps. |
| `strategy_outlier_mult` | 1.5 | 1.0-2.0 tested | ATR multiple added beyond the box edge for stop entries. |
| `strategy_rr_target` | 2.0 | 1.5-2.5 tested | Take-profit multiple of risk distance. |
| `strategy_midline_stop` | true | true/false tested | Use the consolidation-box midline as the raw stop anchor. |
| `strategy_atr_fallback_mult` | 2.0 | 1.5-2.5 tested | ATR stop distance when midline stop is disabled. |
| `strategy_stale_bars` | 12 | 6-24 tested | Maximum age for unfilled stop orders. |
| `strategy_max_range_atr` | 2.5 | card fixed | Cancel or block orders when the box is wider than this ATR multiple. |
| `strategy_min_stop_atr` | 0.5 | card fixed | Minimum stop distance as ATR multiple. |
| `strategy_max_stop_atr` | 3.0 | card fixed | Maximum stop distance as ATR multiple. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Card names gold and the source risk profile references gold-style volatility breakout behavior.
- `EURUSD.DWX` - Card R3 includes DWX FX symbols and this pair has native OHLC and ATR coverage.
- `GBPUSD.DWX` - Card R3 includes DWX FX symbols and this pair has native OHLC and ATR coverage.
- `GDAXI.DWX` - Registered DAX equivalent because card-stated `GER40.DWX` is not present in `dwx_symbol_matrix.csv`.
- `NDX.DWX` - Card R3 includes Nasdaq 100 as a liquid index CFD target.
- `WS30.DWX` - Card R3 includes Dow 30 as a liquid index CFD target.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in the DWX symbol matrix; use `GDAXI.DWX`.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol tick coverage for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Not specified in card; exits via stop, RR target, or closed-bar midline failure. |
| Expected drawdown profile | False-breakout risk during news spikes and overfit consolidation windows. |
| Regime preference | Volatility-expansion breakout after compression. |
| Win rate target (qualitative) | Medium; RR target default is 2.0. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Decoded Volatility Expansion [Ahtisham]`, author handle `AHTISHAM_EE`, https://www.tradingview.com/script/qgLu0K0v-Decoded-Volatility-Expansion-Ahtisham/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10827_tv-vol-exp.md`

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
| v1 | 2026-06-06 | Initial build from card | 0713c3c9-0575-4ff3-93c5-01af2aa45a4a |
