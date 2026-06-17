# QM5_11249_ht-cir-levels — Strategy Spec

**EA ID:** QM5_11249
**Slug:** `ht-cir-levels`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (see `strategy-seeds/sources/af021dd0-e07d-5f72-9933-de7a3533934e/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On each completed D1 bar the EA builds a non-negative pair portfolio
`Y_t = S1 - beta*S2 + offset` (S1 = host close, S2 = partner close) over a
formation window, where `offset` shifts the spread so it stays strictly positive
and `beta` is chosen from a bounded grid by maximising a Cox-Ingersoll-Ross (CIR)
Gaussian quasi log-likelihood proxy. The CIR parameters theta (mean-reversion
speed), mu (long-run mean) and sigma (volatility) are estimated closed-form by
weighted OLS on the variance-stabilised discretised CIR (Euler scheme divided by
sqrt(Y_{t-1})) — no iterative MLE, no ML. Optimal levels are a band around the
long-run mean using the CIR stationary std `sigma_stat = sigma*sqrt(mu/(2*theta))`:
entry `d_chi = mu - entry_k*sigma_stat`, liquidation `b_chi = mu + exit_k*sigma_stat`.

It is a long-only positive-spread trade: when `Y_t <= d_chi` (spread cheap) it
BUYs the host leg and SELLs the partner leg as a two-leg basket. It liquidates the
whole pair when `Y_t >= b_chi` (reverted up), or stops out when `Y_t` breaches the
model stop band `mu - stop_k*sigma_stat` (or the positivity guard `Y_t <= 0`), or
on a time stop after `max_hold_bars` D1 bars. A new position opens only while flat
(the deterministic form of the card's "refit monthly while flat"). If the partner
symbol is blank, the EA applies the same CIR levels to a single positive series
(host close) with no basket leg.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_partner_symbol` | `GBPUSD.DWX` | .DWX or `""` | Foreign leg2 symbol; `""`/host = single positive series |
| `strategy_partner_slot` | 1 | 0-5 | Registered magic slot of the partner leg |
| `strategy_formation_bars` | 504 | 252-756 | CIR formation/fit window (D1 bars) |
| `strategy_beta_grid_min` | 0.50 | 0.25-0.75 | Min hedge ratio in the bounded beta scan |
| `strategy_beta_grid_max` | 2.00 | 1.50-2.50 | Max hedge ratio in the bounded beta scan |
| `strategy_beta_grid_steps` | 16 | 1-64 | Grid resolution for the beta scan |
| `strategy_entry_k` | 1.50 | 0.5-3.0 | Entry depth: `d_chi = mu - entry_k*sigma_stat` |
| `strategy_exit_k` | 0.25 | 0.0-1.0 | Liquidation level: `b_chi = mu + exit_k*sigma_stat` |
| `strategy_stop_k` | 3.00 | 2.0-5.0 | Model stop band: `mu - stop_k*sigma_stat` |
| `strategy_max_hold_bars` | 120 | 60-180 | Time stop (D1 bars) |
| `strategy_cost_cushion_frac` | 0.10 | 0.0-0.5 | Reject if `(b_chi-d_chi) < cushion*sigma_stat` |
| `strategy_min_d1_bars` | 560 | >=560 | Minimum synced D1 bars required on each leg |
| `strategy_min_sigma_stat` | 1e-9 | >0 | Floor on stationary std (degenerate guard) |

---

## 3. Symbol Universe

**Designed for (host / partner positive pair spreads):**
- `EURUSD.DWX` (host A) / `GBPUSD.DWX` (partner A) — tightly correlated G10 USD majors; spread mean-reverts.
- `AUDUSD.DWX` (host B) / `NZDUSD.DWX` (partner B) — classic commodity-bloc cointegrated pair.
- `XAUUSD.DWX` (host C) — strictly positive series usable as a single-series CIR fallback.

**Explicitly NOT for:**
- Index/CFD symbols — the CIR positivity construction targets FX/metals positive spreads, not equity indices.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | partner-leg D1 close reads (basket); else none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~14 (card: 8-25 trades/year/pair) |
| Typical hold time | days to weeks (mean-reversion, capped at 120 D1 bars) |
| Expected drawdown profile | low per-trade; pair-neutral spread reversion |
| Regime preference | mean-revert (stationary CIR positive spread) |
| Win rate target (qualitative) | medium-high (revert-to-mean band) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** documentation (Hudson & Thames ArbitrageLab; primary ref Leung & Li 2015 book)
**Pointer:** https://hudson-and-thames-arbitragelab.readthedocs-hosted.com/en/latest/optimal_mean_reversion/cir_model.html
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11249_ht-cir-levels.md`

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
| v1 | 2026-06-18 | Initial build from card | CIR positive-spread basket, closed-form OLS fit |
