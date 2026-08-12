# FTMO speed-strategy experiment - 2026-07-10

## Status

**SUPERSEDED / FREE-TRIAL AND PAID-CHALLENGE NO-GO.**

The earlier speed composition is withdrawn. Fresh strict evidence subsequently
eliminated two sleeves at Q02 and left the third at Q08 `FAIL_SOFT`. Later
density/decorrelation experiments also failed MT5 stream/report reconciliation.

No T_Live preset, chart, position, account setting, or AutoTrading state was
changed. The FTMO terminal was not controlled. The factory remained under the
`FACTORY_OFF.flag` interlock during the experiment.

## Executive result

The useful conclusion is not simply "use scale 2". A lower-risk Round25 base
combined with three dense, mechanically different sleeves improves both speed
and open-horizon survival in the conservative MAE model.

Withdrawn historical simulation candidate, **not approved for Free Trial or
paid deployment**:

| Component | Baseline risk contract |
|---|---:|
| Round25 12-sleeve base | scale `1.75` (`$1,750` summed `RISK_FIXED`) |
| `QM5_10375 / NDX.DWX / M5` session ATR breakout | `$500` |
| `QM5_12986 / GDAXI.DWX / M15` Xetra ORB | `$500` |
| `QM5_12969 / USDJPY.DWX / M30` Gotobi/Nakane fix | `$500` |
| **Total nominal full-stop budget** | **`$3,250` / 3.25%** |

This `speed_v3` composition was the best simulated speed/survival compromise before
strict gate and input-fidelity follow-up. It is no longer recommended. The
`sprint_v3` variant raises the Round25 base to scale `2.0` but gives up too much
long-horizon survival for a modest speed gain. The `balanced_v3` variant lowers
the base to `1.5` and ORB to `$250` when survival is preferred.

## Claude scale result audit

Claude's directional finding is confirmed: scale `9.0` is structurally too hot
under intraday MAE. The original numeric table was nevertheless optimistic
because Q08 `net` contained only the exit-side deal commission.

Exact reconciliation on the new streams:

| Stream | Q08 net | Exit commission sum | Corrected net | MT5 report net |
|---|---:|---:|---:|---:|
| `10375/NDX` | `$59,503.21` | `-$3,530.69` | `$55,972.52` | `$55,972.52` |
| `12986/GDAXI` | `$39,015.58` | `-$5,907.94` | `$33,107.64` | `$33,107.07` |
| `12969/USDJPY` | `$11,836.97` | `-$862.19` | `$10,974.78` | `$10,974.78` |

The analysis tools now add the missing entry-side commission once per closed
trade and add it to conservative MAE. The MQL5 emitter itself remains a CTO /
Quality-Tech repair item.

Cost-corrected Round25 results, 10,000 bootstrap runs per cell across five
seeds:

| Scale | Phase 1 <=60d | Phase 1 <=180d | Phase 1 <=365d | Daily breach 365d |
|---:|---:|---:|---:|---:|
| `9.0` | `12.0%` | `12.3%` | `12.8%` | `85.9%` |
| `4.0` | `39.1%` | `51.3%` | `51.5%` | `13.6%` |
| `2.5` | `24.1%` | `56.6%` | `67.0%` | `0.0%` |
| `2.0` | `15.9%` | `50.3%` | `67.8%` | `0.0%` |
| `1.5` | `7.1%` | `37.0%` | `63.1%` | `0.0%` |

Thus the original `~76%` scale-2 claim is not a valid conservative lower bound.
The cost-corrected estimate is about `68%`, and it is still a model estimate.

## MT5 strategy screen

All rows used real-tick model 4, canonical backtest sets, and `RISK_FIXED=1000`.
Full raw matrix: `artifacts/ftmo_speed_backtest_matrix_2026-07-10.csv`.

