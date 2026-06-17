# QM5_11247_ht-ou-bertram — Strategy Spec

**EA ID:** QM5_11247
**Slug:** `ht-ou-bertram`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (see `strategy-seeds/sources/af021dd0-e07d-5f72-9933-de7a3533934e/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Two-leg market-neutral pairs trade on cointegrated `.DWX` symbols, using
Bertram (2010) optimal Ornstein-Uhlenbeck (OU) trading thresholds. On each
closed H4 bar the EA builds a log-price spread `S = log(host) - hedge·log(partner)`
over a fixed formation window (hedge = OLS slope of log(host) on log(partner)).
It fits the OU process closed-form from an AR(1) regression of the spread:
`S_t = c + phi·S_{t-1} + e`, giving `theta = -ln(phi)` (reversion speed, requires
`0 < phi < 1`), `mu = c/(1-phi)` (mean), and `sigma_eq = std(e)/sqrt(1-phi²)`
(equilibrium std). No iterative MLE, no ML.

The Bertram optimal entry/exit level `k*` (in `sigma_eq` units around the mean)
is chosen by a deterministic bounded scan that maximises a cost-aware
Sharpe-per-unit-time proxy `(2·k·sigma_eq - cost)·sqrt(theta)/(k·sigma_eq)`,
subject to net expected return per cycle > 0. Entry long-spread (BUY host /
SELL partner) when `S ≤ mu - k*·sigma_eq`; entry short-spread (SELL host / BUY
partner) when `S ≥ mu + k*·sigma_eq`. Exit at the symmetric Bertram liquidation
band (long closes at `S ≥ mu + k*·sigma_eq`), a protective stop at
`|S - mu| ≥ stop_sigma_mult·sigma_eq`, or a time stop at `min(round(3/theta),
max_hold_bars)` H4 bars. Thresholds refit only while flat.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_partner_symbol` | `GBPUSD.DWX` | `.DWX` matrix | Foreign leg2 symbol (partner) |
| `strategy_partner_slot` | 1 | 0-5 | Registered magic slot of the partner leg |
| `strategy_formation_bars` | 252 | 126-504 | OU formation window in H4 bars |
| `strategy_transaction_cost` | 0.001 | 0.0005-0.002 | Round-trip cost in log-spread units |
| `strategy_stop_sigma_mult` | 3.0 | 2.5-3.5 | Protective stop at `mult·sigma_eq` from mean |
| `strategy_max_hold_bars` | 60 | 40-90 | Hard time-stop cap (H4 bars) |
| `strategy_min_level` | 0.5 | 0.25-1.0 | Smallest dimensionless entry level k scanned |
| `strategy_max_level` | 2.5 | 1.5-3.0 | Largest dimensionless entry level k scanned |
| `strategy_level_step` | 0.25 | 0.1-0.5 | Scan step for the Bertram level grid |
| `strategy_min_h4_bars` | 320 | ≥ formation+buffer | Min synced H4 bars on both legs |

---

## 3. Symbol Universe

**Designed for** (host leg / partner leg, registered as two magic slots each):
- `EURUSD.DWX` (host A, slot 0) / `GBPUSD.DWX` (partner A, slot 1) — major-major
  cointegrated FX pair, the source-context default.
- `AUDUSD.DWX` (host B, slot 2) / `NZDUSD.DWX` (partner B, slot 3) — classic
  commodity-FX cointegration (AUD~NZD), a documented strong reverting spread.
- `XAUUSD.DWX` (host C, slot 4) / `EURUSD.DWX` (partner C, slot 5) — gold vs EUR
  cross spread; card-stated PORTING test, not source-stated.

**Explicitly NOT for:**
- Single-symbol trend/breakout instruments — this is a two-leg relative-value
  spread; it needs a genuinely cointegrated partner or it never qualifies.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` (both legs read on H4) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `28` (card; H4 first-passage cycles, 15-45 range) |
| Typical hold time | `hours to days` (≤ 60 H4 bars ≈ 10 trading days) |
| Expected drawdown profile | `bounded; market-neutral spread, protective sigma stop at 3·sigma_eq` |
| Regime preference | `mean-revert` (cointegrated spread reversion) |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** `paper` (Hudson & Thames ArbitrageLab docs; primary ref Bertram 2010, Physica A)
**Pointer:** `https://hudson-and-thames-arbitragelab.readthedocs-hosted.com/en/latest/time_series_approach/ou_optimal_threshold_bertram.html`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11247_ht-ou-bertram.md`

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
| v1 | 2026-06-18 | Initial build from card | Bertram OU optimal-threshold pairs basket EA |
