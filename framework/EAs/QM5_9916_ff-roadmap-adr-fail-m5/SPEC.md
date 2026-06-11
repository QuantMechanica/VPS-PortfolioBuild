# QM5_9916_ff-roadmap-adr-fail-m5 - Strategy Spec

**EA ID:** QM5_9916
**Slug:** ff-roadmap-adr-fail-m5
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades completed M5 failures around the projected ADR boundary or the previous-day high/low during the Frankfurt, London, and early New York window. A long setup requires price to be near ADR low or previous-day low, the Roadmap EMA(8) channel to have breached below that boundary in the prior eight bars, and the latest completed M5 bar to close bullish back above the boundary with EMA(8 close) also above it. Shorts mirror the same logic at ADR high or previous-day high. Stops use the farther of the failure swing and a 0.25 ATR boundary buffer, rejected outside 0.6-2.4 ATR, and targets use the nearest favorable daily open, EMA(200), opposite boundary, or 1.6R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | >=1 | M5 ATR period for failure distance, stop buffer, stop validation, and spread cap. |
| `strategy_ema_period` | 8 | >=1 | Roadmap EMA period for high, close, and low channel confirmation. |
| `strategy_ema200_period` | 200 | >=1 | M5 EMA period used as one of the nearest target candidates. |
| `strategy_adr_days` | 14 | >=1 | Completed D1 bars used to compute ADR high and ADR low. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start of the Frankfurt/London/early New York entry window. |
| `strategy_session_end_hour` | 17 | 0-23 | Broker-hour end of the Frankfurt/London/early New York entry window. |
| `strategy_boundary_near_adr_mult` | 0.20 | >=0 | Maximum distance from close to candidate ADR/previous-day boundary as ADR fraction. |
| `strategy_failure_lookback_bars` | 8 | >=1 | Prior M5 bars searched for an EMA channel breach through the boundary. |
| `strategy_failure_close_atr_mult` | 0.15 | >=0 | Minimum favorable close distance beyond the failed boundary. |
| `strategy_sl_atr_buffer` | 0.25 | >=0 | ATR buffer beyond the boundary for stop placement. |
| `strategy_stop_min_atr` | 0.60 | >0 | Minimum accepted initial stop distance in ATR multiples. |
| `strategy_stop_max_atr` | 2.40 | >0 | Maximum accepted initial stop distance in ATR multiples. |
| `strategy_tp_r_multiple` | 1.60 | >0 | Fixed R target candidate. |
| `strategy_daily_range_min_adr` | 0.45 | >=0 | Blocks entries until current daily range is at least this ADR fraction. |
| `strategy_max_spread_atr_pct` | 12.0 | >=0 | Maximum spread as a percent of M5 ATR. |
| `strategy_time_stop_bars` | 30 | >=1 | Maximum holding period in M5 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 primary FX major with liquid M5 ADR and previous-day levels.
- `GBPUSD.DWX` - card R3 primary FX major with liquid M5 ADR and previous-day levels.
- `USDJPY.DWX` - card R3 primary FX major with liquid M5 ADR and previous-day levels.
- `XAUUSD.DWX` - card R3 metal symbol with M5 OHLC, ADR, ATR, and EMA applicability.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable to the DWX test infrastructure.
- Non-intraday or illiquid symbols - the strategy depends on M5 session boundary failures and tight execution.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | D1 daily open, current daily range, previous-day high/low, and ADR boundary |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Intraday; maximum 30 M5 bars, about 2.5 hours |
| Expected drawdown profile | Medium-frequency mean-reversion drawdowns during strong trend days, bounded by ATR-normalized stops |
| Regime preference | Session mean reversion at ADR or previous-day boundaries |
| Win rate target (qualitative) | Medium |
| Expected trade frequency | Medium; ADR/previous-day boundary failures on M5 should appear roughly 40-90 times/year/symbol after session and range filters. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** LauraT, "Roadmap - A Way To Read Markets", ForexFactory, 2020, https://www.forexfactory.com/thread/post/12905491
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9916_ff-roadmap-adr-fail-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | ae0216f1-8aa2-4c30-bd26-3bea7029e965 |
