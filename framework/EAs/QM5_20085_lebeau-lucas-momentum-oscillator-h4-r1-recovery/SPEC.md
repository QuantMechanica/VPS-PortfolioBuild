# QM5_20085_lebeau-lucas-momentum-oscillator-h4-r1-recovery — Strategy Spec

**EA ID:** QM5_20085
**Slug:** `lebeau-lucas-momentum-oscillator-h4-r1-recovery`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

LeBeau & Lucas (1992, ch. 5–7) smoothed momentum oscillator on the H4 timeframe with
a D1 macro-regime overlay. The core signal is the LeBeau-Lucas Momentum Oscillator
(LLMO), a rate-of-change smoothed by a short SMA:

- `ROC_12(t) = (Close[t] - Close[t-12]) / Close[t-12] * 100`
- `LLMO(t) = SMA(ROC_12, 8)`

The EA enters on LLMO zero-line crossovers, but only when the shorter-term price trend
and the daily macro-regime agree and momentum is still expanding. Using the QM shift
convention (shift 1 = last closed bar, "LLMO[0]"; shift 2 = prior bar, "LLMO[1]"):

- **Long** requires all of:
  1. LLMO crosses up through zero — `LLMO[1] < 0` and `LLMO[0] > 0`.
  2. H4 trend up — `close[1] > EMA(21,H4)[1]`.
  3. D1 regime up — `close(D1)[1] > EMA(50,D1)[1]`.
  4. Momentum expanding — `LLMO[0] > LLMO[1]`.
- **Short** is the exact mirror (cross down through zero, close below EMA(21,H4), D1
  close below EMA(50,D1), `LLMO[0] < LLMO[1]`).

A spread guard skips entries when `spread > 0.35*ATR(20,H4)` but never fail-closes on a
zero spread (which `.DWX` symbols legitimately quote in the tester). Entries are market
orders at ask (long) / bid (short) with an initial protective stop at `2.5*ATR(20,H4)`
against the trigger and no fixed take-profit.

Exits are LeBeau-Lucas trail-and-flip, all evaluated per tick while a position is open
(one position per magic, HR14):
- **Time-stop** — close fully once the position is `>= 20` H4 bars old.
- **Opposite zero-cross** — close a long fully if LLMO crosses down through zero
  (`LLMO[1] > 0` and `LLMO[0] < 0`); close a short on the up-cross mirror.
- **Chandelier-style ATR trail** — once price has moved `1.5*ATR(20,H4)` in favour, a
  `2.0*ATR(20,H4)` trailing stop is engaged. The trail helper only ratchets the stop
  favourably, i.e. it trails from the running extreme (the LeBeau-Lucas Chandelier
  semantics) with no extra state.

`Strategy_ExitSignal` returns false; all exits live in `Strategy_ManageOpenPosition`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `roc_period` | 12 | 8-24 | ROC lookback for the momentum oscillator |
| `llmo_smooth` | 8 | 4-16 | SMA smoothing window applied to the ROC |
| `ema_trend_period` | 21 | 10-50 | H4 price-trend filter EMA period |
| `d1_regime_ema_period` | 50 | 30-100 | D1 macro-regime EMA period |
| `atr_period` | 20 | 10-30 | ATR period for stops and trail |
| `sl_atr_mult` | 2.5 | 1.5-3.5 | Initial protective stop in ATR against trigger |
| `trail_atr_mult` | 2.0 | 1.5-3.0 | Chandelier trail distance in ATR |
| `trail_activate_atr_mult` | 1.5 | 0.5-2.5 | Favourable move in ATR before trail arms |
| `time_stop_bars` | 20 | 10-40 | Max hold in H4 bars |
| `spread_atr_mult_cap` | 0.35 | 0.1-0.6 | Max spread as a fraction of ATR |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; clean H4 momentum with orderly regime shifts.
- `GBPUSD.DWX` — liquid major with sustained directional legs the LLMO tracks well.
- `USDJPY.DWX` — trending major where the D1 EMA(50) regime gate adds directional edge.
- `AUDUSD.DWX` — commodity-linked major with persistent H4 momentum runs.
- `NZDUSD.DWX` — commodity-linked major, complementary regime to AUDUSD.
- `NDX.DWX` — Nasdaq-100 index; strong momentum persistence suits ROC zero-cross entries.
- `WS30.DWX` — Dow-30 index; trend-persistent, ATR-scaled stops adapt to index volatility.
- `XAUUSD.DWX` — gold; strong persistent trends make the momentum + regime filters effective.
- `XTIUSD.DWX` — WTI crude; volatile, trend-prone instrument that the ATR-scaled trail fits.

**Explicitly NOT for:**
- Ultra-low-volatility or pegged FX crosses — a smoothed ROC oscillator generates too few
  clean zero-crossings and the momentum-expansion gate rarely arms; kept to the trending
  FX majors, indices, metal and oil above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1 EMA(50) regime read on close (shift 1)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `15` |
| Typical hold time | `hours to a few days (time-stop 20 H4 bars ~ 3.3 days)` |
| Expected drawdown profile | `moderate; ~18% target, momentum clusters can correlate across symbols` |
| Regime preference | `trend (momentum continuation after zero-cross within macro-trend)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `book`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/` (ForexFactory
trading-systems LeBeau-Lucas cluster; grounded in Charles LeBeau & David W. Lucas,
*Technical Traders Guide to Computer Analysis of the Futures Markets*, McGraw-Hill /
Business One Irwin 1992, ISBN 978-1-55623-468-7, ch. 5 "Momentum Oscillators" +
ch. 6 "Rate-of-Change Studies" + ch. 7 Chandelier-Exit trail)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_20085_lebeau-lucas-momentum-oscillator-h4-r1-recovery.md`

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
| v1 | 2026-08-11 | Initial build from card | build(claude): QM5_20085 |
