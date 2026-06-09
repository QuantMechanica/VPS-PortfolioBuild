# QM5_10110_tv-sma20-200-pullback - Strategy Spec

**EA ID:** QM5_10110
**Slug:** `tv-sma20-200-pullback`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades a 20-SMA pullback in the direction of the 200-SMA trend on the chart timeframe. A long setup requires SMA(20) above SMA(200), the prior closed bar at or below SMA(20), and the latest closed bar back above SMA(20); shorts mirror the rule below SMA(20). The optional source slope filter requires SMA(200) to slope in the trade direction over the prior 10 bars. Exits use broker TP/SL plus an opposite SMA20 pullback signal when it appears first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_sma_period` | 20 | 1+ | Pullback moving-average period. |
| `strategy_slow_sma_period` | 200 | 2+ | Trend moving-average period. |
| `strategy_slope_bars` | 10 | 1+ | Bars used for the optional SMA200 slope check. |
| `strategy_use_slow_slope_filter` | true | true/false | Enables the source SMA200 slope filter. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for FX TP and distance filter. |
| `strategy_max_sma20_atr_distance` | 1.50 | 0+ | Blocks entries whose closed-bar price is too far from SMA20. |
| `strategy_max_spread_stop_frac` | 0.10 | 0+ | Blocks entries when spread exceeds this fraction of stop distance. |
| `strategy_opposing_candle_bars` | 50 | 1+ | Search window for the source opposing-candle stop. |
| `strategy_swing_fallback_bars` | 10 | 1+ | Fallback swing-stop lookback when no opposing candle qualifies. |
| `strategy_fx_tp_atr_mult` | 1.00 | 0+ | FX take-profit distance in ATR multiples. |
| `strategy_index_tp_points` | 100.0 | 0+ | Index take-profit distance in index points. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, news, seed, stress, and Friday-close inputs) are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major; OHLC-derived SMA pullback logic ports directly.
- `GBPUSD.DWX` - card-listed FX major; same trend-pullback mechanics as EURUSD.
- `NDX.DWX` - card-listed liquid index CFD; uses fixed index-point TP.
- `GDAXI.DWX` - canonical available DWX DAX symbol used in place of card-stated `GER40.DWX`.

**Explicitly NOT for:**
- Any symbol outside the active registry rows above - no runtime universe expansion is intended.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 52 |
| Typical hold time | H1 trend-pullback holds until fixed TP, structure SL, or opposite signal; typically hours to days. |
| Expected drawdown profile | Fixed-risk trend-following drawdowns during whipsaw/range regimes. |
| Regime preference | Trend-following / moving-average pullback. |
| Win rate target (qualitative) | medium |

Card frequency note: "H1 trend-pullback mode can trigger multiple times per trend; conservative filtered estimate 35-70 trades/year/symbol."

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView public Pine script
**Pointer:** `https://www.tradingview.com/script/ZqnuKIAw-20-200-SMA-Strategy/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10110_tv-sma20-200-pullback.md`

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
| v1 | 2026-06-09 | Initial build from card | 84bcc837-f939-4e92-a6ed-d038b38d572d |
