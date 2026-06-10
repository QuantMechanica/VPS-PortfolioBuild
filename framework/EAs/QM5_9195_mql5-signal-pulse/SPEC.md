# QM5_9195_mql5-signal-pulse — Strategy Spec

**EA ID:** QM5_9195
**Slug:** `mql5-signal-pulse`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed M15 bar, the EA checks whether price has closed at or beyond the outer Bollinger Band (20-period, 2.0 deviation) while the Stochastic oscillator (5,3,3) is in the corresponding extreme zone and its %K line has just crossed %D. A higher-timeframe (H1) pulse filter confirms the same directional bias by requiring H1 Stochastic %K to be on the same side of the 50 midline. Long entries trigger when price closes below the lower band, Stochastic is oversold and %K crosses above %D, and H1 %K is below 50; short entries mirror this in reverse. The initial stop is placed beyond the signal candle's extreme by ATR(14) × 0.5, and the take-profit is set at a fixed 2R multiple of the stop distance. Positions are also closed early when an opposite confirmed pulse fires (price touches the opposite band with Stochastic in the extreme).

A volatility contraction filter skips entries when the current Bollinger Band width is below half of the 100-bar median width, avoiding trades during tight-ranging conditions.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10–50 | Bollinger Bands period |
| `strategy_bb_deviation` | 2.0 | 1.5–3.0 | Bollinger Bands standard deviation multiplier |
| `strategy_stoch_k` | 5 | 3–14 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 1–9 | Stochastic %D smoothing period |
| `strategy_stoch_slow` | 3 | 1–9 | Stochastic slowing period |
| `strategy_stoch_ob` | 80.0 | 70–90 | Overbought threshold for short entries and long-exit pulse |
| `strategy_stoch_os` | 20.0 | 10–30 | Oversold threshold for long entries and short-exit pulse |
| `strategy_atr_period` | 14 | 7–28 | ATR period for stop-loss calculation |
| `strategy_atr_sl_mult` | 0.5 | 0.25–2.0 | ATR multiplier applied beyond signal candle extreme |
| `strategy_tp_rr` | 2.0 | 1.0–4.0 | Take-profit as a multiple of the stop distance (2R default) |
| `strategy_bbw_lookback` | 100 | 50–200 | Lookback for BB-width median filter |
| `strategy_bbw_min_ratio` | 0.5 | 0.2–0.9 | Minimum ratio of current BB width to lookback median |
| `strategy_htf` | PERIOD_H1 | M30–H4 | Higher timeframe for pulse confirmation |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major pair with clear mean-reversion behaviour on M15; tight spreads minimise cost drag
- `GBPUSD.DWX` — liquid major; higher volatility suits ATR-based stops and wider BB excursions
- `XAUUSD.DWX` — gold exhibits strong mean-reversion episodes around intraday extremes; fits the BB-band-touch entry pattern

**Explicitly NOT for:**
- Indices (NDX, WS30, SP500) — not in the card's target basket; add if P3 sweep warrants it

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1` (Stochastic pulse confirmation via `strategy_htf`) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~80 |
| Typical hold time | Hours (intraday, up to 1–2 sessions) |
| Expected drawdown profile | Mean-reversion; moderate; losses come in clusters during trending conditions |
| Regime preference | Mean-reversion / sideways |
| Win rate target (qualitative) | Medium (target ~50–55% with 2R TP) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 3): Building a Multi-Timeframe Signal Pulse EA", MQL5 Articles, 2025-01-21
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9195_mql5-signal-pulse.md`

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
| v1 | 2026-06-10 | Initial build from card | e3fa3b21-9f75-43dd-b32a-073b05c721ca |
