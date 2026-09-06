# Q08 DSR single-configuration identity adversarial review

- Router task: `4bf2eb39-b201-4ff9-9a1d-080ba70f44e9`
- Parent execution task: `8fe2bac0`
- Reviewed fix: `866e3f2d78`
- Review branch: `agents/board-advisor`
- Review started: `2026-09-06T23:16:55Z`
- Scope: identity normalization only. No Q08 threshold, fail-closed policy,
  stored verdict, T_Live, AutoTrading, or terminal process was changed.

## Result

The observed `QM5_11167` versus integer `11167` mismatch is corrected. The
review also hardened the initial helper: it now accepts only a positive numeric
EA identity, with an optional `QM5_` prefix and optional well-formed label
suffix, rather than truncating arbitrary input at the first underscore.
`farmctl` and `dsr_v2` now use this one helper for the Q08 numeric CLI boundary
and the sealed-context comparison. `dsr_cohort` already imports the same module
for single-configuration declaration/identity validation and preserves the
human-readable `QM5_<id>` candidate in the seal.

Static/code verdict: **PASS**. Runtime acceptance remains dependent on the two
append-only Q08 reruns reaching a terminal result; their observations are
recorded below without inferring a pipeline verdict.

## Adversarial identity matrix

| Candidate/argument | Expected | Verified |
|---|---:|---:|
| `QM5_11167` / `11167` | same EA | yes |
| `qm5_11167` / integer `11167` | same EA | yes |
| `QM5_11167` / `QM5_111670` | different EA | yes, unequal |
| `QM5_11167` / `QM5_11168` | different EA | yes, unequal |
| `QM5_41372_XTI_XNG` | sibling/directory label for 41372 | yes, `41372` |
| `QM5_11167__OTHER` | malformed alias | yes, refused |
| `QM5_11167/OTHER` | path-shaped alias | yes, refused |
| `prefix-QM5_11167` | embedded identity | yes, refused |
| boolean, empty, missing, or leading-zero ID | invalid identity | yes, refused |

This prevents a different numeric EA such as `111670` from matching `11167`.
Suffix-bearing labels collapse only when their numeric registry identity is the
same.

## End-to-end identity trace

1. `terminal_worker._seal_q08_dsr_at_claim()` invokes `dsr_cohort.attach()`
   after the immutable claim time is present.
2. `dsr_cohort.assemble_single_configuration()` obtains the candidate EA and
   symbol directly from the claimed work-item row and the timeframe from the
   payload (`expected_period` first). It validates the exact candidate triple
   against the hash-bound approved-card declaration before sealing.
3. The content-addressed context retains the label form (`QM5_11167` or
   `QM5_11196`).
4. `farmctl._phase_runner_cmd_for_work_item()` now calls the shared strict
   `canonical_ea_id()` and supplies the numeric value to `aggregate.py`.
5. `aggregate.py` parses `--ea-id` as an integer and passes that integer plus
   the unsanitized symbol to `dsr_v2.evaluate()`.
6. `dsr_v2.selection_context()` calls
   `dsr_single_configuration.validate_context()`, which compares the EA via the
   shared canonical helper and the symbol exactly, then revalidates the sealed
   candidate against the hash-bound card, SPEC, source, binary, and setfile.

The CLI-boundary regression invokes `aggregate.main()` with `--ea-id 42`
against a sealed candidate carrying `QM5_42`; the real DSR evaluator returns
PASS rather than `SINGLE_CONFIG_CANDIDATE_MISMATCH`.

## Symbol and timeframe audit

- The work-item, producer seal, and aggregator CLI all carry `XAUUSD.DWX`.
  `XAUUSD_DWX` is used only for filesystem directory names. Passing that
  sanitized form as the DSR symbol is refused with
  `SINGLE_CONFIG_CANDIDATE_MISMATCH`.
- The reviewed live contexts carry `D1` for 11167 and `H4` for 11196, matching
  their `expected_period`, setfile name, and approved-card declaration.
- The MT5 enum value `16408` is not silently treated as `D1` by this identity
  boundary. A context candidate changed from declared `D1` to `16408` is
  refused by the exact declaration comparison. This is fail closed and avoids
  grading a differently represented timeframe without an explicit producer
  contract.

## Live evidence observed

At `2026-09-06T23:25:44Z`:

- `9ec3b856-2040-4870-9f36-797ccb122102` (11196/XAUUSD) was active on T1. Its
  claim-time seal is
  `412daaf831c0196f1062d3519971480dcbd43cf0480935a5a151b06817b75c0d`,
  candidate `QM5_11196 / XAUUSD.DWX / H4`. A read-only call through
  `dsr_v2.selection_context(... ea_id=11196 ...)` validated it.
- `89ea5894-2ce5-4c11-80db-a841baef9e7b` (fourth 11167/XAUUSD rerun) was active
  on T4. Its claim-time seal is
  `870da66b68163c161f350ee73295ea7d68d7bf2e908a69099e3a2b50daad0f6c`,
  candidate `QM5_11167 / XAUUSD.DWX / D1`. A read-only call through
  `dsr_v2.selection_context(... ea_id=11167 ...)` validated it.

Neither row had produced a terminal pipeline verdict at that observation time.
Their final rows and sub-gate 8.2 details must be appended here before claiming
runtime acceptance.

At `2026-09-06T23:28:33Z`, a read-only evaluator replay supplied each live
claim-time seal to `dsr_v2.evaluate()` with the durable, commission-adjusted
trade stream used by Q08:

| EA | Stream SHA256 | Rows | 8.2 status | Detail | `dsr_p` |
|---:|---|---:|---|---|---:|
| 11167 | `c125f885a46f3aa0eeaa36341a8a7b19550a46121509d78512db5c86f9538924` | 311 | PASS | `DSR_V2_COMPUTED` | 0.0008545592805113056 |
| 11196 | `a840d12fe6c9517e3be79528e880c122f3b3f14a5e3dcb98f93945e4e45c8b4f` | 656 | PASS | `DSR_V2_COMPUTED` | 0.0055112447577358985 |

The 11196 stream was written at `22:51:08Z` by the active rerun after its
replacement-set baseline completed; the baseline summary binds H4, the
replacement set SHA `7cc424d2...f6b`, and the expected EX5/MQ5 hashes. The
11167 stream is the prior deterministic run of the same hash-bound set/source/
binary and was evaluated against the fourth rerun's fresh claim-time seal.
These replays confirm that sub-gate 8.2 computes rather than returning INVALID,
but they are diagnostic evidence only: final pipeline verdicts still come from
the active pipeline processes.

## Verification

Command:

```text
python -m pytest tools/strategy_farm/tests/test_dsr_single_configuration.py tools/strategy_farm/tests/test_dsr_v2.py tools/strategy_farm/tests/test_farmctl_cascade.py -q
```

Result:

```text
120 passed, 13 subtests passed in 163.33s
```

`git diff --check` also passed for the four code/test paths. The test set covers
the numeric CLI boundary, distinct numeric IDs, sibling labels, malformed
aliases, exact symbol behavior, and fail-closed timeframe drift.
