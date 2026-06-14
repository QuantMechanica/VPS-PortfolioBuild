# QM5_10654_tv-orb-width - Strategy Spec

**EA ID:** QM5_10654
**Slug:** tv-orb-width
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades a New York regular-session opening range breakout on M5 bars. It records the high and low from 09:30 through 10:15 ET, locks that range after the window closes, and skips the day if the range width is less than 0.35% of the current price. If the day passes the width filter, it places a buy stop at the opening-range high and a sell stop at the opening-range low; when one side triggers, the opposite pending order is removed. The stop is 50% of the opening-range width and the take profit is 1.1R, with any open position closed at 15:45 ET.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_broker_to_ny_offset_hours` | 7 | 0-23 | Converts broker time to New York session time. |
| `strategy_or_start_hhmm` | 930 | 0000-2359 | Opening-range start time in ET. |
| `strategy_or_end_hhmm` | 1015 | 0000-2359 | Opening-range end time in ET. |
| `strategy_session_close_hhmm` | 1545 | 0000-2359 | Hard-flat time in ET. |
| `strategy_min_width_pct` | 0.35 | >0 | Minimum opening-range width as percent of price. |
| `strategy_stop_range_fraction` | 0.50 | >0 | Stop distance as a fraction of opening-range width. |
| `strategy_reward_risk` | 1.10 | >0 | Take-profit distance in R multiples. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Primary card index CFD for NY-session breakout behavior.
- `WS30.DWX` - Primary card index CFD for NY-session breakout behavior.
- `XAUUSD.DWX` - Primary card gold CFD with NY-session liquidity.
- `SP500.DWX` - Card-listed optional S&P 500 backtest-only port; registered for P2 saturation because it is present in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts require canonical `.DWX` names.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker tick data is not available for P2.

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
| Trades / year / symbol | 180 |
| Typical hold time | Intraday, from post-10:15 ET breakout to SL/TP or 15:45 ET hard flat |
| Expected drawdown profile | Not specified in card frontmatter |
| Regime preference | Opening-range breakout / volatility expansion |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView script
**Pointer:** TradingView script `Opening-Range Breakout`, author `fabledforman`, published 2025-07-30, https://www.tradingview.com/script/8vjWAdLN-Opening-Range-Breakout/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10654_tv-orb-width.md`

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
| v1 | 2026-06-14 | Initial build from card | bec9cf5f-11c4-451c-8527-d06bf40fb8dc |
