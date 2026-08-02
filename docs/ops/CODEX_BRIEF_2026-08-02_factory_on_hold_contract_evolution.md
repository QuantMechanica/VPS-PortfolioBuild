# CODEX BRIEF 2026-08-02 — Generation-aware restart-hold release contract (review + implement)

**Author (R1):** Claude (design below). **Reviewer + implementer:** Codex (Sol, effort max).
**Protocol:** adversarial review FIRST with explicit agreement %; implement in the same
session ONLY if your agreement >= 90 % (incorporate your own findings); otherwise stop
after the review and return findings. Claude re-reviews the implementation before any
runtime decision is minted. Factory is in an OWNER-approved OFF window.

**Hard constraints:** no terminal starts, no farm-DB mutation (the change is code +
schema + template + tests only), no T_Live contact, no runtime-decision minting, no
Factory_ON run. Commit ONLY with explicit pathspecs on `agents/board-advisor`.

## Problem

Factory_ON's final gate releases restart holds via `maintenance_control.py
release-on-restart --apply`, which requires the ACTIVE `release_on_restart` hold set to
exactly equal seven hardcoded work-item IDs and inserts into a consumption table whose
column carries `CHECK(released_hold_count=7)`. Those seven holds were released once on
2026-07-31T05:42:49Z (single consumption row, nonce burned). Zero active
release-on-restart holds exist now, so every future full Factory_ON fails its last gate
and rolls back. The contract must become generation-aware.

## Authorized generation content (already committed)

`docs/ops/evidence/2026-08-02_factory_preparation_owner_decision.json` — fresh OWNER
preparation decision (verbatim authorization recorded 2026-08-02 ~07:47Z): 10 workers
T1–T10, **empty** release-on-restart hold plan, 21-task-map restore, runtime-decision
creation authorized. This file is the single source for the generation's hold plan and
the repin target.

## Design (implement exactly this; deviations only via your review findings)

The hold plan stops being a hardcoded constant replicated across three code files and
two JSON files. It becomes single-sourced in the OWNER preparation decision
(`restart_holds.authorized_work_item_ids`, possibly `[]`), carried into the runtime
decision by the builder, verified equal at every hop, and executed as an exact set:
empty set ⇒ assert zero active release-on-restart holds, burn the nonce, record
`released_hold_count=0`. Code pins only the decision's identity (path/SHA/commit/blob),
never its contents.

### File-by-file

1. `tools/strategy_farm/factory_runtime_activation.py`
   - Remove the `RESTART_HOLD_IDS` tuple (~lines 66–74).
   - Rename authorization key `release_seven_restart_holds` → `release_declared_restart_holds`
     in `_require_runtime_authorizations` (~214–240): exact-key set + truthy check.
   - After preparation-decision provenance+load (~316–333): extract
     `prep_plan = prep["restart_holds"]["authorized_work_item_ids"]`; fail closed unless
     it is a list of unique, non-empty, UUID-shaped strings and
     `authorized_release_count == len(prep_plan)`.
   - Replace the hardcoded restart_holds exact-dict check (~361–366) with equality to
     the prep plan carried forward.
   - Result dict `restart_hold_ids` (~457) returns the generation plan.
   - `PREPARATION_DECISION_RELATIVE_PATH/_SHA256/_COMMIT/_BLOB`: repin to the committed
     2026-08-02 preparation decision (compute the real values from git).
   - Worker-policy validation: DO NOT touch.

2. `tools/strategy_farm/build_runtime_activation_decision.py`
   - After loading the preparation decision (~324–328): structurally validate the plan
     (unique strings, count==len).
   - In payload construction (~411–420): set
     `payload["restart_holds"] = {"authorized_release_count": len(ids), "authorized_work_item_ids": ids}`
     from the prep decision (same pattern as nonce/timestamps/restore_intent).

3. `tools/strategy_farm/factory_runtime_activation.v1.template.json`
   - `authorizations.release_seven_restart_holds` → `release_declared_restart_holds: true`.
   - `restart_holds` → builder-overwritten placeholder `{"authorized_release_count": 0, "authorized_work_item_ids": []}`.
   - `preparation_decision` block: repin to the 2026-08-02 decision (path/sha/commit/blob).

4. `tools/strategy_farm/factory_runtime_activation.v1.schema.json`
   - Rename the authorization key (const true).
   - `restart_holds.authorized_release_count`: `{"type":"integer","minimum":0}` (drop const 7).
   - `restart_holds.authorized_work_item_ids`: array, uniqueItems, items pattern
     `^[0-9a-fA-F-]{36}$` (drop const list). RULING: keep this permissive pattern.
   - `preparation_decision.const`: repin per generation (2026-08-02 decision identity).
   - `restore_intent.task_enabled_before_sha256`: verify against the 2026-08-02 prep map
     (the 21-task map is unchanged from 07-30; recompute and confirm rather than assume).

5. `tools/strategy_farm/maintenance_control.py`
   - Remove `CANONICAL_RESTART_HOLD_IDS` (~50–58). Keep `CANONICAL_OWNER_DECISION_*` as
     identity pins; repin them to the committed 2026-08-02 prep decision.
   - `_validate_canonical_restart_owner_decision` (~410–421): structural validation
     (unique-string list, count==len, release_policy const); callers read the plan from
     the returned payload.
   - `_validate_canonical_factory_on_lock` (~783): `expected["restart_hold_ids"]` from
     `runtime_authorization["restart_hold_ids"]`.
   - `_apply_restart_hold_release_transaction` (~1166–1266): derive `expected_ids` from
     `runtime_authorization["restart_hold_ids"]` (fail closed if absent/malformed);
     consumption goes to a NEW versioned side table
     `factory_runtime_activation_consumptions_v2` with `CHECK(released_hold_count>=0)`
     and identical append-only BEFORE UPDATE/DELETE triggers; nonce single-use enforced
     across BOTH tables (fixed-allowlist table names, check inside BEGIN IMMEDIATE
     before insert); insert `released_hold_count = len(rows)`. v1 table and its
     historical row are NEVER touched. Release loop unchanged (empty plan ⇒ no-op).
   - `release_restart_holds` (~1290–1361): dry-run derives the plan from the validated
     prep decision; apply derives from the runtime authorization AND asserts equality
     with the prep plan (defense in depth). No CLI plan argument (plan never comes from
     operator input).

6. `tools/strategy_farm/Factory_ON.ps1`
   - Remove `$QM_OWNER_APPROVED_RESTART_HOLD_IDS` (~142–150). Repin
     `$QM_OWNER_DECISION_*` + path + decision_id/status literals to the 2026-08-02 prep
     decision.
   - `Assert-CanonicalOwnerRestartDecision` (~315–324): load the plan from the pinned
     decision into `$script:approvedRestartHoldIds`; validate count field equality; drop
     the per-index compare against the removed array.
   - After `Get-CanonicalRuntimeActivationAuthorization` (~1105): cross-check runtime
     plan == prep plan (exact ordered set).
   - Lock record (~889): `restart_hold_ids = @($script:runtimeAuthorization.restart_hold_ids)`.
     **MANDATORY ACCEPTANCE CRITERION (top implementation hazard): under Windows
     PowerShell 5.1 an empty array inside the lock hashtable MUST serialize as JSON `[]`
     (never null/""), because maintenance_control compares it to Python `[]`. Force the
     type (e.g. `[string[]]`), round-trip-verify in code, and cover it with a
     source-grep assertion in the PS-contract test.**
   - Release verification (~1001–1010): expected count = plan count (drop literal 7);
     coerce `$releasedIds = @($result.released | %{[string]$_})`.
   - Health-gate-before-release ordering, OFF-wins asserts, rollback-with-lock-retention:
     unchanged.

### Consumption-table ruling (accepted design)

Versioned side table v2 — the v1 table is the immutable audit record of the 2026-07-31
release and is never rewritten. Nonce uniqueness spans v1 ∪ v2 (strictly stronger than
today). Do NOT implement the rebuild-with-copy alternative.

### Accepted author rulings on the open questions

- Empty-plan activation still burns the nonce and writes a v2 row with count 0 (audit
  evidence of the "verified zero holds" gate pass).
- DB floor `CHECK(>=0)`; exact `== len(plan)` enforced in Python (exact set + CAS).
- Key name: `release_declared_restart_holds`.
- UUID pattern stays permissive.
- Worker-policy generalization: OUT OF SCOPE (follow-up ticket); the 10-worker pins from
  the earlier ten-worker-policy work stay as they are.

### Tests (all must pass; run the full four files)

- `tests/test_maintenance_control.py`: fixture gets a local plan tuple; authorization
  dict gains `restart_hold_ids`; consumption assertions move to v2; edit
  `test_restart_release_ids_are_unique_and_bound_to_canonical_owner_decision` to
  structural validation. ADD: empty-plan-verifies-zero-holds-and-consumes-nonce;
  empty-plan-fails-closed-on-any-active-release-hold;
  derives-plan-from-runtime-authorization (2-id plan);
  missing-plan-in-authorization-fails-closed;
  v2-check-allows-zero-and-is-append-only;
  nonce-single-use-across-v1-and-v2 (pre-seeded legacy v1 nonce rejected).
- `tests/test_factory_runtime_activation.py`: seed prep plan in `_build_repo`; rename
  key; rewrite the schema/template pin test to the structural contract. ADD:
  runtime-plan-must-equal-preparation-plan; accepts-empty-declared-plan;
  rejects-missing-release-authorization-key.
- `tests/test_build_runtime_activation_decision.py`: seed prep `restart_holds`; assert
  the built decision carries the prep plan. ADD: carries-empty-declared-plan-forward.
- `tests/test_factory_restart_post_start_health.py`: rewrite the seven-ID test to
  assert the plan is read from the runtime authorization, no literal `-ne 7`, ordering
  preserved (health wait before release), `--factory-on-lock-nonce` present, and the
  PS-5.1 `[]`-serialization coercion is present in source.

Also run `python -m py_compile` on every touched Python file.

### Do NOT change

Nonce single-use semantics (strengthen only), OFF-wins precedence (all
`_require_no_factory_off_intent` / `Assert-NoFactoryOffIntent` sites), mutation-lock
authentication mechanism, append-only triggers (v1 untouched, v2 identical), the
`BEGIN IMMEDIATE` transaction shape + per-row CAS + ledger idempotency keys, Factory_ON
control flow (health gate strictly before release; fail-closed rollback), unrelated
runtime-decision guards (time window, source bindings, task-map SHA, OFF binding),
T_Live/FTMO isolation, worker-cohort validation.

### Deliverable

1. Your adversarial review: agreement % + itemized findings (write to
   `docs/ops/evidence/2026-08-02_factory_on_hold_contract_review.md`).
2. If >= 90 %: the implementation, committed on `agents/board-advisor` with explicit
   pathspecs (code + schema + template + tests + the review doc; nothing else), full
   test output verbatim in the review doc, and the repin values (path/sha/commit/blob of
   the 2026-08-02 prep decision) listed.
3. End your final message with: agreement %, commit hash(es), test summary line, and
   any deviation from this brief.
