# QM5_10338_intraday-comp-mom - Strategy Spec

**EA ID:** QM5_10338
**Slug:** intraday-comp-mom
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

On each D1 bar, the EA ranks the registered index basket by the rolling 20-session sum of log intraday returns, measured as close divided by the same session open. On the Monday rebalance bar it goes long only when the chart symbol is the top-ranked positive member and its score is at least 0.50 times ATR(20) divided by close above the basket median. It goes short only when the chart symbol is the bottom-ranked negative member and its score is at least the same ATR-normalized threshold below the median. Existing positions exit after five sessions, when the symbol's cached score crosses back through the basket median, or under framework Friday-close rules.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_basket_symbols | SP500.DWX,NDX.DWX,WS30.DWX,GDAXI.DWX | comma-separated DWX symbols | Cross-sectional basket used for ranking. |
| strategy_rebalance_day_of_week | 1 | 0-6 | Broker day for weekly rebalance, with Monday = 1. |
| strategy_component_lookback | 20 | >= 1 | Number of closed D1 sessions used for intraday and overnight component sums. |
| strategy_rank_atr_period | 20 | >= 1 | ATR period for the entry distance from basket median. |
| strategy_rank_atr_mult | 0.50 | > 0 | Multiplier applied to ATR(20) / close for median-distance threshold. |
| strategy_stop_atr_period | 14 | >= 1 | ATR period for initial stop placement. |
| strategy_stop_atr_mult | 2.0 | > 0 | Multiplier for the initial ATR stop. |
| strategy_hold_sessions | 5 | >= 1 | Maximum holding period in D1 sessions. |
| strategy_min_valid_symbols | 3 | 1-4 | Minimum basket members with usable open and close data. |
| strategy_spread_lookback | 80 | >= 20 | Closed D1 bars used for rolling spread percentile. |
| strategy_spread_percentile | 80.0 | 0-100 | Current spread must not exceed this historical percentile. |
| strategy_min_stop_spread_mult | 4.0 | > 0 | Stop distance must be at least this many current spreads. |
| strategy_overnight_conflict_ratio | 1.0 | >= 0 | Overnight component blocks entry when opposite in sign and at least this large versus intraday component. |
| strategy_basket_warmup_bars | 96 | >= 21 | History bars preloaded for basket symbols in the tester. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol, part of the approved index momentum basket.
- NDX.DWX - Nasdaq 100 index CFD, part of the approved US large-cap basket.
- WS30.DWX - Dow 30 index CFD, part of the approved US large-cap basket.
- GDAXI.DWX - DAX 40 index CFD, used as the available matrix equivalent for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- SPX500.DWX - not a canonical DWX custom symbol for the S&P 500.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | five trading sessions |
| Expected drawdown profile | ATR-stopped weekly index momentum with single-position exposure. |
| Regime preference | momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4069509
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10338_intraday-comp-mom.md`

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
| v1 | 2026-06-13 | Initial build from card | 350b7050-8b13-4482-8baa-40dcfedc065b |
