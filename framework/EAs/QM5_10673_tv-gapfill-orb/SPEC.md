# QM5_10673_tv-gapfill-orb - Strategy Spec

**EA ID:** QM5_10673
**Slug:** tv-gapfill-orb
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades the first reaction after a session gap. It records the first 15 minutes after the configured cash-session open as the opening range, compares the session open to the prior session close, and only trades if the gap is at least the larger of 0.15% or 0.5 ATR(M15). For gap fills, a gap down buys when price reclaims the opening-range low and targets the prior close, while a gap up sells when price rejects below the opening-range high and targets the prior close. For continuation, a gap up buys a close above the opening-range high and a gap down sells a close below the opening-range low, with a 2R target and session-end forced exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_session_open_hour | 15 | 0-23 | Broker-time cash-session open hour. |
| strategy_session_open_minute | 30 | 0-59 | Broker-time cash-session open minute. |
| strategy_session_close_hour | 22 | 0-23 | Broker-time forced-flat session close hour. |
| strategy_session_close_minute | 0 | 0-59 | Broker-time forced-flat session close minute. |
| strategy_or_minutes | 15 | 1-120 | Minutes after session open used to build the opening range. |
| strategy_atr_period | 14 | 2-100 | ATR period used for gap and opening-range width filters. |
| strategy_min_gap_pct | 0.15 | 0.00-5.00 | Minimum absolute gap as percent of prior session close. |
| strategy_min_gap_atr_mult | 0.50 | 0.10-5.00 | Minimum absolute gap as ATR multiple. |
| strategy_or_width_atr_max | 1.50 | 0.10-10.00 | Maximum opening-range width as ATR multiple. |
| strategy_gapfill_stop_atr_mult | 0.25 | 0.01-5.00 | Gap-fill stop buffer beyond the opening-range boundary. |
| strategy_continuation_rr | 2.00 | 0.25-10.00 | Fixed R target for continuation trades. |
| strategy_max_spread_points | 0 | 0-100000 | Optional no-entry spread cap; 0 disables the cap. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index CFD fits the card's liquid index opening-gap basket.
- GDAXI.DWX - Canonical DWX DAX symbol used in place of the card's GER40.DWX name.
- WS30.DWX - Dow 30 index CFD fits the card's US large-cap opening-gap basket.
- XAUUSD.DWX - Gold CFD fits the card's commodity session-gap basket.
- XTIUSD.DWX - Oil CFD fits the card's commodity session-gap basket.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | ATR reads PERIOD_M15 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday, from post-opening-range reaction to fixed target or session close |
| Expected drawdown profile | Gap and breakout losses are capped by opening-range stops with one trade per session |
| Regime preference | Gap-fill mean reversion and opening-range continuation after liquid-session gaps |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/aydoOjNc-Gap-Fill-Opening-Range-Strategy/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10673_tv-gapfill-orb.md`

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
| v1 | 2026-06-14 | Initial build from card | 7414ba98-7df7-471c-b633-1130da932e95 |
