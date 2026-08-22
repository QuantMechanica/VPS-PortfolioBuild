# OWNER-DEC-CALENDAR-REPIN: refresh-bound receipt chain

Date: 2026-08-22  
Router task: `689b3af1-05ae-42b7-b75e-bc3c7c8622a9`  
Authority: `OWNER-DEC-CALENDAR-REPIN`,
`decisions/2026-08-22_owner_decisions_evening_batch.md` section 8  
Disposition: implementation complete; leave in `REVIEW`

## Decision boundary

OWNER approved Option (a): the regular daily news-calendar refresh must keep
the exact byte-hash dependency binding current and must issue a separately
auditable chained receipt for every pin transition. Option (b), replacing the
byte hash with a coverage/freshness-only check, was not approved.

This change does not alter a gate threshold, a calendar policy, a stale-news
limit, a verdict, or a trade stream. In particular, `stale_max_hours` remains
`336` and stale news remains fail closed. The live refresh exercised below
still emitted its existing `STALE` warning; the repin did not suppress it.

## Before

The four acceptance nodes were red against the live published calendars:

```text
FFFF
test_dxz23_registry_is_source_bound_and_structurally_clean
test_density_execution_contracts_are_source_and_runtime_binding_clean
test_20009_ftmo_news_calendar_is_exact_and_evidence_bound
test_20009_ftmo_news_calendar_expires_fail_closed
4 failed in 23.48s
```

The registry still bound the 2026-07-30 generation:

| Published file | Old SHA-256 | Old rows | Old coverage end |
|---|---:|---:|---:|
| `news_calendar_2015_2025.csv` | `16d95a7ca00de57accbb2bf7ad63418873c7c1afbffd58b8ec35136abb057ece` | 48,150 | 2026-07-31 |
| `forex_factory_calendar_clean.csv` | `e54a18bc317657260edb01a57eb29e97d7c1e3c451a2befc60dbc636d9286338` | 48,159 | 2026-07-31 |

Both exact old artifacts were reconstructible in the committed bundle archive
under `D:/QM/data/news_calendar/.news_calendar_bundles/`.

The live, already-published pair was:

| Published file | Live SHA-256 | Live rows | Live coverage |
|---|---:|---:|---:|
| `news_calendar_2015_2025.csv` | `42b02ae062271b643a9039410617a4c246ebed62c9a77db2e8b610fee6ce82bc` | 48,435 | 2015-01-01 through 2026-08-21 |
| `forex_factory_calendar_clean.csv` | `a0418087ea4f0cf2bc0aa7e5858b2e9dda56337995bf96e7e64e5d20f8356017` | 48,444 | 2015-01-01 through 2026-08-21 |

## Implementation

`tools/strategy_farm/news_calendar_repin.py` supplies two deliberately
different interfaces:

- `verify` is public and read-only. It validates receipt filenames and
  sequence continuity, every embedded canonical SHA-256 signature, every
  previous-receipt link, per-calendar state continuity, the current live
  bytes, and the current registry tail.
- `record` is internal to `refresh_news_calendar.ps1`. It requires the refresh
  parent PID and operation ID, a committed publication receipt and journal,
  exact scheduled-refresh-script provenance, an exact source-bundle match for
  both published files, and successful principal preflights. Calling it as a
  standalone CLI without the refresh-parent proof is refused.

The regular refresh calls `record` only after `multi-publish` has returned a
committed, receipted publication. The mutator holds its own create-only lock,
creates its receipt with `O_EXCL` and `fsync`, and atomically replaces the
registry only after a surgical JSON render. The render performs a structural
before/after diff and permits only `sha256`, `coverage_start`, and
`coverage_end` leaves belonging to the two published calendar filenames.

Plausibility is checked separately for both files. Empty data, a shrinking row
count, coverage-start loss, or a regressing coverage end refuses the repin
before either the registry or receipt chain is advanced.

Receipts use the repository's tamper-evident receipt convention: a canonical
JSON SHA-256 embedded in each receipt plus the preceding receipt SHA-256. The
signer block also binds the exact refresh script bytes and the OWNER decision.
Schema v2 binds the complete published pair; the verifier retains v1 support
for the first primary-only transition and verifies the v1-to-v2 continuation.

