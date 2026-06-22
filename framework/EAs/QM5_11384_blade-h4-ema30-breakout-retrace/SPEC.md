# QM5_11384_blade-h4-ema30-breakout-retrace - Strategy Spec

**EA ID:** QM5_11384
**Slug:** `blade-h4-ema30-breakout-retrace`
**Source:** `f4fa8966-3aa0-5df0-9d8f-3872df92309a` (see `strategy-seeds/sources/f4fa8966-3aa0-5df0-9d8f-3872df92309a/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades the Blade H4 breakout-retrace pattern. A long setup requires EMA(30) on H4 to slope upward over 20 bars, the last closed H4 close to be above EMA(30), and that same closed candle to close above the highest high from shifts 10 through 30 with a range at least 1.5 times ATR(14). It then places a BUY LIMIT at the broken resistance level; shorts mirror the rule with a falling EMA(30), a close below the lowest low from shifts 10 through 30, and a SELL LIMIT at the broken support level. The stop is 25 pips behind the broken level, capped at 40 pips, and the target is the nearest EMA(150/200/365) in the trade direction when available, otherwise 2.5R. Pending orders expire after six H4 bars or are cancelled if price breaks 30 pips back through the level.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 30 | 30-50 | Trend EMA period; default is the card's EMA(30). |
| `strategy_slope_lookback` | 20 | 10-40 | Bars back used to measure EMA slope. |
| `strategy_sr_start_shift` | 10 | 5-20 | First historical closed H4 shift in the S/R window. |
| `strategy_sr_end_shift` | 30 | 20-40 | Last historical closed H4 shift in the S/R window. |
| `strategy_atr_period` | 14 | 10-30 | ATR period for the breakout candle range filter. |
| `strategy_breakout_atr_mult` | 1.5 | 1.0-2.5 | Minimum breakout candle range as ATR multiple. |
| `strategy_retrace_tol_pips` | 5 | 3-15 | Documented retrace touch tolerance around the broken level. |
| `strategy_sl_pips` | 25 | 20-30 | Stop distance behind the broken S/R level. |
| `strategy_sl_cap_pips` | 40 | 20-40 | P2 maximum stop cap. |
| `strategy_tp_rr` | 2.5 | 2.0-3.0 | Fallback target when no major EMA target is ahead. |
| `strategy_pending_expiry_bars` | 6 | 1-12 | H4 bars before an unfilled pending order expires. |
| `strategy_cancel_pips` | 30 | 20-40 | Adverse move through the level that cancels a pending order. |
| `strategy_spread_cap_pips` | 20 | 5-30 | Maximum allowed modeled spread; zero spread remains tradable. |
| `strategy_be_buffer_pips` | 1 | 0-5 | Buffer added when moving stop to breakeven. |
| `strategy_trail_trigger_pips` | 35 | 20-80 | Profit in pips before step trailing starts. |
| `strategy_trail_step_pips` | 15 | 5-40 | Distance used by fixed pip step trailing. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target and primary major FX pair.
- `GBPUSD.DWX` - card target with liquid H4 trend and retrace structure.
- `USDJPY.DWX` - card target; JPY pip scaling is handled through framework pip conversion.

**Explicitly NOT for:**
- Index and commodity `.DWX` symbols - the card specifies major FX pairs and the pip stop/retrace logic is calibrated for forex.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none in code; card's H1 retrace timing is represented by the H4-generated pending limit triggering intrabar on Model 4 ticks |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | hours to a few days |
| Expected drawdown profile | moderate, trend-following with fixed pip stops |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f4fa8966-3aa0-5df0-9d8f-3872df92309a`
**Source type:** local PDF / strategy book
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\219755537-Blade-Forex-Strategies.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11384_blade-h4-ema30-breakout-retrace.md`

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
| v1 | 2026-06-23 | Initial build from card | 6dec6292-03a2-46e6-a976-3f67c37c3ffe |
