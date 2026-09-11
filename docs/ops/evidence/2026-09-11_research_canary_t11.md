# T11 research_canary controller — build and guarded hand-back

Date: 2026-09-11
Router task: `8f6a6b3c-46a1-4ad9-a261-ba0a7fdb4ac8`

## Delivered controller

`tools/strategy_farm/research_canary.py` is a standalone, no-DB governed
controller. It accepts only T11 (T12 remains declared but disabled), creates a
unique artifact root below `D:/QM/reports/research/<program>/<run_id>/`, and
writes a receipt for every dry-run, refusal, or completed test.

Before a launch it requires all of the following:

- a read-only `farm_state.sqlite` count and identical before/after isolation
  snapshot; an absent `FACTORY_MUTATION.lock`; and T11 absent from the active
  custom-history `runner_terminals` list;
- an exact signed-manifest verification of every requested `.DWX` archive file
  in `T11/Bases/Custom`, using the existing private-identity verifier;
- five one-minute fleet-CPU samples at or below 90%, at least 20 GiB free RAM,
  and fewer than the caller-declared (1–4) MetaTester agents;
- an EX5 and setfile already staged under T11's permitted `MQL5` trees, with
  SHA-256 values recorded before launch.

The only actual terminal launch path is inside this component, using a hidden,
suspended `Popen` assigned to a kill-on-close Windows job before its primary
thread is resumed. It has a bounded timeout and refuses missing reports. It
does not invoke a worker, `run_smoke`, `custom_history_smoke_admission`, a
factory lock, or a state-DB mutation.

## Focused verification

```text
python -m pytest tools/strategy_farm/tests/test_research_canary.py -q
5 passed
python -m py_compile tools/strategy_farm/research_canary.py
PASS
```

The tests cover T11-only admission, unchanged before/after isolation, mutation
and activation refusals, resource refusal, and Model-4/shutdown INI rendering.

## S3 status: intentionally not launched

No terminal was started. Inspection found neither the required
`QM5_41398_balke-pattern-repair-opt` EX5 nor the `2021_s3_l3_x18` setfile
staged in T11's permitted paths. The matching fleet setfile is present under a
separate production terminal and the canonical WINSWEEP artifact, but copying
it into T11 outside the governed controller would violate the new component's
input-binding boundary. The requested controller must be reviewed before it is
used to stage/bind those inputs and run its five-minute guard.

Therefore there is no T11 S3 result, comparison table, report hash, or
identity claim. The active factory, T1–T10 backtests, T_Live, AutoTrading,
thresholds, gate contracts, and signed archive were untouched. This packet is
an implementation hand-back only and must remain REVIEW until the first
guarded S3 run produces receipts.

## S3 follow-up — hash-bound staging and real dry-run receipt

Router task: `f04d66ec-b296-4f2c-b5eb-83a8c2379626` (priority 90).

`research_canary.py --stage` now performs the authorized T11-only staging
operation. It accepts only a canonical-repository EX5 source, requires a
declared SHA-256 for both inputs, refuses a divergent existing destination,
and writes an append-only staging receipt. It can also run as the documented
direct CLI (the repository root is added for shared-verifier imports).

At 2026-09-11T01:19:40Z, it copied and hash-verified these exact inputs:

| Input | SHA-256 | T11 destination | Result |
|---|---|---|---|
| `QM5_41398_balke-pattern-repair-opt.ex5` | `68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01` | `D:/QM/mt5/T11/MQL5/Experts/QM5_41398_balke-pattern-repair-opt.ex5` | copied, 438,586 bytes |
| `QM5_41398_balke-pattern-repair-opt_USDJPY.DWX_H1_2021_s3_l3_x18.set` | `afa42711867677bd7d5641f93e52a104f31c86a181f835579241b214f35bf47c` | `D:/QM/mt5/T11/MQL5/Profiles/Tester/QM5_41398_balke-pattern-repair-opt_USDJPY.DWX_H1_2021_s3_l3_x18.set` | copied, 1,541 bytes |

