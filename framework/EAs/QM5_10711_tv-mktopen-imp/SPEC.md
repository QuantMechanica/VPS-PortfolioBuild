# QM5_10711_tv-mktopen-imp - Strategy Spec

**EA ID:** QM5_10711
**Slug:** tv-mktopen-imp
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA checks the closed bar that starts at the configured market-open time. It opens long when that bar has true range at least 1.5 times ATR(14), closes above its midpoint, and closes above its own open. It opens short when the same impulse range test passes and the bar closes below its midpoint and below its own open. The stop is the opposite extreme of the impulse candle by default, take profit is 3.0R, breakeven moves the stop to entry after 1.5R, and any remaining position is closed after 24 M15 bars or at the configured session-close time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_open_hour_broker | 16 | 0-23 | Broker-server hour for the market-open impulse bar. |
| strategy_open_minute_broker | 30 | 0-59 | Broker-server minute for the market-open impulse bar. |
| strategy_atr_period | 14 | 1-200 | ATR period used for impulse and optional ATR stop checks. |
| strategy_impulse_atr_mult | 1.5 | 0.1-10.0 | Minimum true range multiple of ATR for an impulse candle. |
| strategy_max_range_atr_mult | 4.0 | 0.1-20.0 | Maximum true range multiple of ATR; larger bars are skipped as spike risk. |
| strategy_use_atr_stop | false | true/false | Use ATR stop instead of the impulse candle opposite extreme. |
| strategy_atr_stop_mult | 1.0 | 0.1-10.0 | ATR multiple for the optional ATR stop. |
| strategy_take_profit_r | 3.0 | 0.1-20.0 | Take-profit distance measured in initial risk units. |
| strategy_breakeven_enabled | true | true/false | Enables the source optional breakeven rule. |
| strategy_breakeven_trigger_r | 1.5 | 0.1-20.0 | Profit in R required before moving stop to breakeven. |
| strategy_breakeven_buffer_pips | 0 | 0-100 | Extra pips beyond entry when moving the stop to breakeven. |
| strategy_max_hold_bars | 24 | 1-500 | Maximum holding period in current timeframe bars; baseline is M15. |
| strategy_session_close_hhmm | 2200 | 0-2359 | Broker-server time at or after which an open trade is force-closed. |
| strategy_max_spread_stop_frac | 0.15 | 0.01-1.0 | Maximum spread as a fraction of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- GDAXI.DWX - canonical DAX 40 DWX custom symbol, used as the matrix-valid port for the card's GER40.DWX target.
- NDX.DWX - liquid US large-cap index CFD for index cash-open impulse behaviour.
- WS30.DWX - liquid US large-cap index CFD for index cash-open impulse behaviour.
- XAUUSD.DWX - liquid metal CFD included in the card target list.
- EURUSD.DWX - liquid FX major included in the card target list.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.
- SP500.DWX - mentioned only as an optional backtest comparison in the card, not as a primary target symbol for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, up to 24 M15 bars or before session close |
| Expected drawdown profile | Stop-defined impulse breakout losses with fixed $1,000 backtest risk |
| Regime preference | Volatility-expansion and market-open momentum |
| Win rate target (qualitative) | Medium, with 3.0R winners compensating for impulse failures |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source script
**Pointer:** TradingView script `Market Open Impulse [LuciTech]`, author handle `TradesLuci`, published 2025-08-12, https://www.tradingview.com/script/5VVg9PqU-Market-Open-Impulse-LuciTech/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10711_tv-mktopen-imp.md`

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
| v1 | 2026-05-31 | Initial build from card | 718a6fd1-ff74-4f26-8898-feb9a44419fe |
