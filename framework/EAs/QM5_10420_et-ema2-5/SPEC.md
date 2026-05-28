# QM5_10420_et-ema2-5 - Strategy Spec

**EA ID:** QM5_10420
**Slug:** et-ema2-5
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades a completed-bar EMA crossover on the chart timeframe. It opens long when EMA(close, 2) crosses above EMA(close, 5), and opens short when EMA(close, 2) crosses below EMA(close, 5). Initial risk is set with a 1.5 x ATR(20) stop, open trades trail with 1.0 x ATR(20) after price has moved at least 1R, and opposite EMA crosses flatten existing positions before any later re-entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_ema_period | 2 | 1-20 | Fast EMA period used for crossover signals. |
| strategy_slow_ema_period | 5 | 2-50 | Slow EMA period used for crossover signals. |
| strategy_atr_period | 20 | 2-100 | ATR period used for stop, spread, and trailing calculations. |
| strategy_initial_atr_sl_mult | 1.5 | 0.5-5.0 | Initial stop distance as a multiple of ATR(20). |
| strategy_trailing_atr_mult | 1.0 | 0.5-5.0 | Trailing stop distance after the position reaches +1R. |
| strategy_max_spread_atr_fraction | 0.20 | 0.01-1.00 | Blocks new entries when spread exceeds this share of ATR. |
| strategy_index_flat_hour_broker | 21 | 0-23 | Broker hour used to flatten and stop new index CFD exposure. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Liquid major FX pair from the card's R3 P2 basket.
- GBPUSD.DWX - Liquid major FX pair from the card's R3 P2 basket.
- SP500.DWX - S&P 500 custom symbol explicitly allowed for backtest-only index exposure.
- NDX.DWX - Nasdaq 100 DWX index CFD from the card's R3 P2 basket.
- GDAXI.DWX - Available DWX DAX proxy for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Intraday to several M30 bars; card parameter notes include a 16-bar time-exit variant for later testing. |
| Expected drawdown profile | Frequent small losses during chop, with trend-following recovery when M30 direction persists. |
| Regime preference | intraday trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/amibroker-and-interactive-brokers-tws-auto-trading.242537/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10420_et-ema2-5.md`

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
| v1 | 2026-05-25 | Initial build from card | 133fe484-297a-4ff7-be09-451c5a5b0a8b |
