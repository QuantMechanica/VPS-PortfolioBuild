# QM5_10266_coasensi-bb20-mr - Strategy Spec

**EA ID:** QM5_10266
**Slug:** coasensi-bb20-mr
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades a daily Bollinger Band mean-reversion rule using a 20-period SMA and two standard-deviation bands on close prices. It opens long on the next D1 bar after the prior close crosses below the lower band from above, and opens short after the prior close crosses above the upper band from below. Long positions close when the close crosses above the upper band, short positions close when the close crosses below the lower band, and any position that has not reached the opposite band is closed after 30 D1 trading bars. Each entry has a catastrophic stop at 2.5 times ATR(14) from the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_D1 | MT5 timeframe enum | Timeframe used for all Bollinger, ATR, entry, exit, and time-stop calculations. |
| strategy_bb_period | 20 | >= 2 | Bollinger moving-average and standard-deviation period. |
| strategy_bb_deviation | 2.0 | > 0 | Bollinger band deviation multiplier. |
| strategy_atr_period | 14 | > 0 | ATR period for the catastrophic stop. |
| strategy_atr_sl_mult | 2.5 | > 0 | ATR multiplier applied to the entry stop distance. |
| strategy_time_stop_bars | 30 | > 0 | Maximum holding period in D1 trading bars. |
| strategy_min_width_spread_mult | 10.0 | >= 0 | Blocks new entries when Bollinger width is less than this multiple of current spread. |
| strategy_enable_longs | true | true/false | Enables lower-band long entries. |
| strategy_enable_shorts | true | true/false | Enables upper-band short entries. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - Direct S&P 500 port from the source's index/SPX-style reports; backtest-only custom symbol per DWX discipline.
- NDX.DWX - Liquid US large-cap index proxy suitable for the same daily index mean-reversion pattern.
- WS30.DWX - Liquid US large-cap index proxy suitable for the same daily index mean-reversion pattern.
- EURUSD.DWX - Secondary sanity-check FX symbol because the source includes EURUSD-style reports.

**Explicitly NOT for:**
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical DWX symbols in the approved symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | 1 to 30 D1 trading bars |
| Expected drawdown profile | Mean-reversion drawdowns can cluster during strong one-way trends; catastrophic ATR stop bounds single-trade loss. |
| Regime preference | Mean-reverting daily markets after outer Bollinger band excursions. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository and notebook
**Pointer:** coasensi/bollingerbands-backtest README and notebook, https://github.com/coasensi/bollingerbands-backtest and https://github.com/coasensi/bollingerbands-backtest/blob/main/report/bollingerband-backtest.ipynb
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10266_coasensi-bb20-mr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | a3723153-e6e8-4908-8f24-9c4f569cad0b |
