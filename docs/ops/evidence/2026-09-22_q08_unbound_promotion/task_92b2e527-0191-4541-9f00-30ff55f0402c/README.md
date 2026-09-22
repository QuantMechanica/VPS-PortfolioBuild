# Q08 unbound-promotion identity closure

Router task: `92b2e527-0191-4541-9f00-30ff55f0402c`

## Outcome

The Q08 promotion/claim boundary now treats an absent artifact binding as
`BUILD_IDENTITY_UNBOUND`, not as artifact drift. A promoted legacy row with an
exact predecessor is rebound from that predecessor's verified four-part
identity or governed compile receipt before DSR validation; the typed MQ5,
EX5, setfile, include-closure, and optional build identity are persisted in the
same pending-to-active transaction. Any populated claim that disagrees with
the authenticated binding remains `BUILD_IDENTITY_MISMATCH` and is never
overwritten.

New Q08 source promotions already receive their typed execution identity from
the promotion-boundary correction in `dd631220ee`. This task additionally
changes a source-side binding refusal from a silent skipped insertion into a
pending row protected by the non-restart hold
`Q08_PROMOTION_BINDING_REFUSED`, making the refusal durable and reviewable.

Code commits on `agents/codex-orchestration-4`:

- `daf495f8126d78c0d10ebdaeb93a07d5ef7be7ac` — bind legacy promotion
  identity before claim, classify unbound identity, and park new source
  refusals.
- `3347d16eeea7a43b268f23cc90b4cc72da3c18ef` — make governed repair reruns
  idempotent and allow an isolated worktree to authenticate against an
  explicitly selected canonical repository root.

## Root cause and duration

Two Q08-producing paths copied payload metadata but did not populate the typed
artifact columns:

- the cascade promoter, introduced by
  `0797da411b66de4687fa738afe741e491e06dd1f` on 2026-05-17;
- the EA enqueue/requeue path, introduced by
  `53006d01b36f70b52f006be5f460f9cc83572ca3` on 2026-05-18.

The typed artifact-identity contract was added by
`8269d5937e9ab7f609abc3469dc993ccfd8fe590` on 2026-08-23, but those insertion
paths continued to omit MQ5, EX5, setfile, and include-closure columns. Thus
the enforceable unbound-promotion defect dates from that schema deployment;
the retained queue also contains older rows that acquired null columns during
migration. The earliest retained affected enqueue row was created on
2026-07-18, and the earliest retained affected cascade row on 2026-08-18.

At DSR precheck, the single-configuration resolver previously reached file
validation with empty expected hashes. The downstream validator could only
report a mismatch, conflating a missing authority with genuine byte drift.
The resolver now classifies missing claims before filesystem validation, while
conflicting or populated-but-different hashes preserve mismatch semantics.

## Pending identity census

The read-only census selects pending, unclaimed, verdict-free,
unsuperseded rows and tests all four required hashes. Counts are live queue
rows, not pipeline verdicts:

| Stored phase token | Pending | Any hash missing | All four missing |
|---|---:|---:|---:|
| OPT_CENSUS | 2,555 | 2,555 | 2,337 |
| Q02 | 344 | 344 | 268 |
| Q03 | 37 | 37 | 16 |
| Q04 | 142 | 142 | 139 |
| Q05 | 5 | 5 | 2 |
| Q06 | 1 | 1 | 1 |
| Q07 | 14 | 14 | 6 |
| Q08 | 51 | 51 | 29 |
| Q09 | 5 | 5 | 5 |
| Q09_NEWS | 6 | 6 | 0 |
| Q10_NEWS | 20 | 20 | 10 |
| Q12 | 48 | 48 | 0 |

Within Q08, 27 affected rows came from `pump_cascade`, 20 from
`farmctl_enqueue_backtest_ea`, and four have no promotion-source marker. The
47 rows with an exact `promoted_from_work_item` are the governed repair scope;
all 47 have an active hold. Exact selection, history, and counts are bound in
`pending_identity_census.json`.

## Governed dry-run and apply

The correctly rooted dry run evaluated 47 pending, unclaimed, unsuperseded
promoted Q08 rows and found zero safe rebindings:

| Refusal | Count |
|---|---:|
| Predecessor setfile identity mismatch | 22 |
| Current build compile provenance unavailable | 16 |
| Compile include closure unbound | 7 |
| Compile include closure not current | 1 |
| Current execution binding refused (EX5 drift) | 1 |

The apply ran under the factory mutation lock after creating a governed SQLite
backup. It installed zero bindings and overwrote zero holds: 45 candidates had
another active governed hold, and two already had
`Q08_PROMOTION_BINDING_REFUSED`. The final journal therefore records
`applied_count=0`, `held_count=0`, and `raced_count=47`; all 47 remain
non-claimable. It also attests zero terminal-row, verdict, or evidence-path
edits.

An initial repeat-apply exposed a duplicate transition-ledger key left by the
earlier task-scoped repair and rolled back without a journal. The idempotency
fix in `3347d16eee` makes an already-active typed refusal hold a no-op. A later
attempt was safely refused while the canonical scheduled pump held the
mutation lock; the successful retry did not interrupt that process.

Bindings for the successful apply:

- Journal: `q08_promotion_repair_journal.json`, SHA-256
  `ed24e39d84fba665907915c17476b0de5634f09e15029f4f09db22bd3ebdaf86`.
- Backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_q08_promotion_repair_20260922T042822Z_c45a7a91.sqlite`,
  SHA-256
  `dc9f6122f517e92a2ebcb525ac2b05b35b8564e1463311a0e95e1242a17b7a87`.
- Stable candidate/refusal set SHA-256:
  `ed79b63a8e55af85d0c1b4ec87ebe4d29eaf3b52adfdf1894a4d70ff19daac11`.
- Stable active-hold set SHA-256:
  `d34145b2723520da62d405c48bed87ba20840d1e49155b29027739d794cbc36d`.
- No-change reservation SHA-256:
  `5291e2af1f27b8753a8d68047f5325a4284eb7dcd1a22909af71ec9ce36b60e5`
  (`write_allowed=true`).

## Verification

- Python bytecode compilation passed for all changed runtime modules.
- `24 passed`: focused DSR classification, claim-time binding, source hold,
  repair, backup/journal, and idempotency tests.
- `170 passed, 4 deselected, 13 subtests passed`: cascade, atomic claim, and
  Q08 admission regression suite with live-only DSR environment flags removed.
  The four deselected completion-path fixtures exercise an unrelated pre-existing
  SH-3 fixture constraint that does not admit the current canonical verdict
  taxonomy.
- A separate six-test run covering legacy default-off claims and Q08 preflight
  behavior passed after removing those inherited live feature flags.
- `git diff --check` passed for the task changes.
- Cycle-start farm health was already globally `FAIL` (`15 FAIL`, `57 OK`,
  `16 WARN`) due to existing fleet/backlog conditions, including Q08
  invalid-rate and claim-starvation signals; this artifact does not recast
  those health checks as pipeline verdicts.

No terminal was started manually, no active backtest was interrupted, and
AutoTrading/T_Live were not enabled. The implementation and evidence remain
in REVIEW; they were not self-approved or advanced to pipeline execution.
