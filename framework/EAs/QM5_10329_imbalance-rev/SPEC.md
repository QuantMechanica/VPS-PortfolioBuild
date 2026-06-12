# QM5_10329_imbalance-rev - Strategy Spec

**EA ID:** QM5_10329
**Slug:** `imbalance-rev`
**Source:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9` (see SSRN abstract 261876)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA evaluates once per D1 closed bar. It measures the prior daily return against ATR(14) and builds a daily order-imbalance proxy by summing signed M30 tick volume, where positive M30 candles add volume and negative M30 candles subtract volume. It buys at the next session open after a large negative daily return and bottom-20-percent imbalance day, and sells after a large positive daily return and top-20-percent imbalance day. The position uses a 1.25 x ATR(14) stop and exits on the first broker day after entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period used for the large-return threshold and stop distance. |
| `strategy_atr_return_mult` | 1.0 | 0.25-5.0 | Prior daily return must exceed this ATR multiple in absolute value. |
| `strategy_atr_stop_mult` | 1.25 | 0.25-10.0 | ATR multiple used for the initial stop loss. |
| `strategy_imbalance_lookback_days` | 252 | 60-500 | Number of prior D1 bars used for imbalance percentile thresholds. |
| `strategy_imbalance_tail_pct` | 20.0 | 1.0-49.0 | Lower and upper percentile tails used for reversal signals. |
| `strategy_median_range_days` | 20 | 5-100 | Prior-day range must be at least this rolling median range. |
| `strategy_min_m30_bars` | 12 | 1-48 | Minimum M30 bars required for the prior-day tick-volume proxy. |
| `strategy_spread_percentile` | 80 | 50-99 | Current spread must not exceed this historical M30 spread percentile. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 broad US index exposure named in the card and available as a backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 large-cap US index exposure named in the card.
- `WS30.DWX` - Dow 30 large-cap US index exposure named in the card.
- `GDAXI.DWX` - DAX custom symbol in the DWX matrix, used as the available DAX equivalent for the card's `GER40.DWX` reference.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure is registered as `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 aliases; the canonical custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `M30` tick-volume proxy for daily imbalance |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | `one trading day` |
| Expected drawdown profile | Mean-reversion losses cluster during persistent directional index pressure. |
| Regime preference | `mean-revert / liquidity-reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9`
**Source type:** `paper`
**Pointer:** `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=261876`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10329_imbalance-rev.md`

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
| v1 | 2026-06-12 | Initial build from card | e972895d-11b8-45ba-a400-5f07b4a3424d |

