# QM5_21514_qs-klinger-vol-osc-xag — Strategy Spec

**EA ID:** QM5_21514
**Slug:** `qs-klinger-vol-osc-xag`
**Source:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Author of this spec:** Codex
**Last revised:** 2026-08-16

---

## 1. Strategy Logic

On each completed XAGUSD D1 bar, the EA derives Klinger Volume Force from the bar's range, a day-over-day price-direction flag, its cumulative same-direction range, and MT5 tick volume. It subtracts the 55-period Volume Force EMA from the 34-period EMA, then buys when that KVO crosses above its 13-period signal EMA and sells when it crosses below. An opposite cross closes and may reverse the position on the same bar; a 2.5× ATR(14) hard stop, a 60-completed-bar time stop, and framework Friday close provide exits.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_kvo_fast_period` | 34 | 21, 34, 45 | Fast EMA period applied to Volume Force. |
| `strategy_kvo_slow_period` | 55 | 45, 55, 75 | Slow EMA period applied to Volume Force. |
| `strategy_kvo_signal_period` | 13 | 9, 13, 21 | Signal EMA period applied to KVO. |
| `strategy_atr_period` | 14 | 10, 14, 20 | D1 ATR period for the hard stop. |
| `strategy_atr_sl_mult` | 2.5 | 2.0, 2.5, 3.5 | ATR multiple between entry and hard stop. |
| `strategy_max_hold_bars` | 60 | 30, 60, 100 | Maximum completed D1 bars held before a time exit. |
| `strategy_warmup_buffer` | 20 | 10, 20, 40 | Extra derived-series samples used to stabilize the EMA cascade. |
| `strategy_max_spread_points` | 400 | 250, 400, 600 | Entry-only spread ceiling in native XAGUSD points; zero modeled spread is allowed. |

## 3. Symbol Universe

**Designed for:**
- `XAGUSD.DWX` — the card's sole target and the matrix-listed silver CFD whose native D1 OHLC and MT5 tick volume supply every signal input.

**Explicitly NOT for:**
- All other symbols — the approved card sets `single_symbol_only: true`; no cross-symbol portability is authorized in v1.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry; `QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol)` for completed-bar exits without consuming the entry gate |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 15 (estimated range 12–20) |
| Typical hold time | several days to several weeks, capped at 60 completed D1 bars and shortened by framework Friday close |
| Expected drawdown profile | medium risk; card estimate 19.0% drawdown, with losses clustering during choppy KVO recrosses |
| Regime preference | volume-confirmed directional trend / momentum continuation |
| Win rate target (qualitative) | not specified by the approved card |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Source type:** public article
**Pointer:** QuantifiedStrategies.com, “Klinger Oscillator Strategy — Understanding and Evaluating Performance,” https://www.quantifiedstrategies.com/klinger-oscillator-strategy/
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_21514_qs-klinger-vol-osc-xag.md`.

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
| v1 | 2026-08-16 | Initial build from card | 82cb34ad-04dd-4c87-8f1b-cc666c0dc17f |
