# Governed Q02 stale-EX5 rebind

Date: 2026-09-07

Router task: `f9235fb0-7f92-4cc2-96f3-7299306ba669`

Requested disposition: `REVIEW`

## Result

`farmctl rebind-q02` now provides the missing append-only control-plane path.
It is read-only by default and also accepts an explicit `--dry-run`; production
mutation requires `--apply`. An eligible apply:

- authenticates an unclaimed Q02/P2 pending row or terminal `INFRA_FAIL` row;
- proves that EA, logical symbol, host timeframe, and canonical setfile bytes
  are unchanged;
- proves the operator SHA equals the one canonical EX5 and a `done / COMPILE_OK`
  work item whose payload and compile-evidence record both say compile PASS and
  build-check PASS;
- also binds that compile record to the current MQ5 bytes;
- appends one pending successor with the new EX5/MQ5 identity;
- leaves the predecessor status and verdict untouched, records
  `work_item_supersedes`, and writes a hashable JSON receipt; and
- rejects repeats, existing supersessions, open siblings, ambiguous artifacts,
  unrecorded/changed setfiles, free-floating hashes, and incomplete compile
  provenance.

The supersession sidecar is the existing claim boundary: a pending predecessor
remains immutable but is no longer claimable, including by a resident stale
selector because the database trigger blocks activation. A terminal predecessor
likewise remains retained as evidence.

## Required 13-row dry run

Each row was invoked through the canonical controller with this form (the exact
canonical EX5 SHA was calculated before each invocation):

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py rebind-q02 \
  --old-work-item-id <uuid> \
  --expected-current-ex5-sha256 <sha256> \
  --reason "CEO-reviewed stale EX5 binding repair; dry-run only 2026-09-07" \
  --dry-run
```

Output: **0/13 eligible, 0 applied**.

| Source row | EA | State at invocation | Dry-run output |
|---|---|---|---|
| `7ff04187` | QM5_21524 | pending | `source_setfile_sha256_missing` |
| `8322d8c7` | QM5_33007 | pending | `source_setfile_changed` |
| `256846e2` | QM5_20096 | pending | `source_already_superseded` -> `41a774ad` |
| `7dd70134` | QM5_10717 | pending | `source_already_superseded` (retired without successor) |
| `00cf2ac1` | QM5_41359 | pending | `source_setfile_changed` |
| `8f4c4610` | QM5_41360 | pending | `source_setfile_changed` |
| `ecc8e269` | QM5_41361 | pending | `source_setfile_changed` |
| `a126c45e` | QM5_41362 | pending | `source_setfile_changed` |
| `de8e719f` | QM5_41165 | failed / INFRA_FAIL | `source_setfile_changed` |
| `fc8770b5` | QM5_41172 | failed / INFRA_FAIL | `source_setfile_changed` |
| `92ee9327` | QM5_41176 | failed / INFRA_FAIL | `source_setfile_changed` |
| `aa2484aa` | QM5_41312 | failed / INFRA_FAIL | `source_setfile_changed` |
| `4b6ed242` | QM5_41336 | failed / INFRA_FAIL | `source_setfile_changed` |

The normalized command output, including every full EX5/setfile digest, is in
`cohort_dry_run_summary.json`. The production database had zero rows carrying
`q02_stale_binding_rebind=true` and zero supersession records with source
encoding `farmctl:rebind-q02/v1` after the run.

This is material new evidence: the supplied cohort is not an EX5-only stale
binding cohort at current state. Ten rows bind old setfile bytes which differ
from the current canonical files, one has no recorded setfile digest, and two
were already superseded before this audit. The command therefore correctly
refuses all 13. The CEO must not apply this rebind path to these rows; any future
repair that changes setfile bytes needs a separately governed requalification,
not an EX5-only rebinding assertion.

## Verification

- `python -m pytest -q tools/strategy_farm/tests/test_q02_stale_binding_rebind.py tools/strategy_farm/tests/test_pending_superseded_claim_filter.py tools/strategy_farm/tests/test_first_q02_intake.py`: 26 passed.
- Pending predecessor fixture: dry-run makes no write; apply preserves its
  verdict, appends one successor, records supersession, writes a receipt, and
  excludes only the predecessor from the claim selector.
- Terminal predecessor fixture: `failed / INFRA_FAIL` remains unchanged and is
  linked to the pending successor.
- Operator EX5 mismatch and post-intake setfile byte change: both fail closed.
- `python -m py_compile tools/strategy_farm/farmctl.py`: PASS.
- Scoped `git diff --check`: PASS.

No production work item, verdict, supersession, terminal, worker, scheduler,
registry, AutoTrading setting, or `T_Live` state was changed.
