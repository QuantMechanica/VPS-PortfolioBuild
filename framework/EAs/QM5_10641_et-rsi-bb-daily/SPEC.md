# QM5_10641_et-rsi-bb-daily - Strategy Spec

**EA ID:** QM5_10641
**Slug:** et-rsi-bb-daily
**Source:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades daily equity-index mean reversion after the last completed D1 bar closes at an RSI and Bollinger-percent extreme. It opens long on the next D1 bar when RSI(7) closes below 30 and BB% closes below 20, and opens short when RSI(7) closes above 70 and BB% closes above 80. It skips entries when ATR(14) is more than 2.5 times the 100-day ATR median. It exits when RSI or BB% returns through the 50 midline, after 4 D1 bars, or by the framework stop/friday controls.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_period | 7 | 1+ | RSI lookback on D1 closes. |
| strategy_rsi_long_entry | 30.0 | 0-100 | Long entry requires RSI below this value. |
| strategy_rsi_short_entry | 70.0 | 0-100 | Short entry requires RSI above this value. |
| strategy_rsi_exit_level | 50.0 | 0-100 | RSI midline exit level for both directions. |
| strategy_bb_period | 20 | 2+ | Bollinger Band period on D1 close. |
| strategy_bb_deviation | 2.0 | >0 | Bollinger Band standard deviation multiplier. |
| strategy_bb_long_entry_pct | 20.0 | 0-100 | Long entry requires BB% below this value. |
| strategy_bb_short_entry_pct | 80.0 | 0-100 | Short entry requires BB% above this value. |
| strategy_bb_exit_pct | 50.0 | 0-100 | BB% midline exit level for both directions. |
| strategy_atr_period | 14 | 1+ | ATR period for stop and spike filter. |
| strategy_atr_stop_mult | 1.5 | >0 | Initial stop distance in ATR multiples. |
| strategy_atr_median_lookback | 100 | 2+ | Number of daily ATR values used for the median spike filter. |
| strategy_atr_spike_mult | 2.5 | >0 | Skip entry if ATR exceeds this multiple of the median. |
| strategy_max_hold_bars | 4 | 1+ | Mandatory time exit after this many D1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index CFD; matches the card's US equity-index mean-reversion basket.
- SP500.DWX - S&P 500 custom symbol; valid for backtest-only coverage per the card and symbol matrix.
- WS30.DWX - Dow 30 index CFD; broad US large-cap index port listed in the card.

**Explicitly NOT for:**
- Single stocks or sector ETFs - the card was approved as an index-CFD port, not as constituent equity trading.
- Non-DWX S&P symbols such as SPX500.DWX, SPY.DWX, or ES.DWX - unavailable or non-canonical in the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | 2-4 days |
| Expected drawdown profile | Mean-reversion drawdowns concentrate during high-volatility event spikes, filtered by ATR median. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/rsi-on-1-day-charts-automated-strategy.378701/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10641_et-rsi-bb-daily.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-14 | Initial build from card | 1e8a8337-78cd-4e13-bbb9-20f42dd88f0a |
