# QM5_10398_et-hershey-rocket - Strategy Spec

**EA ID:** QM5_10398
**Slug:** et-hershey-rocket
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA trades the Elite Trader Hershey Beginner Rocket setup on M5 index data. It opens a long position when closed-bar tick volume passes the configured CFD fallback gate, MACD(5,13,6) histogram is at least +0.4, and both Slow Stochastic(14,1,3) lines are above 80. It opens a short position when the same volume gate is met, MACD histogram is at most -0.4, and both stochastic lines are below 20. Positions use a 1.5 x ATR(20) stop and close when the slow stochastic line falls back inside the 20/80 band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 5 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 13 | greater than fast | MACD slow EMA period. |
| `strategy_macd_signal` | 6 | 1+ | MACD signal period. |
| `strategy_macd_hist_min` | 0.4 | 0.0+ | Minimum absolute MACD histogram magnitude for entry. |
| `strategy_stoch_k_period` | 14 | 1+ | Slow stochastic K period. |
| `strategy_stoch_d_period` | 1 | 1+ | Slow stochastic D period. |
| `strategy_stoch_slowing` | 3 | 1+ | Slow stochastic slowing period. |
| `strategy_stoch_upper` | 80.0 | 0-100 | Upper stochastic rocket band. |
| `strategy_stoch_lower` | 20.0 | 0-100 | Lower stochastic rocket band. |
| `strategy_volume_gate_mode` | 1 | 0, 1, 2 | Volume gate mode: off, recent percentile, or raw threshold. |
| `strategy_min_tick_volume` | 10000 | 0+ | Raw tick-volume threshold when mode 2 is selected. |
| `strategy_volume_lookback` | 288 | 20-1000 | Closed M5 bars used for the recent volume percentile gate. |
| `strategy_volume_percentile` | 50.0 | 0-100 | Percentile threshold for CFD tick-volume fallback. |
| `strategy_atr_period` | 20 | 1+ | ATR period for the stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.0+ | ATR multiplier for stop distance. |
| `strategy_session_start_hhmm` | 1630 | 0000-2359 | Broker-time regular-session start. |
| `strategy_session_end_hhmm` | 2300 | 0000-2359 | Broker-time regular-session end. |
| `strategy_max_spread_points` | 0 | 0+ | Maximum spread in points; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol matching the ES/SPX baseline; backtest-only per platform caveat.
- `NDX.DWX` - Nasdaq 100 large-cap index CFD analog for US index momentum.
- `WS30.DWX` - Dow 30 large-cap index CFD analog for US index momentum.
- `GDAXI.DWX` - DAX index equivalent used because the card names `GER40.DWX`, which is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated DAX label is not in the DWX symbol matrix; `GDAXI.DWX` is the registered matrix symbol.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable aliases; the canonical S&P 500 custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Intraday, usually minutes to hours |
| Expected drawdown profile | Intraday momentum with ATR-bounded losses and bursty signal clusters |
| Regime preference | Momentum breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** Chicken Little, Jack Hershey Method: Beginner Rockets, Elite Trader, 2006-05-26, https://www.elitetrader.com/et/threads/jack-hershey-method-beginner-rockets.69860/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10398_et-hershey-rocket.md`

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
| v1 | 2026-05-25 | Initial build from card | 069b9f80-5d3d-4c06-86ab-fb6ca9f8df7b |
