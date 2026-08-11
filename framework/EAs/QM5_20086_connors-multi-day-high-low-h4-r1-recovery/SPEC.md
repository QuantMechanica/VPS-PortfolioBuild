# QM5_20086_connors-multi-day-high-low-h4-r1-recovery — Strategy Spec

**EA ID:** QM5_20086
**Slug:** `connors-multi-day-high-low-h4-r1-recovery`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Connors 2008 ch.10 "Multi-Day Highs and Lows" consecutive-extreme-streak mean
reversion on the H4 timeframe, gated by a D1 SMA(200) trend regime. Unlike the
single-touch Double-7s primitive, this strategy requires **two consecutive H4
bars** to each register a new 10-bar extreme before fading the move — a closer
proxy for oversold/overbought capitulation than a one-bar fresh extreme. All
entry logic runs on the last closed bar (shift 1 is the last CLOSED bar).

Entry (both must clear all gates; one position per magic, HR14):

- **Long** (fade consecutive lows):
  1. **D1 regime** — `close(D1)[1] > SMA(200,D1)[1]`.
  2. **Streak** — the bar at shift 1 is a new 10-bar low (its Low is the lowest
     over the trailing 10-bar window ending at shift 1) AND the bar at shift 2 is
     likewise a new 10-bar low over its own trailing 10-bar window (streak >= 2).
  3. **Mean-revert headroom** — `close(H4)[1] < SMA(5,H4)[1]` (still below the
     short-term mean).
  → market-buy at ask.
- **Short** (mirror) — `close(D1)[1] < SMA(200,D1)[1]`, two consecutive new 10-bar
  highs at shift 1 and shift 2, and `close(H4)[1] > SMA(5,H4)[1]` → market-sell at bid.

A spread guard skips entries when `spread > 0.4*ATR(14,H4)` (but never fail-closes
on a zero spread, which `.DWX` symbols legitimately quote in the tester). Entries
are market orders at ask (long) / bid (short) with a backstop stop at
`2.5*ATR(14,H4)` against the trigger and no fixed take-profit — Connors 2008 ch.10
explicitly notes streak-mean-reverters need wide ATR-stop room because the streak
can extend one more bar before reverting.

Exits are evaluated per tick while a position is open, all in
`Strategy_ManageOpenPosition`:
- **Mean-revert TP** — close a long fully when bid `>=` SMA(5,H4); close a short
  fully when ask `<=` SMA(5,H4).
- **Time-stop** — close fully once the position is `>= 8` H4 bars old (~32h).

`Strategy_ExitSignal` returns false — all exits live in the management hook.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `extreme_lookback` | 10 | 5-20 | N-bar window for the high/low extreme streak (card name `lookback_bars`; renamed to avoid a framework identifier collision — see note below) |
| `sma_fast` | 5 | 3-10 | Short-term mean line for headroom gate + mean-revert TP |
| `d1_trend_sma` | 200 | 100-300 | D1 trend-regime SMA period |
| `atr_period` | 14 | 10-30 | ATR period for the backstop stop and spread cap |
| `sl_atr_mult` | 2.5 | 1.5-3.5 | Backstop stop in ATR against the trigger |
| `time_stop_bars` | 8 | 4-16 | Max hold in H4 bars |
| `spread_atr_mult_cap` | 0.4 | 0.1-0.8 | Max spread as a fraction of ATR |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.
>
> Open item / build deviation: the card specifies the input name `lookback_bars`.
> That identifier is also used as a function-parameter name inside framework
> includes (`QM_StopRules.mqh`, `QM_Signals.mqh`), so a same-named EA input trips
> MQL warning 62 ("declaration hides global variable") and fails strict
> `build_check`. The input is therefore renamed `extreme_lookback` (default and
> semantics identical). No effect on the strategy; downstream `.set` files are
> generated from the compiled EA, so they carry the new name consistently.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; clean H4 mean reversion inside SMA(200) regime.
- `GBPUSD.DWX` — liquid major with regular consecutive-extreme pullback behaviour.
- `USDJPY.DWX` — trending major where the D1 SMA(200) regime gate adds value.
- `NDX.DWX` — Connors-canonical port of QQQ; index mean reversion after 2-bar extremes.
- `WS30.DWX` — Connors-canonical port of DIA; large-cap index mean reversion.
- `GDAXI.DWX` — DAX index; orderly H4 extremes with strong regime persistence.
- `XAUUSD.DWX` — gold; strong persistent trends make the SMA(200) filter effective and
  the ATR-scaled stop adapts to its higher volatility.

**Explicitly NOT for:**
- Ultra-low-timeframe or exotic FX crosses — the 10-bar consecutive-extreme streak
  needs liquid, continuously-quoted H4 bars; thin crosses produce false extremes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1 SMA(200) regime read + D1 close (shift 1)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | `hours to ~1.5 days (time-stop 8 H4 bars ~= 32h)` |
| Expected drawdown profile | `moderate; ~16% target, mean-reversion clusters correlate across symbols` |
| Regime preference | `mean-revert (consecutive-extreme-streak fade, trend-gated)` |
| Win rate target (qualitative) | `high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/` (ForexFactory
trading-systems Connors mean-reversion cluster; grounded in Larry Connors & Cesar
Alvarez, *Short Term Trading Strategies That Work*, TradingMarkets Publishing 2008,
ISBN 978-0-9819239-0-3, ch. 10 "Multi-Day Highs and Lows")
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_20086_connors-multi-day-high-low-h4-r1-recovery.md`

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
| v1 | 2026-08-11 | Initial build from card | build(claude): QM5_20086 |
