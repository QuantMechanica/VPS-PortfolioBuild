# CRITIC → Q00 TRANSITION — FTMO candidates H-CW / H-MR / H-FXMR

**Date:** 2026-09-16 · **Author:** Kimi (interim OWNER delegation, `OWNER_DIRECT_SESSION_DELEGATION` 2026-09-15/16)
**Audience:** Fable / critic-era operator · **Status:** DOCUMENTATION ONLY — no DB writes, no commits, no registry changes were made. Every command below was verified to exist in the tooling; every state claim was verified against the repo, the research ledger, and the farm DB (read-only).
**Repo note:** all merge math is against `origin/main @ 68cf5caff2`. The local `main` ref is diverged (14 ahead / 7,233 behind origin/main) — do not merge from it; fetch and let Fable reconcile it first.

---

## 0. TL;DR — the single remaining gate

All three strategies are **built, magic-allocated, and G0-APPROVED**, but **zero rows exist in the farm DB** for them (verified: `work_items` and `tasks` empty for `QM5_41475/41476/41477` in `D:\QM\strategy_farm\state\farm_state.sqlite`). The only blocker is the **fail-closed internal-source critic gate** (`research_source.verify`, contract R-D): each prereg record needs a genuine **non-Kimi cross-vendor `critic_receipt.json`**, then a governed **re-seal**, then everything else is deterministic:

```
critic receipt → research_source seal → verify ok → prescreen KEEP → merge branch to main
  → farmctl enqueue-compile (COMPILE_EA) → build_check stamps build_hash → governed smoke
  → farmctl intake-first-q02 (first Q02 canary) → factory workers pick it up
```

Per-EA extra fixes before prescreen KEEP: **H-CW** needs a re-seal (stale `lineage.json` manifest hash — a birth defect); **H-MR** additionally needs a one-sentence dedup-differentiation note in its card body (NEAR_DUPLICATE false-positive vs `QM5_10140`).

---

## 1. Per-EA current state (verified 2026-09-16)

### QM5_41475 — H-CW (cash-window index continuation, session-flat H1)

| Item | Value |
|---|---|
| Branch / commit | `agents/kimi-hcw-20260915` @ `86e166f26f` (worktree `C:\QM\worktrees\kimi-hcw-20260915`) |
| Card | `artifacts/cards_approved/QM5_41475_cash-window-index-continuation-h1.md` — `g0_status: APPROVED`, `review_status: REVIEW_PENDING`, on origin/main via `c062742682` |
| Prereg | `QM-RESEARCH-2026-0002`, `record_sha256 cd661891447f6bb2ef2465607f7df40138e6a9de0879d0242b5dc7c35554322e` (canonical-record hash, recomputed ✓); ledger status `reviewed` |
| Critic receipt | **Present but pre-dating the lineage edit** — Fable-inline fallback receipt (claude vendor), verdict REVISE, 0 blocking / 3 major / 3 minor |
| ex5 | `…\QM5_41475_cash-window-index-continuation-h1.ex5` sha256 `99126310ab17af2c67de1ebf7f0d61fb7d42db954fae231c474f4baf7d560461` — **uncommitted** (EX5_COMMIT_GUARD), untracked in worktree |
| Setfiles (6, all `; build_hash: pending`) | `…_NDX.DWX_H1_backtest.set`, `…_NDX.DWX_H1_live.set`, `…_GDAXI.DWX_H1_backtest.set`, `…_GDAXI.DWX_H1_live.set`, `…_SP500.DWX_H1_backtest.set`, `…_SP500.DWX_H1_live.set` |
| Magic rows | `414750000/NDX.DWX` (slot 0), `414750001/GDAXI.DWX` (slot 1), `414750002/SP500.DWX` (slot 2) — `framework/registry/magic_numbers.csv`, active, "Codex governed allocator" 2026-09-15; `ea_id_registry.csv` row active |
| Prescreen **current** result | **REJECT** — `INTERNAL_SOURCE_UNRESOLVED:HASH_MISMATCH:lineage.json` (regressed from the 2026-09-15 KEEP: `lineage.json` gained a `versions[]` array during preregistration *after* the last `seal`; the manifest in `source.md` still records the pre-prereg hash `92be248c…` vs actual `a16e5027…`). Present since the original commit `807038391e`; needs one re-seal, not a content change. |

### QM5_41476 — H-MR (cash-open index mean reversion, session-flat H1)

