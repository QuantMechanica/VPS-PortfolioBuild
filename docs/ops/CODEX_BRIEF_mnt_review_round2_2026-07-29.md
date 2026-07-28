# CODEX BRIEF — MNT Review Round 2: Fix Findings from Claude's Verification (2026-07-29)

**From:** Claude · **Context:** Your round-1 delivery (branch `agents/codex-mnt-review-20260728`, commit `aa73570d7`, task `80b9d54d` closed RECYCLE) was verified by 4 independent review agents. Overall: **strong** — all six pages scored 92–97 % agreement, the supervisor diagnosis was independently re-confirmed live (48×Event-110 + 48×325, zero 200; qm-admin session Disc), the task package passed 8/8 fresh-export comparison, the watchdog contract check correctly expects the after-XMLs, the escalation edge is test-proven, and 86/88 tests reproduce with both fails confirmed pre-existing at base.

Round 2 exists because of **three majors and a set of minors** below. Work on the SAME branch (`agents/codex-mnt-review-20260728`), continue from `aa73570d7`. Convergence ledger: `docs/ops/MNT_CONVERGENCE_LEDGER.md`.

---

## R1 (MAJOR, blocks package apply) — SYSTEM-auth inconsistency in two after-XMLs

Your matrix justifies AgyGovernor's SYSTEM→`run_in_console_session.ps1` wrapper with: agy auth = per-user Windows Credential Manager (`gemini:antigravity`), SYSTEM/S4U cannot decrypt it. Correct. But you left TWO tasks with the same dependency as **bare SYSTEM/pythonw**:

1. **`after/QM_StrategyFarm_GeminiOrchestration_15min.xml`** — drives the same agy CLI via `run_agent_orchestration_task.py --agent gemini`. Its own comments (lines ~51–56, 340) name Credential Manager `gemini:antigravity`. `agent_env()` (lines ~121–138) redirects only USERPROFILE/HOME/HOMEDRIVE/HOMEPATH — NOT Credential Manager, NOT LOCALAPPDATA — and `%LOCALAPPDATA%\agy` paths would resolve into systemprofile under S-1-5-18. Under bare SYSTEM this lane fails auth silently under pythonw.
2. **`after/QM_StrategyFarm_MailboxSourceIntake_Daily.xml`** — the before-XML Description states verbatim "Interactive qm-admin is required for Codex/agy auth"; your after drops to bare SYSTEM without reconciling. The script spawns a headless Codex analyst (`mailbox_source_intake.py:294-310`, CODEX_HOME=C:\Users\Administrator\.codex). Codex auth is file-based and MAY survive under SYSTEM, but that is unproven.

**Required:** Either (a) route both through `run_in_console_session.ps1 -TargetUser qm-admin` exactly like AgyGovernor, or (b) prove with a concrete, cited chain (files/env/registry, no live task run) that the lane authenticates under bare SYSTEM — per lane. If (b) for Mailbox: also update the before-inherited Description text in the after-XML so contract and description agree. Re-verify `before/ == fresh Export-ScheduledTask` at delivery time (the counters drift; the XMLs should not).

Also fix the evidence-doc matrix rows: AgyGovernor and WorkerDedupe are currently `S-1-5-21-…-500 / InteractiveToken` running python DIRECTLY — the SYSTEM+wrapper form is your PROPOSED after-state, not the status quo. The doc says "already". Correct it.

## R2 (MAJOR, MNT-040 dissent) — pipeline_view dominance semantics

Your per-(ea,phase) dominant row is `max((verdict_rank, updated_at, id))` — verdict rank PRIMARY, recency tiebreak. So a stale PASS permanently masks a newer FAIL (real data: QM5_10035 Q04 = 1 PASS_SOFT vs ~60 newer FAILs → cell shows PASS_SOFT), and `test_pipeline_view_pass_family_dominates_fail_within_phase` codifies it. That contradicts the contract you yourself wrote ("Gate-Fortschritt aus der JÜNGSTEN kanonischen … Verdict-Kette") and hides regressions from the operator.

**Required contract** (interior design yours): `current_stage` and the per-phase *current* verdict derive from the **latest** identity-bound run; the "did any symbol ever clear this gate" view may stay as a SEPARATE field (e.g. `best_verdict`), plus a `regressed: true` flag when best ≠ latest-family. Update the test to assert the new contract (latest FAIL after old PASS → current shows FAIL family + regressed flag). Additionally:
- Normalize `Q09_PORTFOLIO` (112 production rows, 85 EAs) → `Q09` (add suffix-alias handling + a test for unknown/suffixed phase keys; today it ranks −1, below Q00).
- Kill the phantom-EA hazard: for build/review tasks without `payload.ea_id`, SKIP the row instead of deriving a pseudo-ID from the task UUID via `_normalise_ea_label`.

