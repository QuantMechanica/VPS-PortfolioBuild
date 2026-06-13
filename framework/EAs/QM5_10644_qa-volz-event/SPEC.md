# QM5_10644_qa-volz-event - Strategy Spec

**EA ID:** QM5_10644
**Slug:** `qa-volz-event`
**Source:** `35e40f89-5980-5d15-8964-70f9760db187` (see `artifacts/cards_approved/QM5_10644_qa-volz-event.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades M1 event momentum after a completed bar shows an unusually large tick-volume shock. A long signal requires volume z-score at or above 4.0, a one-bar return at least 0.75 ATR percent, and a close above the prior five completed M1 highs; a short signal uses the same volume shock with a negative ATR-scaled return and a close below the prior five completed M1 lows. Entries use an initial 1.25 ATR stop, move the stop to break-even after +1R, and exit after 10 M1 bars, a close back through the signal bar open, or an opposite volume-z momentum signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_volume_lookback` | 60 | 30-120 | M1 tick-volume lookback for the z-score baseline. |
| `strategy_volume_z_threshold` | 4.0 | 3.0-6.0 | Minimum tick-volume z-score for an event. |
| `strategy_atr_period` | 14 | 14 | ATR period used for return scaling and stop distance. |
| `strategy_return_atr_mult` | 0.75 | 0.50-1.00 | One-bar return threshold as a multiple of ATR percent. |
| `strategy_breakout_lookback` | 5 | 3-10 | Prior completed M1 bars used for breakout confirmation. |
| `strategy_stop_atr_mult` | 1.25 | 1.0-2.0 | Initial stop distance as ATR multiple. |
| `strategy_time_exit_bars` | 10 | 5-30 | Maximum hold time in M1 bars. |
| `strategy_daily_entry_cap` | 1 | 1-3 | Maximum entries per symbol per broker day. |
| `strategy_nonzero_volume_lookback` | 30 | 30 | M1 bars checked for nonzero tick volume. |
| `strategy_min_nonzero_volume_bars` | 20 | 1-30 | Minimum nonzero-volume bars required in the lookback. |
| `strategy_spread_sessions` | 20 | 1-20 | Same-minute spread samples required before the spread cap is active. |
| `strategy_spread_cap_mult` | 3.0 | 1.0-5.0 | Maximum spread as a multiple of median same-minute spread. |
| `strategy_session_edge_filter` | true | true/false | Enables first/last session-minute skip. |
| `strategy_session_start_hhmm` | 1530 | 0000-2359 | Broker-time start of the main index session proxy. |
| `strategy_session_end_hhmm` | 2200 | 0000-2359 | Broker-time end of the main index session proxy. |
| `strategy_session_edge_minutes` | 10 | 1-180 | Minutes skipped at each session edge. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index proxy named in the card R3 basket; backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index proxy named in the card R3 basket.
- `WS30.DWX` - Dow 30 index proxy named in the card R3 basket.
- `XAUUSD.DWX` - gold CFD named in the card R3 basket for commodity event momentum.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtesting.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `25` |
| Typical hold time | `10 M1 bars or less` |
| Expected drawdown profile | Short-horizon event strategy with material spread and slippage sensitivity. |
| Regime preference | Volatility-expansion / news-driven event momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `35e40f89-5980-5d15-8964-70f9760db187`
**Source type:** article
**Pointer:** `https://www.algos.org/p/event-based-alpha-a-quick-guide` and archive `https://archive.ph/2026.01.06-215845/https%3A/www.algos.org/p/event-based-alpha-a-quick-guide`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10644_qa-volz-event.md`

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
| v1 | 2026-06-14 | Initial build from card | 2fe58175-abff-479a-b016-ab68a8940050 |