## Live refresh and receipt chain

The bootstrap used the normal publisher with an empty JSON feed. This added no
events; it republished the already-validated pair and exercised the same
publication journal, bundle, Common-copy preflights, and post-publication hook
used by the scheduled task. No terminal, `T_Live`, or AutoTrading state was
touched.

The resulting append-only chain is:

| Seq. | Schema | Refresh operation ID | Receipt SHA-256 | Previous SHA-256 | Pin change |
|---:|---|---|---|---|---|
| 1 | `qm.news-calendar-repin-receipt/v1` | `0420333cddecdc8c39e818eedd83dd19b90bbe6658a7e4d750db64ed94998c35` | `43fcd3de0813740ff63082a84a215d18aa9d1f7e68853d7cf3b77df0d43f05e5` | genesis | primary |
| 2 | `qm.news-calendar-repin-receipt/v2` | `09966712d563420b5fb92b56cb4900f3d043a638b7a9da7a8eb1a947d348b737` | `c3bab0bb0a683f582472fcfd7b9677ec833a85002edf0899a17b7ce212588ed0` | `43fcd3de0813740ff63082a84a215d18aa9d1f7e68853d7cf3b77df0d43f05e5` | secondary plus full-pair binding |

Receipt directory:
`D:/QM/reports/news_calendar/repin_receipts/`.

Read-only verification after the live transition:

```text
status=PASS
schema_version=qm.news-calendar-repin-receipt/v2
receipt_count=2
registry_pin_matches=true
registry_target_count=19
primary rows=48435 sha256=42b02ae062271b643a9039410617a4c246ebed62c9a77db2e8b610fee6ce82bc
secondary rows=48444 sha256=a0418087ea4f0cf2bc0aa7e5858b2e9dda56337995bf96e7e64e5d20f8356017
coverage=2015-01-01..2026-08-21
```

The registry comparison against `HEAD` has exactly 38 changed JSON leaves:
19 `sha256` leaves and 19 `coverage_end` leaves. `coverage_start` was already
correct. All 38 are calendar identity fields; policy/threshold diff count is
zero. The 19 targets comprise 11 primary and 8 secondary dependency records.

## Tests

The receipt tests exercise two transitions, idempotency, standalone-record
refusal, registry drift, an edited receipt, a missing receipt, row shrinkage,
and coverage recession:

```text
python -m pytest tools/strategy_farm/tests/test_news_calendar_repin.py -q --tb=short
......                                                                   [100%]
6 passed in 1.84s
```

The scheduled-refresh integration verifies publication ordering, both source
files, the Common copy, automatic repin, chain verification, and no new
receipt on an unchanged second run:

```text
python -m pytest tools/strategy_farm/tests/test_refresh_news_calendar.py -q --tb=short
........                                                                 [100%]
8 passed in 47.22s
```

The four formerly red nodes now pass without skip, xfail, removing the hash
check, or weakening an assertion. Current-byte expectations were advanced to
the receipted exact hashes; the expiry test's fixed `as_of` date was moved past
the newly extended coverage so it continues to prove fail-closed expiry.

```text
....                                                                     [100%]
4 passed in 20.01s
```

The complete execution-contract lint test file is green:

```text
python -m pytest tools/strategy_farm/tests/test_execution_contract_lint.py -q --tb=short
.......................................................                  [100%]
55 passed in 129.47s (0:02:09)
```

One combined run overlapped a real Factory mutation lease and therefore had
five expected harness refusals (`64 passed, 5 failed`); the lease released on
its own and the isolated refresh suite then passed 8/8. No lock was deleted and
no active run was interrupted. `git diff --check`, Python byte compilation,
and the Windows PowerShell ASCII/parser tests also passed. `ruff` was not
installed in the canonical Python environment.

## Result

The scheduled refresh now advances exact byte provenance instead of creating
a permanent false red. A missing, reordered, edited, implausible, unpublished,
or registry-divergent continuation is refused or detected. The byte-hash gate
and every existing fail-closed policy remain in force.
