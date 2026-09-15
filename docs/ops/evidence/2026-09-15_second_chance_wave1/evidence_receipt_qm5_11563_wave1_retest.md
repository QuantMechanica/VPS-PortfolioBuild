# Evidence Receipt — Second-Chance Wave-1 Retest Commission: QM5_11563

**Date (UTC):** 2026-09-15T20:51Z
**Commission author:** kimi-interim (Kimi interim OWNER delegation)
**Programme:** Strategy Second-Chance Programme
(`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md`, worktree copy
`.claude/worktrees/wf_717b9d36-ba6-4/docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md`)
**Mode:** ENQUEUE-ONLY. Zero repo code changes. Zero git commits (main-worktree
commit policy handled separately). No historical verdicts, work items, holds or
register rows modified.

---

## 1. Register row commissioned (classification source)

Source: `D:/QM/reports/state/second_chance_register.json`
(schema `qm.second-chance-register/v1`, generated 2026-09-15T18:11:23+00:00,
`inputs_sha256 37ec3be93ae709404a2c829429084cdf9266ed8b916bb29d780adad69fb15982`,
generator `tools/strategy_farm/research/second_chance_register.py`).

QM5_11563 is the register's **#1 ranked** record (Wave-1 FTMO table, §3.1):

```json
{
  "ea_id": "QM5_11563",
  "slug": "connors-rsi2-sma200-mean-reversion-d1",
  "projection_class": "REJECTED",
  "primary_reason": "INFRA_FAIL",
  "matched_rule": "infra_pipeline_blocker",
  "second_chance_status": "ELIGIBLE_FOR_RECONSIDERATION",
  "suppressed_clone_of": "",
  "portfolio_utility_challenger": false,
  "tail_risk_flag": false,
  "priority": 89.677,
  "strategy_family": "mean_reversion",
  "timeframes": "D1",
  "intended_symbols": "EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX",
  "reason_evidence": "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected. | legacy_contract_repair | card_body_incomplete"
}
```

Programme §5 Wave 1: "cheap, high-FTMO, clean rerun — INFRA_FAIL (1) — a
genuine clean rerun (QM5_11563). Cost: one Q00→Q02 pass." INFRA_FAIL means the
original failure was infrastructural; the strategy itself was never judged →
normal-pipeline rerun, not a policy exception.

## 2. DB state BEFORE (farm_state.sqlite)

`work_items` for QM5_11563: **14 rows, all `status=done`, no holds**
(`work_item_holds` empty for this ea_id), none pending/active:

| Phase | Symbol | Verdict | Work-item id |
|---|---|---|---|
| Q02 | EURUSD.DWX | PASS | e8f67e0f-b137-4d8d-b5d0-19658be9f661 |
| Q04 | EURUSD.DWX | FAIL | 433d263f-e9ac-4da8-8763-fb4ca6827d20 |
| Q02 | GBPUSD.DWX | PASS | bf9dceba-a27a-4087-939d-e5a5dc0ec261 |
| Q02 | USDJPY.DWX | PASS | 6806b39e-c5cf-4b73-88fc-6c81143e997f |
| Q04 | GBPUSD.DWX | PASS_LOWFREQ | 2e9ccc12-96d5-4137-8992-1f0bbda9759d |
| Q04 | USDJPY.DWX | FAIL | 47fc9d64-8aec-4d56-b205-30c0be242564 |
| Q03 | EURUSD.DWX | PASS | dd5209c0-0ab7-4968-aa3c-d9ca997a36c2 |
| Q03 | GBPUSD.DWX | PASS | 7f6d01bb-33c7-41b7-89a8-047ca4d9640c |
| Q04 | EURUSD.DWX | FAIL | 001ff56e-7afe-4ba9-9061-5ccf67286ff3 |
| Q05 | GBPUSD.DWX | PASS | 2ebf6ec5-97c5-4204-a174-7beb26a477fd |
| Q06 | GBPUSD.DWX | PASS | 4ece110d-6033-48c3-89cc-96db30741d8a |
| Q07 | GBPUSD.DWX | PASS | eb1cfecc-cb25-4526-81a9-8ed7651ffe40 |
| Q08 | GBPUSD.DWX | INVALID | 79a120af-bde1-42fd-bf4f-b1f8f6c41c05 |
| Q08 | GBPUSD.DWX | INVALID | 44c01339-5b42-4b07-9125-f3e1e9040d7e |

- Q06 evidence verified from `D:/QM/reports/work_items/4ece110d-…/QM5_11563/20260912_085013/summary.json`:
  **PF 1.57, 94 trades, drawdown 4370.07** (register join quoted 4.37% DD).
- Terminal history: Q08 INVALID twice — 2026-09-12
  (`q08_8.2_dsr_mc_fdr:DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT`) and the 2026-09-14
  append-only rerun under OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914 class A
  (`DSR_V2_TRADE_OUTSIDE_SEALED_CALENDAR`, rerun of 79a120af).
- Prior agent task `e26b6273-3c6a-478b-8f2a-b5004e32d85f` (build_ea, **BLOCKED**,
  holds the old pipeline-binding-blocker record). Left untouched as read-only
  evidence.
- `agent_tasks` search: **no** `second_chance` payload anywhere; no open task
  referencing QM5_11563 other than the BLOCKED build row above → nothing
  already running or re-queued. Clean-rerun precondition confirmed.

## 3. What was enqueued (canonical mechanism)

Mechanism: the programme doc §5.1 ticket template — `agent_router.py enqueue`
(the doc's literal `research_task` label is not an enumerated router task type;
`enqueue` validates against `TASK_TYPE_CAPABILITIES`; `research_strategy`
[research, strategy] is the canonical research-lane mapping and preserves the
template payload verbatim).

