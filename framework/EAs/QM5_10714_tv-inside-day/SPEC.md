# QM5_10714_tv-inside-day - Strategy Spec

**EA ID:** QM5_10714
**Slug:** tv-inside-day
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA checks the last completed D1 bar against the D1 bar before it. A setup exists when the last completed bar is an inside day: its high is below the prior high and its low is above the prior low. When the setup passes the ATR range and spread filters, the EA places a buy stop one point above the inside-day high and a sell stop one point below the inside-day low. The long stop is the inside-day low, the short stop is the inside-day high, and take profit is ATR(14) times 1.0 from entry.

When one stop fills, the trade-management hook removes the opposite pending stop. Baseline exits are by structural stop, ATR target, and the framework Friday close; an optional intraday end-of-day flat input is present but disabled for the D1 backtest setfiles.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 1-200 | D1 ATR period used for the range filter and take-profit distance. |
| strategy_atr_tp_mult | 1.0 | 0.1-10.0 | ATR multiple added to entry for the baseline fixed take profit. |
| strategy_min_range_atr | 0.25 | 0.01-10.0 | Minimum inside-day range as a fraction of ATR. |
| strategy_max_range_atr | 2.0 | 0.01-10.0 | Maximum inside-day range as a fraction of ATR. |
| strategy_max_spread_range_ratio | 0.10 | 0.00-1.00 | Maximum current spread as a fraction of the inside-day range. |
| strategy_entry_buffer_points | 1 | 0-100 | Point buffer above the inside-day high and below the inside-day low. |
| strategy_direction_mode | 0 | 0, 1, 2 | 0 trades both directions, 1 long-only, 2 short-only. |
| strategy_pending_expiration_hours | 0 | 0-240 | Pending order lifetime; 0 means good-till-cancelled. |
| strategy_eod_flat_enabled | false | true/false | Enables the optional intraday 16:55 New York flat rule. |
| strategy_eod_ny_hour | 16 | 0-23 | New York hour for optional intraday flat. |
| strategy_eod_ny_minute | 55 | 0-59 | New York minute for optional intraday flat. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major with DWX daily OHLC and tick data.
- GBPUSD.DWX - card-listed FX major with DWX daily OHLC and tick data.
- USDJPY.DWX - card-listed FX major with DWX daily OHLC and tick data.
- XAUUSD.DWX - card-listed metal with DWX daily OHLC and tick data.
- GDAXI.DWX - DAX exposure used because card-listed GER40.DWX is not in the DWX matrix.
- NDX.DWX - card-listed US index with DWX daily OHLC and tick data.

**Explicitly NOT for:**
- GER40.DWX - absent from `framework/registry/dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable S&P variants; not part of this card's target basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | D1 OHLC and D1 ATR(14) only |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Expected trade frequency | About 45 breakout attempts per year per symbol from card frontmatter. |
| Typical hold time | Not specified in frontmatter; expected to hold until ATR target, structural stop, Friday close, or optional intraday EOD flat. |
| Expected drawdown profile | Breakout profile with losses clustered during failed volatility expansion. |
| Regime preference | Volatility expansion / breakout after compressed daily range. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/E7jfjUgH-Inside-Day-Breakout-Strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10714_tv-inside-day.md`

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
| v1 | 2026-05-31 | Initial build from card | 4b77cd1b-7f6b-49eb-8f82-5be93e88bbc5 |
