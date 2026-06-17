# QM5_11245_ht-pca-sscore — Strategy Spec

**EA ID:** QM5_11245
**Slug:** `ht-pca-sscore`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (Hudson & Thames "PCA Approach"; Avellaneda & Lee 2010)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A fixed universe of six liquid `.DWX` CFDs (four FX majors plus two US indices)
is decomposed by Principal Component Analysis on every closed D1 bar. The EA
standardizes each member's daily returns over `corr_window` bars, builds the
return-correlation matrix, and eigendecomposes it with a deterministic symmetric
Jacobi eigenvalue rotation (no ML, no external library). The top
`num_factors` principal components form factor-return series. Each asset's
standardized returns are OLS-regressed on those factor returns over
`residual_window` bars (closed-form normal equations); the regression residual is
cumulated into an Ornstein-Uhlenbeck process. The OU model is fit closed-form as
an AR(1) regression `X(t)=a+b·X(t-1)+ε`, giving mean-reversion speed
`kappa = -ln(b)·252`, equilibrium mean `m = a/(1-b)`, and equilibrium volatility
`sigma_eq = sqrt(var(ε)/(1-b²))`. The s-score is `s = (X - m)/sigma_eq`.

Entry (host symbol only, requires `kappa >= k_min`): go LONG the host when
`s < -sbo`; go SHORT when `s > +sso`. Exit: close LONG when `s >= -sbc`, close
SHORT when `s <= +ssc`; protective stop at `|s| >= s_protect`; time stop after
`time_stop_bars` D1 bars; or exit flat if `kappa` decays below `k_min`. A static
emergency ATR stop (`stop_atr_mult × ATR`) bounds MT5 worst-case loss.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_corr_window` | 252 | 126-504 | D1 bars for the PCA return-correlation matrix |
| `strategy_residual_window` | 60 | 40-90 | D1 bars for OLS factor regression + OU fit |
| `strategy_num_factors` | 2 | 1-4 | Top-k principal components used as factors |
| `strategy_k_min` | 8.4 | 6.0-12.0 | Minimum OU mean-reversion speed (kappa) to trade |
| `strategy_sbo` | 1.25 | 1.0-1.5 | s-score open-LONG threshold (s < -sbo) |
| `strategy_sso` | 1.25 | 1.0-1.5 | s-score open-SHORT threshold (s > +sso) |
| `strategy_sbc` | 0.75 | 0.5-1.0 | s-score close-LONG threshold (s >= -sbc) |
| `strategy_ssc` | 0.50 | 0.25-0.75 | s-score close-SHORT threshold (s <= +ssc) |
| `strategy_s_protect` | 3.0 | 2.5-4.0 | Protective stop at \|s\| >= this |
| `strategy_time_stop_bars` | 60 | 40-90 | Close after this many D1 bars in trade |
| `strategy_min_members` | 4 | 4-6 | Min tradable universe symbols after data QC |
| `strategy_atr_period` | 20 | 14-30 | Emergency-stop ATR period (D1) |
| `strategy_stop_atr_mult` | 4.0 | 3.0-6.0 | Emergency MT5 stop = mult × ATR |
| `strategy_spread_pct_of_stop` | 20.0 | 10-30 | Skip new entry if host spread > this % of stop distance |

---

## 3. Symbol Universe

The PCA universe is fixed and identical for every host instance; each registered
host trades only its own residual against the shared decomposition.

**Designed for:**
- `EURUSD.DWX` — most liquid FX major; anchors the FX factor.
- `GBPUSD.DWX` — liquid FX major correlated with EUR/USD.
- `AUDUSD.DWX` — risk-sensitive FX major; diversifies the factor structure.
- `NZDUSD.DWX` — risk-sensitive FX major highly correlated with AUD/USD (classic stat-arb pair).
- `NDX.DWX` — Nasdaq 100; provides the equity-index factor and cross-asset residuals.
- `WS30.DWX` — Dow 30; second index, correlated with NDX for residual mean reversion.

**Explicitly NOT for:**
- Single-symbol charts where the universe cannot be warmed — the basket warmup of
  all six members is mandatory; an unwarmed foreign read returns 0 → no trades.
- SP500.DWX as a live host — backtest-only routing; not in this EA's universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | foreign-symbol D1 closes for all six universe members (basket reads) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~24 (card: 15-40 trades/year/basket) |
| Typical hold time | days to weeks (OU mean reversion; time stop 60 D1 bars) |
| Expected drawdown profile | shallow per-leg; residual divergence bounded by protective \|s\|>=3 and ATR stop |
| Regime preference | mean-revert (residual reversion of the de-factored series) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** documentation (Hudson & Thames ArbitrageLab) citing academic paper (Avellaneda & Lee 2010)
**Pointer:** https://github.com/hudson-and-thames/arbitragelab/blob/master/docs/source/other_approaches/pca_approach.rst
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11245_ht-pca-sscore.md`

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
| v1 | 2026-06-18 | Initial build from card | basket PCA s-score stat-arb |
