# QM5_11242_ht-copula-mpi — Strategy Spec

**EA ID:** QM5_11242
**Slug:** `ht-copula-mpi`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (see `strategy-seeds/sources/af021dd0-e07d-5f72-9933-de7a3533934e/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Two-leg market-neutral pairs trade driven by a copula Mispricing Index (MPI). On
each closed D1 bar the EA takes the last `formation_bars` daily log-returns of the
host leg (X = `_Symbol`) and the partner leg (Y, a foreign `.DWX` symbol), turns
each return series into empirical-CDF pseudo-observations (rank / (n+1)), and fits
a Gaussian copula whose correlation `rho` is estimated in CLOSED FORM from
Kendall's tau via `rho = sin(pi*tau/2)` — a deterministic method-of-moments
relation, no iterative fit and no ML. It then computes the two conditional
mispricing indices for the most recent return using the closed-form Gaussian
copula h-function: `MI_X|Y = Phi((Phi^-1(u_X) - rho*Phi^-1(u_Y))/sqrt(1-rho^2))`
and the symmetric `MI_Y|X`. These feed two cumulative flags:
`FlagX += MI_X|Y - 0.5`, `FlagY += MI_Y|X - 0.5`.

Entry: when `FlagX <= -open_flag AND FlagY >= +open_flag` the EA goes LONG X /
SHORT Y (X cheap, Y rich); the mirror condition goes SHORT X / LONG Y. Exit when
both flags revert inside `±exit_flag`, OR either flag overextends to `±stop_flag`,
OR the pair has been held `max_hold_bars` D1 bars. Both legs always open and close
together; the cumulative flag series is RESET to zero on every exit. Standard
two-axis news filter and Friday-close apply.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_partner_symbol` | `GBPUSD.DWX` | any registered partner `.DWX` | Foreign leg-2 (Y) symbol traded via the basket path |
| `strategy_partner_slot` | 1 | 0-5 | Partner leg registered magic slot |
| `strategy_formation_bars` | 252 | 126-504 | Rolling window of D1 returns for the empirical CDF + Kendall-tau copula fit |
| `strategy_open_flag` | 0.6 | 0.4-1.0 | Cumulative-flag threshold that opens a pair |
| `strategy_exit_flag` | 0.1 | 0.0-0.2 | Revert-to-flat band; both flags inside `±exit_flag` closes the pair |
| `strategy_stop_flag` | 1.5 | 1.2-2.0 | Flag-overextension stop; either flag at `±stop_flag` closes the pair |
| `strategy_max_hold_bars` | 45 | 20-60 | Time stop in held D1 bars |
| `strategy_min_d1_bars` | 320 | 280-560 | Minimum synced D1 bars on both legs before any fit |
| `strategy_leg_risk_split` | 0.5 | 0.25-0.5 | Share of RISK_FIXED notionally attributed per leg |

---

## 3. Symbol Universe

**Designed for** (host/partner pairs, both legs are real broker-routable `.DWX`
symbols present in `dwx_symbol_matrix.csv`):
- `EURUSD.DWX` (host A, slot 0) / `GBPUSD.DWX` (partner A, slot 1) — co-moving G10 EUR/GBP majors.
- `AUDUSD.DWX` (host B, slot 2) / `NZDUSD.DWX` (partner B, slot 3) — classic commodity-bloc antipodean pair.
- `NDX.DWX` (host C, slot 4) / `WS30.DWX` (partner C, slot 5) — Nasdaq-100 vs Dow-30 US large-cap indices.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (not broker-routable); not registered for this EA to keep both legs live-tradable.
- Single-symbol use — the strategy is intrinsically two-leg; running one leg alone never trades.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` (both legs read D1 closes only) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~18` (card estimate 10-30, source warns parameter sensitivity) |
| Typical hold time | `days to a few weeks` (time stop 45 D1 bars) |
| Expected drawdown profile | `market-neutral spread; drawdown on persistent divergence until stop_flag/time-stop` |
| Regime preference | `mean-revert (relative-value convergence)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** `notebook` (Hudson & Thames Arbitrage Research; primary paper Xie, Liew, Wu & Zou 2016)
**Pointer:** `https://github.com/hudson-and-thames/arbitrage_research/blob/master/Copula%20Approach/Copula_Strategy_Mispricing_Index.ipynb`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11242_ht-copula-mpi.md`

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
| v1 | 2026-06-17 | Initial build from card | closed-form Gaussian-copula realisation (AIC multi-family fit dropped as non-closed-form per HR14) |
