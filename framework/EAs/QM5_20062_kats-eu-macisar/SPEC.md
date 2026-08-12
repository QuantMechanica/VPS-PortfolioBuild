# QM5_20062_kats-eu-macisar - Strategy Spec

**EA ID:** QM5_20062
**Slug:** `kats-eu-macisar`
**Source:** KATSANOS-INTERMARKET-2008 (KATSANOS-INTERMARKET-2008_S02)
**Author of this spec:** Claude
**Last revised:** 2026-07-23

---

## 1. Strategy Logic

This D1 EUR/USD strategy trades a volatility-filtered moving-average turn
confirmed by Katsanos' Congestion Index and Parabolic SAR. A 10-day SMA (MA)
must move beyond its own recent log-change volatility (FILT, a 20-bar StdDev
of Ln(MA/MA[-1])) in the trade direction, price must be on the correct side of
a Parabolic SAR(0.04, 0.10), and a 7-bar EMA of the Congestion Index (a
ROC(39)-over-range(40) oscillator) must exceed an absolute-value gate of 40
and be turning in the trade direction from a 3-bar extreme. The frozen
Appendix A.8 inequality `ABS(CI) > 40` is used (not the Chapter 17 `<40`
form). Signals are computed on the completed D1 bar and submitted at the
first eligible tick of the next D1 bar (causal port; the source's same-day
close fill is not reproduced). Exit is the source's Parabolic SAR close
signal (close crosses SAR), also submitted causally on the next bar's first
tick. A fixed non-alpha catastrophe stop of 3.0x ATR(20) from entry (computed
once, never widened) is the only broker-side protective stop; the source
defines no resting stop. No scale-in, partial close, break-even, trailing, or
take-profit. Framework Friday-close remains enabled.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ma_period` | 10 | fixed | SMA period for MA. |
| `strategy_pc_stddev_period` | 20 | fixed | Lookback for FILT = StdDev(Ln(MA/MA[-1])). |
| `strategy_filt_mult` | 0.7 | fixed | Multiplier on FILT added to the LLV/HHV(MA,3) turn threshold. |
| `strategy_ci_roc_period` | 39 | fixed | ROC(Close,%) period inside CI_raw. |
| `strategy_ci_range_period` | 40 | fixed | HHV(High)/LLV(Low) window inside CI_raw. |
| `strategy_ci_ema_period` | 7 | fixed | EMA period smoothing CI_raw into CI. |
| `strategy_ci_abs_gate` | 40.0 | fixed | Appendix A.8 frozen variant: ABS(CI) > gate. |
| `strategy_ci_turn_threshold` | 3.0 | fixed | CI turn threshold vs LLV/HHV(CI,3). |
| `strategy_turn_lookback` | 3 | fixed | Lookback window for LLV/HHV(MA,.) and LLV/HHV(CI,.). |
| `strategy_sar_step` | 0.04 | fixed | Parabolic SAR acceleration step. |
| `strategy_sar_max` | 0.10 | fixed | Parabolic SAR acceleration maximum. |
| `strategy_catastrophe_atr_period` | 20 | fixed | ATR period for the non-alpha catastrophe stop. |
| `strategy_catastrophe_atr_mult` | 3.0 | fixed | ATR multiplier for the catastrophe stop distance. |

All parameters are frozen per the Card's "Parameters To Test" table (first
falsification build has no selectable alpha sweep); Q03 sweep does not vary
them.

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the Card's sole target symbol; the source study and R3 PASS
  reasoning are specific to EUR/USD D1 with no portable-basket narrative.

**Explicitly NOT for:**
- Any other symbol - the Card is single-instrument scoped (source market is
  EUR/USD spot; no generic cross-symbol port is authorized by this Card).

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` latched once per tick (`qm_new_bar`) and reused for both the cached-state advance and the entry gate, per the single-consume rule |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 12 (source: 62 trades / 5yr = 12.4/yr; causal port and framework exits untested) |
| Typical hold time | days (D1 signal/exit cadence) |
| Expected drawdown profile | `expected_dd_pct: 20.0` conservative G0 ordering prior; catastrophe stop bounds tail risk |
| Regime preference | trend/breakout confirmed by volatility-filtered MA turn + Congestion Index + SAR |
| Win rate target (qualitative) | medium (source reports PF 1.70 over the conventional test; not an `EURUSD.DWX` reproduction claim) |

## 6. Source Citation

This card was mechanised from:

**Source ID:** KATSANOS-INTERMARKET-2008
**Source type:** book
**Pointer:** Katsanos, Markos. *Intermarket Trading Strategies*. Wiley, 2008. Chapter 17, book pp. 279-285 / PDFPAGE 297-303; Table 17.6, book pp. 284-285 / PDFPAGE 302-303; Appendix A.8, book p. 355 / PDFPAGE 373. `docs/research/KATSANOS_CH13_CH17_EXTRACTION_2026-06.md`.
**R1-R4 verdict (Q00):** all PASS; see `artifacts/cards_approved/QM5_20062_kats-eu-macisar.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-23 | Initial build from card | ee2fe37e-5509-4371-8979-c58db2966313 |
