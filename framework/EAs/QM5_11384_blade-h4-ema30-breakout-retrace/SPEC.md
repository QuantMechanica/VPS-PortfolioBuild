# QM5_11384_blade-h4-ema30-breakout-retrace — Strategy Spec

**EA ID:** QM5_11384
**Slug:** `blade-h4-ema30-breakout-retrace`
**Source:** `f4fa8966-3aa0-5df0-9d8f-3872df92309a` (see `strategy-seeds/sources/f4fa8966-3aa0-5df0-9d8f-3872df92309a/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On H4, EMA(30) defines the trend STATE: a rising EMA(30) (now above its value
`slope_lookback` bars ago) with the last closed price above the EMA is a long
bias; the mirror (falling EMA, price below) is a short bias. The EA then finds a
swing S/R level — the highest High (long bias) or lowest Low (short bias) over
the last `sr_lookback` closed bars — and waits for a closed bar to break BEYOND
it in the trend direction. That breakout is latched (the broken level becomes
the new support/resistance). Entry is the single EVENT: a LATER closed bar
retraces back to within `retrace_tol_pips` of the broken level while its close
still holds on the breakout side. Stop is `sl_pips` behind the broken level
(hard-capped at `sl_cap_pips`); take-profit is `tp_rr`× the risk distance. The
latch is cancelled if price closes `cancel_pips` against the breakout or no
retrace arrives within `max_wait_bars`. Breakout and retrace touch occur on
different bars, so there is no two-events-same-bar zero-trade trap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 30 | 20-50 | Trend EMA period (Blade EMA30) |
| `strategy_slope_lookback` | 20 | 10-40 | Bars back to measure EMA slope/direction |
| `strategy_sr_lookback` | 20 | 10-30 | Bars defining the swing S/R level |
| `strategy_retrace_tol_pips` | 10 | 5-20 | Touch tolerance to the broken level on retrace |
| `strategy_sl_pips` | 25 | 20-30 | Stop distance behind the broken level |
| `strategy_sl_cap_pips` | 40 | 30-50 | P2 hard cap on stop distance |
| `strategy_tp_rr` | 2.0 | 2.0-3.0 | Take-profit as a multiple of risk distance |
| `strategy_max_wait_bars` | 12 | 6-24 | Bars to wait for the retrace after a breakout |
| `strategy_cancel_pips` | 30 | 20-40 | Adverse move past the level that cancels the latch |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip if spread exceeds this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary card target; deep liquidity, clean H4 S/R structure.
- `GBPUSD.DWX` — card target; trends well on H4 with clear breakout-retrace legs.
- `USDJPY.DWX` — card target; JPY pip scaling handled via `QM_StopRulesPipsToPriceDistance`.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the card specifies major FX pairs and the
  pip-based S/R / stop logic is calibrated for forex.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` (card mentions H1 entry timing; baseline keeps the entry on H4 closed bars) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | hours to a few days (H4 swing) |
| Expected drawdown profile | moderate; trend-aligned with capped pip stops |
| Regime preference | trend-following breakout (with retrace entry) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f4fa8966-3aa0-5df0-9d8f-3872df92309a`
**Source type:** book / PDF
**Pointer:** "The Blade Forex Strategies" — 4H Breakout System (anonymous, ForexSuccessSecrets.com); local PDF archive
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11384_blade-h4-ema30-breakout-retrace.md`

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
