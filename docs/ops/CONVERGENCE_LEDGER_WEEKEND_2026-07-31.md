# Weekend Programme Convergence Ledger — 2026-07-31

OWNER directive (2026-07-31): work the following topics in order, delegate across
Codex (Sol Ultra/Max), Opus and Sonnet at Claude's discretion, **cross-review**
(Claude reviews Codex work, Codex reviews Claude work), implementation only at
**>= 90% joint agreement**, and every implementation is re-reviewed afterwards.
The Obsidian vault may be used as an exchange document.

## Protocol

1. One side authors (spec / plan / design). The other side reviews adversarially
   and states an explicit **agreement percentage** plus itemized findings.
2. `agreement >= 90%` -> implementation may start (implementer = the reviewer of
   the artifact where practical, so builder != approver is preserved end-to-end).
3. `agreement < 90%` -> author revises, next round. Rounds are logged here.
4. After implementation: the counter-party re-reviews the implementation
   (evidence: test runs, renders, hashes — never narrative), then the topic closes.
5. All routing via `agent_router.py` tickets (Rule 9: no manual codex exec while
   the factory runs). Evidence lives under `docs/ops/evidence/` or
   `docs/research/`; this ledger only records rounds and scores.

## Topics

| # | Topic | Author (R1) | Reviewer (R1) | State | Rounds / agreement |
|---|---|---|---|---|---|
| A | Gate-taxonomy single-source: cockpit -> phase_ids, add Q00, purge stale Q14 (farmctl + state_name_adapter), wire `gate_manifest.v1.json` as validated single source | Claude (spec: `CODEX_BRIEF_2026-07-31_gate_taxonomy_singlesource.md`) | Codex | **CLOSED** — implemented `e4d31aed3`, Claude re-verified (40 tests, Q00 rendered, Q14 gone) | R1: **92 %** |
| B | Live-book kill-switch baselines 10/24 (pulse ALARM): mechanism, gap plan, safe window, apply | Claude (plan after recon) | Codex | Phase 1 **EXECUTED** by Claude (divergence 20->0, +2 deploys, backup 54 files); Codex verification ticket open; Phase 2 = Sunday OWNER+Claude arming | R1: **94 %** |
| C | FTMO Book3 conservative-bound diagnostic (v1 "sealed validation" retitled after R1: seen holdout cannot be retro-sealed, n_trials>=165) | Claude (design v2: `FTMO_BOOK3_CONSERVATIVE_BOUND_DESIGN_V2_2026-07-31.md`) | Codex | R2 dispatched | R1: **62 %** |
| D | Q08 frontier queue steering: 10582 (parser fallback, NOT byte edits), 20039 Q06 (wave blocked 4/5), 20007 (priority stale; only NDX actionable) | Claude | Codex | R1 rejected the plan (correctly); parser-fallback implementation ticket dispatched; 3 OWNER decisions pending (NDX flag displacement, single-target Q08 requal mechanism, Sunday Factory-OFF window) | R1: **28 %** |
| E | New motors 20183 / 20184 / 11592 (Q02) | — | — | watch only (20184 active on T8; 11592 GBPUSD Q04 merit-FAIL; EURUSD self-healed) | — |
| — | MNT-003 (predates ledger): apply v1 failed 0x80070002 -> exact rollback; R2 root cause = literal apostrophes in raw -Arguments (H1 env-block refuted with evidence) | Codex diagnosis | Claude | apply-v2 ticket dispatched (plan v2 WhatIf 5/5) | R2 diagnosis APPROVED |

## Round log (continued, 2026-07-31 afternoon)

- **A CLOSED** (92 %, e4d31aed3, Claude re-verified).
- **B:** Phase 1 executed (Claude) + Codex-verified PASS 5/5 (`d6fea536`).
  OWNER restart 13:06Z armed 14/24; remaining 9 = binary vintage (builds
  <= 07-04, pre-KillSwitch-fix) -> recompile plan ticket `5690506f` running;
  **OWNER standing approval granted 2026-07-31 for the recompile-deploy plan**
  (Claude reviews, approves, records decision on arrival).
- **C:** v2 design 92 % -> evaluator implemented (`d6d2a8dfc`) + Claude-reviewed;
  R3 IS-config prepared (config `0581c74b`); Claude's evaluate run refused
  fail-closed (window end exceeds 9936 stream coverage — guard working);
  R3b config fix queued (`78d4d826`).
- **D:** parser fallback + last-wins ablation precedence landed (`12629f507`,
  `ba13af972`; ablations parse 6/6 override values, setfile bytes untouched);
  single-target requal controller landed + Claude-approved (`527228e3`);
  exception-contract rebind + fresh dry-run queued (`0debec3a`). Remaining
  blockers by design: Sunday Factory-OFF/zero-active window.
- **MNT-003:** apply-v2 ticket re-queued behind full Codex slots (`8b4f791a`).
- **Hygiene:** items 2/3/4 approved; pump-gate clamp reverted to 1800
  (`7bd303931`); Rule-11 kill-recorder amendment restored out of the ratified
  doc into `docs/ops/proposals/2026-07-31_rule11_kill_recorder_amendment.md` —
  **pending OWNER ratification**.
