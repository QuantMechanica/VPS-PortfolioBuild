# QM5_9263_mql5-chaikin-zero - Strategy Spec

**EA ID:** QM5_9263
**Slug:** `mql5-chaikin-zero`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA calculates a Chaikin Oscillator from the accumulation/distribution line using tick volume on closed H1 bars. The fast EMA is 3 bars and the slow EMA is 10 bars. A long entry is opened when the oscillator crosses from zero or below to above zero, and a short entry is opened when it crosses from zero or above to below zero. The signal bar must have tick volume at least 80% of the 20-bar median volume. Positions exit on the opposite zero-line cross, on the framework SL/TP, on Friday close, or after 48 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_chaikin_fast_ema` | 3 | 1+ and less than slow EMA | Fast EMA period for the Chaikin Oscillator. |
| `strategy_chaikin_slow_ema` | 10 | Greater than fast EMA | Slow EMA period for the Chaikin Oscillator. |
| `strategy_chaikin_warmup_bars` | 80 | At least slow EMA + 5 | Closed-bar OHLCV window used to seed ADL and EMA state. |
| `strategy_volume_median_bars` | 20 | 1+ | Median tick-volume lookback for the signal-bar volume filter. |
| `strategy_volume_min_ratio` | 0.80 | 0.0+ | Minimum signal-bar volume as a ratio of the volume median. |
| `strategy_atr_period` | 14 | 1+ | ATR period for initial stop placement. |
| `strategy_atr_sl_mult` | 2.0 | 0.0+ | ATR multiple for the initial stop. |
| `strategy_take_profit_rr` | 2.0 | 0.0+ | Take-profit multiple relative to initial risk. |
| `strategy_time_stop_bars` | 48 | 0+ | Maximum holding time in chart bars; 0 disables the time stop. |
| `strategy_spread_cap_points` | 1000 | 0+ | Optional wide-spread blocker; zero modeled spread is allowed. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target forex major with native DWX tick volume and H1 history.
- `GBPJPY.DWX` - Card target JPY cross with native DWX tick volume and H1 history.
- `GDAXI.DWX` - Available matrix DAX instrument used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - Card target name is not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- Non-DWX symbols - The V5 backtest pipeline requires canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `85` |
| Typical hold time | Intraday to two trading days; hard time exit after 48 H1 bars |
| Expected drawdown profile | ATR-bounded momentum system with fixed 2R target |
| Regime preference | Momentum with volume confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/11242`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_9263_mql5-chaikin-zero.md`

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
| v1 | 2026-06-23 | Initial build from card | 5257893d-fca8-4961-b88f-1cd926cfe514 |
