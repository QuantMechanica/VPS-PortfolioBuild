# QM5_9723_ff-sonicr-scout-h1 - Strategy Spec

**EA ID:** QM5_9723
**Slug:** `ff-sonicr-scout-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA trades H1 Scout reversals on liquid FX pairs. It waits for a significant ATR-scaled run into a whole/half-number or repeated swing support/resistance zone, then requires a rejection candle with at least 45% wick and a close back through the zone midpoint. Long trades buy support rejection after a down run; short trades sell resistance rejection after an up run. The stop sits beyond the rejection zone with an ATR buffer, the target is the closer of 3R or the next opposing zone, and exits also occur on adverse zone close or after 12 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 5-50 | ATR period for zone width, run size, and stop buffer. |
| `strategy_swing_lookback_bars` | 80 | 20-200 | H1 bars scanned for repeated swing-zone rejections. |
| `strategy_run_lookback_bars` | 20 | 10-80 | Bars used to measure the pre-entry significant run. |
| `strategy_swing_reject_count` | 2 | 2-5 | Required repeated swing touches near the candidate zone. |
| `strategy_round_step_pips` | 50 | 25-100 | Whole/half-number zone spacing in pips. |
| `strategy_zone_atr_mult` | 0.35 | 0.10-1.00 | ATR multiple used as half-width around S/R zones. |
| `strategy_run_atr_mult` | 2.0 | 0.5-5.0 | Minimum run size before a Scout reversal is valid. |
| `strategy_wick_min_pct` | 45.0 | 20.0-80.0 | Minimum rejection wick as percent of total bar range. |
| `strategy_sl_atr_buffer` | 0.20 | 0.05-1.00 | ATR buffer beyond the rejection zone for the stop. |
| `strategy_max_stop_atr` | 1.40 | 0.50-3.00 | Rejects trades with initial risk above this ATR multiple. |
| `strategy_tp_r_mult` | 3.0 | 1.0-5.0 | R-multiple cap for the profit target. |
| `strategy_min_opposing_r` | 2.5 | 1.0-5.0 | Minimum distance to the next opposing zone in R units. |
| `strategy_time_stop_bars` | 12 | 1-48 | Maximum hold time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with reliable H1 liquidity and round-number structure.
- `GBPUSD.DWX` - major FX pair suited to whole/half-number support and resistance.
- `USDJPY.DWX` - JPY major; pip scaling handles 50-pip round steps.
- `EURJPY.DWX` - liquid cross with repeated H1 round-number reactions.

**Explicitly NOT for:**
- `XAUUSD.DWX` - metal volatility and level geometry differ from the Sonic R FX Scout premise.
- `SP500.DWX` - index-only structure is outside this card's R3 FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | 1-12 hours |
| Expected drawdown profile | Reversal strategy; losses cluster when runs continue through apparent support/resistance. |
| Regime preference | mean-revert / reversal after significant intraday runs |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/114792-sonic-r-system`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9723_ff-sonicr-scout-h1.md`

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
| v1 | 2026-07-09 | Initial build from card | `fde41b9f-3707-4b2d-9b85-9119f5008b01` |
