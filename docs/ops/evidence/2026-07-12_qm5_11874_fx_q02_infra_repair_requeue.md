# QM5_11874 JPY-cross Q02 infrastructure recovery and re-enqueue

## Outcome

`QM5_11874_usdjpy-24hr-range-breakout` has a fresh framework-linked binary and
is re-enqueued at Q02 on its three approved forex instruments: `AUDJPY.DWX`,
`GBPJPY.DWX`, and `USDJPY.DWX`. Canonical Q02 task
`fc01f8ec-3f59-4531-92fc-314a43a7b39d` owns three pending work items with zero
attempts and no skips.

This is one diversity/throughput recovery, not a new build. The approved rates
and lumber cards were not faithfully executable because their required series
are absent from the DWX matrix. Several apparent FX infrastructure candidates
were also false diversity caused by legacy fanout beyond their card-authorized
index universes. This EA is price-only, structural, registered on three actual
JPY crosses, and had no Q02 business verdict or downstream phase.

## Diagnosis

All historical Q02 attempts ended as infrastructure failures with
`summary_missing_retries_exhausted`. They produced no usable tester summary,
strategy verdict, or evidence that could justify retirement. The retained
`.ex5` and setfile build hashes dated from June 20 and predated the current V5
framework state.

The original build task (`a7dedc7d-2be2-4f65-8e42-672b99f3f800`) also retained
an obsolete static-check failure for bounded `iTime`/`iHigh`/`iLow` reads. The
current source already carries the required `perf-allowed` annotations for its
single daily 24-bar range scan. A current strict build therefore passes; no
strategy-rule change was needed or authorized.

## Repair

The approved MQ5 was recompiled unchanged against the current framework. This
produced a new EX5 and refreshed the canonical build hash in each backtest
setfile. All three setfiles retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the
registered slots AUDJPY=2, GBPJPY=1, USDJPY=0.

Current hashes:

- MQ5: `54E2BC4A04B32211E4023418C1CF0F28497D62C480DB2FBBAAAF06794A151462`
- EX5: `364F62887AB6BE12CF8608C80517D909B7B508CB69DAB59EBB8254E7DE041C2E`

## Verification

- SPEC validation: PASS
- strict build/compile: PASS, 0 errors and 0 warnings
  (`D:\QM\reports\framework\21\build_check_20260712_023920.json`)
- dedicated Model-4 smoke: PASS, deterministic, no OnInit failure, valid report
  (`D:\QM\reports\smoke\QM5_11874\20260712_024013\summary.json`)

The single bounded smoke used `AUDJPY.DWX`, H1, 2024. Both determinism runs
reported 183 trades, PF 0.87, net profit -17,151.23, and 24.58% drawdown. Those
weak economics are preserved honestly: the smoke only proves initialization,
report production, determinism, and trade generation. The 2017-2022 Q02 rows
remain responsible for the strategy verdict.

## Q02 handoff

| Symbol | Work item | State |
|---|---|---|
| AUDJPY.DWX | `3696e47e-c0c8-403d-a9f8-d7ad0d7d3fad` | pending |
| GBPJPY.DWX | `9ab6782c-2f94-4007-90e8-e14b900c5364` | pending |
| USDJPY.DWX | `93b8629f-b209-4fdc-96c1-5370215fda2e` | pending |

Farm coordination used lease
`manual:codex:agents/board-advisor:QM5_11874:q02_infra_recovery`. The pre-enqueue
backup is
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11874_q02_enqueue_20260712T024519Z.sqlite`.

`FACTORY_OFF.flag` remained asserted, so the enqueue did not dispatch Q02.
The bounded T6 tester smoke exited and released its slot. No T_Live file or
process, AutoTrading setting, portfolio gate, or T_Live manifest was touched;
the CPU ceiling was not reached.
