# FTMO secret-survivor pipeline and book - 2026-07-11

## Verdict

All five OWNER handoff ideas have a terminal pipeline decision. One idea,
`QM5_10377 XAUUSD.DWX D1 SMA50`, earns a research-only portfolio admission.
None earns admission to a paid FTMO Challenge book.

The updated best measured 30-calendar-day research frontier is **27.59%** by
15,000-path block bootstrap and **23.08%** over 2,977 historical rolling
windows. The required 80% target is therefore missed by **52.41 percentage
points**. No deploy manifest was created.

FTMO's current official 2-Step objectives are 10% Phase-1 profit, 5% maximum
daily loss, 10% maximum loss, at least four trading days, and an unlimited
trading period:

- <https://ftmo.com/en/2-step-challenge/>
- <https://ftmo.com/en/trading-objectives/>

The 30-day horizon is QuantMechanica's internal speed objective, not an FTMO
deadline.

## Candidate attrition

| Idea | Independent MT5 result | Terminal gate | Book decision |
|---|---|---|---|
| SECRET_01 Pre-FOMC event-flat | Existing `12971` exact H1 `_v2`; fresh T4 Model-4: 56 trades, PF 1.50, two identical runs; current-cost PF 1.730 | Q04-Q06 PASS; Q07 PF variance 32.75% | Reject |
| SECRET_02 XAU SMA50 D1 | Existing `10377`; current-cost PF 1.826; Q04-Q07 PASS | Q08 `FAIL_SOFT`; FTMO-costed Q09 `PASS_PORTFOLIO` | Research only, 2% book weight |
| SECRET_03 JPY SMA20 D1 | Existing `10377`; AUDJPY current-cost PF 1.312, GBPJPY 1.164 | AUDJPY recent 2023-25 PF 1.066; GBPJPY Q02 FAIL | Reject both |
| SECRET_04 Breadth Tuesday | New `13137`; compile 0/0, smoke PASS | SP500 Q07 variance 24.69%; WS30 DD 28.93%; XAU non-deterministic | Reject |
| SECRET_05 XAU M5 EMA20 | New `13138`; native PF 1.51, compile 0/0, smoke PASS | Current FTMO cost PF 0.899, net -2,207; swap -10,523 | Reject |

IDs `13135` and `13136` were retired at G0 because their mechanics already
exist in `QM5_10377`. This avoids duplicate code and magic-number lineages.

### Exact SECRET_01 amendment

The initial comparison against the existing M30 mode was not mechanically exact.
`QM5_12971` was therefore amended without a new ID: an explicit H1 broker-clock mode,
the frozen 57-date regular-FOMC calendar, broker 21:00 entry on D-1, broker 20:00 exit
on D, and a 2.0 x prior-D1 ATR emergency stop. The legacy M30 mode remains the default,
so the amendment is backward compatible.

The exact binary was frozen at SHA256
`C51887E09C3C5A8F118EB163E9DDCFB3B220E26E090822EFD3C29F3874E16EFC` before testing.
The 2018-07-02 through 2025-12-31 run produced 56 trades, PF 1.50, net +9,485.06,
and 6.05% equity drawdown in both repetitions. On the complete 2019-2025 years,
current FTMO costs produce 54 trades, PF 1.730277, net +12,228.32, and at least seven
trades in every year.

Q04 fold PFs are 2.646, 1.932, and 1.028. Q05 passes at PF 1.54 and Q06 at PF
1.38. Q07's five profitable seed PFs are 1.38, 1.47, 1.71, 1.90, and 1.48, but
their 32.75% variance exceeds the 20% hard gate. Q08 and later phases were not run.

### Additional FX-M5 density scout

After the five-idea pipeline, 704 causal configurations across ten London/New-York
session families and `EURUSD`, `GBPUSD`, `USDJPY`, and `GBPJPY` were screened on
T_Export M5 bars. The contract selects on 2018-2022 DEV plus 2023 validation and
only then computes the sealed 2024-2025 holdout. Conservative all-in round-trip
price costs and stop-first same-bar collisions are applied.

