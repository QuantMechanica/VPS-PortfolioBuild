# QM5_12708 challenger arithmetic and QM5_20177 frequency variant

Date: 2026-08-16 (Europe/Berlin)

Router task: `a38af97c-5b0e-4824-b7ee-d4ad038f78f1`

Branch: `agents/board-advisor`

Disposition: REVIEW. This is evaluation and draft-card evidence only. It does not change `T_Live`, a deploy manifest, the current book, an approved card, an EA source, or any pipeline verdict.

## QM5_12708 XAUUSD challenger evaluation

The calculation reuses the exact 28-sleeve book encoded by the authoritative Q09 artifact:

`D:/QM/reports/work_items/9347d44c-b107-4cd6-9c07-7094009bda25/QM5_12708/Q09_PORTFOLIO/XAUUSD_DWX/aggregate.json`

The production Q09 machinery in `tools/strategy_farm/portfolio/portfolio_admission.py` was applied read-only to the SHA-bound Q08 streams. The requested target is the weakest incumbent by standalone daily Sharpe, not the most-correlated incumbent selected by the original correlation-rejection branch.

| Measure | Result |
|---|---:|
| Challenger | `12708:XAUUSD.DWX` |
| Weakest incumbent | `11165:EURUSD.DWX` |
| Incumbent standalone Sharpe | 0.255785 |
| Current book Sharpe | 2.802693 |
| Swap-book Sharpe | 2.828729 |
| Sharpe delta | +0.026036 |
| Current book MaxDD | 0.261465% |
| Swap-book MaxDD | 0.276438% |
| MaxDD delta | +0.014973 percentage points (worse) |
| Existing challenger-superior rule | `false` — Sharpe improves, MaxDD does not, and the +0.026 Sharpe delta is below the +0.05 strong-Sharpe override |

Correlation bases:

| Relationship | Full-sample basis | High-volatility regime basis | Measurability |
|---|---:|---:|---|
| Challenger to weakest incumbent | 0.118741 | 0.094861 | Daily full-sample pair overlap is below the 60-day floor, so Q09's calendar-month fallback supplies the full-sample number. The regime basis is measurable on 390 regime days. |
| Challenger to book (worst measurable member pair, Q09 definition) | -0.028129 | 0.667115 | Both are measurable; the regime result uses 389 regime days and binds the original Q09 rejection. |

The regime basis is therefore measurable for both requested relationships. This differs from the earlier QM5_13054 study, where the monthly full-sample fallback left zero meaningful daily regime days. The arithmetic says only that the 12708-for-11165 swap improves Sharpe while worsening MaxDD; no swap recommendation or current-book mutation is made.

## QM5_20177 historical frequency evidence

The six authoritative Q02 summaries cover 2018-07-02 through 2022-12-31 (4.501 years), bind the same repaired source and EX5, and contain 42 completed trades:

| Symbol | H4 Q02 trades | Trades/year |
|---|---:|---:|
| EURUSD.DWX | 8 | 1.78 |
| GBPUSD.DWX | 6 | 1.33 |
| USDJPY.DWX | 8 | 1.78 |
| XAUUSD.DWX | 6 | 1.33 |
| NDX.DWX | 0 | 0.00 |
| WS30.DWX | 14 | 3.11 |
| **Total / mean per symbol** | **42** | **9.33 total / 1.56 mean** |

The terminal disposition and row paths are recorded in `docs/ops/evidence/ceaa0c8b_qm5_20176_log_bomb_qm5_20177_frequency_disposition_2026-08-16.md`.

### Offline pattern census

A read-only census used the existing `D:/QM/mt5/T_Export/MQL5/Files/*_H1.csv` and `*_D1.csv` exports. H4 was aggregated from H1. The census mirrors the EA's alternating five-bar fractals, bounded 4..80 pivot scan, D1 RSI [25,75], BC/AB [0.382,0.886], ATR projection-touch window, next-bar confirmation, 18-bar same-direction cooldown, and time-symmetry test. It does not launch MT5 and does not claim a pipeline verdict.

Because exported-bar reconstruction does not reproduce tester spread/news/position-state decisions exactly, estimates are calibrated by the observed ratio of the six Q02 results (42 realized trades) to the reconstructed H4 ±20% census (19 triggers). The calibration is used only for frequency ranking, not profitability.

| Option | Census result | Estimated trades/year/symbol | Build-worth result |
|---|---|---:|---|
| (a) Lower H4 to H1; retain ±20% symmetry | 64 H1 triggers across the six current symbols | 5.24 mean | Mixed: EURUSD 5.40, GBPUSD 6.38, USDJPY 5.40, WS30 6.38 pass; XAUUSD 2.95 and NDX 4.91 miss |
| (b) Widen H4 symmetry from ±20% to the card-declared ±30% bound | H4 triggers rise 19 -> 24 (+26.3%) | 1.97 mean | Reject for build: still far below 5 |
| (c) Extend the H4 symbol set, unchanged mechanics | Best new symbol is GDAXI at 3.44; NZDUSD 2.95; AUDJPY/EURJPY 2.46 | <5 on every additional exported symbol | Reject for build: breadth does not solve per-symbol cadence |

The only evidence-positive shape is therefore an H1 variant restricted to the four symbols whose individual estimates exceed five trades/year. That restriction prevents the pooled mean from hiding XAUUSD and NDX failures.

## Draft variant for OWNER approval

Draft card:

`D:/QM/strategy_farm/artifacts/cards_review/PENDING_A38AF97C_carney-ab-cd-pattern-h1-density.md`

The draft changes only the bar carrier from H4 to H1 and preserves the 72-hour physical cooldown by expressing it as 72 H1 bars. The harmonic price ratios, ±20% time symmetry, D1 RSI regime, projection-touch/confirmation, stops, targets, risk contract, news blackout, and prohibited-mechanics exclusions are unchanged. It targets only EURUSD, GBPUSD, USDJPY, and WS30, with a predeclared expected cadence of 5.9 trades/year/symbol from the census.

Status remains `PENDING_REVIEW`. No approved card, registry row, magic row, source, EX5, setfile, or work item is created or changed. Development may begin only after OWNER approves the draft and an identity is allocated through the normal deterministic process.

## Focused verification

- Recomputed the 28-sleeve current and swap books through Q09's inverse-volatility `portfolio_metrics` path.
- Recomputed full and regime correlations through Q09's `_candidate_corr`, `_regime_correlation`, and monthly pair fallback.
- Bound the baseline cadence to all six terminal `run_smoke/v2` Q02 summaries and their 42 reported trades.
- Ran the read-only 21-symbol exported-bar census; no additional H4 symbol reached five estimated trades/year.
- Confirmed the draft stays inside the active Edge Lab box: H1 swing horizon, mandatory news blackout, fixed risk for backtest, no HFT, ML, grid, or martingale.

## Safety boundary

- no current-book or incumbent mutation;
- no `T_Live`, AutoTrading, or deploy-manifest change;
- no terminal launch or active backtest interruption;
- no gate, pipeline verdict, news-staleness, or risk-contract change;
- no main or `C:/QM/worktrees/cto_main` mutation.
