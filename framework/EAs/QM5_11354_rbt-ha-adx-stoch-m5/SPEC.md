# QM5_11354_rbt-ha-adx-stoch-m5 — Strategy Spec

**EA ID:** QM5_11354
**Slug:** `rbt-ha-adx-stoch-m5`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (RoboForex Strategy Collection PDF)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Intraday Heikin-Ashi trend-confirmation on M5. The EA reconstructs Heikin-Ashi
candles deterministically from raw OHLC over a bounded warmup window (no HA
indicator reader), caching the last few closed-bar HA opens/closes once per new
bar. It then trades a confluence of three forces: a Heikin-Ashi STATE (two
consecutive same-colour HA bars plus HA-mid on the correct side of an SMA of the
HA close line), an ADX(14) STATE (ADX above 22 = a trend is present), and a
Stochastic(5,3,3) STATE (%K heading in the trade direction and not at the far
extreme). To avoid the "two crossovers on the same bar never coincide"
zero-trade trap, exactly ONE fresh EVENT is required to fire: either a Heikin-Ashi
colour flip into the trade direction on the last closed bar, OR a Stochastic %K
cross of its mid level (50) in the trade direction. Long fires when the bullish
states hold and one bullish event occurs; short is the mirror. Stop is a fixed 10
pips and take-profit a fixed 15 pips (both pip-scaled). A defensive exit closes
the position on the first opposite-colour Heikin-Ashi bar. Trading is restricted
to the London+NY session (13:00-22:00 UTC, DST-correct via broker→UTC conversion).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ha_warmup_bars` | 200 | 60-500 | Bounded HA reconstruction window (bars folded forward each closed bar) |
| `strategy_ha_consec_bars` | 2 | 1-3 | Consecutive same-colour HA bars required (STATE) |
| `strategy_ha_ma_period` | 14 | 5-50 | SMA period of HA close used as the HA-mean proxy |
| `strategy_adx_period` | 14 | 7-28 | ADX period (trend-strength STATE) |
| `strategy_adx_threshold` | 22.0 | 15-35 | ADX must exceed this for a trade |
| `strategy_stoch_k` | 5 | 3-21 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 2-9 | Stochastic %D period |
| `strategy_stoch_slow` | 3 | 1-9 | Stochastic slowing |
| `strategy_stoch_mid` | 50.0 | 40-60 | %K mid level for the cross EVENT |
| `strategy_stoch_ob` | 80.0 | 70-90 | Overbought guard — long blocked above |
| `strategy_stoch_os` | 20.0 | 10-30 | Oversold guard — short blocked below |
| `strategy_sl_pips` | 10 | 5-40 | Fixed stop-loss, pips (pip-scaled) |
| `strategy_tp_pips` | 15 | 8-60 | Fixed take-profit, pips (pip-scaled) |
| `strategy_sess_start_utc` | 13 | 0-23 | Session start hour, UTC |
| `strategy_sess_end_utc` | 22 | 0-23 | Session end hour, UTC |
| `strategy_spread_pct_of_stop` | 25.0 | 5-100 | Block only if spread exceeds this % of stop distance (fail-open on zero spread) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity major; tight spread suits a 10-pip stop on M5.
- `GBPUSD.DWX` — liquid major with strong London/NY directional moves matching the session filter.
- `USDJPY.DWX` — liquid major; pip-scaling helper handles the JPY (2/3-digit) quote correctly.

**Explicitly NOT for:**
- Index/commodity `.DWX` symbols — the fixed 10/15-pip stop/target and HA-flip
  cadence are calibrated to FX major pip behaviour, not index point ranges.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~400` |
| Typical hold time | `minutes to a few hours (intraday M5)` |
| Expected drawdown profile | `frequent small losers (10-pip stops), bounded by intraday holds` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** `book` (RoboForex strategy-collection PDF)
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11354_rbt-ha-adx-stoch-m5.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | (pending build commit) |
