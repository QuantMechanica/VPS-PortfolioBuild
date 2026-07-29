# MNT convergence round 4 — Codex positions

- Date: 2026-07-29
- Router task: `3fbc789c-19fa-4375-ad05-63239dedb15d`
- Predecessor: `6a1811dd-0adb-41a7-a4c9-a9dc63a22a5b` (APPROVED)
- Scope: position round only; no implementation
- Repo snapshot used for checks: `agents/board-advisor@b65ec9eb7`
- Factory database checks: SQLite URI `mode=ro`
- G: state during review: drive absent

## Executive position

| Topic | Agreement on solution + acceptance | Priority position | Result |
|---|---:|---|---|
| MNT-020 | 96% | P1 | Accept all four corrections, but retain the handle cache as a hypothesis until a same-indicator A/B probe proves it. |
| MNT-024 | 94% | P2 | Accept; specify a real `qm-admin` execution contract and a status schema. |
| MNT-025 | 97% | P2 | Accept; use scoped three-state preflight, not a global lane stop. |
| MNT-027 | 98% | P2 | Accept both requested matrix extensions. |
| MNT-028 | 94% | P2 | Accept; baseline must be a versioned artifact, and the G:-bound runner must be named. |
| MNT-029 | 97% | P2 structural; MNT-003 is the P1 outage dependency | Accept Claude ownership; renderer must not turn source failure into an empty feed. |
| MNT-030 | 98% | P1 while the lane is down | Accept dependency `MNT-003 -> MNT-030`, but MNT-003 is necessary rather than sufficient. |
| MNT-031 | 99% | **P1** | Accept promotion and the proposed immediate integration step, refined to preserve ancestry. |
| MNT-032 | 93% | P1 incident / P2 hardening | Accept the design; refute the quoted threshold/date details from current code. |
| MNT-033 | 97% | P2 | Accept an integrated generated view, not a third manually maintained authority. |

All ten positions exceed the 90% convergence threshold after the refinements
below.

## Evidence index

**E1 — Round contract and current ledger.** The inlined source text and Claude
positions are in
`docs/ops/CODEX_BRIEF_mnt_review_round4_2026-07-29.md:3-91`. The convergence
ledger records 36/46 converged after round 3 and identifies exactly these ten
topics as round 4:
`docs/ops/MNT_CONVERGENCE_LEDGER.md:1-45`.

**E2 — BarsCalculated cohort, parsed rather than grepped.** A read-only lexer
probe stripped comments, block comments, strings, and character literals before
matching `BarsCalculated(` under `framework/EAs`. At 2026-07-29 08:47+02:00 it
found 30 call-site files / 30 EAs. A read-only DB join found 28 without a Q02
PASS and 23 with at least one ZERO_TRADES row. This exactly reproduces the page
counts. Targeted DB rows showed:

- `QM5_20143`: seven completed Q02 `INFRA_FAIL`, zero strategy verdicts;
- `QM5_20144`: nineteen completed Q02 `INFRA_FAIL`, zero strategy verdicts;
- `QM5_11912`: eleven Q02 PASS rows;
- `QM5_20102`: two Q02 PASS rows;
- `QM5_20096`: three Q02 ZERO_TRADES rows.

The cohort source call sites are visible with
`rg -n "BarsCalculated\\s*\\(" framework/EAs -g "*.mq5" -g "*.mqh"`.

**E3 — 20096 gate path and cache hypothesis.** The committed canonical 20096
source still contains `TEMP DIAG` at lines 241, 300, 349, 401, 639, and 643.
Its no-trade filter tests `BarsCalculated` at lines 289-293, while the first
indicator-buffer reads in the entry path occur only at lines 333-338:
`framework/EAs/QM5_20096_ha-stoch-h4-swing/QM5_20096_ha-stoch-h4-swing.mq5`.
The common cache is a process-global key/handle array with linear
`QM_IndicatorsLookup` and `QM_IndicatorsRegister` at
`framework/include/QM/QM_Indicators.mqh:45-83`; the MA and Stochastic wrappers
reuse it at lines 270-278 and 443-452.

