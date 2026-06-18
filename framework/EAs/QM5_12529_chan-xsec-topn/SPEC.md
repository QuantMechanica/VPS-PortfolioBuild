# QM5_12529_chan-xsec-topn - Strategy Spec

**EA ID:** QM5_12529
**Slug:** `chan-xsec-topn`
**Source:** `cfeee113-154e-549a-9fba-501b7e3160c0` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates the basket once per completed D1 bar. It computes each active symbol's percent return over the configured D1 lookback, subtracts the basket mean return, and uses the negative deviation as the contrarian score. The symbols with the largest absolute scores are selected, and their target weights are normalized by the sum of selected absolute scores. A chart symbol enters long when its selected weight is above the minimum absolute target threshold, enters short when the selected weight is below the negative threshold, and exits when it falls out of the selected set or the target sign reverses.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_num_positions` | 3 | 1 to basket size | Number of symbols selected by absolute contrarian score. |
| `strategy_min_abs_weight` | 0.05 | 0.03 to 0.08 tested | Minimum absolute normalized target weight required for a new entry. |
| `strategy_return_lookback_d1` | 1 | 1 to 3 D1 bars tested | D1 return lookback used for cross-sectional score calculation. |
| `strategy_min_active_symbols` | 5 | 1 to basket size | Minimum number of symbols with usable D1 closes before any signal is valid. |
| `strategy_atr_period` | 20 | fixed by card stop rule | ATR period for the emergency stop. |
| `strategy_atr_sl_mult` | 3.0 | 2.0 to 4.0 tested | ATR multiplier for the emergency stop distance. |
| `strategy_spread_median_days` | 60 | fixed by card filter | D1 bars used to estimate median modeled spread. |
| `strategy_spread_mult` | 2.0 | fixed by card filter | Blocks new entries when current spread exceeds this multiple of the median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX leg in the card's macro basket.
- `GBPUSD.DWX` - liquid major FX leg in the card's macro basket.
- `USDJPY.DWX` - liquid major FX leg in the card's macro basket.
- `AUDUSD.DWX` - liquid major FX leg in the card's macro basket.
- `USDCAD.DWX` - liquid major FX leg in the card's macro basket.
- `NDX.DWX` - liquid US index leg in the card's macro basket.
- `WS30.DWX` - liquid US index leg in the card's macro basket.
- `XAUUSD.DWX` - liquid metals leg in the card's macro basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available to the DWX tester.
- Single-symbol deployment - the signal requires a cross-sectional basket and at least five active D1 return series.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Expected trade frequency | daily rebalance cadence; frontmatter has no separate `expected_trade_frequency` field |
| Typical hold time | signal-rebalance hold; frontmatter has no explicit hold-time field |
| Expected drawdown profile | higher concentration than broad cross-sectional allocation |
| Regime preference | cross-sectional mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cfeee113-154e-549a-9fba-501b7e3160c0`
**Source type:** blog article
**Pointer:** Teddy Koker, "Improving Cross Sectional Mean Reversion Strategy in Python", published 2019-05-05, https://teddykoker.com/2019/05/improving-cross-sectional-mean-reversion-strategy-in-python/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12529_chan-xsec-topn.md`

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
| v1 | 2026-06-18 | Initial build from card | d687ed5d-2897-4553-aa52-1e635a8f3a07 |
