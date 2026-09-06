# DSR V2 cohort producer — REVIEW handoff

Date: 2026-09-06  
Router task: `da23a756-8883-454c-95be-fceb2c115339`  
Result: **REVIEW**  
Implementation branch: `agents/codex-dsr-cohort-producer-20260906`  
Implementation commit: `ab9e4396f3ad6312fa1b071cc981283059c25014`

## Outcome

The review branch adds the governed cohort producer requested after
`OWNER-DEC-DSR-V2-ACTIVATION-20260905`. New Q08 insert paths now attempt to
assemble and seal a loser-inclusive search cohort before the row is inserted.
When complete evidence exists, the payload receives exactly
`dsr_context {path, sha256}`. When it does not, the payload receives an
`UNAVAILABLE` producer status but **no `dsr_context`**, so active DSR V2 remains
`UNCORRECTED_SELECTION`. Existing Q08 rows and their payloads are untouched.

The implementation is not integrated or activated by this handoff. No pipeline
verdict, queue row, backtest, terminal process, live setting, or AutoTrading
state was changed.

## Cohort contract and provenance

`tools/strategy_farm/dsr_cohort.py` emits content-addressed immutable JSON under
`D:/QM/strategy_farm/artifacts/dsr_cohorts/`. The schema is
`qm.dsr-cohort/v1`; its JSON Schema is
`tools/strategy_farm/schemas/dsr_cohort_v1.schema.json`.

The producer authenticates and records:

- the matching DL-089 V3 census ledger and its sealed rule hash;
- the matrix-service Q12 selection receipt;
- the ledger-bound Q02 precondition/baseline;
- all distinct readable Q03 parameter configurations, deduplicated by sealed
  set-file hash;
- all 154 declared DL-089 pattern trials and every declared numeric trial;
- contiguous per-peer trial indexes, daily after-cost net-cash series hashes,
  daily Sharpe inputs, calendar-day counts, and summary/native-report hashes.

The producer refuses non-terminal ledgers, absent Q02/Q03 evidence, absent or
stale files, hash mismatches, missing matrix cells, pruned/unmeasured arms,
incomplete annual coverage, numeric-count mismatches, and zero/invalid cohort
dispersion. It never fills a missing trial with zero and never reduces the
declared count to the available survivors. Legacy programs without an
authenticated sealed count are therefore `UNAVAILABLE`; no count is inferred
from surviving database rows.

`framework/scripts/q08_davey/dsr_v2.py` accepts the new schema while retaining
the prior `qm.dsr-selection-context/v1` adapter. It independently re-hashes all
source and peer provenance, checks identity, trial IDs/indexes/roles/counts,
requires the 154-trial DL-089 declaration, recomputes cohort dispersion, and
uses the effective selection-plus-research trial count. A bad producer file
falls back to the existing fail-closed `UNCORRECTED_SELECTION` result.

## Q08 enqueue coverage

The pre-insert adapter is called by:

1. the ordinary pump cascade into Q08;
2. explicit new Q08 creation through `enqueue_cascade_backtest_for_ea`;
3. append-only Q08 reruns, including the stream-recovery service that delegates
   to the explicit cascade path.

The existing-row requeue branch does not call the adapter. This preserves the
append-only requirement and prevents historical payload rewriting.

## Read-only replay of three recent Q08 artifacts

Replay command:

```powershell
python tools/strategy_farm/dsr_cohort.py replay --limit 3 --out C:/QM/repo/docs/ops/evidence/2026-09-06_dsr_cohort_replay/replay.json
```

The command opened `farm_state.sqlite` with `mode=ro` and `query_only=ON`. It
did not update any row or artifact under `D:/QM/reports/work_items`.

| Q08 work item | EA / symbol | Stored verdict | Cohort result | V2 replay |
|---|---|---|---|---|
| `d7d32fef-0557-41c9-9a0d-965b89c527ee` | QM5_11172 / XAUUSD.DWX | FAIL_HARD | `SEALED_SEARCH_LEDGER_UNAVAILABLE` | UNCORRECTED_SELECTION |
| `b280892a-18ec-4375-841e-eb360aba5ee1` | QM5_11196 / XAUUSD.DWX | INVALID | `SEALED_SEARCH_LEDGER_UNAVAILABLE` | UNCORRECTED_SELECTION |
| `dad7d53e-7841-4525-b830-6c3a9cb97470` | QM5_10038 / XAUUSD.DWX | FAIL_HARD | `SEALED_SEARCH_LEDGER_UNAVAILABLE` | UNCORRECTED_SELECTION |

The machine-readable table is
`docs/ops/evidence/2026-09-06_dsr_cohort_replay/replay.json`. A separate
read-only probe of the terminal DL-089 program for QM5_11421/EURUSD.DWX refused
with `Q03_GOVERNED_SOURCE_UNAVAILABLE`; it did not substitute the available
census survivors.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_dsr_cohort.py tools/strategy_farm/tests/test_dsr_v2.py tools/strategy_farm/tests/test_q08_stream_rerun.py -q`
  — **48 passed**.
- `QM_ALLOW_NONCANONICAL=1 python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_q08_stream_rerun.py tools/strategy_farm/tests/test_advancement_centralization.py -q`
  — **87 passed, 13 subtests passed**, one pre-existing invalid-escape warning.
- Python bytecode compilation for `dsr_cohort.py`, `farmctl.py`, and
  `dsr_v2.py` — PASS.
- `git diff --check` — PASS.
- Cohort JSON Schema parse and `$id == qm.dsr-cohort/v1` — PASS.

No pipeline phase was run. This implementation and evidence remain in REVIEW
for Codex/OWNER integration review; they do not authorize movement to PIPELINE.
