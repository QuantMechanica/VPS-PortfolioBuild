# QM5_9416_qs-coint-bb — Strategy Spec

**EA ID:** QM5_9416
**Slug:** `qs-coint-bb`
**Source:** `842161b9-a728-55c7-97e8-33e33719b70c`
**Author of this spec:** Claude (rebuild)
**Last revised:** 2026-07-05

---

## 1. Strategy Logic

D1 cointegrated index-pair mean-reversion, two-leg spread trade. Two host pairs
share this EA and are selected by the chart symbol (`_Symbol`):
pair 0 = `SP500.DWX` (y, host) / `NDX.DWX` (x); pair 1 = `WS30.DWX` (y, host) /
`NDX.DWX` (x). The EA opens BOTH legs from the single host-chart instance via
`QM_BasketOpenPosition` (`QM_BasketOrder.mqh`), so one Q02 work item per host
symbol exercises the full hedged spread trade rather than a single-leg proxy.

Hedge ratio beta = raw-price OLS(y ~ x) over `strategy_ols_period` D1 closes
(default 252, ~1yr), re-estimated every `strategy_reestimate_bars` bars
(default 21, ~monthly) per the card. A single-lag Engle-Granger/CADF-style
Dickey-Fuller test on the OLS residuals of that same window gates entry
(`strategy_cadf_critical_value`, default -3.34, the MacKinnon 5%-significance
two-variable asymptotic critical value — a fixed literature constant, not a
fitted parameter). Beta must also stay within
`[strategy_beta_min, strategy_beta_max]`.

Spread: `spread_t = close_y_t - beta * close_x_t` (raw price, per the card's
literal formula — no log transform). Z-score: mean/stdev of the spread over
the most recent `strategy_bb_period` closes (default 15, card-fixed). Entry
fires on the closed D1 bar when no position is open and the beta/CADF gate
passes: `zscore < -entry_z` opens long spread (long y-leg, short beta-adjusted
x-leg); `zscore > +entry_z` opens short spread (short y-leg, long x-leg).
Exit closes both legs when `|zscore| <= exit_z` (reversion), `|zscore| >=
stop_z` (divergence stop), the scheduled beta/CADF re-check fails, or one leg
is unexpectedly missing. Position sizing splits the EA's single `RISK_FIXED`
input across both legs (ATR-scaled, hedge-ratio-weighted via
`QM_LotsForRisk`), consistent with the card's "$1,000 total pair risk split
across two hedge-adjusted slots." No per-leg broker-side SL is set (matches
sibling pair EAs QM5_1023/QM5_10034); the zscore stop-out is the primary risk
control, backed by the kill-switch and Friday-close forcing both legs flat.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ols_period` | 252 | >=30 | OLS/CADF in-sample window, D1 bars (~1yr) |
| `strategy_reestimate_bars` | 21 | >=5 | Hedge-ratio/CADF re-estimate cadence (~monthly) |
| `strategy_bb_period` | 15 | >=5 | Lookback bars for spread mean/std (z-score denominator, card-fixed) |
| `strategy_entry_z` | 1.5 | >0 | Z-score magnitude threshold to open a position |
| `strategy_exit_z` | 0.5 | >=0 | Z-score magnitude threshold to close (mean-reversion target) |
| `strategy_stop_z` | 4.0 | > entry_z | Z-score magnitude hard stop (spread divergence) |
| `strategy_beta_min` | 0.25 | >0 | Minimum valid hedge ratio (card-fixed) |
| `strategy_beta_max` | 4.0 | > beta_min | Maximum valid hedge ratio (card-fixed) |
| `strategy_cadf_critical_value` | -3.34 | n/a | Fixed Engle-Granger/MacKinnon 5% 2-var asymptotic critical value |
| `strategy_atr_period_d1` | 14 | >0 | ATR period for hedge-weighted position sizing |
| `strategy_atr_sizing_mult` | 2.0 | >0 | ATR multiplier feeding `QM_LotsForRisk` sizing points |
| `strategy_deviation_points` | 20 | >=0 | Basket order slippage deviation (both legs) |

---

## 3. Symbol Universe

**Designed for (both legs registered and traded together):**
- `SP500.DWX` - y-leg host for pair 0; slot 0; backtest-only Custom Symbol, structurally cointegrated with NDX/WS30 US equity indices
- `NDX.DWX` - shared x-leg for both pairs; slot 1; live-tradable, Nasdaq vs S&P/Dow cointegration is empirically well-documented
- `WS30.DWX` - y-leg host for pair 1; slot 2; live-tradable, Dow Jones vs Nasdaq pair

**Explicitly NOT for:**
- Forex or commodity symbols - OLS spread semantics assume index-level price correlation; regime and beta validity checks would not apply
- `NDX.DWX` as a standalone host - it only ever trades as the x-leg, internal to whichever y-leg host (SP500 or WS30) is attached to the chart
- Live trading of `SP500.DWX` - backtest-only per DWX symbol matrix; live promotion requires parallel validation on NDX.DWX/WS30.DWX, and per-account admission control must ensure pair 0 and pair 1 never run concurrently on the same live account (both share the NDX.DWX slot 1 magic) — a T6/Board Advisor concern, out of scope for Q02

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | D1 CopyClose for both y-leg and x-leg, gated to the host's own closed bar |
| Bar gating | `QM_IsNewBar()` (host chart, consumed once per `OnTick`) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~80 |
| Typical hold time | 1-10 days |
| Expected drawdown profile | Mean-reversion with bounded spread divergence stops |
| Regime preference | Mean-reversion / pairs cointegration |
| Win rate target (qualitative) | medium-high (>50% typical for cointegrated mean-reversion) |

---

## 6. Source Citation

**Source ID:** `842161b9-a728-55c7-97e8-33e33719b70c`
**Source type:** article
**Pointer:** https://www.quantstart.com/articles/aluminum-smelting-cointegration-strategy-in-qstrader/ (QuantStart / QuarkGluon Ltd.)
**R1-R4 verdict (Q00):** all PASS - see `artifacts/cards_approved/QM5_9416_qs-coint-bb.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-01 | Initial build from card | single-leg proxy only; no CADF gate; log-bomb INFRA_FAIL at Q02 |
| v2 | 2026-07-05 | Rebuild in place (DL-069) | true two-leg execution via QM_BasketOpenPosition; added CADF/Engle-Granger gate; raw-price spread per card literal formula; friday_close_enabled=true; task d3a4794c-e4ba-4294-884a-7f75405252ba |