| Item | Value |
|---|---|
| Branch / commit | `agents/kimi-hmr-20260916` @ `04f10839b2` (worktree `C:\QM\worktrees\kimi-hmr-20260916`); card+prereg cherry-pick `c711bf359c` on `agents/board-advisor` |
| Card | `artifacts/cards_approved/QM5_41476_cash-open-mean-reversion-h1.md` — `g0_status: APPROVED`, `review_status: REVIEW_PENDING`; binds `source_hash: 1887b25e…` |
| Prereg | `QM-RESEARCH-2026-0006`, `record_sha256 8129b0fc617229c40f7898c64a79072ff93019eb08fc7fa7faef69987b140d2d` (recomputed ✓); ledger status `preregistered` |
| Critic receipt | **Placeholder skeleton** — all 8 required fields empty (`status: PENDING` note: claude disabled to 09-17, codex hold to 09-19, agy quota-dead) |
| ex5 | sha256 `89d1107a00ef0365d2a50b7a2a5621c31cba60df9aab39afb131a70d2cf3a702` — uncommitted, untracked |
| Setfiles (6, `build_hash: pending`) | NDX/GDAXI/SP500 × `_H1_backtest.set` / `_H1_live.set` |
| Magic rows | `414760000/1/2` — NDX/GDAXI/SP500, active 2026-09-16; registry row active |
| Prescreen **current** result | **REJECT** — (1) all 8 `MISSING_FIELD:critic.*` sub-reasons; (2) `NEAR_DUPLICATE:QM5_10140_tv-london-session-break.md:score=1.0000`. The duplicate is an analyzed false positive (reversion vs continuation thesis, bigram collision) but prescreen keeps it as a **reason** because the card body contains no differentiation phrase. Fix: one sentence with a marker phrase (§2a/§2b). |

### QM5_41477 — H-FXMR (FX session mean reversion, session-flat M15)

| Item | Value |
|---|---|
| Branch / commit | `agents/kimi-fxmr-20260916` @ `ea38197cc0` (worktree `C:\QM\worktrees\kimi-fxmr-20260916`); card+prereg cherry-pick `5a58fdf883` on `agents/board-advisor` |
| Card | `artifacts/cards_approved/QM5_41477_fx-session-mean-reversion-m15.md` — `g0_status: APPROVED`, `review_status: REVIEW_PENDING`; binds `source_hash: ba89005b…` |
| Prereg | `QM-RESEARCH-2026-0005`, `record_sha256 c408f534bc8825783d44487dd51def684227955988b680fbd4228d4578027475` (recomputed ✓); ledger status `preregistered` |
| Critic receipt | **Placeholder** (`PENDING`) — same 8 missing fields |
| ex5 | sha256 `4e07143ac4e07ed644ba7865a7b1d8a7b262f16696386bb2f7e1248117c1219b` — uncommitted, untracked |
| Setfiles (6, `build_hash: pending`) | EURUSD/GBPUSD/USDJPY × `_M15_backtest.set` / `_M15_live.set` |
| Magic rows | `414770000/EURUSD.DWX`, `414770001/GBPUSD.DWX`, `414770002/USDJPY.DWX`, active 2026-09-16; registry row active |
| Prescreen **current** result | **REJECT** — all 8 `MISSING_FIELD:critic.*` sub-reasons only (the fail-closed critic gate working exactly as designed). |

**Verified `research_source.verify` output today:** 0002 → `HASH_MISMATCH:lineage.json`; 0005 → 8 × `MISSING_FIELD:critic.*`; 0006 → 8 × `MISSING_FIELD:critic.*` (identical on the agent branches and on `origin/main`).

---

## 2. STEP-BY-STEP transition path (exact commands, verified against the tooling)

### 2a. Critic attachment — what file, what format, what clears `MISSING_FIELD:critic.*`

**Authority:** `tools/strategy_farm/research/research_source.py` (contract: `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`, decision `decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md`).

The critic verdict is recorded as **`critic_receipt.json`** inside the prereg store dir:
`strategy-seeds/sources/<QM-RESEARCH-2026-NNNN>/critic_receipt.json` (schema `qm.agent-chain.receipt.v1`).

**Required fields** — `research_source.CRITIC_REQUIRED_PATHS` (research_source.py:110). A missing/empty one yields exactly one `MISSING_FIELD:critic.<path>` sub-reason, aggregated by prescreen into `INTERNAL_SOURCE_UNRESOLVED:…`:

