# QM-TODO-20260821-201 — Qxx-only operator-facing health/monitor escalation text

Date: 2026-08-21
Router task: `32c66cc2`
Branch: `agents/board-advisor`

## Problem

Operator-facing health-check escalation strings emitted by
`tools/strategy_farm/health.py` combined the canonical `Qxx` gate id with the
legacy `P*` storage alias (e.g. `"275 Q02/P2 EA/symbol pairs have no non-infra
terminal disposition …"`). These strings flow into the operator surfaces:

`health.py` `_check(...).detail` / `.action_hint`
→ `farmctl.py health` JSON
→ `hourly_monitor.ps1` (line 74 `"FAIL:$($c.name):$($c.detail)"`) writes
  `D:\QM\reports\state\task_monitor_health.json`
→ folded back into `farmctl health` by `health._external_health_checks`
  (health.py:3633-3643)
→ `heartbeat_snapshot.py` `probe_health` → vault mirror
  `08 Current State/Heartbeat.md`.

The vault lint `00 Governance/lint_company_reference.py`
(`check_forbidden_active_terms`) flags any `P{0..10}` gate token in an active
(non-`_ARCHIV`) page. Its only FAIL was `Heartbeat.md` carrying the `Q02/P2`
token.

The Qxx-only rule is a hard-bounded operator-surface constraint (CLAUDE.md
"Specification Density Principle"; memory `feedback_qxx_only_in_user_surfaces`).
SQL phase keys, storage keys, and internal legacy-name lists must stay.

## What changed (source)

`tools/strategy_farm/health.py` — display/message strings only. No SQL,
threshold, verdict, docstring, or phase-key list touched.

- `chk_q02_stranded_exhausted_pairs` (two `_check` detail strings):
  - `"{stranded} Q02/P2 EA/symbol pairs …"` → `"{stranded} Q02 EA/symbol pairs …"`
  - `"no retry-exhausted Q02/P2 pair has vanished …"` → `"no retry-exhausted Q02 pair …"`
- `chk_unenqueued_eas_count` (detail + action_hint strings):
  - `"…waiting for P2 enqueue"` → `"…waiting for Q02 enqueue"`
  - `"…have no P2 work_items"` → `"…have no Q02 work_items"` (WARN + FAIL)
  - `"…enqueue up to 3 EAs into P2 per cycle."` → `"…into Q02 per cycle."`
  - `"Next pump cycles should enqueue P2 work_items."` → `"…enqueue Q02 work_items."`

Deliberately UNTOUCHED (verified by grep of remaining `\bP[0-9]` hits in
health.py — all are SQL / phases tuple / docstrings):
`WHERE phase IN ('P2','Q02')` clauses, the `chk_p_pass_stagnation` `phases`
tuple used as SQL placeholders (line ~2112), and docstrings documenting the dual
storage naming (lines 15, 689, 1775, 2205-2207).

Monitor emitters `hourly_monitor.ps1` and `morning_brief.py` were grepped:
no `P*` gate tokens in their own literal strings — they only echo `$c.detail`
from health, which is now clean.

## Stale-sidecar echo — one-time reset required

`task_monitor_health.json` is written by `hourly_monitor.ps1` from the health
detail at run time, and its `task_monitor_escalation` rows are folded BACK into
`farmctl health` and re-wrapped by the next monitor run. The historical
`Q02/P2` string therefore echoes perpetually and does NOT self-heal after the
code fix. Broken once by resetting the regenerable observation sidecar:

- Backup: `scratchpad/task_monitor_health.backup_1249.json`
- Removed `D:\QM\reports\state\task_monitor_health.json`, then re-ran
  `hourly_monitor.ps1` (its `farmctl health` saw no prior sidecar → no stale
  echo to fold → wrote a clean sidecar, `checked_at 2026-08-21T12:52:21Z`).

This is a generated observation artifact (not a verdict/trade stream); it
repopulates every hour. Note: the fold-then-rewrap echo is a pre-existing
design smell (duplicate/nested escalations) — out of scope here, left as-is.

## Vault ToDo page

`12 ToDo/AI ToDos/Codex.md` (the ToDo card for this task) quoted the literal
old `Q02/P2` string as defect evidence on line 150 — itself an active-page
P-token the lint flagged after Heartbeat was fixed. Rephrased the evidence line
to describe the defect without embedding the forbidden literal (kept factual).

## Verification

Fresh heartbeat + sidecar P-gate-token scan (regex
`(?<![A-Za-z0-9])P(?:0..10)(?![A-Za-z0-9])`):

```
Heartbeat.md(vault) P-token hits: []
task_monitor_health.json P-token hits: []
```

Vault lint:

```
$ python "G:\My Drive\QuantMechanica - Company Reference\00 Governance\lint_company_reference.py"
Company Reference lint: PASS
```

The next scheduled heartbeat was then forced and rechecked in this orchestration
cycle: `LastTaskResult=0`, `vault_mirror=ok`; the durable rendered
`D:\QM\reports\state\heartbeat.md` had zero matches for the legacy phase-token
regex.

Tests (from `C:\QM\repo`):

```
$ python -m pytest tools/strategy_farm/tests/test_unenqueued_ea_filter.py tools/strategy_farm/tests/test_health_q02_stranded.py -q
..............                                                           [100%]
14 passed in 1.01s
```

- `test_health_q02_stranded.py::test_legacy_p2_is_included_in_same_invariant`
  already asserts `"P2" not in result["detail"]` — was RED before this fix
  (old detail `Q02/P2` contains `P2`), now GREEN.
- Added `test_unenqueued_ea_filter.py::test_warn_branch_message_is_qxx_only`
  guarding the WARN/FAIL branch detail+action_hint of `chk_unenqueued_eas_count`
  against any bare `P2`/`P3` gate token.

## Rollback

- Revert the source string edits: `git checkout tools/strategy_farm/health.py
  tools/strategy_farm/tests/test_unenqueued_ea_filter.py`.
- Revert the vault ToDo line: restore the previous wording in
  `12 ToDo/AI ToDos/Codex.md` line 150.
- The sidecar/heartbeat are regenerated state; the pre-reset sidecar snapshot is
  at `scratchpad/task_monitor_health.backup_1249.json` if needed. Both files
  repopulate on the next scheduled `hourly_monitor` / `heartbeat_snapshot` run.
