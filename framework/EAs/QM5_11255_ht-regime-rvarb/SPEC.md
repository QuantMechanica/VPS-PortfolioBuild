# QM5_11255_ht-regime-rvarb — Strategy Spec

**EA ID:** QM5_11255
**Slug:** `ht-regime-rvarb`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (Hudson & Thames, "Statistical Arbitrage Strategy Based on the Markov Regime-Switching Model")
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Regime-switching relative-value pairs (statistical-arbitrage) trade on two
related `.DWX` symbols, evaluated on completed D1 bars. On each new D1 bar the EA
fits a rolling-OLS log-ratio hedge ratio of the host on the partner over a
TRAINING window (`training_window_bars` bars) and forms the spread
`X_t = ln(host/host_0) - beta*ln(partner/partner_0)`.

The spread sample over the training window is classified into TWO regimes
**deterministically** (NO machine learning / NO HMM-EM / NO likelihood fitting):
the sample is split at its MEDIAN — state 1 is the high cluster (spread >=
median), state 2 the low cluster (spread < median). Per-cluster mean/std give
`mu_1, sigma_1, mu_2, sigma_2`. The current regime of the latest closed bar is
the fixed rule "state 1 if `X_t >= grand_mean` else state 2"
(`grand_mean = 0.5*(mu_1+mu_2)`). The regime posterior `P(state k | X_t)` is the
closed-form equal-prior Gaussian Bayes ratio — a fixed algebraic evaluation, not
a fitted/learned probability. (A two-state Markov/Hamilton EM fit is an iterative
likelihood optimisation banned under HR14; this deterministic median-split +
closed-form posterior realises the same two-state structure with no iteration and
no PnL-adaptive parameters.)

Entry trades the spread market-neutrally with the card's regime-specific
sigma-band + probability rules (`delta`, `rho`):
- LONG spread (BUY host / SELL partner): state 1 `X_t <= mu_1 - delta*sigma_1`
  AND `P(1|X_t) >= rho`; state 2 `X_t <= mu_2 - delta*sigma_2`.
- SHORT spread (SELL host / BUY partner): state 1 `X_t >= mu_1 + delta*sigma_1`;
  state 2 `X_t >= mu_2 + delta*sigma_2` AND `P(2|X_t) >= rho`.

Exit uses the card's symmetric close rules (close long on the high-band trigger,
close short on the low-band trigger, each with the regime-2 probability gate) and
a time stop after `max_hold_bars` D1 bars. The host leg is sent through the
framework magic (slot = `qm_magic_slot_offset`); the partner leg is sent on a
foreign `.DWX` symbol through the framework basket order path at its own
registered slot. One position per (magic, symbol); both legs open and close
together (partner opened first so a failed partner aborts the pair — no naked leg).

Qualification (deterministic, card filters): enough synced D1 bars on both legs,
both cluster sigmas > 0, regime means separated
(`|mu_1 - mu_2| >= min_regime_mean_gap_sigma * pooled_sigma`), and a bounded
AR(1) half-life inside `[min_half_life, max_half_life]`. Refit each closed bar
from the fixed rolling window while flat; no in-position parameter update.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_partner_symbol` | `GBPUSD.DWX` | any registered partner `.DWX` | Leg-2 (partner) symbol read for the spread and traded opposite the host |
| `strategy_partner_slot` | 1 | 0-9999 | Partner leg's registered magic slot in `magic_numbers.csv` |
| `strategy_training_window_bars` | 504 | 252-756 | Rolling OLS hedge + regime training window (D1 bars) |
| `strategy_delta_sigma` | 1.5 | 1.0-2.0 | Sigma-band multiplier for entry/exit thresholds |
| `strategy_regime_prob_threshold` | 0.70 | 0.60-0.80 | `rho`: `P(state\|X_t)` gate on the probability-conditioned legs |
| `strategy_max_hold_bars` | 60 | 30-90 | Time stop in D1 bars |
| `strategy_min_regime_mean_gap_sigma` | 0.5 | 0.25-0.75 | Skip if `\|mu_1-mu_2\| < gap*pooled_sigma` (nearly-equal regimes) |
| `strategy_min_half_life` | 3 | 1-10 | Card half-life filter lower bound (D1 bars) |
| `strategy_max_half_life` | 80 | 20-80 | Card half-life filter upper bound (D1 bars) |
| `strategy_min_d1_bars` | 560 | >= training+buffer | Skip until both legs have enough synced D1 history |
| `strategy_leg_risk_split` | 0.5 | 0.25-1.0 | Documentary share of RISK_FIXED notionally per leg (lots sized per-leg by framework) |

---

## 3. Symbol Universe

Pairs trade — registered as three economically-related host/partner pairs.
Host = leg1 (`qm_magic_slot_offset`), partner = leg2 (`strategy_partner_slot`).
Pairing selected per-setfile.

**Designed for:**
- `EURUSD.DWX` (slot 0, host A / partner C) / `GBPUSD.DWX` (slot 1, partner A) — two USD majors driven by a common USD factor; classic EUR/GBP relative-value pair (card primary candidate).
- `AUDUSD.DWX` (slot 2, host B) / `NZDUSD.DWX` (slot 3, partner B) — antipodean commodity-currency pair, the strongest persistent FX relative-value relationship (card primary candidate).
- `XAUUSD.DWX` (slot 4, host C) / `EURUSD.DWX` (slot 0, partner C) — gold vs the euro; metal-vs-USD-funding-currency relative value (card R3 pair C: XAUUSD/EURUSD). EURUSD reuses its slot-0 registration as the pair-C partner.

All five distinct legs are REAL `.DWX` symbols present in
`dwx_symbol_matrix.csv` — no port was needed.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker routes no orders); a pairs EA whose legs must both be live-tradable cannot promote an SP500 leg.
- Single-symbol or unrelated symbols — the strategy is only meaningful on a related two-symbol spread.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | partner-symbol D1 closes (cross-symbol, same TF) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~18 (card: 10-30 trades/year/pair after regime + sigma gates) |
| Typical hold time | days to a few weeks (spread reversion; time stop = `max_hold_bars` ≈ 60 D1 bars) |
| Expected drawdown profile | bounded; risk-fixed per leg, market-neutral, regime sigma-band entries |
| Regime preference | mean-revert (regime-conditioned spread reversion around per-state means) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** forum/repo (GitHub notebook)
**Pointer:** `https://github.com/hudson-and-thames/arbitrage_research/blob/master/Time%20Series%20Approach/regime_switching_arbitrage_rule.ipynb` (Hudson & Thames; primary paper Bock & Mestel 2009, "A regime-switching relative value arbitrage rule")
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11255_ht-regime-rvarb.md`

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
| v1 | 2026-06-18 | Initial build from card | two-leg regime-switching relative-value basket pairs EA; deterministic median-split regime model (no ML/HMM-EM); all 5 distinct legs native `.DWX` (no port) |
