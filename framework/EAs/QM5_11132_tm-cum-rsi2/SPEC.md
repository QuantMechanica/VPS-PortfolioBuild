# QM5_11132_tm-cum-rsi2 - Strategy Spec

**EA ID:** QM5_11132
**Slug:** tm-cum-rsi2
**Source:** 63b6d09c-d79f-561b-b577-eb5bf5878af1
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates the last closed D1 bar. It opens a long position on the next bar when the close is above SMA(200) and the sum of the last two closed RSI(2) values is below 35. It exits when RSI(2) closes above 65, or after 5 D1 bars if the RSI exit has not occurred. Each entry uses a 2.5 x ATR(14, D1) stop and no fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_period | 2 | 1+ | RSI lookback used in the cumulative entry and exit rules. |
| strategy_cum_window | 2 | fixed at 2 | Number of closed RSI values summed for the entry trigger. |
| strategy_cum_rsi_entry | 35.0 | 0-200 | Long entry fires when the two-bar cumulative RSI closes below this value. |
| strategy_rsi_exit | 65.0 | 0-100 | Long exit fires when RSI closes above this value. |
| strategy_sma_period | 200 | 1+ | D1 trend filter moving-average period. |
| strategy_atr_period | 14 | 1+ | D1 ATR period used for stop distance. |
| strategy_atr_sl_mult | 2.5 | 0+ | ATR multiple used to place the initial stop loss. |
| strategy_max_hold_bars | 5 | 1+ | Maximum D1 bars to hold a position. |
| strategy_max_spread_points | 300 | 0+ | Blocks new trading when current spread exceeds this many points; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 large-cap index exposure named in the approved card.
- NDX.DWX - Nasdaq 100 large-cap index exposure named in the approved card.
- WS30.DWX - Dow 30 large-cap index exposure named in the approved card.
- GDAXI.DWX - DAX 40 equivalent available in the DWX matrix for the card's GER40 target.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical DWX symbols for S&P 500 testing.

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
| Trades / year / symbol | 15 |
| Typical hold time | Up to 5 D1 bars |
| Expected drawdown profile | Short holding-period mean reversion can be exposed to continuation gaps after oversold closes. |
| Regime preference | Mean-reversion with long-term index trend alignment |
| Win rate target (qualitative) | High |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 63b6d09c-d79f-561b-b577-eb5bf5878af1
**Source type:** article
**Pointer:** David Goodboy, "The Killer App of Cumulative RSIs & 3 PowerRatings Stocks", TradingMarkets, 2010-03-05, https://tradingmarkets.com/recent/the_killer_app_of_cumulative_rsis__3_powerratings_stocks-826745
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11132_tm-cum-rsi2.md`

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
| v1 | 2026-06-07 | Initial build from card | 83e5baaa-e5a7-4822-b8c5-47a3789786b9 |