Staging receipt: `D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/staging/20260911_011940_06fc048e_receipt.json`.

The real `--dry-run` receipt was written at
`D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_011946_c01dfb9a/receipt.json`.
It passed the 108-file signed private-history audit, captured unchanged
factory isolation before and after (146,955 work items; T11 absent from
T1–T10 activation), then refused before any terminal launch because the
MetaTester guard observed 5 agents, exceeding the task's hard limit of 4.
Its terminal state is `REFUSED`, not a smoke result. No T11 terminal or
T1–T10 job was started or interrupted.

Focused verification after the change:

```text
python -m pytest tools/strategy_farm/tests/test_research_canary.py -q
6 passed
python -m py_compile tools/strategy_farm/research_canary.py
PASS
```

**RESULT (Q-only):** Q-S3 remains REVIEW: inputs are staged and bound by
receipt, but the mandatory `<= 4` MetaTester guard refused the smoke cell;
there is consequently no S3 identity comparison or selection claim. Re-run
the direct CLI only when the guard admits it:

```text
python C:/QM/repo/tools/strategy_farm/research_canary.py --program WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025 --terminal T11 --expert QM5_41398_balke-pattern-repair-opt.ex5 --expert-path D:/QM/mt5/T11/MQL5/Experts/QM5_41398_balke-pattern-repair-opt.ex5 --setfile D:/QM/mt5/T11/MQL5/Profiles/Tester/QM5_41398_balke-pattern-repair-opt_USDJPY.DWX_H1_2021_s3_l3_x18.set --symbol USDJPY.DWX --period H1 --from-date 2021.01.01 --to-date 2021.12.31 --max-agents 4 --dry-run
```

## S3 rerun — T11-scoped agent guard and report-export refusal

Router task: `f04d66ec-b296-4f2c-b5eb-83a8c2379626` (continuation).

The previous guard incorrectly counted all fleet `metatester64.exe` processes.
`research_canary.py` now counts only executable paths under the target T11
root, records the selected PIDs/paths in the receipt, and permits the stated
`<= 4` T11 agents. Focused verification: `7 passed` from
`python -m pytest tools/strategy_farm/tests/test_research_canary.py -q`, plus
`python -m py_compile tools/strategy_farm/research_canary.py`.

The real dry-run receipt is
`D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_014940_80d83d4d/receipt.json`.
It recorded the hash-bound EX5 and setfile, a 108-file signed-private-history
PASS, zero T11-owned MetaTester processes, 35,034,267,648 bytes available RAM,
and CPU samples `66.6,64.7,50.6,52.6,64.4` (mean 59.78%, below 90%). The
factory independently advanced its own queue from 147,169 to 147,170 during
the observation; the receipt therefore truthfully marks
`isolation_unchanged: false`. The controller wrote no work-item row and did
not launch a terminal in dry-run mode.

The authorized non-dry T11 smoke was then attempted through that same
controller. Receipt:
`D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_015408_0d019d2e/receipt.json`.
Its T11 guards passed (zero T11-owned agents; 35,280,703,488 bytes RAM; CPU
mean 74.62%); the private-history audit again passed. `terminal64.exe` was
created suspended, bound to the kill-on-close job, and exited `0`. The T11
tester log independently records that the USDJPY.DWX H1 run completed in
2:26.285 with 28,993,517 ticks, but MT5 wrote no configured HTML report. The
controller correctly refused with `tester exited without report` and no
metrics/report hash were accepted. The log-only final balance and trade stream
are not a substitute for the required report/summary evidence.

Consequently, there is no valid S3 identity table, PASS, delta, tuning, or
selection claim. The next bounded repair is report-export capture in the
canary controller; it must preserve the T11-only path, hash bindings, factory
read-only boundary, and receipt contract before another smoke attempt.

**RESULT (Q-only):** Q-S3 remains REVIEW — T11-scoped guard and dry-run receipt
PASS; the actual 2021 S3 run is `REFUSED_NO_REPORT`, so fleet identity is
unproven. T1–T10 were not interrupted; T_Live and AutoTrading were untouched.

