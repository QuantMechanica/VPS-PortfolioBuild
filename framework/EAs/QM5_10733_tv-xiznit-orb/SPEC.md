# QM5_10733_tv-xiznit-orb - Strategy Spec

**EA ID:** QM5_10733
**Slug:** tv-xiznit-orb
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA builds the opening range from the first configured 15 minutes of the session on M5. After the range is complete, it waits for one closed bar outside the range and then a second confirming closed bar in the same direction, still outside the range. Long trades require close above the range high, RSI at least 50, normal ATR, volume above 1.2 times the recent tick-volume average, no inside bar, and close above the higher-timeframe EMA(50); shorts mirror those rules below the range low. The initial stop is the opposite side of the opening range or the confirming candle extreme, whichever gives the smaller valid risk, with a 2R take profit and a break-even stop move after 1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_or_start_hhmm | 1630 | 0-2359 | Broker-time start of the opening range window. |
| strategy_or_end_hhmm | 1645 | 0-2359 | Broker-time end of the opening range window. |
| strategy_session_end_hhmm | 2300 | 0-2359 | Broker-time end-of-day flatten boundary. |
| strategy_rsi_period | 14 | >= 2 | RSI period used for directional confirmation. |
| strategy_atr_period | 20 | >= 2 | ATR period used for the volatility-normal filter. |
| strategy_atr_avg_bars | 20 | >= 1 | Number of closed ATR samples used as the ATR baseline. |
| strategy_atr_min_ratio | 0.70 | > 0 | Minimum ATR/current-average ratio allowed. |
| strategy_atr_max_ratio | 1.80 | > min | Maximum ATR/current-average ratio allowed. |
| strategy_volume_sma_bars | 20 | >= 1 | Tick-volume average lookback. |
| strategy_volume_mult | 1.20 | > 0 | Required multiplier over average tick volume. |
| strategy_htf | PERIOD_M15 | MT5 timeframe | Higher timeframe for EMA trend filter. |
| strategy_htf_ema_period | 50 | >= 2 | EMA period used by the higher-timeframe trend filter. |
| strategy_take_profit_rr | 2.00 | > 0 | Full-position take-profit multiple of initial risk. |
| strategy_min_stop_points | 20 | >= 1 | Minimum valid stop distance in points. |
| strategy_max_spread_points | 0 | >= 0 | Optional spread cap; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - R3-approved liquid index target for futures-style ORB behavior.
- WS30.DWX - R3-approved liquid index target for futures-style ORB behavior.
- XAUUSD.DWX - R3-approved liquid metals target with intraday breakout behavior.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtest registration.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable S&P variants; not part of this card's R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | M15 EMA(50) by default via `strategy_htf`; configurable input. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday; exits at 2R, break-even stop, or configured session end. |
| Expected drawdown profile | Breakout system drawdowns concentrated in false-breakout and low-volume sessions. |
| Regime preference | Volatility-expansion breakout with trend and volume confirmation. |
| Win rate target (qualitative) | Medium; 2R target permits a moderate hit rate. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView public strategy script
**Pointer:** TradingView script `Xiznit Universal ORB 3.0`, author handle `Xiznit`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10733_tv-xiznit-orb.md`

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
| v1 | 2026-06-14 | Initial build from card | 628172a4-e3ab-481a-8c76-65f5b4079a1f |
