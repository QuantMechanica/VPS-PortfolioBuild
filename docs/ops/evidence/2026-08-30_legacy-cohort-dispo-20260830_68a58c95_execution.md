# Execution — OWNER-DEC-LEGACY-COHORT-DISPO-20260830 = YES

- Decision id: `OWNER-DEC-LEGACY-COHORT-DISPO-20260830`
- Receipt: `68a58c95-a8da-4d4e-9e97-e839a68d5642`
  (`receipt_sha256 = edcd6edd54f9c4cfe3193f988567b0fd71e52d5e5814879d6b8059c5045e3f53`)
- Decided: `2026-08-30T08:00:16.833799Z` — OWNER "Ja" in Claude chat
- Execution contract: `qm.owner-decision-execution-contract/v1`,
  `sha256 = e6743dc885936ca14eec119fa8e82d6ffc390525f46e33383aec28e1341fb521`
- Router task: `b335e499-86e9-5b7d-a309-8000ad07a282`
- Sealed audit input: `docs/ops/evidence/2026-08-30_359988fb_legacy_q12_anchor_audit.md`
- Executed by: claude orchestration cycle 2026-09-02 ~10:45Z
- QM ToDo: `QM-TODO-20260830-706`

Selected effect: **6 append-only retires immediately; 13 Q02-new-identity chains
staggered after REQUAL-8, exactly one router ticket per wave (max 2 waves).**

## Summary

| Part | Scope | Status this cycle |
|------|-------|-------------------|
| (B) 6 retires | 6 measured-FAIL_HARD pairs | **COMPLETE** — verified independently in DB, no new action taken |
| (A) 13 chains | Q02 new-identity chains | **HELD, fail-closed** — REQUAL-8 build wave not through (pair 8 pending) |

No Codex ticket was commissioned this cycle. Part (B) was already commissioned
and closed; Part (A)'s gate is not met.

## Part (B) — 6 append-only retires: already executed, verified

The retire ticket was **already commissioned** on 2026-08-30 as
`7d561f89-f031-4806-9f0f-d0eac630b7e4` (codex, state `APPROVED`, closed
`2026-08-30T08:45:21Z`, artifact
`C:/QM/repo/docs/ops/evidence/2026-08-30_7d561f89_legacy_cohort_retire6.md`).

**A duplicate ticket was therefore NOT created.** Commissioning a second would
have breached acceptance criterion 1 ("Exactly 6 retires"). Dedup was performed
before any commissioning action — see *Duplicate-session hazard* below.

Independent DB verification this cycle (`farm_state.sqlite`, `mode=ro`) rather
than trusting the ticket's own verdict:

| pair | retire successor work_item | phase | status | verdict | taxonomy | created |
|------|---------------------------|-------|--------|---------|----------|---------|
| `QM5_1567/XAGUSD.DWX` | `def43866-a101-54a6-b7bb-6a75373a136d` | Q08 | done | RETIRE | strategy | 2026-08-30T08:10:59Z |
| `QM5_10476/USDCAD.DWX` | `a111b287-3020-573d-8f8c-ff0f011fd926` | Q08 | done | RETIRE | strategy | 2026-08-30T08:10:59Z |
| `QM5_10919/XTIUSD.DWX` | `b013edcf-7086-5306-aa14-67b092827873` | Q08 | done | RETIRE | strategy | 2026-08-30T08:10:59Z |
| `QM5_11421/AUDUSD.DWX` | `33d3b4ca-fb29-5756-b6f0-5d4e5d7779dc` | Q08 | done | RETIRE | strategy | 2026-08-30T08:10:59Z |
| `QM5_12567/XNGUSD.DWX` | `e206d58b-4d0b-51af-9a8c-e3072b8316a6` | Q08 | done | RETIRE | strategy | 2026-08-30T08:10:59Z |
| `QM5_13117/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1` | `840c629e-b8a1-5373-accd-e4c67cca35ce` | Q08 | done | RETIRE | strategy | 2026-08-30T08:10:59Z |

**Count check:** exactly **6** `verdict='RETIRE'` rows across the six audited
pairs — one each, no more.

**Sibling no-touch check (cross-symbol contamination):** for each of the six
`ea_id`s, *all* `verdict='RETIRE'` rows in the whole table were listed. Every EA
has exactly one, at exactly the audited symbol. `QM5_1567/EURUSD`,
`QM5_12567/XAUUSD` (both REQUAL-8) and `QM5_11421/EURUSD` (opt-fork) carry **no**
retire row. Clean.

**Scope check:** all `verdict='RETIRE'` rows created anywhere on 2026-08-30 were
enumerated. Besides these six (08:10:59Z, phase Q08) the only other rows that day
are an unrelated Q10_NEWS pair at 06:24:19Z (`QM5_10847/GDAXI`,
`QM5_13301/GDAXI`) and a separate Q02 batch at 07:03:13Z — different EAs,
different phases, not attributable to this decision.