**E4 — Vault execution environment.** A read-only probe at
2026-07-29 08:48+02:00 returned `DriveGExists=false` and
`VaultRootExists=false`. No `vault_lint` implementation is present in the repo
snapshot (`rg -ni "vault_lint|vault linter" C:/QM/repo`). The existing unreadable
links task documents the correct precedent: it runs interactive `qm-admin`
because G: is user-bound and retries a delayed mount:
`docs/ops/SCHEDULED_TASKS_INVENTORY.md:73`.

**E5 — Active stale-path consumers.** Current executable prompts still name the
legacy targets:

- `_OPEN ITEMS.md`: `tools/strategy_farm/run_agent_orchestration_task.py:154`;
- `P1 Build Validation.md`:
  `tools/strategy_farm/prompts/codex_build_ea.md:14` and
  `tools/strategy_farm/prompts/claude_review_ea.md:12`;
- `G0 Research Intake.md`:
  `tools/strategy_farm/prompts/claude_research_source.md:11`.

**E6 — Q04 and Q08 contracts.** Q04 declares `venue_cost_model.json` as the
OWNER-ratified primary cost truth, keeps flat $7 only as an explicit reproduction
variant / hard fallback, defaults to DXZ worst case, and records cost provenance:
`framework/scripts/q04_walkforward.py:42-51,495-519,1104-1112,1183-1191`.
Q08 binds cached evidence to the exact baseline path/hash and strategy-parameter
count, and classifies absent/duplicate/empty strategy parameters as a
deterministic blocking setfile defect:
`framework/scripts/q08_davey/aggregate.py:141-225,267-302`.

**E7 — OWNER feed and morning brief freshness.** The cockpit reads
`D:/QM/reports/state/owner_decisions.json`, documented as Claude-maintained, but
swallows every read/parse exception with `except Exception: pass`:
`tools/strategy_farm/render_cockpit.py:51,833-858`. The live file reports
`updated_at_utc=2026-07-23T15:44:25Z`; all 14 items use only
`cat,title,detail,due,severity`—zero have an ID, status, execution receipt, or
verification field. The rendered
`D:/QM/strategy_farm/dashboards/morning_brief.md` was last written
2026-07-28 06:00+02:00 and still displayed action items due 2026-07-26.
`morning_brief.py` calls the same cockpit reader at lines 978-1003.

**E8 — agy/mailbox outage and source pool.** Read-only Scheduled Task state at
2026-07-29 08:45+02:00 showed all three as `qm-admin` / `Interactive` / Ready
with last result `0x800710E0`:
`QM_StrategyFarm_AgyGovernor`,
`QM_StrategyFarm_MailboxSourceIntake_Daily`, and
`QM_StrategyFarm_GeminiOrchestration_15min`. The install contracts explicitly
bind agy DPAPI credentials and mailbox Codex/agy credentials to the interactive
profile:
`tools/strategy_farm/install_agy_governor_scheduled_task.ps1:14-35` and
`tools/strategy_farm/install_mailbox_source_intake_task.ps1:4-31`.
The Gemini lane heartbeat and `agy_quota.json` were both 63.3 hours old; the
read-only source census was 7 pending / 89 done / 6 blocked.

**E9 — integration truth.** At 2026-07-29 08:49+02:00:

```text
git rev-list --left-right --count origin/main...agents/board-advisor
4       1751
git worktree list --porcelain
75 worktrees; 48 dirty (read-only status census)
```

The four `origin/main`-only commits are `f4edf200a`, `f51a8d100`,
`1271943d6`, and `1c486f747`; they touch six documentation/evidence files.
The factory branch head was `b65ec9eb7`. Local `main` is not a safe integration
proxy: it is separately divergent from the factory branch (25 / 2733).

**E10 — purge contract and live pressure.** The installer schedules every 20
minutes:
`tools/strategy_farm/install_tester_cache_purge_scheduled_task.ps1:1-19`.
The purger defaults `LowWaterGB=150`, with an inline record that it changed
80 -> 150 on 2026-07-21, and no-ops only when free space is `>= LowWaterGB`:
`tools/strategy_farm/tester_cache_purge.ps1:11-28,110-113`. It protects active
terminals, limits deletion to idle `T1..T10/Tester` caches, and preserves
captured Factory state at lines 64-101 and 115-215. At
2026-07-29 08:50+02:00 D: had 44.5 GB free and the purge task's last result was
`0x800710E0`.