No configuration passed the pre-holdout gate, so no family winner saw holdout
metrics and no EA ID/build was created. The closest useful diagnostic was USDJPY
Asia-range breakout at DEV PF 1.049 and 2023 PF 1.202; it still fails the required
DEV PF 1.12. A close-confirmed GBPJPY variant was even less stable at DEV PF 0.947
versus 2023 PF 1.424. This entire session-family class is rejected rather than tuned
against the holdout.

## Q09 costed admission

The generic Q09 result was repeated on an isolated FTMO research database and
streams recosted trade by trade to the 2026-07-11 FTMO snapshot. The production
DarwinexZero candidate database was not used or modified.

| Metric | FTMO-costed result |
|---|---:|
| XAU harsh-stream trades | 56 |
| Standalone PF | 2.004 |
| Correlation basis | monthly |
| Maximum correlation to research core | 0.120 |
| Sharpe without XAU | 2.020 |
| Sharpe with XAU | 2.035 |
| MaxDD without XAU | 1.391% |
| MaxDD with XAU | 1.503% |
| Q09 verdict | `PASS_PORTFOLIO` |

Q09 confirms diversification, but Q08 remains `FAIL_SOFT`. This is a valid
research-lead path, not strict challenge qualification.

## Research frontier v2

At 6.00% total nominal risk, the best tested allocation is:

| Sleeve | Weight | Effective RISK_FIXED | Qualification |
|---|---:|---:|---|
| `10440 NDX.DWX` | 58% | 3,480 | Research reserve; native equity DD above 15% |
| `12969 USDJPY.DWX` | 20% | 1,200 | Current-cost Q02 PASS |
| `12990 GBPUSD.DWX` | 20% | 1,200 | Conditional low-frequency |
| `10377 XAUUSD.DWX D1` | 2% | 120 | Q09 PASS; Q08 FAIL_SOFT |
| **Total** | **100%** | **6,000** | **NO_GO** |

| 30-day outcome | Bootstrap | Historical rolling |
|---|---:|---:|
| Phase-1 pass | 27.59% | 23.08% |
| Daily breach | 36.43% | 34.20% |
| Maximum-loss breach | 15.93% | 18.64% |
| Target not reached | 20.04% | 24.08% |

The 2% XAU addition improves the old control by only 0.35 bootstrap percentage
points and 0.63 historical percentage points. At 5% and 10% XAU weight, pass
rate falls. Scaling is therefore not the missing solution.

## Evidence

- `artifacts/ftmo_secret_survivor_pipeline_verdict_2026-07-11.json`
- `artifacts/ftmo_secret_survivor_book_frontier_2026-07-11.json`
- `artifacts/ftmo_secret_survivor_weight_grid_phase1_30d_sim_v2_2026-07-11.json`
- `artifacts/ftmo_fx_m5_session_screen_2026-07-11.json`
- `artifacts/qm5_12971_ftmo_v2_build_result_2026-07-11.json`
- `artifacts/ftmo_12971_sp500_cost_reconciliation_2026-07-11.json`
- `artifacts/ftmo_10377_xau_d1_cost_reconciliation_2026-07-11.json`
- `artifacts/ftmo_13137_sp500_cost_reconciliation_2026-07-11.json`
- `artifacts/ftmo_13138_xau_m5_cost_reconciliation_2026-07-11.json`
- `D:\QM\reports\pipeline_ftmo_secret\q09_ftmo_research\costed_result\QM5_10377\Q09_PORTFOLIO\XAUUSD_DWX\aggregate.json`

## Safety boundary

This work used T1, T2, and T4 only. T5 remains disabled for its existing account
defect. No backtest or runtime action was performed on T6-T10, T_Live, or the
installed FTMO terminal, and no live account, AutoTrading state, or deploy manifest
was changed. The compile helper may refresh framework include files in shared
MetaQuotes data directories; it did not launch or configure the installed FTMO
terminal. `FACTORY_OFF.flag` remained present throughout.

## Next research gate

The gap cannot be closed by increasing risk on the measured sleeves. The next
iteration needs multiple independent, current-cost-positive intraday edges with
short holding times and low swap exposure. Each must survive Model 4, current
FTMO costs, walk-forward, stress, multiseed, Q08/Q09, exact stream reconciliation,
and the joint 30-day MAE simulation before it can change the NO_GO decision.
