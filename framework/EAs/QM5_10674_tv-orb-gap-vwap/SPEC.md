# QM5_10674_tv-orb-gap-vwap - Strategy Spec

**EA ID:** QM5_10674
**Slug:** tv-orb-gap-vwap
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source pointer below)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades a New York opening range breakout on the M5 chart. It records the 09:30-09:45 NY opening range, then allows only the first closed-bar break above the range high or below the range low. Long entries require price above a rising session VWAP, volume above the session average by the configured multiplier, opening-range size inside configured bounds, price within 7 points of the breakout level, and price below the prior close when the gap-fill filter is enabled. Short entries mirror the logic below a falling VWAP and require price above the prior close when the gap-fill filter is enabled; exits use fixed TP, SL from reward-to-risk, and 15:00 NY flat.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ny_open_hour | 9 | 0-23 | New York session opening hour used to start the OR window. |
| strategy_ny_open_minute | 30 | 0-59 | New York session opening minute used to start the OR window. |
| strategy_ny_eod_hour | 15 | 0-23 | New York hour for strategy end-of-day flat. |
| strategy_ny_eod_minute | 0 | 0-59 | New York minute for strategy end-of-day flat. |
| strategy_or_minutes | 15 | 1-120 | Opening range length in minutes. |
| strategy_vwap_slope_bars | 1 | 1-10 | Minimum configured slope lookback; the implementation compares current cached VWAP against prior cached VWAP. |
| strategy_volume_mult | 1.20 | 0.1-10.0 | Breakout bar tick volume must exceed prior session average by this multiplier. |
| strategy_min_or_size_pct | 0.02 | 0.0-5.0 | Minimum opening-range width as percent of price. |
| strategy_max_or_size_pct | 0.80 | 0.01-10.0 | Maximum opening-range width as percent of price. |
| strategy_gap_filter_enabled | true | true/false | Enables the prior-close gap-fill bias filter. |
| strategy_breakout_max_points | 7.0 | 0.1-1000.0 | Maximum distance from closed-bar breakout close to the OR boundary. |
| strategy_tp_points | 10.0 | 0.1-10000.0 | Fixed TP distance in symbol price points. |
| strategy_reward_risk | 2.0 | 0.1-20.0 | Reward-to-risk ratio used to derive SL distance from TP distance. |
| strategy_min_avg_volume | 1.0 | 0.0-1000000.0 | Minimum prior session average tick volume required for volume confirmation. |
| strategy_max_spread_points | 0 | 0-100000 | Optional spread ceiling in symbol points; 0 disables the ceiling. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index exposure named directly in the card's P2 basket.
- WS30.DWX - Dow 30 index exposure named directly in the card's P2 basket.
- GDAXI.DWX - DAX exposure; used as the available DWX matrix equivalent for card-stated GER40.DWX.
- XAUUSD.DWX - Gold exposure named directly in the card's P2 basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- SP500.DWX - mentioned only as a later caveat in the card, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, from post-opening-range breakout until fixed TP/SL or 15:00 NY flat |
| Expected drawdown profile | Breakout strategy with fixed risk, small stop distance, and one trade per symbol per day |
| Regime preference | Opening-range breakout with VWAP trend confirmation and gap-fill bias |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView invite-only strategy
**Pointer:** TradingView script `Opening Range Breakout (ORB)`, author handle `levasses`, published 2026-03-07 and updated 2026-05-01, https://www.tradingview.com/script/AMsB94Rs-Opening-Range-Breakout-ORB/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10674_tv-orb-gap-vwap.md`

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
| v1 | 2026-06-14 | Initial build from card | 44027b50-e574-4d4a-8aab-5333f485cfdc |
