# QM5_10094_gh-h4-zone - Strategy Spec

**EA ID:** QM5_10094
**Slug:** `gh-h4-zone`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA defines a daily breakout zone from the prior D1 high/low by default, with an alternate mode that uses the first configured H4 bars of the current day. On each M5 closed bar it looks for a bullish breakout candle that opened at or below the zone high, closed above it, and has enough body size. After that breakout it waits up to 24 hours for price to retest the zone high, then enters long if the bid is back at or below that level and the optional EMA filter has price above EMA 50 and EMA 200 on H1. Exits are by ATR SL/TP by default, optional break-even/trailing management, framework Friday close, and no discretionary opposite-signal close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | PERIOD_M5 | M1-D1 | Closed-bar timeframe used for breakout candle detection. |
| `strategy_ema_tf` | PERIOD_H1 | M1-D1 | Timeframe for the EMA 50/200 trend filter. |
| `strategy_atr_tf` | PERIOD_H1 | M1-D1 | Timeframe for ATR stop and target sizing. |
| `strategy_zone_mode` | 0 | 0-1 | 0 uses previous D1 high/low; 1 uses first H4 bars of the day. |
| `strategy_h4_zone_bars` | 1 | 1-6 | Number of H4 bars used when alternate zone mode is enabled. |
| `strategy_min_body_pct` | 50.0 | 0-100 | Minimum breakout candle body as percent of candle range. |
| `strategy_min_body_points` | 0.0 | >=0 | Alternate absolute body threshold in points. |
| `strategy_max_wait_seconds` | 86400 | >=0 | Seconds to keep a breakout retest state active. |
| `strategy_use_ema_filter` | true | true/false | Require price above EMA 50 and EMA 200 on the EMA timeframe. |
| `strategy_ema_fast_period` | 50 | >=1 | Fast EMA period. |
| `strategy_ema_slow_period` | 200 | >=1 | Slow EMA period. |
| `strategy_use_atr_sizing` | true | true/false | Use ATR stop/target instead of breakout-candle structural stop. |
| `strategy_atr_period` | 14 | >=1 | ATR period for default stop and target sizing. |
| `strategy_atr_sl_mult` | 1.5 | >0 | Stop distance multiplier on ATR. |
| `strategy_atr_tp_mult` | 3.0 | >0 | Target distance multiplier on ATR. |
| `strategy_fixed_rr` | 1.5 | >0 | Reward/risk target when ATR sizing is disabled. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour session start. |
| `strategy_session_end_hour` | 22 | 0-24 | Broker-hour session end. |
| `strategy_spread_cap_points` | 50 | >=0 | Maximum allowed symbol spread in points; 0 disables. |
| `strategy_enable_break_even` | false | true/false | Enable source-style break-even move. |
| `strategy_be_trigger_pips` | 30 | >=1 | Profit trigger for break-even. |
| `strategy_be_buffer_pips` | 2 | >=0 | Break-even buffer. |
| `strategy_enable_atr_trailing` | false | true/false | Enable ATR trailing stop management. |
| `strategy_trail_atr_mult` | 1.5 | >0 | ATR multiplier for trailing stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Primary card target; gold CFD from the cited source logic.
- `GDAXI.DWX` - Canonical DWX DAX symbol; used for the card's DAX port candidate.
- `NDX.DWX` - US index CFD port candidate from the card.
- `WS30.DWX` - US index CFD port candidate from the card.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not broker/tester supported in the DWX matrix.
- `DAX.DWX` - card wording maps to `GDAXI.DWX`, the canonical registered DAX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `D1` previous zone, optional `H4` zone, `H1` EMA and ATR defaults |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Not explicitly specified; intraday-to-multi-hour expected from M5 retest entries and H1 ATR SL/TP. |
| Expected drawdown profile | Bounded by framework fixed-risk sizing, one position per magic, and SL on every entry. |
| Regime preference | Breakout / trend-following with support-resistance retest. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub repository
**Pointer:** `https://github.com/phatnomenal/blackXAU_AUTOMATED-BOT-TRADE/blob/main/blackXAU2.mq5`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10094_gh-h4-zone.md`

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
| v1 | 2026-06-09 | Initial build from card | d8e32f8a-5882-4f4d-88f4-13e31f32595a |