Part (B) acceptance — "exactly 6 pair-scoped retires, zero historical mutation,
no cross-symbol contamination" — **holds under independent verification.**

## Part (A) — 13 Q02-new-identity chains: HELD, fail-closed

Gate per the selected effect: wave 1 starts **only after the REQUAL-8 build wave
(ticket `1b57e398-3709-44b3-a53a-21e20fdb5d7b`) completes.**

State of `1b57e398` at 2026-09-02T10:34:04Z: `APPROVED`, artifact
`C:/QM/repo/docs/ops/evidence/2026-09-02_1b57e398_q09_requal8_pair7_release_pair8_build_handoff.md`.
Its own close-review verdict reads (verbatim, emphasis added):

> CEO close-review 2026-09-02 (independent artifact verification): APPROVED:
> pair-7 (QM5_41221/EURUSD) checkpoint fully verified — worker-bound Q01 smoke
> 7afddab0 done/PASS, append-only gen0→gen1 successor (both SHAs match, gen0
> preserved), one Q02 seed a7974b65 pending, hold 30584122 released 09:03:39Z
> verbatim note, **pair-8 build c2ef7f4a pending**; OPT_CENSUS 1161 no-touch;
> 13/13 tests green; no hard-rule breach.

**`APPROVED` here certifies the pair-7 checkpoint, not completion of the wave.**
Per CLAUDE.md, `APPROVED` means "formally clean enough for the next
deterministic process". REQUAL-8 stands at **7 of 8** pairs; pair 8 is still
pending build. The gate is therefore **not met** and wave 1 was not commissioned.

Secondary blocker — **dangling reference**: the pair-8 build task `c2ef7f4a` is
**not locatable as a row id** in either `agent_tasks` (`id like 'c2ef7f4a%'` → 0)
or `work_items` (`id like 'c2ef7f4a%'` → 0). The string occurs only as free text
inside two verdicts (`1b57e398`, and `5851dc5b-e136-4322-9439-e7c8ed2d1657`
which is now `RECYCLE`). Until pair 8 resolves to a real, trackable row, wave-1
readiness cannot be evaluated deterministically. This satisfies "Any pair-level
ambiguity stops fail-closed".

Supporting throughput argument for the stagger (OWNER's recommendation at
decision time): `COMPILE_EA` pending depth is **45** rows as of 10:36Z. Adding 13
builds now would compound the very compile-queue/review-lane contention the
staggering was designed to avoid — acceptance criterion 2.

### The 13 chains, transcribed verbatim from the sealed audit

Recorded here so wave 1 can be commissioned without re-deriving them. All 13
carry disposition `Q02_NEW_IDENTITY`.

| # | pair | last authentic Q08 row | verdict | reason (audit) |
|---|------|------------------------|---------|----------------|
| 1 | `QM5_1556/XAUUSD.DWX` | `36d46f72-a638-4e59-be41-4bbecbe3e495` | FAIL_SOFT | binary/setfile missing, mismatched, or rebuilt after unbound legacy evidence |
| 2 | `QM5_10700/XAUUSD.DWX` | `fb35a79a-1541-4a35-90a4-056f3e5363db` | FAIL_SOFT | legacy Q08 chain missing or lacks exact EX5+setfile bindings |
| 3 | `QM5_10815/EURUSD.DWX` | `a4efdfd3-e2a1-4f15-a40f-871a5bde9a2d` | FAIL_SOFT | binary/setfile missing, mismatched, or rebuilt |
| 4 | `QM5_10940/XAUUSD.DWX` | `0c185c6d-f25c-4e5c-bf71-0932f9e61cee` | FAIL_SOFT | binary/setfile missing, mismatched, or rebuilt |
| 5 | `QM5_11132/SP500.DWX` | `1759533d-7600-40d1-ad1c-914d7c47c534` | INFRA_FAIL | binary/setfile missing, mismatched, or rebuilt |
| 6 | `QM5_11165/AUDCAD.DWX` | `565b76a0-a74c-40b2-ba4a-e5f29c334b96` | INFRA_FAIL | binary/setfile missing, mismatched, or rebuilt |
| 7 | `QM5_11165/EURUSD.DWX` | `d528948d-222a-4279-bbe8-dee17f70f3d4` | INFRA_FAIL | binary/setfile missing, mismatched, or rebuilt |
| 8 | `QM5_11708/EURUSD.DWX` | `106b5827-acda-4294-9d06-9e215333819a` | FAIL_SOFT | binary/setfile missing, mismatched, or rebuilt |
| 9 | `QM5_11910/NZDUSD.DWX` | `0cb83f40-5301-4f40-a99a-4d3f63874678` | FAIL_SOFT | legacy Q08 chain missing or lacks exact EX5+setfile bindings |
| 10 | `QM5_12580/AUDUSD.DWX` | `92e319b4-b40d-4db1-961c-e212c3f93d67` | FAIL_SOFT | legacy Q08 chain missing or lacks exact EX5+setfile bindings |
| 11 | `QM5_12710/XTIUSD.DWX` | `95a0e11a-d8f0-45bb-89e2-3e5cc16642ca` | FAIL_SOFT | legacy Q08 chain missing or lacks exact EX5+setfile bindings |
| 12 | `QM5_12778/QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` | `8637b758-4763-4a1c-a88e-f2001a1da7b4` | FAIL_SOFT | binary/setfile missing, mismatched, or rebuilt |
| 13 | `QM5_12966/GDAXI.DWX` | `9c11e621-8558-4677-b7ee-d4fc13e9e67e` | FAIL_SOFT | legacy Q08 chain missing or lacks exact EX5+setfile bindings |

