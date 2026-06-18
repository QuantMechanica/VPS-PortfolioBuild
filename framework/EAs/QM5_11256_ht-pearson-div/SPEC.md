# QM5_11256_ht-pearson-div — Strategy Spec

**EA ID:** QM5_11256
**Slug:** `ht-pearson-div`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (see `strategy-seeds/sources/af021dd0-e07d-5f72-9933-de7a3533934e/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Cross-sectional return-divergence rank basket over a fixed cohort of correlated
`.DWX` symbols, rebalanced once per "month". The source is monthly; because the
`.DWX` tester yields zero bars on MN1, the EA is D1-native and uses a deterministic
21-D1-bar/month proxy (252 trading days/year).

At each month boundary the EA builds a monthly-return series for every cohort symbol
from closed D1 closes (one return per `bars_per_month` block over `formation_months`
blocks). For the target symbol it selects the `partner_count` cohort symbols with the
highest positive Pearson correlation of monthly returns (correlation must be > 0 and
≥ `min_partner_corr`), equal-weights them into a partner portfolio, OLS-regresses the
target monthly return on the partner-portfolio return to estimate beta, then computes
the last completed month's return divergence `D = beta·R_target − R_partner` with the
risk-free rate `Rf = 0` (FX/CFD relative-return convention). The same divergence is
computed for every cohort symbol and the cohort is ranked cross-sectionally. Per the
source mean-reversion hypothesis (an over-/under-performance versus the partner
portfolio is expected to revert next month), the EA SHORTS the top-divergence
`short_pct` bucket and LONGS the bottom-divergence `long_pct` bucket. Each instance
runs on its own symbol and acts only on whether `_Symbol` falls in a bucket.

Exit: hold until the next monthly rebalance; close when `_Symbol` leaves its
long/short bucket, when fewer than `min_cohort` symbols are eligible to score, or
after a `time_stop_months` safety budget. Reversal is close-then-reopen across
rebalances — never pyramiding (one position per magic/symbol).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_formation_months` | 24 | 12-36 | Formation window in month-proxy blocks for correlation/beta |
| `strategy_partner_count` | 3 | 2-4 | Number of most-correlated partners forming the partner portfolio |
| `strategy_long_pct` | 0.25 | 0.20-0.33 | Top fraction of cohort to long (bottom-divergence bucket) |
| `strategy_short_pct` | 0.25 | 0.20-0.33 | Bottom fraction of cohort to short (top-divergence bucket) |
| `strategy_min_partner_corr` | 0.25 | 0.15-0.35 | Minimum positive Pearson correlation to qualify a partner |
| `strategy_bars_per_month` | 21 | 18-23 | D1 bars per month proxy (252/yr); MN1-untestable workaround |
| `strategy_min_months` | 12 | 12-24 | Minimum monthly observations required to trade |
| `strategy_min_cohort` | 4 | 4-6 | Skip the rebalance if fewer eligible cohort symbols |
| `strategy_time_stop_months` | 1 | 1-3 | Safety time stop in month-proxy blocks |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are
> documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

The cohort is the card's full R3 PASS basket. Cross-sectional ranking requires the
whole cohort to be present and warmed; each registered symbol runs as its own host
instance (one magic slot each) but reads all cohort closes for the shared ranking.

**Designed for (cohort, slot order):**
- `EURUSD.DWX` (slot 0) — major FX, high mutual correlation within the FX bloc
- `GBPUSD.DWX` (slot 1) — major FX, correlated to EUR/AUD/NZD USD legs
- `AUDUSD.DWX` (slot 2) — commodity-FX, strongly correlated to NZDUSD
- `NZDUSD.DWX` (slot 3) — commodity-FX, strongly correlated to AUDUSD
- `NDX.DWX` (slot 4) — Nasdaq 100, US-equity divergence leg, correlated to WS30
- `WS30.DWX` (slot 5) — Dow 30, US-equity divergence leg, correlated to NDX

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (not broker-routable); excluded to keep the cohort
  live-promotable. May be added later per the card's R3 note with a T6 parallel-validation.
- Single-symbol-only runs — the strategy is inherently cross-sectional; a 1-symbol
  cohort never reaches the `min_cohort` eligibility floor and never trades.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | full-cohort D1 closes (cross-symbol monthly returns) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` + month-proxy boundary gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (monthly rebalance decision) |
| Typical hold time | ~1 month (≈21 D1 bars) |
| Expected drawdown profile | Long/short cohort hedge; divergence-reversion P&L, moderate DD |
| Regime preference | mean-revert (cross-sectional return reversal) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** paper / notebook (Hudson & Thames Arbitrage Research, Pearson Distance Approach; primary paper Chen et al.)
**Pointer:** https://github.com/hudson-and-thames/arbitrage_research/blob/master/Distance%20Approach/pearson_distance_approach.ipynb
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11256_ht-pearson-div.md`

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
| v1 | 2026-06-18 | Initial build from card | Claude EA-build lane; magic registration + compile = central step |