**E11 — existing ledger fragments.** The MNT convergence ledger is explicitly
Claude-maintained and covers per-topic agreement/open dissents:
`docs/ops/MNT_CONVERGENCE_LEDGER.md:1-10,38-45`. The OWNER feed is a distinct
Claude-curated authority but currently has no stable item IDs or lifecycle
fields [E7]. Router/database state already holds stable task IDs, states,
artifacts, verdicts, and timestamps; the round-3 predecessor row is APPROVED
with artifact
`C:/QM/repo/docs/ops/evidence/2026-07-29_mnt_round3_positions.md`.

## MNT-020 — repair the BarsCalculated-first cohort

**Agreement: 96%. Priority: P1.**

Responses to Claude's four corrections:

1. **ACCEPT — parse call sites, not strings.** The parsed probe reproduces
   30/28/23 [E2]. A raw grep happens to return the same 30 in this snapshot, but
   that coincidence is not a linter contract; comments and diagnostic strings
   must never alter cohort membership.
2. **ACCEPT — remove `TEMP DIAG` before rebuild.** It remains in the canonical
   20096 source [E3]. Cleanup must precede source hashing and MNT-043 rebuild;
   otherwise the supposedly clean rebuild permanently embeds temporary
   instrumentation and changes the identity again when it is later removed.
3. **ACCEPT — 20143/20144 require infra triage first.** Their only completed Q02
   results are INFRA_FAIL [E2]. They cannot confirm or refute a strategy-path
   hypothesis until a real control run exists.
4. **ACCEPT the merged probe plan; REFUTE promotion of the cache from
   "main suspect" to established root cause.** The shared lookup/register cache
   is real [E3], while 11912 and 20102 prove that BarsCalculated can become
   positive in this environment [E2]. They do not isolate the cache: 11912 is a
   custom ZigZag handle and 20102 proves only the MA path, not the failing
   MA+Stochastic combination. Require a same-source/same-symbol A/B probe that
   changes only cache reuse versus fresh handles (or performs a controlled
   first `CopyBuffer`) before naming the root cause.

Improved acceptance:

- Classify control flow, not mere API presence: handle creation, first
  `BarsCalculated`, first buffer read, retry path, and permanent-error path.
- Bind every triage result to source SHA, EX5 SHA, symbol, period, terminal, and
  report/work-item ID.
- A permanent `-1` must emit bounded retry/error evidence and become
  INFRA/implementation triage, never silent ZERO_TRADES.
- Use 11912/20102 as environment controls, then a 20096-specific A/B as the
  causal test. The cohort rebuild remains coupled to MNT-043.

## MNT-024 — canonical Vault navigation

**Agreement: 94%. Priority: P2.**

**ACCEPT Claude's implementability question with a condition.** Reading target
frontmatter is straightforward only after the contract defines a status key and
closed enum (`CURRENT`, `HISTORICAL`, `STALE`, `PENDING_REWRITE`, `ARCHIVED`).
Fuzzy scanning of headings/prose is not a durable check. Because no repo-side
`vault_lint` implementation exists and G: is absent [E4], the page must name the
runner rather than merely promise a rule.

Execution contract:

- Run the Vault-truth check in a scheduled interactive `qm-admin` context after
  a root-sentinel/mount preflight, following the proven user-bound pattern [E4].
- Persist JSON + human summary outside G: so a failed mount still leaves
  evidence.
- Allow a repo-fixture unit test anywhere, but never treat that fixture as proof
  that the live Vault is sound.
- During metadata migration, baseline legacy pages explicitly; block only new
  unlabeled canonical-navigation violations.

No material dissent remains once the execution principal, target-status schema,
and durable output are acceptance criteria.

## MNT-025 — repair broken active Vault paths

**Agreement: 97%. Priority: P2.**

**ACCEPT Claude's error-class correction.** Active consumers still carry the
three legacy names [E5], while the entire G: drive is currently absent [E4].
Those observations demonstrate why absence of the mount must not be translated
into proof that a target is missing.

