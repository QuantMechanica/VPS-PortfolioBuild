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