| Path | Notes |
|---|---|
| `chain_id` | any non-empty string, e.g. `CRITIC-HCW-20260917-001` |
| `plan.creator.vendor` / `plan.creator.model` | `kimi` / `kimi-code/kimi-for-coding` |
| `plan.critic.vendor` / `plan.critic.model` | **must be non-Kimi** when creator is Kimi |
| `critic_verdict` | free string; governance intent is `APPROVE` (or `REVISE` with required fixes applied + re-review) |
| `critic_seat_final` | **must be non-Kimi** (string or `{vendor, model}`) |
| `generated_at_utc` | ISO-8601 UTC |

**Additional hard checks** (research_source.py:868-881): `repo_write: true` → `CRITIC_WROTE` (refusal); creator-Kimi + critic-Kimi → `CRITIC_KIMI_ON_KIMI`; ledger status must be `reviewed|preregistered|carded`; every quantitative claim must be manifest-backed; `research_trial_count` must cover the search ledger.

**Real example to copy:** `strategy-seeds/sources/QM-RESEARCH-2026-0001/critic_receipt.json` (and 0002's) — a valid cross-vendor receipt: creator Kimi, critic `claude` seat, `repo_write: false`, `scope_drift: false`, `finding_counts`, `stages` note, `receipt_path` pointing at the human-readable critique markdown.

**Exact commands (operator, after the critic session §3 produces the receipt):**

```bash
# 1. Place the critic-written receipt (critic writes it; do not hand-fill verdicts)
#    strategy-seeds/sources/QM-RESEARCH-2026-0002/critic_receipt.json   (H-CW; replaces nothing — receipt already real, but re-seal needed for lineage)
#    strategy-seeds/sources/QM-RESEARCH-2026-0006/critic_receipt.json   (H-MR; replaces placeholder)
#    strategy-seeds/sources/QM-RESEARCH-2026-0005/critic_receipt.json   (H-FXMR; replaces placeholder)

# 2. Re-seal: recomputes the qm-source-manifest block (hashes research/lineage/critic JSONs)
#    and appends a ledger row. PRESERVE the ledger status:
python tools/strategy_farm/research_source.py seal QM-RESEARCH-2026-0002 --status reviewed
python tools/strategy_farm/research_source.py seal QM-RESEARCH-2026-0006 --status preregistered
python tools/strategy_farm/research_source.py seal QM-RESEARCH-2026-0005 --status preregistered
#    (seal is the ONLY governed repair for the H-CW lineage mismatch — same-version re-anchor, contract §6.2)

# 3. Verify (exit 0 = ok):
python tools/strategy_farm/research_source.py verify --id QM-RESEARCH-2026-0002
python tools/strategy_farm/research_source.py verify --id QM-RESEARCH-2026-0006
python tools/strategy_farm/research_source.py verify --id QM-RESEARCH-2026-0005
```

**Card binding update after seal (important):** sealing rewrites `source.md`'s manifest → new `source_hash`.
- H-MR and H-FXMR cards bind `source_hash:` in frontmatter → **must** be updated to the new sha (printed by `seal`) and committed, else verify → `HASH_MISMATCH`.
- H-CW's card has **no** `source_hash` field (binds via `preregistration_sha256` only) → no card edit needed.
- Update the cards with an in-place amendment (re-stamps `card_sha256`, keeps `g0_status: APPROVED`):
```bash
python tools/strategy_farm/farmctl.py approve-card --card artifacts/cards_approved/QM5_41476_cash-open-mean-reversion-h1.md --reasoning "source_hash rebind after critic seal per OWNER_DIRECT_SESSION_DELEGATION"
python tools/strategy_farm/farmctl.py approve-card --card artifacts/cards_approved/QM5_41477_fx-session-mean-reversion-m15.md --reasoning "source_hash rebind after critic seal per OWNER_DIRECT_SESSION_DELEGATION"
```
- **H-MR dedup note:** add one sentence to the card body containing a prescreen differentiation phrase (`distinct from` / `different from` / `differs from` / `dedup` / `evidence-based delta` / `sole carrier change` / `duplicate fingerprint`) — e.g. *"Distinct from QM5_10140 (tv-london-session-break): QM5_10140 is a London-breakout continuation thesis; H-MR is a failed-breakout mean-reversion thesis on index cash-open over-extension — different entry, opposite trade sign, evidence-based delta documented in QM-RESEARCH-2026-0006."* This demotes `NEAR_DUPLICATE` from reason to warning (card_intake_prescreen.py:676-684). Then re-run the in-place `approve-card` above so `card_sha256` matches the edited bytes.

### 2b. Prescreen re-run — exact command + expected KEEP

```bash
python tools/strategy_farm/card_intake_prescreen.py --card artifacts/cards_approved/QM5_41475_cash-window-index-continuation-h1.md
python tools/strategy_farm/card_intake_prescreen.py --card artifacts/cards_approved/QM5_41476_cash-open-mean-reversion-h1.md
python tools/strategy_farm/card_intake_prescreen.py --card artifacts/cards_approved/QM5_41477_fx-session-mean-reversion-m15.md
```
- Read-only by default (mutation needs `QM_CARD_INTAKE_PRESCREEN=1` + `--apply`; **not** needed — cards already live in `cards_approved`).
- **Expected:** `verdict: KEEP`, `reasons: []` for all three (H-MR may carry the NEAR_DUPLICATE as a **warning** — that is acceptable, warnings are not rejections).
- The internal-source branch fires because each card declares `source_type: internal_research` / `source_id: QM-RESEARCH-…` (card_intake_prescreen.py:622-657); it delegates to `research_source.verify`, so KEEP ⟺ verify ok.

### 2c. Q00 / factory intake entry — which farmctl command is correct

All three candidate commands were read in `farmctl.py` argparse + implementation:

| Command | What it really does | Correct here? |
|---|---|---|
| `approve-card --card … --reasoning …` | G0 gate: sets `g0_status: APPROVED`, moves draft→approved (farmctl.py:33732). Authority checks: r-gate consistency, card contract, English headings, body coverage, `expected_trades_per_year_per_symbol ≥ 2`, `custom_history_archive_admission`. Refuses empty `--reasoning`. | **Already done** for all three (2026-09-15/16). Re-used only as the in-place card amendment mechanism in §2a. |
| `build-ea --card …` | Legacy codex lane: `prebuild_validate_card` (farmctl.py:4484 → 33515) hard-gates on the internal-source verify, then creates a `build_ea` task + renders the Codex prompt. | Viable but **not the chosen lane** — these EAs are already built; the governed COMPILE_EA lane below is the one the interim handoff committed to and it stamps `build_hash` deterministically. |
| `intake-first-q02 --compile-work-item-id … [--apply]` | Appends the **first Q02 canary** from a *done/COMPILE_OK* COMPILE_EA work item (farmctl.py:35766; planner checks at 35565). **Not an intake command** — it is the post-compile, post-smoke step (§2f). | No — this is step (f), after compile+smoke. |
| **`enqueue-compile <EA_LABEL>`** | Enqueues the governed **COMPILE_EA** utility work item (farmctl.py:37865 → `compile_work_items.enqueue_compile_eas`, compile_work_items.py:5075). | **YES — this is the Q00 factory entry for these internally-sourced, already-approved cards.** |

**`g0` authority field:** the cards' `g0_approval_reasoning` frontmatter must (and does) cite the delegation: *"OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-15/16 … Build-only authorization; no pipeline phase, no gate verdict, no live use."* That value is what the interim delegation supports; any further governance action (pipeline phases, gate verdicts, live use) remains OWNER/Fable-only.

**Exact command (positional form enqueues immediately — it implies apply):**
```bash
cd C:\QM\repo   # canonical checkout is enforced for state-mutating commands
python tools/strategy_farm/farmctl.py enqueue-compile QM5_41475_cash-window-index-continuation-h1
python tools/strategy_farm/farmctl.py enqueue-compile QM5_41476_cash-open-mean-reversion-h1
python tools/strategy_farm/farmctl.py enqueue-compile QM5_41477_fx-session-mean-reversion-m15
```
**Authority/guard checks inside `classify_candidate`** (compile_work_items.py:4238-4386) — all currently pass, keep them passing:
- canonical checkout (`_assert_canonical_checkout`, farmctl.py:38495) + factory ON (`FACTORY_OFF` interlock blocks all mutating commands).
- EA dir + `.mq5` present; **`.ex5` must be ABSENT** (`EX5_ALREADY_PRESENT` refusal) → after merging to main, do **not** commit the worktree `.ex5` (EX5_COMMIT_GUARD; the compile lane rebuilds and binds it).
- exactly one active `ea_id_registry.csv` row; ≥1 active magic row with valid `*.DWX` symbols.
- **no prior work items** for the EA (`WORK_ITEMS_EXIST`), no open COMPILE_EA row, no open `build_ea` task (`BUILD_TASK_EXISTS`).
- **no setfile with a real `build_hash`** (`BOUND_SETFILE_HASH_EXISTS`) → keep `; build_hash: pending` until the lane stamps it.
- timeframe resolvable from setfile names (`_H1_` / `_M15_`).

Batch dry-run form (optional): `enqueue-compile --from-file labels.csv` (dry-run until `--apply`).

### 2d. COMPILE_EA execution — what stamps `build_hash` and runs `build_check`

The COMPILE_EA work item is claimed by a compile-lane worker and executed by `run_compile_work_item` (compile_work_items.py:6037):
1. `classify_candidate` recheck → refusal if guards regressed (`CANDIDATE_RECHECK_REFUSED`).
2. `framework/scripts/gen_setfile.ps1` regenerates one `<label>_<symbol>_<TF>_backtest.set` per magic symbol.
3. **`framework/scripts/build_check.ps1 -EALabel <label> -Strict -CompileWorkItemId <id> -ClaimedTerminal <Tn>`** — the governed build: compiles via MetaEditor and runs `Update-SetFileBuildHash` (build_check.ps1:389-426), which sets `; build_hash:` to the **sha256 of the setfile's own normalized bytes with `pending`** — this is the stamp that turns `pending` into a bound build hash.
4. Success requires `build_check.result=PASS` + `compile_one.result=PASS` + exactly-produced `.ex5` + setfiles > 0; evidence written to `D:\QM\reports\work_items\<id>\<ea>\COMPILE_EA\compile_evidence.json`, verdict `COMPILE_OK` recorded on the work item.

Monitor: `python tools/strategy_farm/farmctl.py compile-status QM5_41475_cash-window-index-continuation-h1 …`

**Activation hold (do not miss this):** `enqueue-compile` inserts the row with `kind='compile'`, `phase='COMPILE_EA'`, `status='pending'` **plus an active hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`** (`release_on_restart=1`; compile_work_items.py:5378-5390) — a freshly enqueued COMPILE_EA row is *not claimable* until the governed rollout release. Release exactly the three rows (dry-run first, then `--apply`):

```bash
python tools/strategy_farm/release_compile_wave.py --work-item-ids <id1> <id2> <id3>              # inspect
python tools/strategy_farm/release_compile_wave.py --work-item-ids <id1> <id2> <id3> --apply      # release
# single-row alternative: farmctl release-hold --work-item-id <id> \
#   --expected-hold-code COMPILE_EA_WORKER_ROLLOUT_PENDING --release-note "<durable reason>"
```

(Equivalently a factory restart releases it via the release-on-restart ceremony; the explicit wave is the deterministic route.) After release, resident terminal workers claim the row through the canonical selector and `run_compile_work_item` executes §2d on the claimed terminal.

### 2e. Governed smoke — reservation contract + per-EA acceptance rule

**Path:** `framework/scripts/run_smoke.ps1` (self-admitting) → `tools/strategy_farm/custom_history_smoke_admission.py`.
**Reservation contract** (custom_history_smoke_admission.py:44-137; invoked at run_smoke.ps1:819-876):
- only factory terminals `T1`–`T12`; owner token `run_smoke:<pid>:<guid>`; `minutes > 0`.
- `custom_history_gate` must pass (`PASS_ISOLATED`/`PASS_SERIALIZED_ROLLBACK`); when active isolation requires a worker-bound work item, `--expected-work-item-id` must match the terminal's exactly-one active claim (`$env:QM_WORK_ITEM_ID` is auto-passed by workers).
- refuses if the terminal is already reserved, has another active farm claim, or the claim set changes during reservation (claim/reservation race closed by re-check + auto-release).
- release is ownership-checked (`release … --reserved-by <token>`).

**Per-EA acceptance rule** (build smoke, `-SmokeMode` honors `-MinTrades` verbatim; build smoke floor = 1 trade):
| EA | Smoke symbol | Rule |
|---|---|---|
| QM5_41475 H-CW | `NDX.DWX` | ≥1 trade **or** documented zero-trade reason (recorded rule from the interim receipt) |
| QM5_41476 H-MR | `NDX.DWX` | ≥1 trade or documented zero-trade reason |
| QM5_41477 H-FXMR | `EURUSD.DWX` | ≥1 trade or documented zero-trade reason |

A zero-trade outcome is investigated under `processes/02-zt-recovery.md` (zero trades is never silently accepted). Note the smoke step is deliberately **operator-run**: the farm-reservation path writes factory state, which was outside the interim delegation.

### 2f. Normal factory entry — what Q00+ creates and how the factory picks it up

1. `enqueue-compile` inserts one `work_items` row: `kind='compile'`, `phase='COMPILE_EA'`, `status='pending'`, payload-bound `mq5_sha256`/symbols — **held** by `COMPILE_EA_WORKER_ROLLOUT_PENDING` until the governed release (§2d). A compile worker then claims it through the canonical claim order and `run_compile_work_item` produces the `COMPILE_OK` verdict + evidence.
2. **Smoke (§2e)** is the operator gate between compile and first backtest.
3. `python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id <COMPILE_EA id> --apply` — dry-run first, then appends exactly one Q02 canary work item (receipt at `D:\QM\strategy_farm\artifacts\receipts\first_q02_intake\`). Planner verifies: done/COMPILE_OK binding, evidence pass-bindings, **exactly one canonical `.ex5`** whose sha256 agrees across work item / payload / evidence / current bytes, setfile plan, magic check (farmctl.py:35565-35684). Remaining symbols are deferred via the Q02 fanout policy.
4. From there the **normal factory** owns advancement: `terminal_worker.py` daemons claim pending work items in `pending_claim_order` (pump dispatch), post-classify chaining advances PASS rows to the next phase (Q02→Q03→…→Q17), and `farmctl pipeline` shows per-EA stage progression.

---

## 3. Critic session runbook (provider-neutral — claude CLI or codex CLI)

Hand the critic **read-only** context (it must not write to the repo — `repo_write: true` is a hard refusal):

**Files to hand over (read-only):**
1. The card: `artifacts/cards_approved/QM5_<id>_<slug>.md`
2. The prereg record: `strategy-seeds/sources/<QM-RESEARCH-…>/preregistration.json` (+ `research.json`, `lineage.json`, `source.md`)
3. The EA source: `framework/EAs/<label>/<label>.mq5` + its `.mqh` core module
4. The spec: `framework/EAs/<label>/SPEC.md` and `framework/EAs/<label>/docs/visualization_spec.md`
5. The mechanical-spec card inside the store dir (`H_CW_card.md` / `H_MR_card.md` / `H_FXMR_card.md`) — the preregistration's spec hash binds this file

**Prompt shape (verbatim template):**
> You are an independent critic (vendor `<claude|codex>`, model `<model>`) reviewing a QuantMechanica strategy package authored by Kimi. READ-ONLY: do not write to the repo, do not emit verdicts on gates, do not trade. Check: (1) card rules ↔ preregistration hypothesis and falsifiers agree; (2) EA source mechanically implements the card rules (entry/exit/risk/session-flat/news-blackout/daily-loss guards); (3) SPEC.md and visualization_spec.md match the implementation; (4) every quantitative claim in research.json is backed by a manifest-listed computed output; (5) FTMO fit claims (5% daily / 10% total, news blackout) are actually enforced in code. Verdict: `APPROVE` or `REVISE` with a numbered list of required fixes (classify blocking/major/minor).

**Required verdict schema** — the critic returns one JSON file, `critic_receipt.json` (schema `qm.agent-chain.receipt.v1`), with the 8 required paths from §2a (`chain_id`, `plan.creator.vendor/model`, `plan.critic.vendor/model`, `critic_verdict`, `critic_seat_final`, `generated_at_utc`), plus `repo_write: false`, `scope_drift: false`, `finding_counts{blocking,major,minor}`, `stages[]`, and `receipt_path` pointing at the saved human-readable critique markdown (put it in the store dir or `docs/ops/evidence/`).

**Where the receipt lands:** the operator (not the critic) places it at `strategy-seeds/sources/<id>/critic_receipt.json` and runs the `seal` + `verify` commands from §2a. If the verdict is REVISE, apply the required fixes first, then re-run the critic once; record the final verdict.

---

## 4. Verification checklist per EA (for Fable / critic-era operator)

**A. Identity & registry (all three)**
- [ ] `grep -E "^4147[567]," framework/registry/ea_id_registry.csv` → one row each, `active`, slug + prereg id correct
- [ ] `grep -E "^(41475|41476|41477)," framework/registry/magic_numbers.csv` → 3 rows each, symbols/slots match §1, status `active`
- [ ] `git rev-parse agents/kimi-hcw-20260915 agents/kimi-hmr-20260916 agents/kimi-fxmr-20260916` → `86e166f26f`, `04f10839b2`, `ea38197cc0`

**B. Prereg integrity (per EA)**
- [ ] `python tools/strategy_farm/research/preregister.py --check <preregistration.json> <spec card>` → unchanged/pass (record_sha256 matches card frontmatter `preregistration_sha256`)
- [ ] Canonical record hash recompute matches §1 (`record_sha256` = sha256 of sorted-json record minus the field — verified True for all three on 2026-09-16)
- [ ] `python tools/strategy_farm/research_source.py verify --id <id>` → exit 0, `ok: true` (after §2a)
- [ ] `D:\QM\reports\state\research_source_ledger.jsonl` last row per id: status `reviewed`/`preregistered`, `sha256` == current `sha256(source.md)`

**C. Card (per EA)**
- [ ] `python tools/strategy_farm/card_intake_prescreen.py --card <card>` → `KEEP` (reasons empty; H-MR NEAR_DUPLICATE at most a warning)
- [ ] card `source_hash` (H-MR/H-FXMR) == `seal`-printed source.md sha; `g0_status: APPROVED`, `g0_approval_reasoning` cites `OWNER_DIRECT_SESSION_DELEGATION`
- [ ] card_sha256 front stamp == file content hash (after any in-place `approve-card` amend)

**D. Merge to main (per EA)** — §5 paths; after merge: EA dir + SPEC + viz spec + 6 setfiles present on main; `.ex5` **absent** from git (`git ls-files | grep ex5` empty); `; build_hash: pending` still intact

**E. Compile (per EA)**
- [ ] `enqueue-compile` JSON → `ok: true` (guards §2c all pass)
- [ ] row exists with hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`; `release_compile_wave.py --work-item-ids … --apply` released exactly those rows (no foreign rows)
- [ ] work item reaches `done / COMPILE_OK`; `compile_evidence.json` shows `build_check_result: PASS`, `compile_result: PASS`
- [ ] all 6 setfiles now carry a 64-hex `; build_hash:` (stamped by build_check.ps1); `ex5` rebuilt and sha-recorded in evidence

**F. Smoke & intake (per EA)**
- [ ] smoke admission `PASS_RESERVED` → smoke run → release; acceptance rule §2e met (≥1 trade on the named symbol or documented zero-trade reason)
- [ ] `intake-first-q02 --apply` receipt exists; first Q02 canary row pending in `work_items`; `farmctl pipeline` shows the EA progressing

**G. Global**
- [ ] `work_items`/`tasks` in `D:\QM\strategy_farm\state\farm_state.sqlite` were empty for the three EAs before step C (baseline) and grow exactly as expected after
- [ ] no commits to `framework/registry/` beyond what Fable authorizes; no DB writes during the documentation phase (this doc made none)

---

## 5. Merge path per EA branch into main (verified)

Base fact: the H-MR/H-FXMR branches were cut from `c9dcd9b5fa` (watchdog NO_RUNNABLE_WORK fix, itself a child of main tip `68cf5caff2`), so their merge-base with origin/main **is** main tip. The H-CW branch is older: it was cut from `da1b4b4e0c` and later merged the allocation commit `57d48627e4` (`ee1da2a1ad`) — it does **not** contain `c9dcd9b5fa`, and its merge-base with origin/main is `57d48627e4`. `origin/main` is now at `68cf5caff2` (child of `57d48627e4`). **No commit by which any branch trails main touches `framework/EAs/` or `framework/include/QM/`** — the only main-side delta is one docs commit (see below), so no EA-code conflicts are possible.

### H-CW — `agents/kimi-hcw-20260915` (merge-base with origin/main: `57d48627e4`)
- **main is ahead by 1:** `68cf5caff2` "docs(handoff): H-CW allocation unblocked + build finalized" — touches only `docs/ops/KIMI_INTERIM_HANDOFF_2026-09-18.md`. Zero `framework/EAs` / `framework/include/QM` touches.
- Branch is 6 commits ahead (EA feature, fixes, receipt, setfiles/evidence). Its card+prereg are already on main (`c062742682`) and **byte-identical** to the branch copies (verified via `git diff`).
- **Take from the branch:** `framework/EAs/QM5_41475_cash-window-index-continuation-h1/` (mq5, mqh, SPEC.md, docs/visualization_spec.md, 6 setfiles) + `docs/ops/evidence/2026-09-15_kimi_hcw/`.
- **Take main's side for everything else** (only the handoff doc differs). Merge branch→main is a clean true merge (or rebase onto `68cf5caff2`).
- **Do NOT merge full main into the H-CW branch** — the interim receipt documents that full-merge surfaces Q14–Q16 factory-file replay add/add conflicts between lineages. One-directional promotion only.

### H-MR — `agents/kimi-hmr-20260916` (merge-base with origin/main: `68cf5caff2` = main tip)
- **main is ahead by 0.** Branch = main + 4 commits: `c9dcd9b5fa` (watchdog fix — same sha already on `agents/board-advisor`; whichever lands first brings it), `60ef030a8b` (card+prereg 0006), `9e491426f1` (EA), `04f10839b2` (receipt).
- Card+prereg on `board-advisor` (cherry-pick `c711bf359c`) are **byte-identical** to the branch copies (verified) → no content conflict regardless of merge order.
- **Take from the branch:** EA dir (mq5, mqh, SPEC, viz spec, 6 setfiles), `strategy-seeds/sources/QM-RESEARCH-2026-0006/` (10 files), `docs/ops/evidence/2026-09-16_kimi_hmr/`.
- Merge into main fast-forwards cleanly. Nothing outside those paths is touched (verified: 0 files under `framework/include/`).

### H-FXMR — `agents/kimi-fxmr-20260916` (merge-base with origin/main: `68cf5caff2` = main tip)
- **main is ahead by 0.** Branch = main + 4 commits (`c9dcd9b5fa`, `4b56b100fb` card+prereg 0005, `bf6b729a16` EA, `ea38197cc0` receipt).
- Card+prereg on `board-advisor` (cherry-pick `5a58fdf883`) byte-identical to branch copies (verified).
- **Take from the branch:** EA dir (mq5, mqh, SPEC, viz spec, 6 setfiles), `strategy-seeds/sources/QM-RESEARCH-2026-0005/` (incl. the 9,400-line `universe_map_result.json` — large but inert), `docs/ops/evidence/2026-09-16_kimi_fxmr/`.

### Post-merge hygiene (all three)
- The `.ex5` files stay **uncommitted** in the agent worktrees (EX5_COMMIT_GUARD); the governed COMPILE_EA lane rebuilds and binds the canonical ex5 on main.
- After the critic-era store edits (§2a), commit the updated `strategy-seeds/sources/<id>/` (receipt, re-sealed `source.md`) on the respective branch **before** merging, so main carries a verifiable store.
- Registry (`ea_id_registry.csv`, `magic_numbers.csv`) already contains all rows on main — no registry merge needed.

---

## 6. Addendum 2026-09-18 — §2f.3 canary selection is now RAM-aware

`intake-first-q02`'s canary pick (§2f step 3, planner at `farmctl.py:35565-35684`) used a
hand-maintained liquidity priority list (`Q02_CANARY_SYMBOL_PRIORITY`, retired) that ranked
`SP500.DWX` ahead of `NDX.DWX`/`GDAXI.DWX` regardless of RAM cost. It silently drifted from
`terminal_worker`'s admission-lane RAM calibration table (`INDEX_TICK_RESERVATION_GB_BY_BASE`),
which is revised on measured evidence — the 2026-09-16 recalibration moved NDX and GDAXI back
to the 44GB exclusive-drain-lane class alongside SP500. QM5_41476 (H-MR)'s first-intake canary
landed on `SP500.DWX` (2026-09-18, receipt
`D:\QM\strategy_farm\artifacts\receipts\first_q02_intake\07087e86-8a5a-4638-b3aa-3d56edc55780_96e5f16f-8d18-4ace-8318-a0c26ea6b9cf.json`);
its candidate set was `{SP500.DWX, GDAXI.DWX, NDX.DWX}` — under the *current* calibration table
all three are already 44GB, so this specific canary's cost is unchanged by the fix below.

**Fix (this session):** `_q02_canary_symbol_rank` now delegates to
`terminal_worker._ram_reservation_detail_for_candidate` (the same resolver `terminal_worker`
uses to reserve RAM at claim time) instead of the static list, ranking candidates by RAM
class/GB ascending with ties broken by card order. This closes the drift permanently — a future
recalibration (e.g. if `UK100`/`WS30` regain a sub-44GB table entry) is picked up automatically,
with no second place to edit. H-CW (QM5_41475) has the identical `{SP500, GDAXI, NDX}` candidate
set and will see the same "no change today, but no future drift" outcome once it reaches §2f.3.

Also fixed in the same change: `enqueue_universe_expansion_q02`'s owner-decision gate
(`farmctl.py:26426`) was hard-bound to the single literal `OWNER-DEC-13036-XAU`. It now checks
membership in `UNIVERSE_EXPANSION_ACCEPTED_OWNER_DECISIONS`, which also accepts
`OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917` — unrelated to this doc's three EAs (they
use the compile→smoke→`intake-first-q02` lane, not universe-expansion), noted here only because
both fixes shipped together per the routing ticket that cited this doc.

Tests: `tools/strategy_farm/tests/test_q02_canary_ram_ranking.py`,
`tools/strategy_farm/tests/test_mnt038_canary_fanout.py`,
`tools/strategy_farm/tests/test_universe_expansion_owner_decision.py`; two pre-existing tests
that encoded the retired priority list's tie-break (`test_mnt038_canary_fanout.py`,
`test_sweep_enqueue_built_eas.py`) were updated to the new card-order tie-break.
