# QM5_10786_tv-daily-bias - Strategy Spec

**EA ID:** QM5_10786
**Slug:** tv-daily-bias
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView script citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

This EA trades M5 bars only when the daily trend bias agrees with the M5 execution signal. Daily bias is bullish when the last closed D1 close is above EMA(200), ADX(14) is at least 20, and +DI is at least -DI; bearish bias mirrors those rules. M5 execution uses a fixed DEMA(21/55) direction/cross, a Q-Trend proxy based on close versus EMA(50), a UT-Bot proxy based on EMA(50) plus ATR(10) distance, VWAP/opening-range context, and a supply-demand/tick-volume proxy; entries require the directional bias, execution direction, context, and a 9-point confluence score of at least 6. Exits are ATR stop, fixed 2R target, opposite cached execution direction, session end, framework Friday close, or max bars in trade.

The TradingView source card names DEMA, Q-Trend, UT Bot, VWAP, opening range, supply/demand zones, volume/delta strength, and a 9-point score, but does not provide formulas for every subcomponent. This build uses fixed transparent proxies for those ambiguous components and keeps the ambiguity visible for review.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_daily_ema_period | 200 | 100-200 P3 | D1 EMA length used for daily bias. |
| strategy_daily_adx_period | 14 | fixed baseline | D1 ADX and DI period. |
| strategy_daily_adx_threshold | 20.0 | 15-25 P3 | Minimum D1 ADX required for trend bias. |
| strategy_dema_fast_period | 21 | fixed baseline | Fast DEMA period for M5 execution. |
| strategy_dema_slow_period | 55 | fixed baseline | Slow DEMA period for M5 execution. |
| strategy_qtrend_ema_period | 50 | fixed baseline | EMA proxy for Q-Trend structure. |
| strategy_ut_atr_period | 10 | fixed baseline | ATR period for UT-Bot proxy. |
| strategy_ut_atr_mult | 1.5 | fixed baseline | ATR multiple for UT-Bot confirmation. |
| strategy_or_start_hhmm | 800 | broker HHMM | Opening-range start time. |
| strategy_or_end_hhmm | 830 | broker HHMM | Opening-range end time. |
| strategy_trade_start_hhmm | 800 | broker HHMM | Earliest entry time. |
| strategy_trade_end_hhmm | 2100 | broker HHMM | Hard session end and no-new-entry cutoff. |
| strategy_max_bars_in_trade | 72 | fixed baseline | Maximum M5 bars in trade before strategy exit. |
| strategy_vwap_chop_filter | true | off/on P3 | Requires long above VWAP and short below VWAP. |
| strategy_opening_range_filter | true | off/on P3 | Requires long above opening range or short below it. |
| strategy_zone_lookback | 48 | fixed baseline | Bars scanned for supply/demand proxy. |
| strategy_zone_edge_pct | 0.25 | fixed baseline | Range fraction defining supply/demand edge zones. |
| strategy_volume_lookback | 20 | fixed baseline | Tick-volume lookback for volume-strength proxy. |
| strategy_volume_strength_mult | 1.0 | fixed baseline | Closed-bar tick volume must meet this multiple of average volume. |
| strategy_score_threshold | 6 | 5-7 P3 | Minimum fixed 9-point confluence score. |
| strategy_cooldown_bars | 10 | 5-20 P3 | Bars after an accepted signal before another entry can fire. |
| strategy_atr_period | 14 | fixed baseline | ATR period for stop placement. |
| strategy_atr_sl_mult | 1.5 | 1.0-2.0 P3 | ATR stop multiple. |
| strategy_rr_target | 2.0 | 1.5-2.0 P3 | Fixed R multiple for target. |
| strategy_max_spread_points | 0 | 0 disables | Optional spread gate in points. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 primary FX basket symbol with DWX data.
- GBPUSD.DWX - card R3 primary FX basket symbol with DWX data.
- USDJPY.DWX - card R3 primary FX basket symbol with DWX data.
- XAUUSD.DWX - card listed XAUUSD; canonical matrix symbol is XAUUSD.DWX.
- GDAXI.DWX - card listed GER40.DWX; matrix-valid DAX equivalent is GDAXI.DWX.
- NDX.DWX - card R3 US index basket symbol with DWX data.
- WS30.DWX - card R3 US index basket symbol with DWX data.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable S&P variants; use SP500.DWX only when a card explicitly calls for S&P exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | D1 EMA(200), ADX(14), +DI, -DI |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via skeleton wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, capped at 72 M5 bars |
| Expected drawdown profile | Trend-filtered intraday confluence model with ATR-defined per-trade risk |
| Regime preference | Daily trend with M5 execution confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** https://www.tradingview.com/script/kZzDTCDd-Daily-Bias-5-Min-by-sam86-live-com/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10786_tv-daily-bias.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-05 | Initial build from card | d439da97-a975-4400-8fe4-c9b96bfef00a |
