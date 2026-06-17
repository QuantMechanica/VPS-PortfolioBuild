# QM5_11252_ht-multicoint — Strategy Spec

**EA ID:** QM5_11252
**Slug:** `ht-multicoint`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (Hudson & Thames, Multivariate Cointegration Framework / Strategy)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Multivariate (Johansen-style) cointegration basket, traded on the close of each
D1 bar. While flat, the EA fits a closed-form cointegrating vector over a
`training_window_bars` formation window by a **deterministic rolling multi-OLS
hedge**: it regresses `ln(host)` on `[1, ln(partner_2), ..., ln(partner_k)]`
(normal equations solved by in-place Gauss-Jordan with partial pivoting). The
cointegrating vector is `b = [+1, -beta_2, ..., -beta_k]` and the spread is
`Y_t = ln(host) - sum_j beta_j*ln(partner_j) - intercept`. It then forms the
one-step change `Z_t = Y_t - Y_{t-1}`, the finite lagged sum
`S_t = sum_{p=1..lag_p} Z_{t-p}`, and standardises `S_t` by the spread-change
std (scaled by sqrt(lag_p)) into portfolio sigmas. When `S_t >= +deadband_z` the
spread is shorted (SELL host, partners by sign of their weight); when
`S_t <= -deadband_z` the spread is bought. Each partner leg L takes side
`sign(spread_dir * sign(beta_L))`. Exit when the target side changes, when
`|S_t|` falls back inside the deadband (mean-band), after a hard time stop of
`time_stop_bars` D1 bars, or on the flat-only `refit_interval_days` refit. All
legs open and close together as one basket.

**Determinism flag:** the card cites a Johansen eigenvector for `b`. A full
Johansen eigen-MLE is an iterative optimiser, not deterministically expressible
in pure MQL5 without a banned numerical/ML eigensolver. Per the build mandate
this is approximated by the fixed rolling multi-OLS hedge (regress leg1 on legs
2..k) — the standard Engle-Granger multivariate analogue, closed-form on
closed-bar prices. No ML, no external feed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_partner1_symbol` | `GBPUSD.DWX` | .DWX or "" | Partner leg 2 symbol ("" = unused) |
| `strategy_partner1_slot` | 1 | -1..n | Partner leg 2 registered magic slot (-1 = unused) |
| `strategy_partner2_symbol` | `AUDUSD.DWX` | .DWX or "" | Partner leg 3 symbol |
| `strategy_partner2_slot` | 2 | -1..n | Partner leg 3 registered magic slot |
| `strategy_partner3_symbol` | `NZDUSD.DWX` | .DWX or "" | Partner leg 4 symbol |
| `strategy_partner3_slot` | 3 | -1..n | Partner leg 4 registered magic slot |
| `strategy_partner4_symbol` | "" | .DWX or "" | Partner leg 5 symbol (unused by default) |
| `strategy_partner4_slot` | -1 | -1..n | Partner leg 5 registered magic slot |
| `strategy_training_window_bars` | 504 | 252-756 | Multi-OLS formation window (D1 bars) |
| `strategy_lag_p` | 20 | 10-40 | Finite lagged Z-sum length |
| `strategy_deadband_z` | 0.25 | 0.0-0.5 | `|S_t|` portfolio-sigma entry/exit deadband |
| `strategy_max_leg_gross_pct` | 45.0 | 35-55 | Max single-leg gross `|weight|` share (concentration cap) |
| `strategy_refit_interval_days` | 22 | 11-44 | Flat-only refit cadence (D1 bars) |
| `strategy_time_stop_bars` | 5 | 1-20 | Hard time stop with no side change |
| `strategy_min_legs` | 3 | 3-5 | Required active leg count |
| `strategy_min_d1_bars` | 560 | — | Min synced D1 bars per leg before trading |

---

## 3. Symbol Universe

Cointegration legs must come from a single coherent matrix. Two card baskets are
registered; the FX 4-leg basket is the default instance.

**Designed for (FX 4-leg basket, default):**
- `EURUSD.DWX` — host leg (slot 0); major EUR/USD anchor of the FX system.
- `GBPUSD.DWX` — partner (slot 1); GBP/USD co-moves with EUR/USD.
- `AUDUSD.DWX` — partner (slot 2); commodity-USD leg.
- `NZDUSD.DWX` — partner (slot 3); AUD/NZD tightly cointegrated, completes the basket.

**Also registered (index basket, selectable via setfile partner bindings):**
- `NDX.DWX` — slot 4; Nasdaq 100, US large-cap index leg.
- `WS30.DWX` — slot 5; Dow 30, US large-cap index leg.

**Explicitly NOT for:**
- Mixing FX and equity-index legs in ONE Johansen vector — economically
  incoherent. An index basket instance (e.g. EURUSD/NDX/WS30) is run as its own
  setfile, never blended with the FX legs in a single fit.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~80 |
| Typical hold time | 1-5 D1 bars (rebalanced/closed at next bar on side change) |
| Expected drawdown profile | Mean-reversion basket; small per-trade risk, bounded by leg concentration cap |
| Regime preference | mean-revert (cointegration relative-value) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** documentation + paper
**Pointer:** Hudson & Thames ArbitrageLab "Multivariate Cointegration Framework / Strategy"; primary reference Galenko, Popova & Popova (2012), "Trading in the presence of cointegration".
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11252_ht-multicoint.md`

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
| v1 | 2026-06-18 | Initial build from card | basket multi-OLS coint approximation of Johansen vector |

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`
