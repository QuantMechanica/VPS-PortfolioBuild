# QM5_11250_ht-ou-optstop — Strategy Spec

**EA ID:** QM5_11250
**Slug:** `ht-ou-optstop`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (see `strategy-seeds/sources/af021dd0-e07d-5f72-9933-de7a3533934e/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Two-leg basket pairs trade on a mean-reverting spread, traded under the
Ornstein-Uhlenbeck (OU) optimal-stopping framework (Leung & Li). On each closed
D1 bar, while flat, the EA fits a static hedge ratio by ordinary least squares of
the host close on the partner close over a training window, forms the spread
`X(t) = host - (a + beta*partner)`, then fits an OU process to that spread in
closed form via an AR(1) regression `X_t = c + phi*X_{t-1} + eps`. The OU
parameters follow directly: long-run mean `theta = c/(1-phi)`, mean-reversion
speed `kappa = -ln(phi)`, and equilibrium standard deviation
`sigma_e = sqrt(var(eps)/(1-phi^2))`. No iterative maximum-likelihood, no
optimiser, no machine learning.

The pair qualifies only when `0 < phi < 1` (genuine reversion), `sigma_e > 0`,
and the OU half-life `ln(2)/kappa` lies in `[min_half_life, max_half_life]`. The
EA then computes optimal levels in equilibrium-std units around `theta`: enter
long-spread when `X <= d* = theta - z_entry*sigma_e` (spread cheap); enter
short-spread when `X >= theta + z_entry*sigma_e` (spread rich). Liquidate at the
reversion target `b* = theta ± z_exit_eff*sigma_e`, where the discount rate `r`
tightens the target closed-form (`z_exit_eff = max(0, z_exit - r/kappa)` — the
Leung-Li value-of-waiting effect). Exit also fires at the hard OU optimal stop
`L = theta ∓ z_stop*sigma_e`, after `max_hold_bars` D1 bars (time stop), or on
Friday close. Trades skip if the cost-adjusted target width `(b*-d*)` falls below
`min_target_atr * sigma_e`, or if the hedge ratio moved more than
`beta_max_change` versus the prior flat refit. Refits happen only while flat; the
OU frame is latched for the life of an open trade. The host leg trades via the
framework magic; the partner leg trades a foreign `.DWX` symbol via the basket
order path, opposite side for market-neutral exposure. Both legs close together.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_partner_symbol` | `GBPUSD.DWX` | any matrix `.DWX` | Partner (leg2) foreign symbol |
| `strategy_partner_slot` | 1 | 0-4 | Partner leg registered magic slot |
| `strategy_training_window_bars` | 504 | 252-756 | OU/OLS training window (D1 bars) |
| `strategy_discount_rate` | 0.05 | 0.02-0.10 | OU discount rate r (tightens liquidation target) |
| `strategy_entry_z` | 1.5 | 1.0-3.0 | Entry band offset in sigma_e: d*=theta-z_entry*sigma_e |
| `strategy_exit_z` | 0.25 | 0.0-1.0 | Base liquidation offset in sigma_e (before discount) |
| `strategy_stop_z` | 2.5 | 2.0-3.0 | OU optimal-stop offset in sigma_e: L=theta-z_stop*sigma_e |
| `strategy_min_target_atr` | 1.5 | 1.0-3.0 | Skip if (b*-d*) < this * sigma_e (cost/edge floor) |
| `strategy_beta_max_change` | 0.25 | 0.1-0.5 | Skip refit if |beta-prev|/|prev| exceeds this |
| `strategy_min_half_life` | 3 | 2-10 | Min OU half-life (D1 bars) qualification |
| `strategy_max_half_life` | 60 | 20-90 | Max OU half-life (D1 bars) qualification |
| `strategy_max_hold_bars` | 80 | 40-120 | Time stop (D1 bars) |
| `strategy_min_d1_bars` | 560 | 300-900 | Min synced D1 bars required on both legs |

---

## 3. Symbol Universe

**Designed for** (cointegrated `.DWX` pairs, all real matrix symbols, no port):
- `EURUSD.DWX` — host A / partner C leg; major USD-base FX, deep history
- `GBPUSD.DWX` — partner A leg; co-moves with EURUSD (shared USD factor)
- `AUDUSD.DWX` — host B leg; commodity-FX, co-integrates with NZDUSD
- `NZDUSD.DWX` — partner B leg; tight AUD/NZD reversion pair
- `XAUUSD.DWX` — host C leg; gold vs USD-base FX (XAUUSD/EURUSD pair C)

Card R3 pairs: A = EURUSD/GBPUSD, B = AUDUSD/NZDUSD, C = XAUUSD/EURUSD. A setfile
binds host slot + partner symbol + partner slot to pick the pair. Pair C reuses
EURUSD.DWX (slot 0) as partner, so pairs A and C cannot both hold an EURUSD
position at once (same magic+symbol) — a documented setfile-time constraint.

**Explicitly NOT for:**
- `SP500.DWX` / index symbols — OU pairs model is calibrated on FX/metals
  cointegration here; index legs are out of scope for this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~20 (card: 12-35 / year / pair)` |
| Typical hold time | `days to weeks (bounded by 80-bar time stop)` |
| Expected drawdown profile | `market-neutral spread; DD when reversion is slow / regime breaks` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** `paper`
**Pointer:** Hudson & Thames, "Trading Under the Ornstein-Uhlenbeck Model",
ArbitrageLab documentation
(https://hudson-and-thames-arbitragelab.readthedocs-hosted.com/en/latest/optimal_mean_reversion/ou_model.html);
primary reference Tim Leung & Xin Li, "Optimal Mean Reversion Trading".
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11250_ht-ou-optstop.md`

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
| v1 | 2026-06-18 | Initial build from card | OU optimal-stopping basket pairs EA |
