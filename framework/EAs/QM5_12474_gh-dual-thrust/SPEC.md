# QM5_12474_gh-dual-thrust - Strategy Spec

**EA ID:** QM5_12474
**Slug:** gh-dual-thrust
**Source:** af7930c8-6c65-52d1-9c01-040490b5ad39 (see Q00-approved GitHub source)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the Dual Thrust intraday breakout on M1 data. For each new session it reads the prior five complete sessions, computes `range1 = max(high) - min(close)` and `range2 = max(close) - min(low)`, then uses the larger value as the session range. The upper band is `session_open + param * range`; the lower band is `session_open - (1 - param) * range`. It buys when live price breaks the upper band, sells when live price breaks the lower band, closes at session end, and closes an open position if the opposite threshold is breached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_M1` | M1 recommended | Timeframe used for session OHLC aggregation and signal checks. |
| `strategy_lookback_sessions` | `5` | 1-30 | Number of complete prior sessions used for the Dual Thrust range. |
| `strategy_param` | `0.50` | 0.0-1.0 | Multiplier for upper threshold; `1 - param` is used for lower threshold. |
| `strategy_stop_range_mult` | `1.00` | >0 | Protective stop distance as a multiple of the computed session range. |
| `strategy_session_open_hhmm` | `1000` | 0000-2359 | Broker-time session open mapped from the card's 03:00 EST source rule. |
| `strategy_session_close_hhmm` | `1900` | 0000-2359 | Broker-time session close mapped from the card's 12:00 EST source rule. |
| `strategy_max_spread_points` | `0` | 0 or higher | Optional spread ceiling; 0 disables this extra filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with verified DWX history.
- `GBPUSD.DWX` - card-listed FX major with verified DWX history.
- `XAUUSD.DWX` - card-listed metal with verified DWX history.
- `GDAXI.DWX` - verified DWX DAX custom symbol used as the available port for card-stated `DAX40.DWX`.

**Explicitly NOT for:**
- `DAX40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Symbols absent from `dwx_symbol_matrix.csv` - no broker/custom-symbol tick history is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `75` |
| Typical hold time | Intraday; from breakout until opposite threshold, stop, or 19:00 broker-time session close. |
| Expected drawdown profile | Breakout-style losses should be bounded by the 1.0 x session-range protective stop. |
| Regime preference | Volatility-expansion / breakout. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** af7930c8-6c65-52d1-9c01-040490b5ad39
**Source type:** GitHub repository
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/Dual%20Thrust%20backtest.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12474_gh-dual-thrust.md`

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
| v1 | 2026-06-11 | Initial build from card | ff232ec8-7424-42fc-8913-5a1c19b229fc |
