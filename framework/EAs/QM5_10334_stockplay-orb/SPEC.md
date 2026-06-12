# QM5_10334_stockplay-orb - Strategy Spec

**EA ID:** QM5_10334
**Slug:** stockplay-orb
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades a five-minute opening range breakout on the U.S. cash-session window. It records the first session bar as the opening range, then compares the first fifteen minutes of tick volume against the median first-fifteen-minute volume from the prior twenty sessions. If the session is in play, it buys after a break above the opening-range high or sells after a break below the opening-range low, taking only the first breakout of the session. It exits at the configured cash-session close or early when a closed bar returns inside the opening range.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_hour` | 16 | 0-23 | Broker-time hour for the U.S. cash-session open. |
| `strategy_session_start_minute` | 30 | 0-59 | Broker-time minute for the U.S. cash-session open. |
| `strategy_session_end_hour` | 23 | 0-23 | Broker-time hour for the cash-session close exit. |
| `strategy_session_end_minute` | 0 | 0-59 | Broker-time minute for the cash-session close exit. |
| `strategy_opening_range_minutes` | 5 | 5 | Opening range length from the card. |
| `strategy_relative_volume_minutes` | 15 | 15 | First-session volume window for the in-play gate. |
| `strategy_volume_median_sessions` | 20 | 1-60 | Number of prior sessions used for median first-15-minute tick volume. |
| `strategy_relative_volume_min` | 1.50 | 1.00-5.00 | Minimum first-15-minute relative volume for in-play classification. |
| `strategy_news_proxy_window_minutes` | 120 | 0-240 | First-session minutes checked for a high-impact scheduled event as the card's news proxy. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the emergency stop cap. |
| `strategy_emergency_atr_mult` | 1.00 | 0.10-5.00 | Maximum stop distance as ATR multiple when the opening range is wide. |
| `strategy_spread_history_bars` | 100 | 20-200 | Closed-bar spread samples used for the rolling percentile filter. |
| `strategy_spread_percentile` | 80.0 | 50.0-99.0 | Spread percentile threshold above which new entries are skipped. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - canonical S&P 500 custom symbol for the U.S. large-cap ORB port.
- `NDX.DWX` - Nasdaq 100 index CFD, matching the U.S. large-cap intraday breakout theme.
- `WS30.DWX` - Dow 30 index CFD, matching the U.S. large-cap intraday breakout theme.

**Explicitly NOT for:**
- `SPY.DWX` - not present in the DWX symbol matrix.
- `SPX500.DWX` - not present in the DWX symbol matrix.
- `ES.DWX` - not present in the DWX symbol matrix.

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
| Trades / year / symbol | `90` |
| Typical hold time | Intraday, from post-open breakout to same-session close or earlier inside-range close |
| Expected drawdown profile | Breakout losses are bounded by the opposite opening-range side with a 1.00 ATR emergency cap |
| Regime preference | Breakout / news-driven / high relative-volume sessions |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** Carlo Zarattini, Andrea Barbon, Andrew Aziz, SSRN abstract 4729284, 2024/2025
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10334_stockplay-orb.md`

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
| v1 | 2026-06-13 | Initial build from card | 251aeed0-d032-4f79-b4d5-51bab969cf33 |
