# QM5_10748_tv-qc-orb - Strategy Spec

**EA ID:** QM5_10748
**Slug:** tv-qc-orb
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA builds a 15-minute opening range from 09:30 ET on M5 bars, then locks the range high, low, and midpoint. A long setup starts after a closed bar breaks above the range high; it enters only after price pulls back to the broken high or midpoint and a bullish rejection candle closes back above that level. Shorts mirror the rule below the range low. Exits use a single full-position R:R target, an adaptive stop based on today's opening range versus prior opening ranges, and a forced flat rule at the configured session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_session_start_hour_et | 9 | 0-23 | Eastern Time session start hour. |
| strategy_session_start_min_et | 30 | 0-59 | Eastern Time session start minute. |
| strategy_orb_minutes | 15 | 5-45 | Opening range duration in minutes. |
| strategy_session_end_hour_et | 16 | 0-23 | Eastern Time forced-flat hour. |
| strategy_session_end_min_et | 0 | 0-59 | Eastern Time forced-flat minute. |
| strategy_adaptive_lookback | 20 | 20-120 | Number of prior opening ranges used for the adaptive average. |
| strategy_adaptive_min_ratio | 0.50 | 0.50-1.00 | Normal-range lower bound versus average OR range. |
| strategy_adaptive_max_ratio | 2.00 | 1.75-2.50 | Normal-range upper bound versus average OR range. |
| strategy_adaptive_stop_mult | 1.00 | 0.50-2.00 | Average OR range multiplier used when today's range is abnormal. |
| strategy_rr_target | 1.50 | 1.00-2.50 | Full-position reward:risk target. |
| strategy_retest_timeout_bars | 10 | 5-20 | Maximum M5 bars to wait for a retest after breakout. |
| strategy_retest_level_mode | 2 | 0-2 | Retest level: 0 boundary, 1 midpoint, 2 either. |
| strategy_min_or_range_points | 0 | 0+ | Optional minimum opening range in points; 0 disables. |
| strategy_max_spread_points | 0 | 0+ | Optional maximum spread in points; 0 disables. |
| strategy_trade_monday | true | true/false | Enables Monday entries. |
| strategy_trade_tuesday | true | true/false | Enables Tuesday entries. |
| strategy_trade_wednesday | true | true/false | Enables Wednesday entries. |
| strategy_trade_thursday | true | true/false | Enables Thursday entries. |
| strategy_trade_friday | true | true/false | Enables Friday entries. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index exposure listed in the card's primary P2 basket.
- WS30.DWX - Dow 30 index exposure listed in the card's primary P2 basket.
- GDAXI.DWX - Matrix-backed DAX custom symbol used for the card's GER40 exposure.
- XAUUSD.DWX - Matrix-backed gold CFD used for the card's XAUUSD exposure.
- EURUSD.DWX - Matrix-backed forex major listed in the card's primary P2 basket.
- GBPUSD.DWX - Matrix-backed forex major listed in the card's primary P2 basket.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the available DAX symbol.
- SP500.DWX - Mentioned by the card as optional backtest-only, not part of the primary P2 basket registered for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, from retest entry until R:R target, stop, or session-end flat. |
| Expected drawdown profile | Concentrated intraday breakout losses when opening ranges fail. |
| Regime preference | Breakout and volatility-expansion sessions after the opening range. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView protected-source strategy
**Pointer:** https://www.tradingview.com/script/LNECVcuq-Quantcrawler-ORB-Strategy-with-Adaptive-Risk-and-Session-Levels/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10748_tv-qc-orb.md`

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
| v1 | 2026-06-14 | Initial build from card | fb7c006b-1c7a-46ed-811d-6d99d28fbbd7 |
