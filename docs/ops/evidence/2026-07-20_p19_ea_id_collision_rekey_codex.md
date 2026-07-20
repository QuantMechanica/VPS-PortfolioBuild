# P1.9 EA-ID collision re-key — tracked pass and runtime plan

Date: 2026-07-20

Owner: Codex (`agents/codex`)

Status: tracked repository pass complete; Claude ACK received for the mapping
and D-store card moves; runtime card pass deliberately deferred because the
factory/router boundary was not quiescent. Historical RECYCLE-row annotation
requires separate follow-up adjudication.

Claude coordination task
`62b407a5-68fc-4d7a-b700-d10b201db36d` entered `REVIEW` at
`2026-07-20T06:14:16Z` with verdict: the mapping is verified, has no pipeline
exposure, and may proceed at the documented quiescent window. Its artifact is
`C:/QM/repo/docs/ops/evidence/registry_p19_ea_id_rekey_ack_2026-07-20.md`;
the authoritative task row is in
`D:/QM/strategy_farm/state/farm_state.sqlite`.

## Tracked mapping

| Identity | Result | Compiled artifact policy |
|---|---|---|
| `QM5_1157_plastun-crude-oil-autumn` | Retained at 1157; active registry owner restored with source `afab7a6f-c3c8-51ae-a609-f376744beb8e`. | Existing MQ5/EX5 untouched. |
| `QM5_1157_qp-stress-reversal-sp500` | Old 1157 registry claim retired; source-only directory/file re-keyed to preallocated 12074. | No EX5 created. |
| `QM5_1619_aa-overnight-mom` | Retained at 1619. | Existing MQ5/EX5 untouched. |
| `QM5_1619_ehlers-adaptive-cg-h4` | Source-only directory/file re-keyed to preallocated 12247. | No EX5 created. |
| `QM5_1624_ehlers-adaptive-cg-h4` | Archived at `_obsolete_QM5_1624_ehlers-adaptive-cg-h4_duplicate_pre-p19-rekey`. | Source-only; no EX5. |
| `QM5_1643_aa-overnight-mom` | Archived at `_obsolete_QM5_1643_aa-overnight-mom_duplicate_pre-p19-rekey`. | Source-only; no EX5. |
| Registry alias 12249 | Normalized to `aa-overnight-mom` and retired. | No magic allocation or resolver change. |

Deterministic coverage is in `tools/strategy_farm/tests/test_registry_rekey_p19.py`. It binds active registry rows, production directory names, MQ5 filenames, internal `qm_ea_id` literals, and any non-retired magic rows for the four canonical identities. It also proves the two duplicate sources are outside the production-directory namespace.

Retained EX5 SHA-256 values at `2026-07-20T05:57:10Z`:

- `QM5_1157_plastun-crude-oil-autumn.ex5`: `4eb3efb5ff881eb8e1f5c7115c1ca3b39ff26d957ec291635865c1f196efca52`
- `QM5_1619_aa-overnight-mom.ex5`: `382bfb4c369c53c58696c98e9c8da954e9f924302c74facc21a7912e23d3bd23`

`git diff --quiet -- framework/EAs/QM5_1157_plastun-crude-oil-autumn framework/EAs/QM5_1619_aa-overnight-mom` returned 0. No retained source or binary changed.

## Read-only runtime audit

The database was opened as `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro` and `PRAGMA query_only=ON` was set. The exact query was:

```sql
SELECT id, task_type, state, assigned_agent, artifact_path, verdict,
       payload_json, created_at, updated_at
FROM agent_tasks
WHERE id LIKE 'e22dac9b%'
   OR id LIKE '5766506d%'
   OR id LIKE '02da%'
   OR id LIKE 'c248%'
ORDER BY id;
```

Result observed on 2026-07-20 (read-only):

| Task UUID | Existing identity | State / last update | Current artifact |
|---|---:|---|---|
| `e22dac9b-351f-41ca-9214-164a7a607ab1` | 1157 QP stress reversal | `RECYCLE`, `2026-07-20T05:22:58+00:00` | `C:/QM/repo/framework/EAs/QM5_1157_qp-stress-reversal-sp500/QM5_1157_qp-stress-reversal-sp500.mq5` |
| `5766506d-8630-44b8-b85c-229d93051449` | 1619 Ehlers adaptive CG | `RECYCLE`, `2026-07-20T05:22:58+00:00` | `C:/QM/repo/framework/EAs/QM5_1619_ehlers-adaptive-cg-h4/QM5_1619_ehlers-adaptive-cg-h4.mq5` |
| `02da6437-8c76-42c5-82df-ed307ce12628` | 1624 duplicate Ehlers | `RECYCLE`, `2026-07-19T17:31:21+00:00` | `C:\QM\repo\framework\EAs\QM5_1624_ehlers-adaptive-cg-h4\QM5_1624_ehlers-adaptive-cg-h4.mq5` |
| `c24879e3-75d8-4ef5-8d1a-57b64cd0f2c8` | 1643 duplicate AA overnight | `RECYCLE`, `2026-07-19T17:31:22+00:00` | `C:\QM\repo\framework\EAs\QM5_1643_aa-overnight-mom\QM5_1643_aa-overnight-mom.mq5` |