| EA / carrier | Window | Trades | PF | Net | DD | Decision |
|---|---|---:|---:|---:|---:|---|
| `10375 / NDX / M5` current build | 2018-2025 | 1,633 | 1.13 | `$55,973` | `$15,295` | ADVANCE TO GATES |
| `12969 / USDJPY / M30` | 2017-2025 | 331 | 1.53 | `$10,975` | `$2,016` | ADVANCE Q08/Q10 |
| `12986 / GDAXI / M15` | 2018-2025 | 1,790 | 1.05 | `$33,107` | `$36,877` | CHALLENGER ONLY |
| `1142 / USDJPY / M30` | 2017-2025 | 1,334 | 1.10 | `$11,608` | `$7,902` | BACKUP / NO PRIORITY |
| `10115 / GDAXI / M15` | 2018-2025 | 430 | 1.08 | `$14,052` | `$26,216` | REJECT FOR FTMO |
| `1045 / SP500 / M30` | 2018-2025 | 946 | 0.96 | `-$18,057` | `$55,422` | REJECT |
| `12985 / NDX / D1` | 2018-2025 | 68 | 0.73 | `-$3,815` | `$5,867` | REJECT |
| `12700 / USDJPY / M15` | 2017-2025 | 168 | 1.03 | `$1,019` | `$10,879` | REJECT |
| `10774 / NDX / M15` | 2018-2025 | 1,574 | 0.97 | `-$25,890` | `$46,543` | REJECT |
| `11629 / NDX / M15` | 2018-2025 | 174 | 0.97 | `-$5,029` | `$22,881` | REJECT |
| `10094 / GDAXI / M5` | 2018-2025 | 90 | 0.51 | `-$36,849` | `$43,934` | REJECT |
| `10715 / USDJPY / M15` | 2017-2025 | n/a | n/a | n/a | n/a | INCOMPLETE: no report after >20 min |

Locked-parameter `10375` ports did not justify promotion: GDAXI PF 1.06,
SP500 PF 1.05, XAUUSD PF 0.93, and WS30 PF 0.89. Only NDX advances.

The current NDX report reconciles to `1,633/1,633` fresh Q08 rows with numeric
`entry_time` and `mae_acct`.

## Candidate efficiency

Cost-corrected conservative efficiency:

| Sleeve | Trades/year | PF | Annual net at base | Worst daily MAE at base | Annual net / daily MAE |
|---|---:|---:|---:|---:|---:|
| `10375/NDX` | 220.1 | 1.132 | `$7,543` | `$2,049` | `3.68` |
| `12986/GDAXI` | 240.4 | 1.055 | `$4,445` | `$1,358` | `3.27` |
| `12969/USDJPY` | 40.3 | 1.547 | `$1,335` | `$1,012` | `1.32` |

`10375` and `12986` provide velocity. `12969` provides cleaner expectancy and a
different clock/calendar driver.

## Phase 1 confirmation

Each cell uses 25,000 bootstrap paths (5,000 x five seeds), five-day blocks,
CE(S)T days, four actual trade-open days, corrected round-trip costs, and
conservative lifetime-MAE alignment.

| Scenario | 30d | 60d | 90d | 180d | 365d | Daily breach 365d |
|---|---:|---:|---:|---:|---:|---:|
| `balanced_v3` | 4.46% | 17.70% | 31.44% | 60.83% | 81.64% | 0.00% |
| `speed_v3` | 8.78% | 25.72% | 40.55% | 65.66% | 78.56% | 0.00% |
| `sprint_v3` | 11.18% | 29.53% | 44.11% | 66.76% | 76.28% | 0.00% |
| Round25 scale `2.0` | 5.5% | 15.9% | not run | 50.3% | 67.8% | 0.00% |

## Two-phase completion

This table simulates Phase 1 (`+10%`) followed by a fresh, independently sampled
Verification (`+5%`). `Max total days` means up to the shown half-window for
each phase. It is **not** a cash-payout probability.

| Scenario | <=120 total days | <=180 | <=360 | <=730 |
|---|---:|---:|---:|---:|
| `balanced_v3` | 8.70% | 19.95% | 49.52% | 72.38% |
| `speed_v3` | 14.66% | 27.90% | 53.21% | 66.30% |
| `sprint_v3` | 17.30% | 31.00% | 53.34% | 62.92% |

