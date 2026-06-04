# QM5_10709_tv-orb-multitp - Strategy Spec

**EA ID:** QM5_10709
**Slug:** `tv-orb-multitp`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView script source cited by the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-04

---

## 1. Strategy Logic

The EA locks the high and low of the first 30 minutes of the configured intraday session. After the opening range is locked, it buys when current price breaks above the range high and sells when current price breaks below the range low, with only the first breakout per direction allowed each session. The baseline stop is the opposite side of the opening range, with an optional midpoint stop parameter for later sweeps. The EA closes 50 percent of the net position at 1.0R, leaves the remainder targeting 2.0R, and force-closes any remaining position at the configured session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_start_hour` | 9 | 0-23 | Broker-time hour for the session start. |
| `strategy_session_start_minute` | 0 | 0-59 | Broker-time minute for the session start. |
| `strategy_session_end_hour` | 17 | 0-23 | Broker-time hour for force-close and entry cutoff. |
| `strategy_session_end_minute` | 0 | 0-59 | Broker-time minute for force-close and entry cutoff. |
| `strategy_opening_range_minutes` | 30 | 1-240 | Minutes from session start used to lock the opening range. |
| `strategy_range_lookback_bars` | 256 | 8-1000 | Closed bars scanned once per new bar to compute the current session range. |
| `strategy_min_range_pct` | 0.15 | 0.00-10.00 | Minimum opening-range width as percent of mid-price. |
| `strategy_max_range_pct` | 1.25 | 0.01-10.00 | Maximum opening-range width as percent of mid-price. |
| `strategy_use_midpoint_stop` | false | true/false | Use midpoint stop instead of opposite range side. |
| `strategy_tp1_rr` | 1.0 | 0.1-10.0 | First deterministic partial-close target in R. |
| `strategy_tp2_rr` | 2.0 | 0.1-10.0 | Remaining-position broker take-profit target in R. |
| `strategy_tp1_close_pct` | 50.0 | 0.0-100.0 | Percent of current net volume to reduce at TP1. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional spread ceiling; 0 disables this card-unspecified filter. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DAX custom symbol verified in `dwx_symbol_matrix.csv`; used as the available port for card-stated `GER40.DWX`.
- `NDX.DWX` - Nasdaq 100 index CFD, matching the card's US index ORB target.
- `WS30.DWX` - Dow 30 index CFD, matching the card's US index ORB target.
- `EURUSD.DWX` - Liquid FX major named by the card.
- `XAUUSD.DWX` - Gold symbol named by the card.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the verified DAX equivalent in this repo.
- `SP500.DWX` - The card mentions SP500 only as a backtest-only comparison, not as a primary target basket member.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, minutes to the configured session end |
| Expected drawdown profile | Breakout whipsaws during narrow or false range expansions |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium, with expectancy from 1R partial and 2R remainder |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Open Range Breakout Strategy With Multi TakeProfit`, author handle `Milvetti`, published 2025-08-13 per card citation, https://www.tradingview.com/script/Tr0vgxkq-Open-Range-Breakout-Strategy-With-Multi-TakeProfit/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10709_tv-orb-multitp.md`

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
| v1 | 2026-06-04 | Initial build from card | 8b308faa-1c13-466c-8b59-0850fd17058c |
