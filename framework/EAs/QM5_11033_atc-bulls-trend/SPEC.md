# QM5_11033_atc-bulls-trend - Strategy Spec

**EA ID:** QM5_11033
**Slug:** `atc-bulls-trend`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades the first directional impulse after a Bulls Power trend change on completed bars. Long entries require Bulls Power above zero, ATR-normalized Bulls Power slope above the threshold, and the last close above the EMA of the Bulls period. Short entries require negative Bulls Power, or optional negative Bear Power confirmation, with the opposite slope and close-below-EMA conditions. Exits are the fixed 2R take profit, the fixed stop, framework Friday close, and optional early close when Bulls Power crosses back through zero.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bulls_period` | 13 | 13, 21, 34 | EMA period used in Bulls Power and Bear Power. |
| `strategy_trend_lookback` | 5 | 3, 5, 8 | Bars back for Bulls Power slope comparison. |
| `strategy_bulls_slope_threshold` | 0.50 | 0.25-0.75 | Minimum ATR-normalized Bulls Power slope. |
| `strategy_atr_period` | 14 | 14 | ATR period used for stop and slope normalization. |
| `strategy_atr_sl_mult` | 1.50 | 1.0-2.0 | ATR stop multiplier. |
| `strategy_fixed_sl_pips` | 40 | 30-50 | Fixed pip stop candidate; larger of this and ATR stop is used. |
| `strategy_reward_risk` | 2.0 | 2.0 | Take profit multiple of stop distance. |
| `strategy_use_bear_power` | true | true/false | Allows Bear Power to confirm short entries. |
| `strategy_use_adx_filter` | true | true/false | Enables the optional ADX trend confirmation filter. |
| `strategy_adx_period` | 14 | 14 | ADX period for optional trend confirmation. |
| `strategy_adx_min` | 18.0 | 18.0 | Minimum ADX when the optional filter is enabled. |
| `strategy_use_zero_cross_exit` | true | true/false | Enables early close on Bulls Power zero-cross. |
| `strategy_session_start_hour` | 8 | 0-23 | Broker-hour start for London/New York liquid hours. |
| `strategy_session_end_hour` | 22 | 0-23 | Broker-hour end for London/New York liquid hours. |
| `strategy_max_spread_pips` | 3 | 0+ | Maximum modeled spread in pips; zero spread remains tradeable. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary source-compatible major FX pair with deep DWX H1 history.
- `GBPUSD.DWX` - major London/New York FX pair fitting the liquid-hours filter.
- `EURJPY.DWX` - card-listed FX cross with DWX H1 data and trend impulse behavior.
- `USDJPY.DWX` - card-listed major FX pair with DWX H1 data and liquid-session coverage.

**Explicitly NOT for:**
- `SP500.DWX` - index symbol outside the card's FX basket.
- `NDX.DWX` - index symbol outside the card's FX basket.
- `XAUUSD.DWX` - commodity symbol outside the card's FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | hours to a few days, bounded by fixed SL/TP and Friday close |
| Expected drawdown profile | trend-continuation losses cluster during choppy reversals after near-miss TP moves |
| Regime preference | trend / momentum-breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `article`
**Pointer:** `https://www.mql5.com/en/articles/537`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11033_atc-bulls-trend.md`

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
| v1 | 2026-06-18 | Initial build from card | 0442f8ee-fa0e-41b3-b8f7-811fc4e75ab9 |
