# FTMO strict qualification follow-up - 2026-07-10

## Decision

**NO-GO for Free-Trial ratification, paid Challenge, preset regeneration, or
deploy-manifest changes.** There is currently no sleeve set that satisfies both
the strict pipeline contract and the MT5 input-fidelity contract.

No T_Live setting, chart, position, preset, account, or AutoTrading state was
changed. The factory remained behind `FACTORY_OFF.flag`; the only Codex MT5 job
was a targeted Q08 run on T2, which completed and exited.

## Strict gate result

| candidate | fresh result | decision |
|---|---|---|
| `10375/NDX` | model 4, 1,108 trades, PF `1.17` | Q02 FAIL (`PF > 1.20` required) |
| `12986/GDAXI` | latest canonical Q02 `FAIL` | reject strict path |
| `12969/USDJPY` | Q08 `FAIL_SOFT`; 9 PASS, 2 edge-soft failures | research only, no Q10 cascade |

`12969` passed the Q08 Neighborhood test at baseline PF `1.53`, with stop
distance perturbations PF `1.55` and `1.52`. It failed seasonal robustness
(October `-$1,180.11`) and low-volatility regime P&L (`-$144.94`).

The fail-closed inventory now requires Q02, Q03, Q04, Q05, Q06, Q07, Q08, and
Q10 PASS, evidence newer than the current binary, an active magic, and a Q08
artifact-linked durable baseline stream containing `entry_time` and `mae_acct`.
Result: 108 candidates, `0 CHALLENGE_READY`, 3 `RESEARCH_LEAD`, and 105
`NOT_QUALIFIED`.

## A/B input audit

The stream-to-report gate uses the known one-entry/one-exit correction: the Q08
stream contains closing-side commission, so the same commission is added once
for the entry side. Count and corrected Net Profit must then match MT5.

| sleeve | stream/report trades | corrected stream/report net | result |
|---|---:|---:|---|
| `10118/NDX` | 714 / 716 | `$36,702.11` / `$35,545.14` | FAIL |
| `10916/GDAXI` | 611 / 611 | `$75,181.67` / `$75,181.80` | PASS |
| `10546/XAUUSD` | 1,708 / 1,762 | `$96,685.15` / `$143,387.49` | FAIL |
| `10569/EURUSD` | 341 / 341 | `-$27,030.02` / `-$27,029.81` | PASS, but PF `0.82` |
| `10706/GBPUSD` | 364 / 367 | `$54,021.68` / `$65,214.23` | FAIL |

Therefore density workstream A and decorrelation workstream B are invalid for
book decisions. The measured correlations can describe the available samples,
but they do not authorize adding a sleeve.

## New strategy research

`strategy-seeds/cards/tokyo-fix-5m_card.md` is a lint-clean DRAFT extracted from
the complete approved Ito/Yamada paper. It tests the exact long USDJPY
09:50-09:55 JST and short 09:55-10:00 JST cycle. The source reports a gross
average only and does not deduct transaction costs, so the card is explicitly
high-risk and cost-critical. It needs CEO + Quality-Business review, CEO + CTO
EA-ID allocation, and decisions for the stop, spread ceiling, deviation, and
holiday source before any build.

## Claude handoff prompt

