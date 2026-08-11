# QM5_20177_carney-ab-cd-pattern-h4-r1-recovery — Strategy Spec

**EA ID:** QM5_20177
**Slug:** `carney-ab-cd-pattern-h4-r1-recovery`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Mechanical implementation of Scott Carney's foundational 4-pivot AB=CD harmonic
(Carney 2010 Vol I ch. 2). The EA finds three most-recent alternating swing
pivots A-B-C, projects the equal-magnitude completion point D, and enters a
counter-reversal trade when price touches and confirms at D.

Signal (long, H4 closed bars):
1. Find the three most-recent alternating fractal pivots A-B-C via 5-bar
   Williams fractals (`QM_FractalUpper`/`QM_FractalLower`), scanning shift
   `pivot_scan_start` (4) up to `pivot_scan_max` (80). For a long, A = a
   pivot-low, B = a pivot-high after A, C = a pivot-low after B with `C > A`.
2. BC/AB retracement gate: `bc_ratio = (B - C) / (B - A)` must lie in
   `[bc_ab_ratio_min, bc_ab_ratio_max]` = `[0.382, 0.886]` (Carney published
   range). Pivot spacing sanity: `3 <= ab_bars <= 60`.
3. Projected completion `D_proj = C + (B - A)` (equal-magnitude measured move).
4. Touch: the touch-bar candidate (shift 2) has BOTH its low and its close
   inside `[D_proj - 0.5*ATR(14), D_proj + 0.5*ATR(14)]`.
5. Confirmation: the confirmation-bar candidate (shift 1) closes above the
   touch bar's high (`c1.close > c2.high`).
6. Regime: D1 RSI(14) on the prior D1 close in `[25, 75]`.
7. Cooldown: no same-direction re-entry within `cooldown_bars` (18) H4 bars.
8. Spread gate: skip when `spread > spread_atr_mult_cap * ATR(14)` (never
   fail-closed on a zero/absent spread).
