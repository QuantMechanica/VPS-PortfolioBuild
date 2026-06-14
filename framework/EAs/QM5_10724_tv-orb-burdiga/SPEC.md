# QM5_10724_tv-orb-burdiga - Strategy Spec

**EA ID:** QM5_10724
**Slug:** tv-orb-burdiga
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView script citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA records the first 30 minutes of the configured broker-time session as an opening range. After the range closes, a long setup arms when a closed bar breaks above the range high, then enters only after a later closed bar retests the high and closes back above it. A short setup mirrors this below the range low. Stops sit at the opposite opening-range boundary, take profit is 1.5R, breakeven moves the stop to entry after price moves 50% of the opening-range width, and any open position is closed at session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_or_minutes | 30 | 1-240 | Minutes used to build the opening range from the session open. |
| strategy_us_or_start_hhmm | 1530 | 0000-2359 | Broker-time US session opening-range start for NDX, WS30, SP500, and XAUUSD. |
| strategy_eu_or_start_hhmm | 900 | 0000-2359 | Broker-time EU session opening-range start for GDAXI and UK100. |
| strategy_us_session_end_hhmm | 2200 | 0000-2359 | Broker-time force-flat time for US-session symbols. |
| strategy_eu_session_end_hhmm | 1730 | 0000-2359 | Broker-time force-flat time for EU-session symbols. |
| strategy_min_bars_after_break | 1 | 0-20 | Minimum closed bars after the initial breakout before retest entry is allowed. |
| strategy_setup_timeout_bars | 20 | 1-200 | Bars after breakout before an unfilled retest setup is cancelled. |
| strategy_atr_period | 14 | 2-200 | ATR period for opening-range width validation. |
| strategy_min_or_atr_mult | 0.40 | 0.0-10.0 | Skip if OR width is below this multiple of ATR(14). |
| strategy_max_or_atr_mult | 3.00 | 0.1-20.0 | Skip if OR width is above this multiple of ATR(14). |
| strategy_reward_risk | 1.50 | 0.1-10.0 | Fixed take-profit multiple of stop distance. |
| strategy_be_width_fraction | 0.50 | 0.0-5.0 | Move stop to breakeven after this fraction of OR width in profit. |
| strategy_be_buffer_points | 0 | 0-10000 | Optional point buffer added to breakeven stop. |
| strategy_max_spread_points | 0 | 0-100000 | Optional entry spread cap; 0 disables because the card did not specify a spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 is one of the card's target US index CFDs.
- WS30.DWX - Dow 30 is one of the card's target US index CFDs.
- SP500.DWX - S&P 500 is explicitly allowed for backtest-only S&P exposure.
- GDAXI.DWX - DAX exposure; used as the DWX canonical equivalent for the card's GER40 target.
- UK100.DWX - FTSE 100 is one of the card's target EU index CFDs.
- XAUUSD.DWX - Gold is included in the card's target basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - not canonical DWX symbols for S&P 500 exposure.

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
| Typical hold time | Intraday; entry after OR retest, forced flat by session end |
| Expected drawdown profile | Breakout/retest losses are capped at the opposite OR boundary |
| Regime preference | Breakout / volatility expansion after a defined opening range |
| Win rate target (qualitative) | Medium, with 1.5R winners offsetting failed retests |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView script
**Pointer:** TradingView script `ORB Strategy by Burdiga84`, https://fr.tradingview.com/script/cMF0qjoB/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10724_tv-orb-burdiga.md`

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
| v1 | 2026-06-14 | Initial build from card | 7a5e20f5-0fa6-4d60-ae1e-baf4b93ca880 |
