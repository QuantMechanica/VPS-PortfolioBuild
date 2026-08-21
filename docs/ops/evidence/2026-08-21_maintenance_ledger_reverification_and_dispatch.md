# Maintenance ledger: live re-verification and dispatch — 2026-08-21

**Author:** Claude (orchestrator) · **Branch:** `agents/board-advisor`
**Ledger:** vault `Maintenance/Offene Punkte.md`, written 2026-07-28, 46 items (MNT-001…046)

## 1 · Why re-verify instead of dispatch

The ledger was three and a half weeks old. Its items are factual claims — counts, broken
tasks, stale files — and the factory moved a lot in between. Turning stale claims into work
orders would have spent agent capacity re-fixing things that were already fixed, and worse,
would have made the ledger look authoritative while being wrong.

Four read-only agents each verified twelve-ish items against the **live state** (farm DB,
`farmctl health`, scheduled-task state, filesystem, logs, git), with an explicit instruction
to quote the measured number and never restate the ledger's figure as if checked.

## 2 · Result

| Classification | Count |
|---|---:|
| RESOLVED — condition no longer holds | **17** |
| SUPERSEDED — overtaken by a later decision | **2** |
| PARTIAL — partly fixed, remainder named | **16** |
| OPEN — still true as written | **11** |

**A third of the ledger was already done.** Examples: NO_HISTORY residue 35 → **0**;
null-signal events ~3017/day → **3 in 24 h**; Q07 seed-auth failures **0/69**; T5 back in
the fleet since 2026-07-31; live supervisor and watchdog both running (the ledger's
"stale" reading was task code `0x41301`, which means *running*, not failed).

## 3 · The structural finding

Before today, **zero router tasks carried a `QM-TODO` id.** The vault ToDo system and the
`agent_tasks` router were disconnected: a checkbox tagged `@Codex` executed nothing. The
five FTMO ToDos on the programme page had been correctly tagged for weeks and were never
dispatched — which is also why the maintenance ledger sat untouched since 2026-07-28. It
was an inventory, never a work queue.

**Convention introduced:** every dispatched task carries `vault_todo_id` in its payload, and
every vault ToDo line carries a `Router-Task:` line. A ToDo without a router task is noted,
not commissioned — and that distinction is now stated on the ledger, in the AI-ToDo index,
and on the FTMO page (whose five ToDos are deliberately *not* dispatched yet, because Codex
already holds 16 open tasks).

## 4 · Dispatched (15 router tasks)

| MNT | Task | Prio | Core measured fact |
|---|---|---|---|
| 011 | `df0cfed8` | 94 | dirty guard blocks the build lane with the factory's own output |
| 020 | `663ba5f6` | 88 | **327 EAs** have `ZERO_TRADES` on their latest Q02 |
| 038 | `8d0726d7` | 86 | 275 pairs each burned ≥ 12 backtests on the same defect |
| 006 | `e95271d7` | 84 | those 275 need cause-class disposition (after 038) |
| 030 | `ee125790` | 82 | `source_pool_drained` = FAIL, **0** pending sources |
| 030 | `7f48a274` | 80 | @Antigravity: refill the source pool itself |
| 039 | `2c9179ac` | 80 | limbo **grew** to 726 stranded, 571 older than 3 days |
| 013 | `875bd3b0` | 78 | 365 unbuilt cards (was 445, and 813 on 08-16 — draining) |
| 009 | `95f7c689` | 76 | 70/167 recent INFRA rows lack `evidence_path` |
| 003 | `9226799b` | 74 | permanent non-zero task result masks a real outage |
| 026 | `4f3943b3` | 72 | no test proves the dedup path cannot return false CLEAN |
| 016 | `23922c21` | 70 | historical taxonomy contamination, derived-view restamp |
| 031 | `9abed1bd` | 68 | 74 branches, 65 without upstream, ~1,014 unpushed commits |
| 032 | `c1c56bb6` | 66 | governor does not read real disk/RAM headroom |
| 035 | `f5bbd3a9` | 64 | watchdogs still disagree outside the health contract |
| 012 | `c96cef85` | 60 | two cards' R3 frontmatter contradicts their own body |

## 5 · Claude-owned (8) and OWNER-bound (4)

Claude keeps MNT-021, 024, 027, 033, 034 (residual report), 036, 042, 044.
**MNT-025 was closed today** — see §6.

OWNER-bound and recorded on the decision surface without blocking anything: MNT-045 (tester
news-filter semantic), MNT-001 (one missing KS baseline — 23/24 restored, was 0/24),
MNT-022 (FTMO go/no-go; recommendation: no challenge purchase), MNT-043 (noting only).

## 6 · Closed today by Claude — MNT-025, which the vault rebuild had made worse

The 2026-08-21 vault rebuild renamed the gate pages to the Qxx series and retired the root
open-items page. Four **active** agent prompts still pointed at the old names, so headless
agents were being told to read files that no longer exist:

- `prompts/claude_research_source.md:11` → `G0 Research Intake.md` → now `Q00 Research Intake.md`
- `prompts/claude_review_ea.md:12`, `prompts/codex_build_ea.md:14` → `P1 Build Validation.md` → now `Q01 Build & Spec.md`
- `run_agent_orchestration_task.py:196` → `_OPEN ITEMS.md` → now `12 ToDo/_INDEX.md`

Fixed in `9d372216b`. The important part is the blind spot behind it: **the vault linter
checks vault-internal wikilinks only**, so a repo file naming a vault page is invisible to
it — the rebuild could break these and the linter still returned PASS. Added
`tools/strategy_farm/check_repo_vault_refs.py`, which scans the other direction: **24
references checked, 0 broken** after also repointing an archived `Strategie Links.md`
reference (`4eae23421`).

## 7 · Errors found in the July ledger

- **MNT-017** claimed "14 candidates"; the adjudicated cohort was **13** (8 + 5) — a
  miscount at the time of writing, not a later change.
- **MNT-028** ("31 broken links") over-scoped the work: the links lived on a root page that
  was itself a rebuild candidate. The fix was archiving, not repairing.
- **MNT-030/018/021** carried point-in-time snapshots as literals (source pool 7 → now 0,
  cards 445 → 365); acceptance has since been re-pinned to invariants.
- **MNT-043** implied a *verdict* risk from stale binaries; the later causality study
  ("recompiles change streams, not verdicts") refuted that.
- **MNT-044**'s live-sleeve claim is outdated in one direction and understated in another:
  13128/NDX is **not** on stale evidence (fresh Q07 PASS 2026-08-05, variance 27.38 %), but
  **1556/XAUUSD carries `variance_pct = 0.00`** — the signature of seeds that never took
  effect. 1556 is one of the three probation sleeves due 2026-09-06, so its Q07 evidence is
  now folded into the MNT-036 package.
- One agent reported `agents/board-advisor` as "~10k commits behind main". Measured: **27
  ahead of `origin/main`, 0 behind**; local `main` is stale at 2026-08-12. The claim was a
  misread against the stale local branch and was not acted on.

## 8 · Verification

Vault linter after all edits: `Company Reference lint: PASS`.
Reports: session scratchpad `mnt_verify_A|B|C|D.md`; dispatch record `dispatch_result.json`.
