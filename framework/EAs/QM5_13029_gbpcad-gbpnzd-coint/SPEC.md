# QM5_13029_gbpcad-gbpnzd-coint - Strategy Spec

**EA ID:** QM5_13029
**Slug:** gbpcad-gbpnzd-coint
**Source:** QM-COINT-SCREEN-EXT-2026-07-06_GBPCAD-GBPNZD plus Chan cointegration pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-08-13

---

## 1. Strategy Logic

The EA trades the GBPCAD.DWX and GBPNZD.DWX D1 cointegration spread. It
computes `S = ln(GBPCAD) - beta * ln(GBPNZD)` with beta defaulting to
`0.3460`, then calculates a 90-bar rolling z-score of that spread. The
90-bar state window is the card's pre-declared slow-horizon variant and aligns
the signal horizon with the source screen's 84.8-day estimated half-life.

It opens a short-spread package when z is above +2.0 and a long-spread package
when z is below -2.0. Because beta is positive, the second-leg hedge direction is
opposite the first leg: long spread means long GBPCAD and short GBPNZD; short
spread means short GBPCAD and long GBPNZD. Each leg carries a 2.0 * ATR(20, D1)
protective stop.

The extended FX cointegration screen labels GBPCAD/GBPNZD as borderline and
requiring owner risk acceptance rather than a formal all-gates survivor. It is
the next non-duplicate card-worthy FX row after the already-built AUDCAD/GBPAUD
sleeve: strongest OOS trade-check result in the extension, shared-GBP structure,
and a plausible CAD/NZD commodity-bloc residual. The caveat is explicit: DEV net
Sharpe was negative and the half-life was 85 days, so Q02 and later gates must
judge whether the slow residual is tradable after costs.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_z_lookback_d1 | 90 | 20+ | D1 bars used for rolling spread mean and standard deviation; source-aligned slow-horizon variant |
| strategy_beta | 0.3460 | non-zero | Hedge coefficient in `ln(GBPCAD) - beta * ln(GBPNZD)` |
| strategy_entry_z | 2.0 | >0 | Absolute z-score threshold for opening a spread package |
| strategy_exit_z | 0.5 | >=0 | Absolute z-score threshold for closing the open package |
| strategy_atr_period_d1 | 20 | 2+ | D1 ATR period for per-leg hard stop distance |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiplier for each leg's hard stop |
| strategy_deviation_points | 20 | 0+ | Broker deviation points for market leg entries |

---

## 3. Symbol Universe

**Designed for:**
- GBPCAD.DWX - leg 1 of the fixed GBPCAD/GBPNZD spread and the spread numerator.
- GBPNZD.DWX - leg 2 of the fixed GBPCAD/GBPNZD spread and the beta-weighted spread denominator.

**History/conversion dependencies:**
- USDCAD.DWX - CAD profit-currency conversion support for USD tester accounting.
- NZDUSD.DWX - NZD profit-currency conversion support for USD tester accounting.

**Explicitly not for:**
- Other `.DWX` symbols. This card is a fixed two-leg FX basket, not a portable multi-pair strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / logical basket | 4-8 |
| Typical hold time | weeks to months |
| Expected drawdown profile | high; Q02/Q04/Q05 must judge whether this OOS-heavy residual is tradable after cost |
| Regime preference | shared-GBP residual between CAD and NZD commodity-bloc exposures |
| Win rate target | medium |

---

## 6. Source Citation

Primary method source:
- Chan, Ernest P. (2009). *Quantitative Trading*. Wiley. Chapter 7, stationarity and cointegration pair trading; examples 3.6, 7.2, 7.5 as extracted in `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

Pair-selection source:
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/results_full.csv`
- `D:/QM/strategy_farm/artifacts/research/coint_screen_ext_20260706/survivors.json`

Screen excerpt for this candidate:

| pair | half ADF t1 | half ADF t2 | rolling z excursions | half-life | hedge | OOS net Sharpe | OOS ret | OOS state changes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| GBPCAD~GBPNZD | -3.597 | -3.264 | 42 | 84.8d | 0.3460 | 1.66 | 14.2% | 30 |

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | USD 1,000 per basket trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

Q02 tester note: the manifest pins `tester_currency=USD` and
`tester_deposit=100000`. The logical basket backtest setfile uses the canonical
`RISK_FIXED=1000`, with `RISK_PERCENT=0`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial extended-screen FX cointegration basket build | Built from the 13024 two-leg basket pattern with sign-aware positive-beta leg direction |
| v2 | 2026-08-12 | Mechanize the approved slow-horizon variant | Changed only the pre-authorized z-score window from 60 to 90 D1 bars to align with the 84.8-day source half-life; task `41092da0-e9a5-4983-b615-2c85993668fa` |
| v3 | 2026-08-12 | Advance the current binary after Q02 PASS | Q02 work item `614cc154-31e1-4919-9a1e-de7bc5e0c5f3` passed; append-only Q03 work item `493a64ad-c9ed-46f4-9d05-1444ef50e645` was enqueued without dispatching a tester |
| v4 | 2026-08-13 | Bounded Codex review rework | Routed the chart-host leg through `QM_TM_OpenPosition`, made the entry gate explicitly D1, and moved news gating below package management and exits; build task `6000e70b-9b3d-41c2-97ce-113858c6a77d` |
