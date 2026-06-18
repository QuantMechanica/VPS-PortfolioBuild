# QM5_11438_td-ema9ema30-momentum-h1 — Strategy Spec

**EA ID:** QM5_11438
**Slug:** `td-ema9ema30-momentum-h1`
**Source:** `fb2ae527-c7ef-5765-a09d-9eb8157e55a0` (see `strategy-seeds/sources/fb2ae527-c7ef-5765-a09d-9eb8157e55a0/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Trend-following breakout on H1. The single entry EVENT is an EMA(9)/EMA(30)
crossover on the last closed bar. Two STATES confirm it: Momentum(10) above 100
for a long (close higher than 10 bars ago) or below 100 for a short, and a
3-bar swing break — the last closed bar's high exceeds the prior two bars' highs
(long) or its low undercuts the prior two bars' lows (short). The 3-bar swing
break is the card's explicit deterministic, bounded, closed-bar approximation of
a Tom DeMark trend-line break. Entry is at market on the new-bar gate after the
trigger bar closes through the swing. Stop is a fixed 40 pips; take-profit is
ATR(14) x 2.0 from entry. The position also exits early if EMA(9) crosses back
across EMA(30) against the trade (trend reversal).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 9 | 5-13 | Fast EMA period for the cross event |
| `strategy_ema_slow_period` | 30 | 20-50 | Slow EMA period for the cross event |
| `strategy_mom_period` | 10 | 5-20 | Momentum period; compared to baseline 100 |
| `strategy_mom_baseline` | 100.0 | 100 | Momentum neutral level (>100 bull, <100 bear) |
| `strategy_swing_lookback` | 3 | 3-5 | N-bar swing for the TD break (High[1]>High[2..N]) |
| `strategy_sl_pips` | 40 | 30-60 | Fixed initial stop in pips (card 40, P2 cap 50) |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the take-profit target |
| `strategy_tp_atr_mult` | 2.0 | 1.5-3.0 | Take-profit distance = ATR x mult |
| `strategy_max_spread_pips` | 20 | 10-30 | Skip only a genuinely wide spread (fail-open on .DWX) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; clean H1 trend/momentum structure.
- `GBPUSD.DWX` — liquid major with strong intraday momentum bursts.
- `USDJPY.DWX` — trending major; 3-digit pip scaling handled via QM_Stop* helpers.
- `AUDUSD.DWX` — commodity major; trend-and-momentum responsive on H1.
- `USDCAD.DWX` — commodity major; complements the basket for diversification.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card scopes this strategy to FX majors;
  the fixed-pip stop and momentum baseline are calibrated for FX H1.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~55` |
| Typical hold time | `hours (intraday to a few days)` |
| Expected drawdown profile | `moderate; trend-following with fixed 40-pip stop` |
| Regime preference | `breakout / trend` |
| Win rate target (qualitative) | `low/medium (trend-following, ATR target > fixed stop)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fb2ae527-c7ef-5765-a09d-9eb8157e55a0`
**Source type:** `forum` (DayTradeForex.com commercial web resource, "9 Profitable Trading Systems", System #6)
**Pointer:** `strategy-seeds/sources/fb2ae527-c7ef-5765-a09d-9eb8157e55a0/`
**R1–R4 verdict (Q00):** all PASS (R1 CONDITIONAL — commercial resource, no named author) / see `artifacts/cards_approved/QM5_11438_td-ema9ema30-momentum-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | initial |