```text
Workstream C: repair FTMO evidence integrity, then build a Stage-2 joint-equity
simulator. Do not edit T_Live, AutoTrading, FTMO presets, challenge set files,
the deploy manifest, or live accounts. Do not execute manifest delta cc61645c0.
Factory remains OFF; any MT5 use must be an explicitly targeted run on T8-T10
after confirming those terminals are idle.

1. Start from these artifacts and treat them as blocking gates:
   - artifacts/ftmo_stream_reconciliation_2026-07-10.json
   - artifacts/ftmo_qualification_freshness_2026-07-10.json
   - artifacts/ftmo_qualification_proposed_sleeves_2026-07-10.json
   - docs/ops/evidence/Q08_ROUND_TRIP_COMMISSION_HANDOFF_2026-07-10.md

2. Root-cause and fix the evidence mismatch for 10118/NDX (714 vs 716),
   10546/XAUUSD (1708 vs 1762), and 10706/GBPUSD (364 vs 367). Determine whether
   the cause is partial closes, scale-in/out, unclosed positions, event loss,
   wrong stream provenance, or report pairing. Do not patch the numbers. Produce
   report-linked baseline streams with exact trade/deal allocation and hashes.
   Every input must PASS ftmo_stream_reconciliation.py before simulation.

3. Correct the B premise: 10569/EURUSD is MT5 PF 0.82, Net -$27,029.81. Exclude
   it from candidate books. Re-evaluate 10706 only after its stream reconciles.
   Mark all prior A/B probability outputs superseded.

4. Audit Stage-2 data availability before implementation. We need a synchronized
   portfolio equity trace, not summed lifetime trade MAEs. Prefer tick-aligned or
   M1 equity snapshots per sleeve with balance, floating P/L, commission, swap,
   position state, symbol, EA, binary hash, setfile hash, model, and UTC timestamp.
   If existing logs cannot provide this, write the CTO/Quality-Tech emitter spec
   and a fixture first; do not manufacture per-bar paths from entry/exit/MAE.

5. Implement a read-only Stage-2 simulator only after reconciled data exists.
   Model the FTMO 2-Step $100k rules exactly:
   - Phase 1 target $110k; Verification target $105k on a fresh account.
   - At least four CE(S)T trading days with a new position opened.
   - Daily equity floor = balance recorded at 00:00 CE(S)T minus $5,000.
   - Static total equity floor = $90,000.
   - Equity includes closed P/L, floating P/L, swaps, and both commission sides.
   - Target counts only when all positions are closed.
   - Correct Europe/Prague DST and overnight reset behavior.
   Preserve the joint timestamp vector across sleeves when bootstrapping; never
   bootstrap sleeves independently. Label M1 results non-exact for within-bar
   excursions unless a conservative tick/high-low bound is included.

6. Required tests: spring/fall DST, midnight open position, profitable and losing
   midnight balance, sequential same-day losses, floating loss plus commission,
   static max-loss breach, four-day minimum, flat-at-target, Phase-2 reset,
   deterministic seeds, missing timestamp/data fail-closed, and stream/report
   provenance mismatch fail-closed.

7. Compare only reconciled scenarios: current base, density delta, and each valid
   FX addition. Report pass/breach rates with bootstrap confidence intervals,
   median and p90 calendar time, sample window, costs, stale/missing sleeves, and
   sensitivity to snapshot resolution. No deployment recommendation unless every
   included sleeve also passes the strict Q02-Q10 qualification contract.

Deliver code, focused tests, machine-readable artifacts, and a short evidence
document. A valid outcome may be NO-GO or DATA_INSUFFICIENT.
```

## Evidence

- `D:\QM\reports\ftmo_qualification\20260710\10375_q02_current\QM5_10375\20260710_180450\summary.json`
- `D:\QM\reports\work_items\74a089c5-194d-466f-ba0f-0536fdf32641\QM5_12969\Q08\USDJPY_DWX\aggregate.json`
- `artifacts/ftmo_qualification_freshness_2026-07-10.json`
- `artifacts/ftmo_qualification_proposed_sleeves_2026-07-10.json`
- `artifacts/ftmo_stream_reconciliation_2026-07-10.json`
- FTMO 2-Step objectives and loss rules:
  `https://ftmo.com/en/trading-objectives/`
- FTMO daily-limit reset explanation:
  `https://academy.ftmo.com/lesson/maximum-daily-loss/`

## Codex-only continuation

Claude is no longer part of the FTMO workstream. The current installed Round25
book has been evaluated by the combined readiness gate: 12 sleeves, `0` strict
qualification passes, `2` stream-reconciliation passes, and `0` sleeves passing
both. Status is `NO_GO`.

Codex implemented the Stage-2 rule engine and capture contract. Future MT5
execution is limited to T1-T5 and starts only after the ownership-controlled
kill-switch magic, commission allocation, tester-end, and joint-equity capture
repairs are available. See
`docs/ops/evidence/FTMO_BOOK_REBUILD_STATUS_2026-07-10.md`.
