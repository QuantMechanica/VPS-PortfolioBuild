# QM5_11335_tc20-h1-6-ema5-15-60-pullback — Strategy Spec

**EA ID:** QM5_11335
**Slug:** `tc20-h1-6-ema5-15-60-pullback`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Strategy #6)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A triple-EMA (5/15/60) trend-pullback EA on H1. The three EMAs in cascade
define the trend STATE; the pullback-and-resume to the slow EMA is the single
trade EVENT.

Long: the EMA stack is fully aligned up — EMA5 > EMA15 > EMA60 — and both the
EMA60 and EMA15 are rising (value on the last closed bar above the prior bar's
value). The entry fires on the closed bar whose low pulled back and TOUCHED
EMA60 (Low <= EMA60) while the close held back above it (Close > EMA60), and
where the prior bar had not yet touched EMA60 (prior Low > prior EMA60) — so the
touch is a genuine one-shot pullback event, not a hover at the line. Short is the
exact mirror (stack down, EMAs falling, the bar's high tags EMA60 from below and
the close stays under it). Exit is purely the fixed stop or target; there is no
discretionary or trailing exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 5 | 3-10 | Fast EMA (top of the cascade) |
| `strategy_ema_mid_period` | 15 | 10-25 | Middle EMA |
| `strategy_ema_slow_period` | 60 | 40-120 | Slow EMA — the pullback target |
| `strategy_sl_pips` | 30 | 10-80 | Fixed stop-loss distance, pips |
| `strategy_tp_pips` | 50 | 20-150 | Fixed take-profit distance, pips |
| `strategy_spread_cap_pips` | 20 | 5-50 | Skip only a genuinely wide spread, pips (fail-open on zero) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card primary; deep liquidity, clean H1 trend/pullback behaviour.
- `GBPUSD.DWX` — card primary; trends well on H1 with frequent EMA pullbacks.
- `USDJPY.DWX` — card P2 expansion; major USD pair, trend-pullback friendly.

**Explicitly NOT for:**
- Index/commodity `.DWX` symbols — the card scopes this to H1 FX majors; pip
  scaling and the fixed 30/50-pip stop/target are calibrated for FX.

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
| Trades / year / symbol | `~80` |
| Typical hold time | `hours (intraday to ~1-2 days on H1)` |
| Expected drawdown profile | `moderate; fixed 30-pip stop bounds per-trade loss` |
| Regime preference | `trend (pullback continuation)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Strategy #6 (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11335_tc20-h1-6-ema5-15-60-pullback.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
