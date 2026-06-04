# QM5_10133_tv-ema80-scalp - Strategy Spec

**EA ID:** QM5_10133
**Slug:** tv-ema80-scalp
**Source:** 30591366-874b-5bee-b47c-da2fca20b728
**Author of this spec:** Codex
**Last revised:** 2026-06-04

---

## 1. Strategy Logic

The EA trades an M1 EMA-band scalping rule. It opens long when EMA(80) > EMA(90) > EMA(340) > EMA(500), the last closed candle touches the EMA(80)/EMA(90) band, then closes upward above EMA(80) and SMA(325). It mirrors the rule for shorts with the EMA hierarchy inverted and the candle closing downward below EMA(80) and SMA(325). Stops are placed 0.2% from entry, take profit is 2.5%, and the stop is moved to secure 0.2% once price reaches 0.3% profit; the EA also exits on EMA trend reversal or a post-activation break through the EMA(80)/EMA(90) band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast | 80 | 1+ | Fast EMA used as the outer entry/exit band line. |
| strategy_ema_band_slow | 90 | 1+ | Slow EMA used as the paired entry/exit band line. |
| strategy_ema_trend_fast | 340 | 1+ | Faster trend EMA for hierarchy and trend-reversal exits. |
| strategy_ema_trend_slow | 500 | 1+ | Slower trend EMA for hierarchy and trend-reversal exits. |
| strategy_sma_safety | 325 | 1+ | Safety SMA filter; longs require close above it and shorts below it. |
| strategy_stop_pct | 0.002 | >0 | Initial stop distance as a fraction of entry price. |
| strategy_be_trigger_pct | 0.003 | >0 | Profit threshold that activates secured-stop movement. |
| strategy_secured_pct | 0.002 | >0 | Profit fraction locked in after the breakeven trigger. |
| strategy_take_profit_pct | 0.025 | >0 | Fixed take-profit distance as a fraction of entry price. |
| strategy_max_spread_frac | 0.08 | 0-1 | Maximum spread as a fraction of stop distance. |
| strategy_cooldown_bars | 100 | 0+ | Number of bars to wait after an exit before the next entry. |
| strategy_fx_session_start | 13 | 0-23 | Broker-hour start for FX and gold session filter. |
| strategy_fx_session_end | 17 | 0-23 | Broker-hour end for FX and gold session filter. |
| strategy_dax_session_start | 8 | 0-23 | Broker-hour start for DAX session filter. |
| strategy_dax_session_end | 12 | 0-23 | Broker-hour end for DAX session filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX major suitable for London/New York overlap scalping.
- GBPUSD.DWX - liquid FX major suitable for London/New York overlap scalping.
- XAUUSD.DWX - liquid gold CFD included in the approved card basket.
- GDAXI.DWX - canonical DWX DAX symbol used for the card's DAX.DWX target.

**Explicitly NOT for:**
- SPX500.DWX - unavailable phantom S&P symbol; SP500.DWX is the canonical custom S&P symbol when needed.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | Tight percent stops with frequent small losses during non-trending noise. |
| Regime preference | Fast intraday trend continuation after EMA-band retests. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script
**Pointer:** https://www.tradingview.com/script/UDNlq5ow-Macketings-1min-Scalping/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10133_tv-ema80-scalp.md`

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
| v1 | 2026-06-04 | Initial build from card | 660384f2-3afe-4f3d-84ee-1701a45a3dc6 |