## S3 rerun — 2026-09-11T05:18Z

Router task: `f04d66ec-b296-4f2c-b5eb-83a8c2379626`.

The hash-bound T11-only controller was run again after its relative report
capture implementation. Receipt:
`D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_051851_052198d5/receipt.json`.
The signed private-history audit passed (108 files), the T11 agent count was
zero, RAM was 37,659,582,464 bytes, and the five CPU samples averaged 93.48%
(below the 95% controller limit). It launched only the suspended, job-bound
T11 process; `terminal64.exe` exited `0`.

No `research_canary_20260911_051851_052198d5.htm` was found under T11 or the
standard roaming terminal roots. The controller therefore recorded
`status=REFUSED`, `reason=tester exited without report`, and did not accept any
metrics. Factory isolation changed only because the independent factory
mutation lock appeared after admission; the controller wrote no work-item row.

**RESULT (Q-only):** Q-S3 is REVIEW. The real run and all safety/input guards
are evidenced, but report export is still absent; there is no identity table,
PASS, delta, tuning, selection, T1–T10 interruption, T_Live, or AutoTrading.

## S3 receipt-bound refusal and ceiling correction — 2026-09-11T06:40Z

Router task: `f04d66ec-b296-4f2c-b5eb-83a8c2379626`.

The controller now records an append-only `receipt.json` even when admission
refuses before the tester contract and resource sampling.  This closes an
evidence gap in which a present `FACTORY_MUTATION.lock` previously left a
created run directory with no receipt.  The T11 canary CPU ceiling is also
the task-authorized **90%** five-sample average (not the fleet's 95% general
admission ceiling).  Focused verification:

```text
python -m pytest tools/strategy_farm/tests/test_research_canary.py -q
11 passed
python -m py_compile tools/strategy_farm/research_canary.py
PASS
```

The first fresh dry-run receipt after the initial receipt repair was
`D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_063525_cb71a08b/receipt.json`.
It is `DRY_RUN_PASS`: the staged EX5 and setfile hash-bind to
`68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01` and
`afa42711867677bd7d5641f93e52a104f31c86a181f835579241b214f35bf47c`, the
108-file signed-history audit passed, T11-owned MetaTester count was zero,
RAM available was 37,383,778,304 bytes, and its CPU samples averaged 88.18%.
The independently operating factory changed `worker_pids.json` during that
observation, so `isolation_unchanged=false`; no terminal was launched.

After the 90% ceiling correction, the guarded retry produced the real refusal
receipt `D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/20260911_064005_f4d6664b/receipt.json`:
`status=REFUSED`, `reason=FACTORY_MUTATION.lock is present`, with matching
before/after isolation snapshots (147,181 work items; T11 absent from the
T1–T10 activation).  Thus the required safety receipt exists and no live
smoke was admissible.  A live run and fleet-cell identity table would be
unsafe to attempt while the factory mutation lock is live.

**RESULT (Q-only):** Q-S3 remains REVIEW — staging is hash-bound and the
controller has a receipt for both admission and refusal paths, but there is
no current lock-free, isolation-stable live smoke; therefore no report hash,
metric identity PASS, delta, tuning, or selection claim exists.  T1–T10,
T_Live, and AutoTrading were untouched.  When a future scheduled cycle finds
the lock absent, the sole permitted command surface is:

```text
python C:/QM/repo/tools/strategy_farm/research_canary.py --program WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025 --terminal T11 --expert QM5_41398_balke-pattern-repair-opt.ex5 --expert-path D:/QM/mt5/T11/MQL5/Experts/QM5_41398_balke-pattern-repair-opt.ex5 --setfile D:/QM/mt5/T11/MQL5/Profiles/Tester/QM5_41398_balke-pattern-repair-opt_USDJPY.DWX_H1_2021_s3_l3_x18.set --symbol USDJPY.DWX --period H1 --from-date 2021.01.01 --to-date 2021.12.31 --max-agents 4 --dry-run
```
