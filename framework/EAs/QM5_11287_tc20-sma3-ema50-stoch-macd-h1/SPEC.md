# QM5_11287_tc20-sma3-ema50-stoch-macd-h1 — Strategy Spec

**EA ID:** QM5_11287
**Slug:** `tc20-sma3-ema50-stoch-macd-h1`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-12

---

## 1. Strategy Logic

SMA(3) acts as a fast trigger MA and EMA(50) as the trend-direction MA on H1.
The card's literal entry rule requires SMA(3) to cross EMA(50) AND either a
Stochastic(50,60,30) %K cross of its own EMA(8), or a MACD(65,75,35) Main
cross of its own EMA(8). Per DWX backtest invariant #4 (two simultaneous
cross events almost never coincide and would starve entries to near zero),
the SMA/EMA relationship is implemented as the trend STATE filter (sma3
above/below ema50) and the Stochastic %K crossing its own EMA(8) is the
single TRIGGER event per bar. MACD(65,75,35) Main vs. its own EMA(8) is an
optional sign-relative STATE confirmation (toggle `strategy_require_macd`,
default true). A long fires when trend STATE is bullish (sma3>ema50), the
Stoch trigger crosses up, and MACD state agrees (macd_main>macd_ema8); short
is the mirror. Exit is a fixed 50-pip stop and a 2R (100-pip) take-profit —
no discretionary exit or trade management beyond broker-side SL/TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 3 | 1-50 | Fast trigger SMA period (trend state) |
| `strategy_ema_period` | 50 | 10-200 | Trend-direction EMA period |
| `strategy_stoch_k` | 50 | 1-100 | Stochastic %K period |
| `strategy_stoch_d` | 60 | 1-100 | Stochastic %D period |
| `strategy_stoch_slow` | 30 | 1-100 | Stochastic slowing |
| `strategy_stoch_ema` | 8 | 2-50 | EMA period smoothing the Stoch %K (trigger line) |
| `strategy_macd_fast` | 65 | 1-200 | MACD fast EMA period |
| `strategy_macd_slow` | 75 | 1-200 | MACD slow EMA period |
| `strategy_macd_signal` | 35 | 1-100 | MACD native signal period (indicator handle only) |
| `strategy_macd_ema` | 8 | 2-50 | EMA period smoothing the MACD Main (confirm line) |
| `strategy_require_macd` | true | true/false | Require MACD-vs-EMA8 sign agreement alongside the Stoch trigger |
| `strategy_sl_pips` | 50 | 10-200 | Fixed stop-loss distance in pips |
| `strategy_rr` | 2.0 | 0.5-5.0 | Take-profit as a multiple of the stop distance (card: 1:2 RR) |
| `strategy_spread_cap_pips` | 20 | 1-100 | Spread guard: block entries only above this pip cap (card: 20 pips) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card primary instrument, FX major, native Stoch/MACD cadence tested against
- `GBPUSD.DWX` — card R3 portable basket member, same asset-class liquidity profile
- `USDJPY.DWX` — card R3 portable basket member; pip-scaling handled via `QM_StopRulesPipsToPriceDistance`

**Explicitly NOT for:**
- Indices/metals/crypto — card mechanics were validated only against the FX-major basket named in R3

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
| Trades / year / symbol | ~100 |
| Typical hold time | hours (fixed 50-pip SL / 100-pip TP, no time stop) |
| Expected drawdown profile | moderate — fixed 1:2 RR with no trailing management |
| Regime preference | trend-following with oscillator-confirmed entries |
| Win rate target (qualitative) | medium (1:2 RR implies <50% win rate can still be profitable) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** local PDF archive — "20 Forex Trading Strategies (1 Hour Time Frame)" by Thomas Carter, 2014, Strategy #1
**R1–R4 verdict (Q00):** all PASS — R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11287_tc20-sma3-ema50-stoch-macd-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | prior build session |
| v2 | 2026-08-12 | Rebuilt in place: fixed OnTick canonical ordering (news gate below management/exit, added QM_FrameworkTrackOpenPositionMae), replaced % -of-stop spread guard with literal 20-pip card cap, added SPEC.md + P2 setfiles | abfb1474-ea47-43f8-a265-46b5ec7ae003 |
