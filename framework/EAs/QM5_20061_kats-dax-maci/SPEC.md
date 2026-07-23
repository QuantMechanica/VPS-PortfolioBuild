# QM5_20061_kats-dax-maci — Strategy Spec

**EA ID:** QM5_20061
**Slug:** `kats-dax-maci`
**Source:** `KATSANOS-INTERMARKET-2008` (see `strategy-seeds/sources/KATSANOS-INTERMARKET-2008/`)
**Author of this spec:** Claude
**Last revised:** 2026-07-23

---

## 1. Strategy Logic

A Congestion Index (CI) — a scaled 39-bar rate-of-change divided by a 40-bar
high/low range proxy — classifies each completed D1 bar as directional
(|CI|>30) or congested (|CI|<25). In the directional regime the EA takes
asymmetric fast/slow moving-average trend trades (different MA periods for
long vs short); in the congested regime it takes fast/slow stochastic
reversal trades. Longs and shorts are each OR-of-two-branch conditions
(trend branch OR congestion branch). Exits are signal-based (CI mean
reversion for longs, CI reversal or a MACD/EMA cross-and-confirm for
shorts) or a fixed 60-completed-bar time stop, whichever fires first. The
source has no protective stop; QuantMechanica adds a fixed ATR(20)x3.0
catastrophe stop as a non-alpha safety overlay. If both long and short
conditions are ever true on the same signal bar, the EA remains flat and
logs an ambiguous-signal reject (the source defines no tie-break).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `ci_roc_period` | 39 | fixed | ROC(Close,39,%) — CI numerator lookback |
| `ci_range_period` | 40 | fixed | HHV(High,40)/LLV(Low,40) — CI denominator lookback |
| `stoch_fast_k_period` | 5 | fixed | S5 = Stoch(5,3) main (%K) |
| `stoch_fast_d_period` | 3 | fixed | SMA(S5,3), read as the %D buffer with slowing=1 |
| `stoch_slow_k_period` | 40 | fixed | S40 = Stoch(40,3) main (%K) |
| `stoch_slow_d_period` | 3 | fixed | S40 %D period (unused directly; HHV/LLV(S40) reads %K) |
| `trend_long_fast_ma` | 15 | fixed | TREND_LONG: SMA(Close,15) > SMA(Close,20) |
| `trend_long_slow_ma` | 20 | fixed | see above |
| `trend_short_fast_ma` | 10 | fixed | TREND_SHORT: SMA(Close,10) < SMA(Close,20) |
| `trend_short_slow_ma` | 20 | fixed | see above |
| `trend_short_micro_ma` | 2 | fixed | TREND_SHORT: SMA(Close,2) < SMA(Close,150) |
| `trend_short_macro_ma` | 150 | fixed | see above |
| `macd_fast_period` | 12 | fixed | M = EMA(Close,12) - EMA(Close,26) |
| `macd_slow_period` | 26 | fixed | see above |
| `macd_signal_period` | 9 | fixed | MT5 iMACD constructor arg only; buffer 1 unused |
| `macd_signal_ema_period` | 7 | fixed | EMA(MACD,7) for short-cover CrossUp(MACD,EMA(MACD,7)) |
| `exit_close_ema_period` | 7 | fixed | EMA(Close,7) for short-cover Close>EMA(Close,7) confirm |
| `time_exit_bars` | 60 | fixed | close after 60 completed D1 bars in the position |
| `catastrophe_atr_period` | 20 | fixed | QM non-alpha stop: ATR period |
| `catastrophe_atr_mult` | 3.0 | fixed | QM non-alpha stop: ATR multiple |
| `min_warmup_bars` | 200 | fixed | fail-closed floor; source requires >=151 + indicator warm-up |

All values are source-locked per the G0 Card's "Parameters To Test" table
(Appendix A.4 baseline). No alpha sweep is authorized by this build.

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — the card's sole target symbol; the source's continuous FDAX
  futures series ported to the DAX 40 CFD. No portable basket is proposed
  by the card (single-symbol Katsanos DAX port, not a generic-index rule).

**Explicitly NOT for:**
- Any other index/FX symbol — the card is a single-instrument port of a
  DAX-specific historical study (Table 13.2 continuous FDAX comparison);
  extending it to other symbols would require a new Card and requalification.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` latched once in `OnTick`, reused via `is_new_bar` to drive `AdvanceState_OnNewBar()` and the entry gate (CI/stochastic/MACD-EMA state is cached once per closed bar; see file header) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~13 (source: 51 trades / ~3.8yr continuous FDAX, Table 13.2) |
| Typical hold time | up to 60 completed D1 bars (time stop), earlier on signal exit |
| Expected drawdown profile | `expected_dd_pct: 20.0` — conservative G0 ordering prior; no source stop, so tail risk is the ATR20x3 overlay only |
| Regime preference | regime-switching: trend-following in directional CI states, mean-reversion in congested CI states |
| Win rate target (qualitative) | medium (`expected_pf: 1.20` G0 prior) |

---

## 6. Source Citation

**Source ID:** `KATSANOS-INTERMARKET-2008`
**Source type:** book
**Pointer:** `strategy-seeds/sources/KATSANOS-INTERMARKET-2008/source.md`; Katsanos, Markos. *Intermarket Trading Strategies*. Wiley, 2008. Ch.13 pp.209-213 / PDFPAGE 227-231; Table 13.2 p.210 / PDFPAGE 228; Appendix A.4 p.329 / PDFPAGE 347.
**R1–R4 verdict (Q00):** R1 TIER_A, R2 PASS, R3 PASS, R4 PASS — all PASS per `artifacts/cards_approved/QM5_20061_kats-dax-maci.md`. R1 lineage recorded and R2-R4 PASS per that Card.

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
| v1 | 2026-07-23 | Initial build from card | 602425d9-2b73-4796-909b-b7c6bf0b36b1 |
