# QM5_10432_et-sp-bbshort — Strategy Spec

**EA ID:** QM5_10432
**Slug:** `et-sp-bbshort`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA trades a short-only daily Bollinger reversal. On each completed D1 bar, it checks whether the close is above the upper Bollinger Band using SMA(20) plus 2.0 standard deviations. If flat, it opens a short at the next daily bar with a protective stop 2.5 ATR(20) above entry. It exits when the completed daily close returns below the Bollinger midline, when 5 completed daily bars have elapsed, or when the protective stop is hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_D1` | `PERIOD_D1` | Baseline signal and exit timeframe from the card. |
| `strategy_bb_period` | `20` | `15-30` | Bollinger moving-average and standard-deviation lookback. |
| `strategy_bb_deviation` | `2.0` | `1.5-2.5` | Standard-deviation multiplier for the Bollinger bands. |
| `strategy_atr_period` | `20` | `20` | ATR lookback used for the protective stop. |
| `strategy_atr_stop_mult` | `2.5` | `2.0-3.0` | ATR multiple added above short entry for the stop. |
| `strategy_hold_bars` | `5` | `3-10` | Maximum completed D1 bars to hold before covering. |
| `strategy_min_history_bars` | `230` | `50+` | Warmup guard for Bollinger, ATR, and long-index history. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — primary S&P 500 custom symbol named by the card and available for backtest.
- `NDX.DWX` — portable US large-cap index CFD fallback from the card basket.
- `WS30.DWX` — portable US large-cap index CFD fallback from the card basket.
- `GDAXI.DWX` — verified DAX custom symbol used because `GER40.DWX` is not in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `SPX500.DWX` — not a canonical available custom symbol.
- `SPY.DWX` — not a canonical available custom symbol.
- `ES.DWX` — not a canonical available custom symbol.
- `GER40.DWX` — card-stated DAX alias, but not present in `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with `Strategy_NoTradeFilter` requiring `_Period == PERIOD_D1` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | `up to 5 daily bars` |
| Expected drawdown profile | Short-only equity-index mean reversion can lose repeatedly in strong bull markets. |
| Regime preference | `mean-revert / index-hedge` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/short-s-p-system.180794/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10432_et-sp-bbshort.md`

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
| v1 | 2026-05-27 | Initial build from card | edba1fd6-8636-4632-99e0-088a8f0f61e2 |
