# QM5_9903_ff-roadmap-do-fail-m5 - Strategy Spec

**EA ID:** QM5_9903
**Slug:** ff-roadmap-do-fail-m5
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M5 daily-open failure and retest patterns during the London and early New York window. A short setup starts when price closes at least 0.25 ATR above the daily open, then closes back below the daily open within 12 bars, then retests the daily open from below within 6 bars with a bearish close below EMA(8 close) and RSI(14) at or below 45. A long setup mirrors that logic below and then above the daily open, with a bullish retest close above EMA(8 close) and RSI(14) at or above 55. Stops are set beyond the retest swing plus 0.25 ATR, rejected outside the 0.5-2.0 ATR range, and targets use the nearest of the yesterday level, ADR boundary, or 1.8R after a 1.5R room check.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | >=1 | M5 ATR period for failure distance, spread cap, retest tolerance, and stop validation. |
| `strategy_ema_period` | 8 | >=1 | M5 EMA(close) Roadmap channel confirmation period. |
| `strategy_rsi_period` | 14 | >=1 | M5 RSI period used by the retest confirmation gate. |
| `strategy_sma_period` | 200 | >=1 | M5 SMA period used to reject compressed daily-open/SMA level stacks. |
| `strategy_adr_days` | 14 | >=1 | Daily range lookback for the ADR boundary target. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start of London/early New York entries. |
| `strategy_session_end_hour` | 17 | 0-23 | Broker-hour end of London/early New York entries. |
| `strategy_failure_atr_mult` | 0.25 | >0 | Required close distance beyond the daily open before a failure setup can start. |
| `strategy_failure_window_bars` | 12 | >=1 | Maximum M5 bars allowed for price to close back across the daily open. |
| `strategy_retest_window_bars` | 6 | >=1 | Maximum M5 bars allowed for the post-failure daily-open retest. |
| `strategy_retest_atr_mult` | 0.15 | >=0 | Retest tolerance around the daily open, in ATR multiples. |
| `strategy_sl_atr_buffer` | 0.25 | >=0 | ATR buffer beyond the retest swing high or low for the stop. |
| `strategy_stop_min_atr` | 0.5 | >0 | Minimum accepted stop distance in ATR multiples. |
| `strategy_stop_max_atr` | 2.0 | >0 | Maximum accepted stop distance in ATR multiples. |
| `strategy_tp_r_multiple` | 1.8 | >0 | Fixed R target candidate. |
| `strategy_min_room_r` | 1.5 | >0 | Minimum room to the nearest mapped support/resistance candidate. |
| `strategy_sma_stack_atr_mult` | 0.20 | >=0 | Rejects entries when daily open is too close to SMA(200). |
| `strategy_max_spread_atr_pct` | 12.0 | >=0 | Maximum spread as a percent of M5 ATR(14). |
| `strategy_time_stop_bars` | 30 | >=1 | Maximum holding period in M5 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 primary FX pair with liquid London/New York M5 coverage.
- `GBPUSD.DWX` - card R3 primary FX pair with liquid London/New York M5 coverage.
- `XAUUSD.DWX` - card R3 metal symbol with M5 OHLC and ATR/EMA/RSI applicability.
- `NDX.DWX` - card R3 index symbol with M5 OHLC and daily-open failure applicability.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable to the DWX test infrastructure.
- Non-intraday or illiquid symbols - the source logic depends on M5 daily-open retests and tight session execution.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | D1 daily open, yesterday high/low, and ADR boundary |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 85 |
| Typical hold time | Intraday; maximum 30 M5 bars, about 2.5 hours |
| Expected drawdown profile | Medium frequency with fixed ATR-bounded stops and single active position per magic-symbol |
| Regime preference | Intraday session-level failure, retest entry, and momentum continuation |
| Win rate target (qualitative) | Medium |
| Expected trade frequency | Medium-high; M5 daily-open failure/retest entries should produce roughly 60-130 trades/year/symbol after Roadmap context filters. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** LauraT, "Roadmap - A Way To Read Markets", ForexFactory, 2020-2026, https://www.forexfactory.com/thread/993524-roadmap-a-way-to-read-markets
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9903_ff-roadmap-do-fail-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | 1ce4695a-7058-40a5-86fe-4363509af2ec |