After Verification, actual first-Reward timing is longer. FTMO currently allows
a Reward request on the 14th or a later day after the first trade on the FTMO
Account, provided the account has closed profit and no open/pending orders. FTMO
states 1-2 business days for review and typically another 1-2 business days after
invoice approval. This funded-stage profit and processing interval is not modeled.

Official source:
`https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/`.

## Tooling changes

- `ftmo_phase1_mae.py`: reproducible scale grids, arbitrary horizons/seeds,
  Phase-1/Verification targets, two-phase bootstrap, CSV output, and round-trip
  commission correction.
- `ftmo_candidate_efficiency.py`: fresh-stream return-density/MAE ranking.
- `ftmo_candidate_book_experiment.py`: candidate sleeve scenarios and two-phase
  completion simulation.
- `Factory_OFF.ps1`: wrapper-before-terminal shutdown order, factory MetaTester
  cleanup, accurate final verification, and preservation of the original
  `codex_parallel` restore value across repeated OFF calls.

Focused automated tests: `13 passed`. `QM5_10375` strict compile: PASS, 0 errors,
0 warnings.

## Risks and blockers

1. The MQL5 Q08 emitter still omits entry-side commission. Python analysis now
   compensates exactly for the observed one-entry/one-exit streams, but CTO /
   Quality-Tech should repair and test the emitter.
2. `QM5_10375` was rebuilt against current includes. Its old downstream evidence
   does not qualify this new binary; it must restart at canonical Q02 and pass all
   hard gates through Q10.
3. `QM5_12969` still needs canonical Q08 and Q10 closure.
4. `QM5_12986` has only PF 1.05 over full history and is fragile. It remains an
   experimental sleeve unless the entire cascade passes without waivers.
5. Candidate selection and confirmation use overlapping historical data. A locked
   temporal holdout and per-bar equity reconstruction remain required.
6. Lifetime MAE aligned on every spanned day is deliberately conservative but not
   per-bar exact. It can distort both breach timing and correlations.
7. No paid challenge should start before a fresh Free Trial proves the exact
   candidate set, request rate, kill switch, daily anchors, and live-equivalent
   risk mapping.
8. `QM5_10715` exceeded the experiment harness limit without producing a report.
   It has no performance verdict and needs a separately bounded diagnostic run.

## Superseding strict follow-up

- `QM5_10375/NDX`: current-binary model-4 baseline produced 1,108 trades and
  PF `1.17`; canonical Q02 verdict is `FAIL` because PF must exceed `1.20`.
- `QM5_12986/GDAXI`: latest canonical Q02 verdict is `FAIL`.
- `QM5_12969/USDJPY`: fresh canonical Q08 is `FAIL_SOFT`; Neighborhood PASSed,
  but October seasonality and the low-volatility regime failed.
- Strict inventory across 108 known candidates: `0 CHALLENGE_READY`, three
  `RESEARCH_LEAD`, 105 `NOT_QUALIFIED`.
- The density A/B source audit reconciled only two of five tested streams;
  `10118`, `10546`, and `10706` failed count/net reconciliation, while
  `10569/EURUSD` reconciled to a negative PF `0.82` result.
- `strategy-seeds/cards/tokyo-fix-5m_card.md` is a lint-clean DRAFT for a
  distinct source-backed strategy. It is not approved and no EA ID was issued.

Superseding machine-readable evidence:

- `artifacts/ftmo_qualification_freshness_2026-07-10.json`
- `artifacts/ftmo_qualification_proposed_sleeves_2026-07-10.json`
- `artifacts/ftmo_stream_reconciliation_2026-07-10.json`

## Next execution order

1. CTO/Quality-Tech repair Q08 round-trip commission emission and add reconciliation
   tests against MT5 report Net Profit.
2. Canonically run `10375/NDX`, `12969/USDJPY`, and `12986/GDAXI` through remaining
   hard gates with current binaries.
3. Run per-bar exact equity reconstruction for `balanced_v3`, `speed_v3`, and
   `sprint_v3` on locked 2025/holdout data.
4. Deploy `speed_v3` only to a new Free Trial, with full kill-switch proof and no
   live-account changes.
5. Promote to a paid challenge only if the Free Trial remains inside the internal
   daily/total drawdown limits and all strict qualification gates are PASS.