- **Rebind note:** commits `7122eaf2b`/`c817f5a74`/`7bd303931` touch
  runtime-decision-bound files — decision rebind is MANDATORY before the next
  Factory ON (builder: `tools/strategy_farm/build_runtime_activation_decision.py`).
- **OWNER decisions recorded 2026-07-31:** (1) YES NDX priority_track incl.
  displacement; (2) YES single-target Q08 requal controller; (3) YES Sunday
  session (reminder set); (4) standing YES to approve the recompile-deploy
  plan on arrival.

## Round log

- 2026-07-31: Ledger opened. Topics A and C authored by Claude and dispatched to
  Codex for adversarial R1 review. Topics B and D awaiting read-only recon
  results (workflow: KS mechanism + frontier blocking causes) before the plan
  artifacts are authored.
- 2026-07-31 (recon complete): Read-only recon landed with two corrections:
  (1) 10582 is NOT the backfill class — its setfiles carry strategy_* lines but
  lack the `; strategy-specific params` section header that
  `q08_5_neighborhood_runner.parse_setfile_assignments` requires (likely a new
  sub-class among the 158 undiagnosed Q08 INFRA_FAILs); (2) the pulse "dormant"
  count is soft (4MB log-tail; 10706 is actually armed) and KS baselines are
  read exactly once at OnInit — file drops never arm running EAs, only a
  T_Live re-init does (OWNER+Claude, Sunday market-closed window). Plans B and
  D authored (`CODEX_BRIEF_2026-07-31_ks_baseline_gap_plan_review.md`,
  `CODEX_BRIEF_2026-07-31_q08_frontier_steering_review.md`) and dispatched to
  Codex for R1.

## T5 reactivation note (2026-07-31 ~13:43Z, Codex lane)

T5 left quarantine after a controlled Model-4 positive control
(`docs/ops/evidence/2026-07-31_t5_reactivation.md`: 11912/AUDUSD PASS, 16
trades, SHA-stable; the 07-27 "T5 fault" isolation was invalid — 11144 was no
positive control). `disabled_terminals.txt` removed with dated backup; fleet
now 10/10, T5 verified claiming work (Claude DB check). **Sunday consequence:**
the runtime-activation contract still encodes the 9-worker/T5-quarantine
policy — any Factory_OFF/ON will FAIL CLOSED until (a) the worker-policy
source is updated to the 10-terminal cohort and (b) a fresh OWNER runtime
decision authorizes it. Both fold into the already-mandatory Sunday rebind;
needs explicit OWNER authorization of the 10-worker policy.

## OWNER SIGNATURE (2026-07-31 evening): KS recompile deploy SIGNED

OWNER wording: "passt alles, Sonntagsfenster bestätigt!" — recorded in the
signature packet (`2026-07-31_ks_recompile_signature_packet.md`) covering the
7-file deploy, all behavioral riders (incl. 10911 1.0 % cap), the registry
exact-baseline exception at `6fbebcd2d`, and the revised canary gate. Approved
window: Sunday 2026-08-02, market-closed until broker reopen. Rollback still
requires a separate written OWNER authorization if invoked.

## OWNER approvals batch (2026-07-31, "alle Freigaben erteilt")

1. **Rule-11 amendment RATIFIED:** the kill-recorder duty is merged back into
   `docs/ops/OPERATING_RULES_2026-07-03.md` Rule 11 with a ratification note;
   the proposal doc is marked RATIFIED.
2. **10-worker policy AUTHORIZED:** source update dispatched to Codex
   (`CODEX_BRIEF_2026-07-31_ten_worker_policy_source.md`); the fresh OWNER
   runtime decision itself is minted in the Sunday rebind.
3. **GDAXI priority option OBSOLETE BY EXECUTION:** row `05652c88` was already
   ACTIVE on T5 at execution time (re-census by Claude) — it is running now;
   successor rows inherit priority via `owner_priority_tracks.json`. No
   mutation performed (controller CAS would also have refused an active row).
4. Recompile-deploy plan standing approval unchanged (awaiting ticket
   `5690506f`).

## SUNDAY 2026-08-02 EXECUTION LOG (agenda below is historical)

**OFF window (executed 07:21Z–):** Factory_OFF quiescent (MNT-046 evidence
`…20260802T072113Z_8676.json`, 2 stable null scans, phase runner reaped); two
claim-orphan rows released via a documented one-shot R5 invocation (evidence
line in `reconcile_orphans.jsonl`) → zero active; OFF SHA `908ec1dd…` bound.
**10582 requal APPLIED** (event 340695, journal `fabb35a3…`, row fresh
Q08/pending). **Q02 disposition repair APPLIED** (10 rows done/PASS incl.
12535 GDAXI 621-trade + 9940 SP500; backup + receipt `9fa981ac…`, commit
c7fbc7a2b-adjacent). **Q06 wave-1 requeued** (exact 5 incl. 20039 NDX,
journal `q06_wave1_requeue_snapshot_20260802T0733Z.json`).

