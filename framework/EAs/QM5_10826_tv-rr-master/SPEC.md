# QM5_10826_tv-rr-master - Strategy Spec

**EA ID:** QM5_10826
**Slug:** tv-rr-master
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades the RR Master LC rule on the close of each H1 bar. A long setup requires close above EMA(200), close above the broker-day session VWAP, ADX(14) above 30 and rising, and price at least 0.25 ATR(14) away from EMA(200); the trigger is RSI(7) crossing above RSI(14). A short setup mirrors those rules below EMA(200) and VWAP with RSI(7) crossing below RSI(14). Entries place a market bracket immediately, with the stop beyond the signal bar by 0.2 ATR(14), the target at 1.7R, and an 8-bar cooldown after any closed trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_fast_period | 7 | 5-7 tested | Fast RSI period used for the trigger cross. |
| strategy_rsi_slow_period | 14 | 14-21 tested | Slow RSI period used for the trigger cross. |
| strategy_ema_period | 200 | fixed by card | Trend filter EMA period. |
| strategy_adx_period | 14 | fixed by card | ADX period for trend-strength filtering. |
| strategy_adx_threshold | 30.0 | 20-30 tested | Minimum ADX value; ADX must also be rising. |
| strategy_atr_period | 14 | fixed by card | ATR period for EMA clearance and stop buffer. |
| strategy_ema_atr_clear_mult | 0.25 | 0.0-0.5 tested | Minimum distance from EMA(200), in ATR multiples. |
| strategy_stop_atr_buffer_mult | 0.20 | 0.1-0.3 tested | ATR buffer beyond signal-bar low or high. |
| strategy_target_rr | 1.70 | 1.5-2.0 tested | Take-profit distance in R multiples. |
| strategy_cooldown_bars | 8 | 4-12 tested | Bars to wait after a closed trade. |
| strategy_vwap_max_bars | 256 | 64-512 | Maximum closed-bar window for broker-day VWAP calculation. |
| strategy_spread_stop_fraction | 0.10 | card default | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 forex basket member with DWX OHLC, EMA, VWAP proxy, ADX, RSI, and ATR data.
- GBPUSD.DWX - card R3 forex basket member with the same mechanical indicator support.
- USDJPY.DWX - card R3 forex basket member with the same mechanical indicator support.
- XAUUSD.DWX - card R3 metals basket member with the same mechanical indicator support.
- GDAXI.DWX - verified local DWX DAX equivalent for the card's GER40.DWX target.
- NDX.DWX - card R3 US index basket member with the same mechanical indicator support.
- WS30.DWX - card R3 US index basket member with the same mechanical indicator support.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is used instead.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - build rules forbid phantom DWX registrations.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Expected trade frequency | M15/H1 cadence in card; implemented H1 baseline for Q01/P2 |
| Typical hold time | Not specified in card; bracket exits imply intraday to multi-day holds depending on volatility |
| Expected drawdown profile | Fixed-risk short-term trend-continuation with bracket SL/TP and Friday close |
| Regime preference | Trend continuation with ADX strength and VWAP/EMA alignment |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** louislapis9, RR Master - LC, TradingView open-source strategy, `https://www.tradingview.com/script/vR3zgCKG/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10826_tv-rr-master.md`

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
| v1 | 2026-06-06 | Initial build from card | 28553d2c-9e38-4ca7-92eb-c764c7ca138f |