Entry is a market BUY at Ask; initial stop is the structural
`D_proj - sl_atr_mult * ATR(14)` (a fixed price, below the projection).
The short side mirrors exactly: A = pivot-high, B = pivot-low, C = pivot-high
with `C < A`, `bc_ratio = (C - B) / (A - B)`, `D_proj = C - (A - B)`, touch via
the touch bar's high+close inside the tolerance band, confirmation `c1.close <
c2.low`, market SELL at Bid, stop `D_proj + sl_atr_mult * ATR(14)`. Bullish is
attempted first; if it does not fire, the bearish side is attempted.

Exits (`Strategy_ManageOpenPosition`):
- T1: close 50% at `D + t1_fib*(C - D)` (0.382 retrace of the CD leg).
- After T1: ATR-trail the remaining 50% at `ATR(14) * 1.0`; full-close at
  `D + t2_fib*(C - D)` (0.618 retrace of the CD leg). The single T1/T2 formula
  works both directions because the sign of `(C - D)` flips between long/short.
- Time-stop: full close once `bars_since_entry >= time_stop_mult * 10` (= 15
  H4 bars at the default), regardless of P&L.

**Two documented simplifications vs. the source card (both intentional):**
(a) **Fractal-based pivot detection** replaces the card's ZigZag(12,5,3). Native
5-bar Williams fractals are the framework-sanctioned pivot primitive
(`QM_FractalUpper`/`QM_FractalLower`); they confirm a pivot 2 bars after it
prints. This changes which swings are labelled A-B-C but preserves the
alternating-pivot / measured-move mechanics.
(b) **Flat-bar time-stop** replaces the card's "1.5 × CD-leg-bars" time-stop.
The CD leg's bar-count is not resolvable at signal time (D has not formed yet),
so the EA uses a flat `time_stop_mult * 10` = 15-bar cap as the practical
stand-in. Likewise the card's AB-vs-CD **time-symmetry ±20% gate** is not
resolvable pre-D and is omitted; `time_symmetry_tolerance` is declared but inert
(reserved for the P3 sweep). See §5 and Open Items.

Open items:
- The pivot scan deliberately starts at shift `pivot_scan_start = 4`, skipping
  shifts 1-3 so the D-projection touch (shift 2) and confirmation (shift 1)
  checks never overlap the A-B-C pivots. This is the documented deviation from
  the card's implicit "scan to the live edge".
- `time_symmetry_tolerance` (0.20) is declared but unused in this R1 build; it
  is the reserved handle for the P3 CD-leg time-symmetry sweep once a
  post-D-relative implementation is added. Documented dead-param, not a defect.
- The projection geometry (D, C, entry-time) is file-scope only; a live restart
  mid-trade would lose it. Management guards on `g_position_D/C > 0` and leaves
  the hard structural SL to protect the position rather than acting on a zeroed
  level. Tester behaviour is unaffected (state is always set within a run).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `pivot_scan_start` | 4 | 3-10 | First fractal scan shift (keeps touch/confirm bars clear of pivots) |
| `pivot_scan_max` | 80 | 40-120 | Last fractal scan shift (bounded pivot search) |
| `bc_ab_ratio_min` | 0.382 | 0.3-0.6 | Minimum BC/AB retracement ratio |
| `bc_ab_ratio_max` | 0.886 | 0.7-0.95 | Maximum BC/AB retracement ratio |
| `time_symmetry_tolerance` | 0.20 | 0.1-0.3 | Reserved for P3 CD-leg time-symmetry sweep (inert pre-D) |
| `projection_touch_atr_mult` | 0.5 | 0.3-0.8 | ± ATR tolerance band around projected D |
| `atr_period` | 14 | 7-28 | ATR period (H4) for stop / spread / touch tolerance |
| `sl_atr_mult` | 1.0 | 0.5-1.5 | Structural stop distance from D in ATR units |
| `t1_fib` | 0.382 | 0.272-0.5 | T1 target as fib retrace of the CD leg (close 50%) |
| `t2_fib` | 0.618 | 0.5-0.786 | T2 target as fib retrace of the CD leg (close remainder) |
| `time_stop_mult` | 1.5 | 1.0-2.0 | Time-stop = mult*10 flat H4 bars |
| `d1_rsi_period` | 14 | 7-21 | D1 regime-filter RSI period |
| `d1_rsi_lo` | 25.0 | 20-30 | D1 RSI lower band (mixed-trend gate) |
| `d1_rsi_hi` | 75.0 | 70-80 | D1 RSI upper band (mixed-trend gate) |
| `spread_atr_mult_cap` | 0.3 | 0.2-0.5 | Skip entry if spread > cap*ATR |
| `cooldown_bars` | 18 | 6-30 | No same-direction re-entry within N H4 bars |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid H4 major; clean fractal swing structure.
- `GBPUSD.DWX` — liquid major with pronounced H4 swings for AB=CD projection.
- `USDJPY.DWX` — liquid major; symmetric measured-move behaviour ports cleanly.
- `XAUUSD.DWX` — high-volatility metal; harmonic measured moves are prominent.
- `NDX.DWX` — index CFD; broker-routable proxy for equity-index harmonics.
- `WS30.DWX` — index CFD; broker-routable, complements NDX for index coverage.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (not broker-routable); a live promotion would
  require parallel validation on NDX.DWX/WS30.DWX first (Board Advisor T6 gate).
- Sub-H4 timeframes — fractal swings are too noisy for the measured-move logic.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` RSI(14) regime filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~3` (very low frequency; a strict 4-pivot touch+confirm pattern) |
| Typical hold time | `hours to a few days` (bounded by the 15-bar H4 time-stop ≈ 2.5 days) |
| Expected drawdown profile | `moderate; ~20% expected DD per card, capped by structural ATR stop` |
| Regime preference | `mean-revert / counter-trend reversal in mixed-trend regimes` |
| Win rate target (qualitative) | `medium` |

> Frequency note: at ~3 trades/year/symbol a single-year smoke window can
> legitimately produce zero trades — that is `zero_trades`, not a defect.
> The two §1 simplifications (fractal pivots; flat-bar time-stop with the
> time-symmetry gate omitted pre-D) further narrow the setup vs. the raw card.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** book / forum
**Pointer:** Scott M. Carney, *Harmonic Trading, Volume One* (FT Press/Pearson
2010, ISBN 978-0-13-705150-3), ch. 2 pp. 25-52 "The AB=CD Pattern"; ForexFactory
harmonic-pattern thread family (threads 272317, 76772). See
`strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.md`

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
| v1 | 2026-08-11 | Initial build from card | fractal-pivot + flat-bar-time-stop simplifications; 6 symbols |
