# QM5_11450_london-breakfast-asian-range-m15 - Strategy Spec

**EA ID:** QM5_11450
**Slug:** london-breakfast-asian-range-m15
**Source:** 5e8b6dc8-07fd-5faf-823f-35c966d028a4 (see `strategy-seeds/sources/5e8b6dc8-07fd-5faf-823f-35c966d028a4/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA builds the Asian session range from closed M15 bars whose UTC bar-open time is from 00:00 through 07:45. During the London open it checks only the first three M15 bars opening at 08:00, 08:15, and 08:30 UTC. A close above the Asian high opens a buy; a close below the Asian low opens a sell. If the first intrabar break does not close outside the range, the day is marked done and no opposite-side flip is allowed. Open positions use fixed SL/TP, a 10-pip breakeven-plus stop move after 20 pips profit, and a 10:00 UTC time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_asian_start_hour` | 0 | 0-23 | UTC hour that starts Asian-range accumulation. |
| `strategy_asian_start_minute` | 0 | 0-59 | UTC minute that starts Asian-range accumulation. |
| `strategy_asian_end_hour` | 8 | 1-23 | UTC hour that ends Asian-range accumulation. |
| `strategy_asian_end_minute` | 0 | 0-59 | UTC minute that ends Asian-range accumulation. |
| `strategy_london_open_hour` | 8 | 0-23 | UTC hour for the first London breakout bar. |
| `strategy_london_open_minute` | 0 | 0-59 | UTC minute for the first London breakout bar. |
| `strategy_entry_bars_to_check` | 3 | 1-12 | Number of M15 bars checked after London open. |
| `strategy_time_stop_hour` | 10 | 0-23 | UTC hour to close any still-open trade. |
| `strategy_time_stop_minute` | 0 | 0-59 | UTC minute to close any still-open trade. |
| `strategy_range_min_pips` | 15 | 1-200 | Minimum Asian range width required. |
| `strategy_range_max_pips` | 80 | 1-300 | Maximum Asian range width allowed. |
| `strategy_sl_inside_pips` | 10 | 1-100 | Stop offset back inside the Asian range. |
| `strategy_sl_cap_pips` | 30 | 1-100 | Maximum total SL distance for P2. |
| `strategy_tp_pips` | 40 | 1-200 | Fixed take-profit distance. |
| `strategy_trail_trigger_pips` | 20 | 1-200 | Profit threshold before moving stop. |
| `strategy_trail_buffer_pips` | 10 | 0-100 | Breakeven-plus stop buffer after trigger. |
| `strategy_spread_cap_pips` | 15 | 1-100 | Maximum modeled spread before rejecting entry. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid London-session FX major.
- `GBPUSD.DWX` - card-listed liquid London-session FX major.
- `USDJPY.DWX` - card-listed liquid FX major with DWX M15 data.
- `AUDUSD.DWX` - card-listed liquid FX major with DWX M15 data.
- `USDCAD.DWX` - card-listed liquid FX major with DWX M15 data.

**Explicitly NOT for:**
- `SP500.DWX` - index behavior is not the card's London FX breakfast setup.
- `XAUUSD.DWX` - metal volatility/session behavior is outside the approved card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `200` |
| Typical hold time | Intraday, usually minutes to 2 hours |
| Expected drawdown profile | Breakout losses cluster on false London-open moves; capped by 30-pip SL. |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 5e8b6dc8-07fd-5faf-823f-35c966d028a4
**Source type:** forum / anonymous online community strategy
**Pointer:** local PDF `423041768-London-Free-Breakfast-Forex-Trading-Strategy-1.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11450_london-breakfast-asian-range-m15.md`

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
| v1 | 2026-06-20 | Initial build from card | ef8c8949-df83-45d4-a02b-cc2c7024a562 |