Command (run from the canonical checkout `C:\QM\repo`):

```
python tools/strategy_farm/agent_router.py enqueue research_strategy \
  --priority 70 --state TODO --payload-json '{ …template payload… }'
```

Result:

```json
{ "enqueued": true, "state": "TODO", "task_id": "b0ef5d66-5947-4d79-ad72-02f2caee04cb", "task_type": "research_strategy" }
```

**Created ID: agent task `b0ef5d66-5947-4d79-ad72-02f2caee04cb`**
(table `agent_tasks`, farm_state.sqlite; priority 70 — the doc's ≤70 bound;
state TODO; capabilities ["research","strategy"]; unassigned — routing is the
router's job; budget_class standard).

Ticket payload (the append-only NEW-lineage second-chance ticket; the doc
defines no separate ticket file — this payload IS the ticket):

- `kind: second_chance_retest`, `origin_ea_id: QM5_11563`,
  `second_chance_reason: INFRA_FAIL`,
  `second_chance_status: ELIGIBLE_FOR_RECONSIDERATION`,
  `register_inputs_sha256: 37ec3be9…5982`, `lineage: NEW`,
  `tail_risk_contract: null` (not a tail-risk reason)
- `provenance: { source: second_chance_wave1, register_ref + schema + record,
  commission_author: kimi-interim, commissioned_at_utc: 2026-09-15T20:51:04Z }`
- `origin_source_class: external book (Connors RSI2, source_id
  278c6e13-…)` — INFRA_FAIL carries no QM-RESEARCH mint precondition
- `venue_hypothesis: FTMO (§31), D1 mean-reversion, low-swap FX majors`
- `intended_symbols: EURUSD.DWX / GBPUSD.DWX / USDJPY.DWX`
- `historical_evidence` (Q06 numbers + terminal Q08 history),
  `prior_agent_task_evidence` (BLOCKED build row, do-not-reopen),
  `action: clean rerun via normal pipeline; mint NEW ea-id via farmctl
  allocation; never reopen the old verdict`
- `notes: append-only; old work-item rows remain as evidence`

## 4. DB state AFTER

Exactly one new row: `agent_tasks.b0ef5d66-5947-4d79-ad72-02f2caee04cb`
(state TODO, priority 70, created 2026-09-15T20:51:20+00:00). No work_items,
holds, verdicts or registry rows were touched. No second-chance payload existed
before; exactly one exists now.

## 5. Boundaries kept

- Pipeline decides verdicts; this commission enqueues through the canonical
  router only (no hand-written SQL, no verdict writes).
- Append-only: the old ea-id, its 14 work items, both Q08 INVALID rows, the
  BLOCKED build task and the register row are read-only evidence. Retest runs
  under a NEW minted ea-id at execution time.
- Repo: zero code changes, zero commits; this receipt is the only new file.
- Not enqueued (per handoff): QM5_10648, QM5_1355, QM5_1354, QM5_9576 — all
  NO_EXTERNAL_SOURCE; they require a QM-RESEARCH provenance mint first (Wave 3,
  batch mint then enqueue highest-priority FTMO-relevant first).

## 6. Provenance-mint requirement for the next four (NO_EXTERNAL_SOURCE)

Per `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md` (FINAL v1) + programme
Wave 3, each record needs a `QM-RESEARCH://` artifact before Q00:

1. **Mint** via `tools/strategy_farm/research_source.py mint --author … --model …
   --task-id … --title …` → allocates next `QM-RESEARCH-YYYY-NNNN` (ledger
   `D:/QM/reports/state/research_source_ledger.jsonl`; 0001/0002 already used;
   ids never reused), scaffolds the store.
2. **Durable store** in-repo on C: `strategy-seeds/sources/QM-RESEARCH-YYYY-NNNN/`
   with `source.md` (frontmatter + fenced `qm-source-manifest` block),
   `research.json` (`qm.internal-research-source/v1`: research_question,
   source_datasets + computed_outputs with sha256, quantitative_claims each
   backed by a computed-output hash, ml_method, observations,
   proposed_mechanism, candidate_edge, confidence, confounders,
   related_strategies, research_trial_count, search_history_ref,
   critic_receipt, lineage), `critic_receipt.json`, `lineage.json`
   (`qm.research-lineage/v1`).
3. **Hash anchoring:** `source_hash = sha256(source.md)`; manifest block hashes
   every sibling + every computed-output file cited by a numeric claim;
   `research_source.py verify` recomputes and **fails closed** on any mismatch
   (`NOT_FOUND`/`HASH_MISMATCH`/`MANIFEST_MISSING`/`NUMERIC_UNBACKED`).
4. **Cross-vendor read-only critic:** creator vendor ≠ critic vendor,
   `repo_write == false`; verify fails closed on a kimi-on-kimi critic or any
   critic write (`CRITIC_KIMI_ON_KIMI`/`CRITIC_WROTE`).
5. **Ledger status** must be `reviewed|preregistered|carded` (draft not
   admissible); ledger is append-only, status changes are new rows.
6. **Trial count:** card `research_trial_count` ≥ research-layer
   `search_history_ledger` count for the family (fails closed on
   understatement).
7. **Card frontmatter:** `source_id: QM-RESEARCH-…`, `source_type:
   internal_research`, `source_author`, `source_model`,
   `source_artifact: QM-RESEARCH://<id>`, `source_hash`,
   `research_trial_count` → then the §9.3 intake verify must pass at prescreen
   AND at `farmctl approve-card` (reason `INTERNAL_SOURCE_UNRESOLVED` on any
   miss).
8. Only then may a second-chance ticket (same §5.1 template, with
   `provenance: QM-RESEARCH://<id>`) be enqueued for the record.
