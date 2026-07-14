# FTMO book frontier - 2026-07-11

## Verdict

The requested FTMO Phase-1 book is **not challenge-ready**. After processing the
five secret-survivor ideas, the best fully reconstructed research frontier
reaches a 27.59% bootstrap pass rate within 30 continuous calendar days, versus
the required 80%. The corresponding historical rolling-window pass rate is
23.08%.

No deploy setfiles, paid-challenge manifest, live-account change, or AutoTrading
change were made. T6-T10 and T_Live received no backtest or runtime action. The
compile helper may refresh framework includes in shared MetaQuotes data directories,
but the installed FTMO terminal was neither launched nor configured.

Machine-readable book verdict:

- `artifacts/ftmo_book_research_frontier_2026-07-11.json`
- `artifacts/ftmo_secret_survivor_book_frontier_2026-07-11.json`
- `artifacts/ftmo_secret_survivor_weight_grid_phase1_30d_sim_v2_2026-07-11.json`

## Research frontier book

| EA | Target | Effective RISK_FIXED | Nominal risk | Qualification |
|---:|---|---:|---:|---|
| 10440 | US100.cash | 3480 | 3.48% | research reserve only; current native equity DD 19.83% |
| 12969 | USD/JPY | 1200 | 1.20% | current-cost Q02 PASS |
| 12990 | GBP/USD | 1200 | 1.20% | conditional low frequency |
| 10377 | XAU/USD | 120 | 0.12% | Q09 PASS_PORTFOLIO; Q08 FAIL_SOFT research lead |
| **Total** | | **6000** | **6.00%** | **NO_GO** |

The frontier is a research allocation, not a deployment recommendation. It is
reported because it maximizes the measured 30-day pass probability among the
tested weights, not because it satisfies the release gate.

| Outcome over 30 calendar days | Bootstrap, 15,000 paths | Historical rolling, 2,977 windows |
|---|---:|---:|
| Phase-1 pass | 27.59% | 23.08% |
| Daily-loss breach | 36.43% | 34.20% |
| Maximum-loss breach | 15.93% | 18.64% |
| Target not reached | 20.04% | 24.08% |

The 80% target is short by 52.41 percentage points. The new XAU sleeve improves
the old control by only 0.35 bootstrap percentage points; higher XAU weights
reduce pass rate. Risk controls and reweighting alone cannot credibly bridge the
gap; the book needs materially more return density per unit of intraday MAE.

The exact `12971` Pre-FOMC H1 amendment does not change this frontier. It passes
current FTMO costs, Q04, Q05, and Q06, but fails Q07 with 32.75% PF variance across
five profitable harsh-stress seeds. It was therefore excluded before portfolio
simulation.

## Audit scope

- 95 latest Q08 report/stream cases audited; only 14 archived streams reconciled
  exactly before fresh reproduction.
- 84 non-basket Q08 reports repriced successfully to the 2026-07-11 FTMO symbol
  snapshot; two cases errored and nine unsupported cases were skipped.
- Eight shortlisted sleeves were reproduced or re-evaluated with current FTMO
  costs and trade-level report reconstruction.
- All selected fresh streams reconcile on trade count, native net, and MAE
  availability before entering the simulator.
- 496 new intraday configurations were screened across US100, US500, GER40, and
  XAUUSD. None passed the pre-holdout gate, so no curve-fit EA was promoted.
- 704 additional FX-M5 session configurations were screened across EURUSD,
  GBPUSD, USDJPY, and GBPJPY. None passed the 2018-2023 pre-holdout gate; the
  2024-2025 holdout remained uncomputed and no EA was built.

Primary audit artifacts:

- `artifacts/ftmo_all_q08_stream_reconciliation_sweep_2026-07-11.json`
- `artifacts/ftmo_q09_stream_reconciliation_sweep_2026-07-11.json`
- `artifacts/ftmo_q08_archive_current_cost_sweep_2026-07-11.json`
- `artifacts/ftmo_intraday_screen_v2_NDX_2026-07-11.json`
- `artifacts/ftmo_intraday_screen_v2_SP500_2026-07-11.json`
- `artifacts/ftmo_intraday_screen_v2_GDAXI_2026-07-11.json`
- `artifacts/ftmo_intraday_screen_v2_XAUUSD_2026-07-11.json`
- `artifacts/ftmo_fx_m5_session_screen_2026-07-11.json`

## Current-cost candidate inventory

| EA | Symbol | Trades | FTMO PF | FTMO net | Close DD | Positive active years | Gate |
|---:|---|---:|---:|---:|---:|---:|---|
| 10286 | XTIUSD.DWX | 488 | 1.479 | 80,629 | 16,098 | 6/8 | FAIL |
| 10440 | NDX.DWX | 618 | 1.208 | 80,913 | 22,514 | 6/8 | FAIL |
| 10476 | USDCAD.DWX | 257 | 1.332 | 49,169 | 12,477 | 6/8 | FAIL |
| 10815 | GDAXI.DWX | 79 | 2.146 | 9,563 | 2,403 | 6/8 | FAIL |
| 10919 | XTIUSD.DWX | 30 | 4.618 | 6,407 | 1,434 | 7/8 | FAIL |
| 11125 | SP500.DWX | 51 | 1.894 | 7,026 | 1,992 | 6/7 | FAIL |
| 12969 | USDJPY.DWX | 331 | 1.435 | 9,041 | 1,587 | 8/9 | PASS |
| 12990 | GBPUSD.DWX | 91 | 1.695 | 24,622 | 4,999 | 9/9 | FAIL (frequency) |

The individual JSON artifacts named
`artifacts/ftmo_<ea>_*_q02_current_binary_2026-07-11.json` contain the native
deal reconstruction, direction-specific FTMO swap and commission application,
annual results, hashes, and gate verdicts.

## Model contract

The simulator uses continuous Europe/Prague calendar days, the FTMO +10% target,
5% daily loss, 10% maximum loss, and four minimum trading days. It bootstraps
five-day blocks and also evaluates every historical 30-day rolling window.

The result is conservative because all open trades are assumed to reach their
recorded MAE together on each day. It is still not evidence for an 80% book:
conservatism can hide some diversification benefit, but cannot justify replacing
a measured 27.24% with an unsupported 80% claim.

## Required next gate

The next book iteration must add new, structurally different intraday alpha, not
more scaling of the current sleeves. Each new sleeve must be tested at current
FTMO costs, reconcile exactly to its MT5 report, survive pre-holdout and holdout
periods, and improve the joint 30-day frontier after MAE.

A synchronized per-bar joint-equity capture plus a portfolio-wide daily governor
model is also required before any paid challenge. The governor may reduce breach
paths, but it must be measured on exact traces and cannot be credited with
turning stopped paths into successful +10% paths without evidence.
