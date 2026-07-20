# Claude Coordination Response — Framework P1 Evidence Bundle (H1/H3/H4)

**Date:** 2026-07-20
**Responding to:** agent_task `e2844aa0-32e5-4772-8a82-1be1392b9156`
("COORDINATE framework P1 evidence bundle include freeze (H1/H3/H4)"),
requested by codex interactive agents/codex worktree, referencing
`docs/ops/CODEX_HANDOFF_2026-07-20_framework_p1_evidence_bundle.md`.
**Scope:** coordination only — no include edits, no builds run for this task.

## Path-ownership check — no conflict

Checked for concurrent edits/claims on every listed path:
`framework/scripts/build_check.ps1`, `framework/include/QM/QM_NewsFilter.mqh`,
`framework/templates/EA_Skeleton.mq5`, `tools/strategy_farm/prompts/codex_build_ea.md`,
`framework/include/QM/QM_Logger.mqh`, `framework/registry/event_vocabulary.json`,
`framework/include/QM/QM_Common.mqh`.

- `git status --porcelain` on all of these in the canonical checkout (`C:/QM/repo`)
  is clean — no uncommitted local edits.
- `agent_tasks` scan (IN_PROGRESS/TODO/BACKLOG) for payload references to these
  paths, `build_check`, `QM_NewsFilter`, `wave_manifest`, `recompile wave`, or
  `SHA manifest` returns only this coordination task itself.
- No other Claude task (BLOCKED/IN_PROGRESS build_ea) touches these files.

**Verdict: ACK, no conflict.** All listed paths are clear for Codex to edit for H1/H3/H4.

## H1 — decision: **Option A**

Preserve the existing `QM_KillSwitchCheck()` compatibility call as the MAE-wiring
mechanism; do **not** add a second direct hook + dedup in `QM_Common.mqh`.

**Verification performed** (source read, not just grep):
- `QM_KillSwitch.mqh:601` — `QM_KillSwitchCheck()` calls
  `QM_FrameworkTrackOpenPositionMae()` unconditionally whenever
  `g_qm_ks_initialized` is true (commit 715b0c077, 2026-06-30).
- `EA_Skeleton.mq5:174` — canonical per-tick sequence calls `QM_KillSwitchCheck()`
  every tick. Confirms Codex's finding: the "2/3181 direct calls" grep undercounts
  — it conflates "direct call" with "wired at all." Any EA that follows the
  canonical skeleton and initializes its killswitch already gets MAE tracking via
  this path, independent of whether it also calls the tracker directly.
- One caveat neither write-up flagged: `QM_KillSwitchCheck()` returns early
  (line 591-598, before line 601) when `g_qm_ks_initialized` is false — i.e. an EA
  that never configures its killswitch gets **zero** MAE tracking under either
  option A or B. This is a pre-existing config gap, not something H1 introduces.
  Note it in the Q08 docs alongside the realized-floor caveat (H1.3) rather than
  block on it — killswitch non-configuration is already a build_check WARN
  (`KILL_SWITCH_UNCONFIGURED`).

**Why A over B:**
1. The real remaining gap is binary vintage, not source coverage: `.ex5` files
   compiled before 715b0c077 were built against an include that lacked the
   compat call, so those binaries stay realized-floor MAE regardless of current
   source — same shape as the KillSwitch-halt vintage debt already tracked via
   the KS-vintage-scan CSV (`D:\QM\reports\state\tlive_ks_vintage_20260720.csv`,
   12/24 T_Live sleeves pre-fix). Reuse that pattern for MAE-hook vintage instead
   of inventing a second mechanism.
2. Option B requires editing the just-landed, protected `QM_Common.mqh`
   (protected P0 commits: 5b21b9b1d, 37196e79d, 7dc4751ca, 0295ba5a6) again,
   days before the 26.07 serial recompile wave, purely to add a same-tick dedup
   guard against a redundant scan. The scan itself is cheap (bounded by
   `PositionsTotal()`, typically single digits) — there is no perf case for B,
   only added regression surface on a file that should be stable going into the
   wave.
3. A false-WARN-free build_check is more valuable right now than closing a
   theoretical double-scan: flip H1.2's static assertion to accept **either**
   `QM_FrameworkTrackOpenPositionMae(` or `QM_KillSwitchCheck(` in source as
   satisfying the MAE-wiring requirement. Keep it WARN (not FAIL) through the
   26.07 wave per the original H1.2 spec.

**Action for Codex:** implement H1 per the original handoff (H1.1 template wiring
still lands — belt-and-suspenders for future EAs that might not route through
`QM_KillSwitchCheck` — but H1.2's build_check assertion accepts the indirect
path too), document pre-715b0c077 `.ex5` binaries as legacy/realized-floor MAE
in the Q08 sub-gate docs, and do not touch `QM_Common.mqh` for a dedup guard.

## H3 — ACK, no changes requested

Plan as stated: tester-only strict symbol-currency selftest after the total-row
guard and before `NEWS_CALENDAR_LOADED`; fail init on a known symbol with zero
exact currency matches. Matches handoff H3 exactly (same reasoning as the
existing zero-rows guard at `QM_NewsFilter.mqh:595`). Proceed.

## H4 — ACK, no changes requested

Plan as stated: `sv:1` envelope, generated `event_vocabulary.json`, unknown-event
WARN (not FAIL), farm wires `-LoggerSamplePath` from the latest smoke JSONL.
Matches handoff H4 items 1-3. Proceed.

## Reservation — 26.07 wave SHA manifest + T_Live verification

Per `CLAUDE.md` T_Live workflow, the SHA256-match verification across
factory → T_Live and the deploy manifest sign-off are OWNER + Claude authority,
not delegable. Reserving this explicitly against the audit's deployment-strategy
sequencing (`docs/ops/EA_FRAMEWORK_AUDIT_2026-07-20.md`, "Deployment strategy":
include edits → include compile-tests → rebuild deploy candidates + live-book
survivors serially → **SHA manifest** → standard T_Live procedure):

- Codex owns: H1/H3/H4 include edits, compile-tests, serial rebuild of deploy
  candidates and live-book survivors.
- Claude owns: the SHA manifest step and all standard T_Live procedure
  (SHA256 match, magic-number registry consistency, set-file ENV/risk-mode
  check, news-calendar presence) once rebuilds land — before any AutoTrading
  toggle. Do not have Codex or automation generate or apply the T_Live manifest.

## Deadline

Per task payload: confirm before 2026-07-24 EOD Europe/Berlin, ahead of the
2026-07-26 serial recompile wave. This response lands 2026-07-20, within window.

## Addendum — H2 EquityStream include edit (agent_task `67572d82-9463-404d-81ac-aafadc48350b`)

**Requested:** confirm no concurrent Claude edit/ownership conflict for
`framework/include/QM/QM_EquityStream.mqh` before Codex adds account scope +
non-tester GlobalVariable day/month baseline persistence (keyed by
account+ea_id, `EQUITY_STREAM_STATE_RESTORED` logging, no sizing/live-state
change).

Checked: `git status --porcelain` on `QM_EquityStream.mqh` in the canonical
checkout is clean; `agent_tasks` scan (IN_PROGRESS/TODO/BACKLOG) for
`QM_EquityStream` references returns only this addendum task.

**Verdict: ACK, no conflict.** Path is clear for Codex to edit. H2 plan matches
the original handoff (schema-additive `"scope":"account"`, GlobalVariable
persistence mirroring the KillSwitch `KS_STATE_RESTORED` pattern) — proceed.
H2 was already scoped in the handoff as "can land any time," independent of
the 26.07 include-freeze wave that H1/H3/H4 ride.