All four rows are already `RECYCLE`; no task-state transition remains to perform.

## Exact card mutations deferred to the quiescent integration window

Do not execute these while factory automation or routing is active. Claude has
approved the mapping, but its ACK requires confirming no concurrent router or
pump before the one-pass mutation. The 2026-07-20 08:17 Europe/Berlin check
found active `run_smoke.ps1`/MetaTester work on DEV1 and multiple T1-T10
terminals, the five-minute pump due at 08:18, the agent router last run at 08:16
and due again at 08:21,
and Claude orchestration still `Running`; the 08:19 follow-up then found
`farmctl.py pump` active as PID 15088 (started 08:18:52). That is not a
quiescent integration window, and this task has no authority to suspend factory
scheduling. Per the handoff rule, the following runtime mutation was therefore
not started:

1. Pause/verify the farm pump and router at a declared quiescent boundary after
   the tracked commit is integrated.
2. Create
   `D:\QM\strategy_farm\artifacts\cards_approved\_obsolete_rekey_20260720\`
   and record pre-mutation SHA-256 values for all five current approved cards.
3. Leave `cards_approved\QM5_1157_plastun-crude-oil-autumn.md` unchanged.
4. Archive `QM5_1157_qp-stress-reversal-sp500.md`; issue
   `QM5_12074_qp-stress-reversal-sp500.md` with `ea_id: QM5_12074` and otherwise
   preserved strategy/source identity. Remove the old filename from the active
   approved-card namespace only after the replacement passes card lint.
5. Archive `QM5_1619_ehlers-adaptive-cg-h4.md`; issue
   `QM5_12247_ehlers-adaptive-cg-h4.md` with `ea_id: QM5_12247` and otherwise
   preserved strategy/source identity. Remove the old filename from the active
   approved-card namespace only after lint passes.
6. Archive `QM5_1624_ehlers-adaptive-cg-h4.md` with no active replacement;
   12247 owns the retained Ehlers identity.
7. Archive `QM5_1643_aa-overnight-mom.md`; issue
   `QM5_1619_aa-overnight-mom.md` with `ea_id: QM5_1619` and otherwise preserved
   strategy/source identity. This supplies the approved card for the retained
   built 1619 EA.
8. Run card identity/dedup lint and farm health against the quiescent snapshot;
   publish the pre/post card hashes and lint output before resuming automation.

Do not rewrite the four historical RECYCLE rows during that card pass. Claude's
ACK says no `agent_tasks` referenced the identities, but the current read-only
audit above proves four such rows exist and retain their old artifact paths.
Changing closed historical evidence was therefore not within the reliable ACK
scope. Those rows stay immutable unless Claude explicitly adjudicates whether
their old-path provenance or a re-key annotation should win.

No runtime card, SQLite row, terminal, magic-number registry, resolver, or compiled artifact was mutated in this tracked pass.

## Tests

- `python -m pytest -q tools/strategy_farm/tests/test_registry_rekey_p19.py tools/strategy_farm/tests/test_health_registry_uniqueness.py` — PASS, 9 tests.
- `python framework/scripts/generate_event_vocabulary.py --check` — PASS, 240 events and 3 explicitly unresolved calls.
- `git diff --check -- framework/registry/ea_id_registry.csv framework/EAs` — PASS (Git emitted only its configured LF-to-CRLF checkout notice).
- Direct `health.chk_ea_id_slug_uniqueness(repo)` audit — the result remains `WARN` for eight unrelated pre-existing registry-only duplicates, but its detail contains neither `1157` nor `1619` after this pass. This work does not claim global registry cleanup.

The event-vocabulary generator intentionally scans every MQ5/MQH below `framework/EAs`, including `_obsolete_*` directories. Moving these two skeletons does not alter vocabulary content because neither source contains a logger call; the post-move `--check` remains the required deterministic guard.
