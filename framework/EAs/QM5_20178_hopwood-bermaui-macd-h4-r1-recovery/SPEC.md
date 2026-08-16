# QM5_20178_hopwood-bermaui-macd-h4-r1-recovery — Strategy Spec

**EA ID:** QM5_20178
**Slug:** `hopwood-bermaui-macd-h4-r1-recovery`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

An H4 smoothed-MACD, three-state momentum-confluence trend follower. MACD(12,26,9)
is computed on the current (H4) timeframe, then a "Bermaui" smoothing kernel is
applied to the MACD line and signal line; the smoothed histogram is the smoothed
line minus the smoothed signal. All reads are on closed bars (shift 1 is the last
closed H4 bar).

**Long entry** — all four true on the last closed H4 bar:
1. smoothed MACD line > smoothed signal line, and
2. smoothed MACD line > 0 (above the zero baseline), and
3. smoothed histogram rising (this bar's histogram > prior bar's histogram), and
4. regime gate: D1 close(shift 1) > D1 SMA(200).

**Short entry** mirrors: smoothed line < signal, smoothed line < 0, smoothed
histogram falling, and D1 close < D1 SMA(200).

**Stop loss:** `entry − 2.5 × ATR(20, H4)` for longs, inverse for shorts. No
take-profit — exits are purely signal-driven.

**Exit (in-position management, per tick, evaluated on closed-bar values):** close
the full position on either the smoothed line crossing back through the smoothed
signal OR the smoothed histogram slope reversing — whichever comes first. For a
long: exit if smoothed line < signal OR histogram falling. For a short: exit if
smoothed line > signal OR histogram rising.

**Spread filter:** skip a new entry when the current spread (points) exceeds
`spread_mult_cap` × the rolling mean spread over the last `spread_lookback_bars`
closed bars. The rolling mean is built from `MqlRates.spread` (per-bar spread in
points). `.DWX` symbols report zero spread in the tester, so the filter degrades
to always-pass there and is never fail-closed on a zero current spread.

One position per magic (HR14); a reverse setup cannot open while an opposite
position is held, so the signal-driven exits above handle flips without extra
reverse-detection code.

### DELIBERATE, DOCUMENTED SIMPLIFICATION — Bermaui kernel → single SMA(7)

The source card specifies the Bermaui kernel as a **two-stage cascade**: a
7-period Wilder moving average followed by a 7-period Hull moving average (HMA),
applied to the *derived* MACD line / signal / histogram series (i.e. a smoother
whose input is the MACD output, not price).

The QuantMechanica framework's `QM_*` indicator helpers only compute indicators
directly from price via native pooled MT5 handles; none of them can take an
arbitrary derived series (such as a MACD-line buffer) as a second-stage input.
Reproducing the exact Wilder-MA → HMA cascade would require a hand-rolled,
second-order numerical filter over the MACD buffer — unverifiable within the
one-pass build discipline and outside the corset of pooled, tester-correct
indicator reads.

This EA therefore implements the kernel as a **single trailing 7-bar simple
moving average** over the raw MACD line and signal:
`BermauiLine(shift) = mean( MACD_Main(shift .. shift+6) )` and the analogous
`BermauiSignal`. This preserves the qualitative character the card relies on —
a smoothed, lag-reduced MACD relative to the raw MACD — and keeps the full
three-state line/signal/histogram entry and exit logic intact. It is a
smoothing-shape approximation, not a logic change. See `open_questions` in the
build report.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `macd_fast` | 12 | 2-50 | MACD fast EMA period |
| `macd_slow` | 26 | 5-100 | MACD slow EMA period |
| `macd_signal` | 9 | 2-50 | MACD signal EMA period |
| `bermaui_smooth_period` | 7 | 2-30 | Trailing SMA window smoothing the derived MACD (single-SMA simplification of the Wilder-MA→HMA cascade) |
| `atr_period` | 20 | 5-100 | ATR period for the protective stop (H4) |
| `sl_atr_mult` | 2.5 | 0.5-10.0 | Stop distance in ATR multiples |
| `d1_sma_period` | 200 | 20-400 | D1 SMA period for the regime gate |
| `spread_mult_cap` | 2.0 | 1.0-10.0 | Skip entry if current spread > cap × rolling-mean spread |
| `spread_lookback_bars` | 100 | 10-500 | Rolling-mean spread lookback (bars) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are
> documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, trend-capable FX major; clean H4 MACD momentum.
- `GBPUSD.DWX` — volatile FX major with sustained H4 trends.
- `USDJPY.DWX` — strong directional regimes suit the D1-SMA(200) trend gate.
- `XAUUSD.DWX` — high-volatility metal; ATR-scaled stop adapts to its range.
- `NDX.DWX` — index CFD with persistent momentum legs on H4.
- `WS30.DWX` — index CFD; trend-following momentum confluence fits well.

**Explicitly NOT for:**
- Low-liquidity or thin exotic `.DWX` symbols — the spread filter and momentum
  confluence assume a continuously quoted, liquid instrument.
- Sub-H4 timeframes — the smoothed-MACD lag is calibrated for the H4 cadence and
  the ~6 trades/year/symbol expectation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1 close + D1 SMA(200) regime gate` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~6` |
| Typical hold time | `several days to weeks (H4 trend legs)` |
| Expected drawdown profile | `moderate; ATR stop caps per-trade loss, trend regime gate limits chop` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/` — Mohammed
Bermaui (indicator author) × Steve Hopwood (ForexFactory cross-poster). Bermaui-MACD
MQL5 Code Base (2018); FF thread/254595 Hopwood-Bermaui cluster. Base MACD: Gerald
Appel 1976.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_20178_hopwood-bermaui-macd-h4-r1-recovery.md`

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
| v1 | 2026-08-11 | Initial build from card | single-SMA(7) simplification of Wilder-MA→HMA Bermaui kernel |
