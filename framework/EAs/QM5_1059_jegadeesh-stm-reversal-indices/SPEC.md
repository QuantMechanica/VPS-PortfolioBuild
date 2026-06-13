# QM5_1059_jegadeesh-stm-reversal-indices - Strategy Spec

**EA ID:** QM5_1059
**Slug:** jegadeesh-stm-reversal-indices
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853 (see `strategy-seeds/sources/7ede58dd-d184-5099-9d48-7a65de230853/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

Each Friday at or after 22:00 broker time, the EA ranks the registered index basket by 5-day return. The current chart symbol is bought if it is the worst 5-day performer in the basket and sold if it is the best 5-day performer. Existing positions are closed at the next Friday rebalance window, then a new qualifying weekly leg can be opened. Entries are skipped when the symbol's ATR(20) divided by price is above 3% or when current spread is greater than 5 times the recent H1 median spread.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_hour_broker` | 22 | 0-23 | Earliest broker hour on Friday when weekly close/rebalance can run. |
| `strategy_return_d1_bars` | 5 | 1+ | Lookback in D1 bars for the short-term reversal return rank. |
| `strategy_atr_stop_period` | 14 | 1+ | ATR period for the hard stop. |
| `strategy_atr_stop_mult` | 3.0 | >0 | ATR multiple for the hard stop distance. |
| `strategy_vol_atr_period` | 20 | 1+ | ATR period for the volatility gate. |
| `strategy_vol_max_atr_close` | 0.03 | >0 | Maximum ATR/price ratio allowed for ranking and entry. |
| `strategy_spread_median_bars` | 20 | 1+ | H1 spread sample count used for the median spread gate. |
| `strategy_spread_mult` | 5.0 | >0 | Maximum current-spread multiple of median spread. |
| `strategy_min_rank_symbols` | 4 | 2-4 | Minimum number of qualified basket symbols required before ranking. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index exposure from the card's index basket.
- `WS30.DWX` - Dow 30 index exposure from the card's index basket.
- `GDAXI.DWX` - canonical matrix symbol for the card's GER40/DAX exposure.
- `UK100.DWX` - FTSE 100 index exposure from the card's index basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `JPN225.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`.
- `AUS200.DWX` - mentioned as "check availability" in the card but absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` closes for 5-day return ranking; `D1` ATR for volatility and stops; `H1` spreads for spread median |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | About 5 trading days, Friday rebalance to Friday rebalance |
| Expected drawdown profile | Mean-reversion losses are bounded by the 3x ATR hard stop per leg |
| Regime preference | Short-term mean-reversion after one-week relative underperformance or outperformance |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7ede58dd-d184-5099-9d48-7a65de230853
**Source type:** encyclopedia entry with academic paper backbone
**Pointer:** Quantpedia Short-Term Reversal entry; Jegadeesh (1990) and Lehmann (1990)
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1059_jegadeesh-stm-reversal-indices.md`

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
| v1 | 2026-06-13 | Initial build from card | ee64ff94-3341-4a05-ac23-3d7c37d447be |