Refined fail-closed semantics:

- `MOUNT_UNAVAILABLE`: WARN globally; defer only the action that requires that
  Vault target. Do not stop unrelated lane work, and do not proceed using an
  unverified page.
- `TARGET_MISSING`: hard failure after the mount/root sentinel is proven healthy.
- `TARGET_INVALID`: hard failure when the target exists but is historical,
  stale, pending rewrite, or schema-invalid for an active instruction.

Every job preflight must emit one of those codes plus root, target, timestamp,
and runner identity. This is scoped fail-closed behavior, not the false choice
between "continue blindly" and "kill every lane."

## MNT-027 — synchronize Q01–Q10 gate documentation

**Agreement: 98%. Priority: P2.**

1. **ACCEPT Q04 cost contract in the matrix.** The code now makes
   `venue_cost_model.json` primary and flat $7 an explicit fallback/reproduction
   path [E6]. "Already solved" is not a reason to omit it: the matrix must pin
   the selected venue variant, fallback policy, provenance fields, tests, and
   effective date so documentation cannot regress to the old flat cost.
2. **ACCEPT Q08 `strategy_*` baseline parameters in the matrix.** Q08 hashes the
   baseline and requires a strategy-parameter count; empty/duplicate/empty-value
   parameters are deterministic blocking defects [E6]. This is part of the
   gate input contract, not a set-generator footnote.

Improvement: each matrix row needs `decision_id`, authoritative text, code path,
positive test, negative test, verdict/evidence schema version, effective-from
timestamp, and legacy-evidence rule. A document version alone cannot satisfy
"every verdict names the gate version"; the emitted verdict artifact must carry
the gate-contract version and effective date. No dissent remains on the two
requested additions.

## MNT-028 — renew the Company manifest and Vault linter

**Agreement: 94%. Priority: P2.**

**ACCEPT both Claude additions.**

- The runner must use the G:-capable interactive `qm-admin` contract and leave
  an off-Vault result [E4].
- The manifest should link the MAINTENANCE section and the convergence ledger.
  It should not copy their changing status into a second authority.
- The broken-link baseline must be a reviewed, versioned data file containing
  normalized source, target, classification, justification, first-seen, and
  expiry—not literals hidden in linter code.

Improvement: distinguish internal missing targets, external access-denied URLs,
and intentionally archived links. Bind each run to manifest version, baseline
hash, Vault root identity, runner principal, and timestamp. Block new internal
breakage; require an explicit baseline change to forgive an old one.

## MNT-029 — keep OWNER decisions and Morning Brief fresh

**Agreement: 97%. Priority: P2 structural; MNT-003 remains the P1 outage
dependency.**

**ACCEPT Claude's ownership correction.** Claude remains the authority that
writes/curates OWNER decisions; automation renders and validates. The concrete
stale source is `D:/QM/reports/state/owner_decisions.json`, last logically
updated 2026-07-23, while the last rendered brief is from 2026-07-28 [E7].

Material current defect: the reader silently converts missing/malformed feed
state to no curated rows [E7], violating "generator failure != empty source."
Required architecture:

- Claude writes stable decision IDs, OWNER answer, status, and supersession.
- Execution agents append receipts and verification references keyed by that
  ID; they do not rewrite the OWNER answer.
- The renderer joins those sources and emits source timestamp/status
  (`FRESH|STALE|MISSING|INVALID`) prominently.
- Closed items disappear from the open list only after an execution receipt and
  required verification, while remaining available in history.

## MNT-030 — restore agy mailbox and source lane

**Agreement: 98%. Priority: P1 while the lane is down.**

**ACCEPT dependency `MNT-003 -> MNT-030`.** The live agy, mailbox, and Gemini
tasks are correctly configured as interactive `qm-admin` yet all return
`0x800710E0`; heartbeats are 63.3 hours stale and the source pool is seven [E8].
Applying the MNT-003 task-contract package is therefore a prerequisite.

One refinement: MNT-003 is necessary, not sufficient. MNT-030 closes only after
separate credential-decrypt, mount, mailbox delivery, consumer, acknowledgment,
and completion tests pass. A scheduler success alone must not refresh the
business heartbeat. Record separate timestamps for attempted wake, successful
credentialed action, source delivery, acknowledgment, and completion, plus
separate SLOs for source inventory and approved-card inventory.

