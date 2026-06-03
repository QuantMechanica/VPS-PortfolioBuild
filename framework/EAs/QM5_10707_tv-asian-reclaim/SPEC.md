# QM5_10707_tv-asian-reclaim - Strategy Spec

**EA ID:** QM5_10707
**Slug:** tv-asian-reclaim
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA records the high and low of the configured Asian session on M15 bars. After that session ends, it buys when price has traded below the Asian low and a closed M15 candle has its full body back inside the range; it sells when price has traded above the Asian high and a closed M15 candle has its full body back inside the range. The initial stop is one ATR(14) beyond the reclaim candle extreme, the take profit is 1.5R, the stop moves to breakeven after price reaches half the target distance, and any open trade is closed when the next Asian session begins.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_asian_start_hour | 0 | 0-23 | Broker-time hour when Asian range collection starts. |
| strategy_asian_start_min | 0 | 0-59 | Broker-time minute when Asian range collection starts. |
| strategy_asian_end_hour | 6 | 0-23 | Broker-time hour when Asian range collection ends. |
| strategy_asian_end_min | 0 | 0-59 | Broker-time minute when Asian range collection ends. |
| strategy_atr_period | 14 | >=1 | ATR period used for the stop-distance rule. |
| strategy_atr_sl_mult | 1.0 | >0 | ATR multiple placed beyond the reclaim candle extreme. |
| strategy_tp_r | 1.5 | >0 | Take-profit distance in R multiples from entry. |
| strategy_be_trigger_frac | 0.5 | 0-1 | Fraction of target distance reached before moving SL to breakeven. |
| strategy_min_stop_atr | 0.5 | >0 | Minimum allowed stop distance as ATR multiple. |
| strategy_max_stop_atr | 3.0 | >0 | Maximum allowed stop distance as ATR multiple. |
| strategy_max_spread_stop | 0.15 | 0-1 | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major with liquid M15 OHLC and ATR data.
- GBPUSD.DWX - card-listed FX major with liquid M15 OHLC and ATR data.
- USDJPY.DWX - card-listed FX major with liquid M15 OHLC and ATR data.
- XAUUSD.DWX - card-listed gold CFD with liquid M15 OHLC and ATR data.
- GDAXI.DWX - available DWX DAX custom symbol used for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday; closed before the next Asian range begins. |
| Expected drawdown profile | Fixed-risk mean-reversion drawdowns from failed session sweeps. |
| Regime preference | Mean-revert after liquidity sweep. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Asian Reclaim - ATR Stop`, author handle `MatteoSan84`, published 2026-03-10, https://www.tradingview.com/script/6LtYu07m/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10707_tv-asian-reclaim.md`

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
| v1 | 2026-05-31 | Initial build from card | d698a90d-47bf-4478-8ad2-0e75788a7f50 |