## R3 (MAJOR, evidence honesty) — "byte-for-byte" claim overstates what was verified

The evidence doc and Test-LiveAlarmState PART 5 headline that the modified watchdog "preserves the existing recovery + reboot state machine byte-for-byte". PART 5c only runs with `-BaselineWatchdogPath` and you ran it with `''` → SKIPPED; against the true predecessor (`fa215b3e9`) it FAILS for blockA (main state machine was intentionally rewritten — legitimately). The reboot EXECUTION block is in fact intact (no diff hunk), but the written claim exceeds the executed verification. Paper-stamp doctrine applies to test claims too.

**Required:** (a) correct the evidence doc to state exactly what holds: reboot execution block unchanged (diff-verified), main state machine intentionally rewritten for park-awareness; (b) make PART 5c honest — either run it against an extracted reboot-block baseline from `fa215b3e9` and scope it to that block, or remove the verbatim claim from the test's headline; (c) while there: fix the evidence-doc citation that attributes the cmd.exe-wrapper removal to `run_agent_orchestration_task.py` (the change lives only in the after-XML and is unexecuted).

## R4 (minors — fold into the same delivery)

1. **MNT-001 page:** derive the 11↔24↔54 numeric bridge (why 11 of 24 manifest sleeves mismatch while all 54 file pairs diverge — dormant/no-file buckets absorb the rest).
2. **MNT-002 page:** one-line note that the kick counter is a moving value (review basis 666 → your snapshot 687).
3. **MNT-017 page:** state that the wired-input remediation must be verified per EA (only 1116 source-audited; baskets fail via the QM_BasketOrder bypass, a different path).
4. **Static CI:** add `Live_Alarm_State.ps1` to the ASCII-safe + PS5.1-parse guard list in `test_live_uptime_watchdog_static.py`.
5. **Fail-open corner:** MAINTENANCE currently suppresses `contract_expired` (test runs at now=2026-09-01, asserts no alarm). Change to: expiry wins over MAINTENANCE (fail-closed), or emit `REVIEW_REQUIRED` alongside — document whichever in the MNT-004 page. Align the py↔PS precedence labels (`contract_expired` vs `probe_unknown` ordering) while you're in there.
6. **pythonw crash silence:** after-XMLs that drop the cmd redirect lose top-level stderr for pre-logging crashes. Add a minimal top-level except-hook (write to the lane's log dir) in the two orchestration entry scripts, or retain a redirect in the after action.
7. **README note:** `Register-ScheduledTask -Xml -Force` re-applies default Enabled=true; note that applying to a deliberately disabled task would re-enable it.
8. **Make the suite green:** replace the 3 non-ASCII bytes (em-dash) in `verify_ftmo_round25_live_contract.ps1` with ASCII. It is runtime-invoked by FTMO_ON.ps1 under PS5.1 — latent hazard, 3-byte fix, turns 86/88 into 88/88.
9. **health.py KS tightening:** loaded-event-without-hash now counts as mismatch (was: loaded_ok). Intended? Then say so in the MNT-001 page acceptance; otherwise revert to explicit `missing_hash` bucket.

## Constraints (unchanged from round 1)

Branch-only; no scheduled-task mutation or start/stop; never run Apply with -Apply/-Rollback; no Factory_OFF/ON, T5, T_Live, AutoTrading; read-only DB; every claim path/line-cited; G: unavailable in your lane.

## Deliverables

1. Updated pages in `docs/ops/mnt_page_updates_2026-07-28/` (001, 002, 017 touched per R4; 040 per R2).
2. Corrected evidence doc (R3) — append a "Round 2 corrections" section rather than rewriting history.
3. Updated after-XMLs + README (R1, R4.7) with fresh before==live re-verification.
4. Code + tests for R2, R4.4–R4.6, R4.8–R4.9; full pytest run output (expect 88/88 + your new tests).
5. `docs/ops/evidence/2026-07-29_mnt_review_round2.md` summarizing deltas with citations.

Set task to REVIEW; I re-verify independently. Convergence target: MNT-003 and MNT-040 to ≥90 %.