**T_Live window (executed ~08:15–08:35Z):** signed 8-file deploy executed
(bash-pipe output loss + independent verification; registry-drift fresh
review append-only-clean), OWNER re-init 08:24:21Z, **§2 gate 10/10 PASS**,
pulse `loaded_ok=23/24; dormant=0`. Evidence
`2026-08-02_ks_deploy_execution.md` + decision record
`decisions/2026-08-02_t_live_ks_recompile_deploy.md`. Topic B CLOSED.

**Blocker found at rebind:** the activation contract requires releasing
exactly the seven July restart holds, which were consumed 2026-07-31 (nonce
ledger, 1 row) — a full Factory_ON now fails closed at its final gate; the
prep window had also expired. Fresh OWNER preparation decision minted from
the in-session package authorization (10 workers, empty hold plan):
`2026-08-02_factory_preparation_owner_decision.json` (commit 8f8b77b06).

| # | Topic | Author | Reviewer/Implementer | State |
|---|---|---|---|---|
| F | Generation-aware restart-hold release contract (unblocks Factory_ON) | Claude (brief `CODEX_BRIEF_2026-08-02_factory_on_hold_contract_evolution.md`) | Codex Sol max (adversarial review ≥90 % then implement in-session) | R1 dispatched |
| G | MNT-043 bill apply: staged-binary adoption + bill-bound overlay tool (`apply_ks_vintage_bill.py`) + 17 rerun enqueue prep; recon found repo-tree EX5s still old + generic scanner cannot reproduce the 26-row bill + 10911/GDAXI Q06 lacks a Q05 PASS predecessor | Claude (rulings) | Codex Sol max builds; Claude runs the mutating apply + enqueues | R1 dispatched |
| H | Mailbox analyst chunk tuning 5/600 s with env overrides | Claude (spec) | Codex implemented, Claude re-tested (24 passed) | **CLOSED** (64125d64b; natural verification 2026-08-03 06:07) |
| I | 20007 GDAXI/NDX Q02 INFRA_FAIL diagnosis (read-only) | Claude (spec) | Codex Sol max | R1 dispatched |

## SUNDAY 2026-08-02 CONSOLIDATED AGENDA (work from here)

**OFF window (market closed, before broker reopen):**
1. Factory_OFF (no manifest) → wait zero active → bind fresh `FACTORY_OFF` SHA.
2. **10582 Q08 requal apply** (`q08_single_target_requal.py --apply`, contract
   `717bdea1…`, fresh dry-run must show zero blockers first).
3. **Q02 disposition repair apply** (`q02_disposition_repair.py apply`, plan
   `764a23d0…` / authority `5abc6260…`, date-gated to 08-02) — 10 rows
   failed/INFRA_FAIL → done/PASS incl. the hidden 621-trade case.
4. Q06 wave-1 requeue ONLY if a legitimate 5th eligible row exists
   (`requeue_stranded_infra.py --phases Q06 --wave 1` dry-run first).
5. **Decision rebind** via `build_runtime_activation_decision.py` — MUST bind
   the 10-worker policy sources (Factory_ON blob `85bd0a82`,
   runtime_activation blob `78fbca9c`) + all later commits to bound files
   (pump-gate revert, framed records, **worker-identity fix c4dc83a84:
   start_terminal_workers.py blob `bcf0833b`**). Fresh OWNER runtime decision.
   Also in the OFF window: re-run the DL-065 orphan-cascade query (READY PASS
   parents without successor) as the authoritative sweep for anything the five
   pre-fix workers dropped before their natural churn.
6. Factory_ON (10-worker cohort now required by the contract).

**T_Live window (after ON, still market-closed):**
7. Signed 7-file deploy per signature packet §1 (+ **10513 addendum §runbook if
   OWNER signs it**), preimage backups verified before any overwrite.
8. OWNER-controlled T_Live re-init.
9. §2 verification: 9/9 (or 10/10 with addendum) `KS_BASELINE_LOADED`,
   payload-hash==baseline-hash, INIT_OK/NEWS per identity, SHA equalities.
10. Swap-rate capture. 11. Post-window: pulse re-run (expect KS OK except
    10440 [+10513 if unsigned]); MNT-043 vintage overlay append for the 7
    deployed EAs + admission Q06/Q07 rerun enqueues per the bill.

Open OWNER items: 10513 addendum signature (optional), Agy OAuth refresh.

## Standing constraints (bind every topic)

- Factory keeps running; no Factory_OFF/ON as part of any topic; never T5, never
  T_Live process/AutoTrading mutation. T_Live file-side deploys (topic B) only
  SHA-verified per the standing go-live procedure, in the agreed safe window.
- Staged recovery requeues only (one stage per action, never bulk).
- Gate criteria are hard-bounded: no topic may silently redefine
  `challenge_ready`, Q08 semantics, or promotion rules. Where a design needs a
  gate-adjacent decision, it is surfaced as an explicit OWNER question.
- Display surfaces show Qxx only; stored legacy `P*` compatibility keys
  (public-data contracts) are never rewritten.