## MNT-031 — establish repo/worktree/integration truth

**Agreement: 99%. Priority: P1 — accept Claude's promotion.**

The measured divergence has worsened since Claude's snapshot:
`origin/main...agents/board-advisor` is now 4 / 1,751, with 75 registered
worktrees and 48 dirty [E9]. This makes a generic "merged to main" assertion
ambiguous and can authenticate the wrong code/evidence. P1 is warranted.

**ACCEPT the immediate step, refined to preserve fast-forward ancestry:**

1. OWNER authorizes an integration window and captures immutable backup tags /
   bundle plus the exact `origin/main` and factory heads.
2. Use a clean integration worktree at `agents/board-advisor`; merge the four
   `origin/main`-only commits into it (do not merely cherry-pick them), resolve
   and verify. A real merge makes `origin/main` an ancestor.
3. After contract tests and a factory-path/commit check, fast-forward
   `origin/main` to that verified merge commit. Do not use the separately
   divergent local `main` worktree as the source.
4. Repoint/pin runners and dashboards to the single canonical ref+SHA, then
   inventory unique worktree commits with owner/lifecycle before any archive or
   removal.

This is an OWNER-authorized integration operation, not work for this position
round. No merge/push/worktree cleanup was performed.

## MNT-032 — harden disk, RAM, and cache purge

**Agreement: 93%. Priority: P1 incident while D: is near the stop threshold and
the purge task is failing; P2 for the structural hardening after recovery.**

Responses to Claude's context:

- **ACCEPT** that the existing purger should be hardened rather than replaced.
  It already protects active slots, scopes factory terminals, limits cache
  targets, and restores captured owner state [E10].
- **ACCEPT** the 20-minute cadence [E10].
- **REFUTE** "No-Op >80 GB." Current code no-ops at `free >= 150 GB`.
- **REFUTE** "LowWater 150 stable since 07-14." The canonical inline change
  record says 80 -> 150 on 2026-07-21 [E10].

The live 44.5 GB free-space reading and failing purge task make recovery urgent
[E10], but the launch outage belongs to MNT-003. Structural MNT-032 acceptance
should add: resolved-path containment under exact idle `T1..T10/Tester` roots,
per-target before/after byte counts, negative/implausible reclaim as telemetry
error, fault-injection for protected active slots and captured Factory state,
and a concurrency governor driven by measured disk/RAM headroom. Reports,
verdicts, registries, source ticks, active tester directories, and all live
terminals must remain technically outside the deletion set.

## MNT-033 — introduce a measurable milestone ledger

**Agreement: 97%. Priority: P2.**

**ACCEPT Claude's integration architecture correction.** The convergence ledger
already owns MNT agreement/dissents, and `owner_decisions.json` already owns
curated OWNER calls [E11]. A third manually edited ledger would create another
reconciliation problem.

Use a generated milestone view:

- MNT convergence stays in the convergence ledger.
- OWNER authority stays in an upgraded decision feed with stable IDs.
- Execution state/receipts stay in router/database evidence keyed by task ID.
- A renderer joins those sources into milestones with owner, measurable DoD,
  current evidence, remaining criteria, dependencies, target date, confidence,
  next review, and per-source freshness/provenance.
- Human authorities set outcome/approval; automation computes runtime values and
  remaining machine-checkable criteria.

The current OWNER feed has no IDs/status/receipts [E7], so schema linkage is a
prerequisite. Acceptance should explicitly reject duplicate unlinked records and
show technical completion, gate clearance, and live authorization as separate
states.

## Final verdict

`ROUND4_POSITIONS_READY_FOR_REVIEW`

The four material Claude corrections for MNT-020 are accepted with causal-proof
wording tightened; both MNT-027 matrix additions are accepted; MNT-031 is
promoted to P1 with a preserving-ancestry integration strategy; and the MNT-032
threshold/date assertions are corrected from canonical code. No code,
scheduled-task, Factory, terminal, or live-trading mutation was performed for
this position round.
