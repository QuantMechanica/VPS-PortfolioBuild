# QM5_12455 EURUSD Q02 Infrastructure Repair And Requeue

## Outcome

`QM5_12455_ea31337-pinbar` has a current-template, strict-clean binary and one
append-only `EURUSD.DWX` H1 Q02 recovery row. The original terminal evidence is
preserved; new work item `07eb49bd-5e8f-4947-be75-2e1e5adc36c2` was pending at
verification. Farm coordination claim:
`556a82bf-9b54-46e5-bf77-b514adf0ad55`.

This is a funnel-throughput repair, not a profitability or certification
claim. Q02 owns the next economic verdict.

## Selection And Diversity Value

- The approved build backlog had no genuinely unbuilt, unclaimed diverse card;
  candidates were already built, claimed, active, or represented by later
  phase evidence.
- This EA is a structural H1 spinning-top reversal sleeve on liquid FX. Its
  durable SPEC binds source ID `041e0d5c-bf76-501d-bee2-31c0f4a6e233` to the
  public EA31337 `Strategy-Pinbar` GitHub implementation and records R1-R4
  approval.
- The identical historical EX5
  `a7c19b72269503ad10ff3a55aed3ddc5fa4aabcbdc59bec6b89d522a2895b0f1`
  passed Q02 on GBPUSD, USDJPY, and XAUUSD. GBPUSD then reached Q04
  `PASS_SOFT` (`d30ee319-a0e8-4967-a592-ba3edc9d3ff3`). It later failed Q05,
  so this EURUSD recovery is deliberately limited to one Q02 canary.
- EURUSD is an active registered carrier: magic slot 0, magic `124550000`.

## Diagnosis

Preserved source work item `2cb70bd8-ebaa-4470-80ad-3f541a578344` is Q02
`INFRA_FAIL`. Its bound summary is:

`D:/QM/reports/work_items/2cb70bd8-ebaa-4470-80ad-3f541a578344/QM5_12455/20260728_164622/summary.json`

Summary SHA-256:
`578582e8cc0284d0bf85d9bb45e19b3ec2176a72b8361d426ff98c73a07a54a5`.

The wrapper classified the run as `ONINIT_FAILED`, but the report identity
findings were `BARS_ZERO`, `NO_HISTORY_LOG`, `HISTORY_CONTEXT_INVALID`, an
M0/1970 period, and empty expert/symbol fields. Because the same binary
initialized successfully on three sibling carriers, the retained EURUSD
verdict is invalid history-context evidence rather than a strategy verdict.

The current strict static preflight exposed one separate compatibility defect:
the older source lacked the explicit `QM_FrameworkTrackOpenPositionMae()` hook
required by the current framework contract. The two bespoke one-candle
`CopyRates` calls also needed same-line `perf-allowed` annotations for the
static gate to recognize their bounded use.

## Repair And Build Evidence

The source now:

- samples framework-managed open-position MAE before any per-tick early return;
- retains the strategy logic and parameters unchanged; and
- documents the two bounded structural candle reads for the performance gate.

The standard strict build refreshed deterministic build-hash headers in all
package setfiles and compiled the EA with zero errors and zero warnings.

| Check | Result |
|---|---|
| Strict build check | PASS, 0 failures, 0 warnings |
| Compile | PASS, 0 errors, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260821_184450.json` |
| Build-check report SHA-256 | `8a11268d68629903319838b63737158232f0dc669d4930d3111156ef4963a2c6` |
| Compile log | `C:/QM/repo/framework/build/compile/20260821_184450/QM5_12455_ea31337-pinbar.compile.log` |
| Compile log SHA-256 | `ec10313fd3381157d8de22ea267d3c31785c54eb49b1b5238065437340f68e99` |
| MQ5 SHA-256 | `373c949a9f3c0759f82dd4087fdad584b74bbd6cf5c09fa0b56c1a64324b04a4` |
| EX5 SHA-256 | `87e3a1ccf8e1ab59ec3acd2d6388e55e8f8c89acccc3ec6c37c91b73ce759c53` |
| EURUSD set SHA-256 | `7fe5aadbd808e3aab232788f7e856a289d52e9f9702fca690ea75093d2649642` |

The EURUSD backtest set remains H1, slot 0, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Append-Only Q02 Handoff

`farmctl enqueue-backtest` authenticated the current EX5 hash and created only
work item `07eb49bd-5e8f-4947-be75-2e1e5adc36c2`. Its payload binds the current
MQ5, EX5, and set hashes above, records
`append_only_rerun_of_work_item=2cb70bd8-ebaa-4470-80ad-3f541a578344`, and keeps
the historical row terminal and unchanged.

The row also carries active custom-history admission for exactly
`EURUSD.DWX`: 108 archive rows, activation SHA-256
`61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`,
and manifest SHA-256
`fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`.
That directly addresses the invalid old shared-history context without
altering strategy mechanics.

## Capacity And Safety Boundary

Immediately before enqueue, the farm had five active work items and three
running factory terminals (`T1`, `T2`, `T4`), below the seven-job backtest CPU
ceiling. No manual smoke or dispatch tick was launched; the paced worker owns
the queued canary.

No `T_Live` file or process, AutoTrading state, portfolio gate, or live manifest
was changed.
