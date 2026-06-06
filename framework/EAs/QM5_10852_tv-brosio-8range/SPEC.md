# QM5_10852_tv-brosio-8range - Strategy Spec

**EA ID:** QM5_10852
**Slug:** tv-brosio-8range
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades the M5 08:00 opening range. It builds the high, low, and midpoint from the first 15 minutes after the configured anchor time, then trades only during the configured morning window. A long signal requires a prior break above the range high, then a closed bar that retraces to the midpoint tolerance and closes back above the midpoint; shorts mirror this below the range low. The stop is the opposite side of the 08:00 range, the take-profit is 4R, and the stop is moved to breakeven after 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_anchor_hour` | 8 | 0-23 | Broker-time hour for the opening-range anchor. |
| `strategy_anchor_minute` | 0 | 0-59 | Broker-time minute for the opening-range anchor. |
| `strategy_range_minutes` | 15 | 5-60 | Number of minutes used to form the opening range. |
| `strategy_trade_start_hour` | 9 | 0-23 | Broker-time hour when entries may start. |
| `strategy_trade_start_minute` | 45 | 0-59 | Broker-time minute when entries may start. |
| `strategy_trade_end_hour` | 11 | 0-23 | Broker-time hour for session-end forced exit. |
| `strategy_trade_end_minute` | 40 | 0-59 | Broker-time minute for session-end forced exit. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for validating opening-range width. |
| `strategy_min_range_atr_mult` | 0.5 | 0.0-5.0 | Minimum accepted range width as a multiple of ATR. |
| `strategy_max_range_atr_mult` | 2.5 | 0.1-10.0 | Maximum accepted range width as a multiple of ATR. |
| `strategy_retest_tolerance_frac` | 0.10 | 0.0-1.0 | Midpoint retest tolerance as a fraction of range width. |
| `strategy_spread_stop_max_frac` | 0.15 | 0.0-1.0 | Maximum spread as a fraction of stop distance. |
| `strategy_tp_rr` | 4.0 | 0.5-10.0 | Final take-profit distance in R. |
| `strategy_breakeven_rr` | 2.0 | 0.5-10.0 | R multiple that triggers a breakeven stop move. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - liquid DWX index CFD suitable for intraday opening-range tests.
- `WS30.DWX` - liquid DWX index CFD suitable for intraday opening-range tests.
- `GDAXI.DWX` - canonical DWX DAX symbol port for the card's `GER40.DWX` basket member.
- `XAUUSD.DWX` - liquid DWX metal symbol included in the card's intraday basket.
- `GBPUSD.DWX` - liquid DWX FX pair included in the card's intraday basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX S&P 500 symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, usually minutes to two hours |
| Expected drawdown profile | High-cadence false-breakout risk during noisy morning sessions |
| Regime preference | breakout / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/iZ9pJtfN-BROSIO-TRADES-8-00-15-Min-Break-and-Retest/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10852_tv-brosio-8range.md`

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
| v1 | 2026-06-06 | Initial build from card | 5b3a7eb7-df24-44c5-94f7-0f064ed58e36 |
