# QM5_11066_atc-channel-brk - Strategy Spec

**EA ID:** QM5_11066
**Slug:** `atc-channel-brk`
**Source:** `429e4612-2e1d-57be-b12e-ff8b94d42117` (see `strategy-seeds/sources/429e4612-2e1d-57be-b12e-ff8b94d42117/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

On each closed M5 bar, the EA calculates the highest high and lowest low over the last 48 M5 bars to define a horizontal channel. If the latest closed price is between 35% and 65% of the channel depth and the channel width is at least 0.8 x ATR(14), it arms a buy stop above the channel high and a sell stop below the channel low. Each order has a stop equal to 0.5 x channel width, a 1.5R target, and a 12-bar expiry. When one side fills, the EA cancels the opposite pending order and optionally trails the stop after the trade moves at least 1R in favor.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_M5` | M1-MN1 | Timeframe used for the channel and ATR reads. |
| `strategy_channel_bars` | `48` | `2+` | Number of closed M5 bars in the horizontal channel. |
| `strategy_depth_min` | `0.35` | `0.0-1.0` | Minimum allowed normalized channel depth before arming orders. |
| `strategy_depth_max` | `0.65` | `0.0-1.0` | Maximum allowed normalized channel depth before arming orders. |
| `strategy_entry_buffer_points` | `5` | `0+` | Points added above the high and below the low for stop-order placement. |
| `strategy_stop_channel_mult` | `0.50` | `>0` | Stop distance as a multiple of channel width, subject to broker minimum stop distance. |
| `strategy_take_profit_rr` | `1.50` | `>0` | Take-profit distance in R multiples. |
| `strategy_order_expiry_bars` | `12` | `1+` | Maximum age for unfilled pending orders. |
| `strategy_atr_period` | `14` | `1+` | ATR period used by the minimum channel-width filter. |
| `strategy_min_channel_atr_mult` | `0.80` | `0+` | Required channel width as a multiple of ATR(14). |
| `strategy_max_spread_points` | `30` | `0+` | Maximum spread in points before new orders are blocked; `0` disables the check. |
| `strategy_session_filter_enabled` | `true` | `true/false` | Enables the liquid-hours entry session filter. |
| `strategy_session_start_hour` | `7` | `0-23` | Broker-hour start of the default London/New York entry window. |
| `strategy_session_end_hour` | `21` | `0-23` | Broker-hour end of the default London/New York entry window. |
| `strategy_trailing_enabled` | `true` | `true/false` | Enables the optional trailing rule. |
| `strategy_trail_start_r` | `1.00` | `>0` | Favorable movement in R before trailing begins. |
| `strategy_trail_distance_r` | `0.50` | `>0` | Trailing distance in R after the trigger is reached. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - The card's R3 row maps EURUSD directly to EURUSD.DWX and names no additional portable basket.

**Explicitly NOT for:**
- Other `.DWX` symbols - They were not listed in the card's R3 PASS row for this EA.

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
| Trades / year / symbol | `250` |
| Typical hold time | M5 breakout holds, usually minutes to hours; not specified in frontmatter. |
| Expected drawdown profile | Stop-defined breakout drawdown with fixed 1R risk per trade; not specified in frontmatter. |
| Regime preference | Volatility expansion / channel breakout. |
| Win rate target (qualitative) | Medium, with 1.5R target offsetting normal breakout failures. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `429e4612-2e1d-57be-b12e-ff8b94d42117`
**Source type:** MQL5 article / interview
**Pointer:** `https://www.mql5.com/en/articles/538` and `artifacts/cards_approved/QM5_11066_atc-channel-brk.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11066_atc-channel-brk.md`

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
| v1 | 2026-06-07 | Initial build from card | 571004bd-0e2f-4878-869c-39ace45cefa4 |
