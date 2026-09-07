# QM5_11129 / SP500 Q-lineage recovery disposition

- Router task: `632a00c9-32c5-4f79-92bd-7baa6e9b83bf`
- Parent task: `bb814520-3364-5355-97b6-27f662f3ed8b`
- Target: `745671a4-02e4-4df5-b5e1-e25f0e41ca0e`
- Disposition: **governed regeneration already enqueued; execution deferred by active CEO RAM hold**

## Exact surviving lineage

| Q phase | Work item | DB verdict/state | Evidence status |
|---|---|---|---|
| Q07 | `e3187d46-42c3-4dc7-beac-25cc8a0d947b` | PASS/done | Missing: bound `aggregate.json` absent |
| Q07 successor | `e046b36b-80e6-4e5d-b826-8d4c667cfe25` | pending | Correct append-only rerun already exists; no evidence yet |
| Q08 | `5171b4bf-cbb8-4b93-9f54-af83f41d3a19` | PASS/done | Present, SHA-256 `372c0cd88bd55487aac2187fa769ec76f7e03f89d1d9d54147e025303c5fb140` |
| Q09 | `3799336c-28a8-4099-87ec-7d304dc83428` | PASS/done | Present, SHA-256 `5de4da1f588beb7dd843e2e2f3612d4ac6a5c489d75496c2dc1caf34d35a7ea2` |
| Q09 | `052d13f1-5444-445d-b924-df1eb5c772e5` | PASS/done | Present, SHA-256 `e8f484c64981872afdc501a9ae8d0af50efdfde2fcf146f28b9a2e5dae9df683` |
| Q10_NEWS | `745671a4-02e4-4df5-b5e1-e25f0e41ca0e` | pending/null | `NEWS_RUNNER_SPAWN_SILENT_ABORT`; plan remains authenticated but bound Q07 file is absent |

The Q10 payload's Q08 binding exactly matches the surviving Q08 file. Its Q07
binding expects SHA-256
`80af0ab779ce7caf594c3aca2f60b7667ed769b8667acd344431d1ef2cc654e1`,
but that path no longer exists.

## Existing governed Q07 successor

No duplicate row was appended. `e046b36b` was created on 2026-09-02 with:

- `append_only_rerun=true`
- `append_only_rerun_of_work_item=e3187d46-42c3-4dc7-beac-25cc8a0d947b`
- expected/current EX5 SHA-256
  `1ddd4ef135b3e8cf0154b21e50d6ad696551efe7c5fb4c94808f2bc80f9569d8`
- current setfile SHA-256
  `6211284c422f06406cfa444f668a8ad0c044bbd4f6073faa3b80066022aceee6`
- rerun reason: exact Q10 wave-2 lineage regeneration.

The canonical EX5 and setfile still match those hashes.

## Why execution was not released

`e046b36b` has the active `RAM_WINDOW_44GB` hold written under the CEO
2026-09-04 instruction. It requires 48 GB free and may be released only after
the RAM upgrade or in an explicitly scheduled isolated window. At inspection,
the 63.12 GB host had only 25.39 GB free and six T1-T10 backtests were active.
Releasing it would violate the hold and the instruction not to interrupt active
backtests.

Therefore no Q08/Q09 successor can yet be truthfully chained from regenerated
Q07 evidence, and no fresh Q10_NEWS plan/B-prime marker can yet be sealed. No
old verdict, payload binding, evidence path, hold, or calendar pin was changed.

## Fail-closed verification

`scoped_q10_wave2.py` was run in dry-run mode. For `745671a4` it returned:

- `eligible=false`
- `q07_evidence_intact=false`
- `releasable=false`
- `bound Q07 evidence is missing; release remains fail-closed`

Receipt:
`docs/ops/evidence/2026-09-07_632a00c9_wave2_post_lineage_dry_run.json`

The deterministic continuation is: OWNER/scheduler supplies an isolated
48-GB-free window and releases `RAM_WINDOW_44GB`; the existing `e046b36b` Q07
successor runs; only a pipeline-produced PASS may authorize append-only Q08 and
Q09 successors; then the wave-2 tool may create/release a fresh sealed
Q10_NEWS B-prime successor. Pipeline verdicts remain exclusively evidence-derived.