Count reconciles with the audit header: `Q02_NEW_IDENTITY: 13`,
`RETIRE_CANDIDATE: 6` — 19 pairs total, matching the decision scope.

## Duplicate-session hazard observed this cycle

Three headless claude orchestration sessions were running concurrently, all
started 2026-09-02T10:15Z:

| PID | model | worktree |
|-----|-------|----------|
| 25952 | opus | `C:\QM\worktrees\claude-orchestration-1` |
| 8352 | sonnet | `C:\QM\worktrees\claude-orchestration-2` |
| 31436 | opus | `C:\QM\worktrees\claude-orchestration-3` (this session) |

The spawn lease `agent_task:b335e499-86e9-5b7d-a309-8000ad07a282` is keyed on
`agent_id='claude'`, **not on process** (acquired 10:21:56Z, expires 10:51:56Z),
so it does not prevent all three from picking up the same task — the recurrence
class in `project_qm_claude_orchestration_duplicate_session_race`. This task's
`quota_gate.invocation.model` is `sonnet`, i.e. the router's intended lane is
orchestration-2, not this one.

Mitigation applied: **dedup before commissioning.** Existing tickets for this
decision were queried first; that is what surfaced `7d561f89` as already
APPROVED and prevented a duplicate retire ticket. Since Part (A) is gated shut
and Part (B) was already done, this cycle commissioned nothing, so a concurrent
sibling session can at worst repeat the same read-only verification.

The task had already been stale-released twice
(`age_expired` 2026-08-30T14:02:28Z, `lane_heartbeat_stale`
2026-08-30T16:02:48Z) — it has been circulating unclosed since 2026-08-30.

## Acceptance criteria

1. *Exactly 6 retires, zero historical mutation; 13 chains follow audit rows
   verbatim and start only after REQUAL-8* — **MET.** 6 verified, no duplicate
   commissioned; 13 transcribed verbatim and **not** started.
2. *Compile queue and review lane never flooded by parallel waves* — **MET.** No
   wave started; `COMPILE_EA` pending is already 45.
3. *Any pair-level ambiguity stops fail-closed* — **MET.** Pair-8 (`c2ef7f4a`)
   is both pending and unlocatable → held.

## Next step

When pair-8 build `c2ef7f4a` resolves to a real row **and** REQUAL-8 is through
8/8, commission **one** Codex ticket for wave 1 (rows 1–7 above), then a second
for wave 2 (rows 8–13). Resolving the `c2ef7f4a` dangling reference is the
blocking precondition.

## Authority and containment compliance

Contract authority was `execution_authorized: true`, `scope:
selected_effect_only`, `notes_may_expand_scope: false`.

Actions taken: read-only DB queries (`mode=ro`), read-only file reads, and this
evidence document. **No** Codex ticket commissioned, no work item, verdict,
hold, lock, or portfolio_candidates row mutated, no existing evidence deleted or
overwritten.

Forbidden-action attestation — none of the following occurred: Factory_OFF/ON,
worker or terminal interruption, T_Live file/process/chart/preset/account
mutation, AutoTrading change, order placement, live deployment, gate-threshold /
gate-criterion / candidate-universe change, deletion or overwrite of verdicts or
trade streams, book construction or live-book mutation.

## Evidence sources

- `D:/QM/strategy_farm/state/farm_state.sqlite` (`mode=ro`) — `work_items`,
  `agent_tasks`, `spawn_leases`
- `C:/QM/repo/docs/ops/evidence/2026-08-30_359988fb_legacy_q12_anchor_audit.md` (sealed audit)
- `C:/QM/repo/docs/ops/evidence/2026-08-30_7d561f89_legacy_cohort_retire6.md` (Part B execution)
- `C:/QM/repo/docs/ops/evidence/2026-09-02_1b57e398_q09_requal8_pair7_release_pair8_build_handoff.md` (REQUAL-8 checkpoint)
- agent_tasks `7d561f89-f031-4806-9f0f-d0eac630b7e4`, `1b57e398-3709-44b3-a53a-21e20fdb5d7b`,
  `5851dc5b-e136-4322-9439-e7c8ed2d1657`, `b335e499-86e9-5b7d-a309-8000ad07a282`
