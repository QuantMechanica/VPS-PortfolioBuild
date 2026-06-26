# Strategy Farm Review Repair

Date: 2026-06-26
Scope: `ea_review` / final review recovery, Strategy Farm runtime

## Incident

The farm had dozens of old `ea_review` tasks stuck in `pending` with no active
`claude_review_*.live.log`, no `codex_review_*.live.log`, and no written
`review_*.json` verdict. These rows prevented the pump from recreating final review
work for completed `build_ea` tasks.

Separately, verdict ingestion could reject valid JSON files that contained a UTF-8 BOM,
and review verdicts could convert pure smoke/MetaTester infrastructure failures into
`REJECT_REWORK`, sending clean EAs back to code rework.

## Fix

- `repair.py` now has `R8_stranded_ea_review`, analogous to the existing
  `codex_review` repair. It deletes old inactive pending `ea_review` tasks only when
  there is no fresh review log and no non-empty verdict file.
- `farmctl.py` reads final review and Codex review verdict JSON with `utf-8-sig`.
- `farmctl.py` detects `REJECT_REWORK` verdicts whose blocking evidence is only
  smoke/terminal infrastructure (`REPORT_MISSING`, `METATESTER_HUNG`,
  `MODEL4_MARKER_REQUIRED`, terminal contention, duplicate dispatch) and records them
  as `APPROVE_FOR_BACKTEST` with `infra_only_review_repaired=true`.

## Live Repair Run

Before the live mutation, a SQLite backup was written:

```text
D:\QM\strategy_farm\state\backups\farm_state_pre_ea_review_repair_20260626_072405.sqlite
```

`farmctl repair` completed with no errors and removed the old stranded review rows.
The next pump cycle recreated fresh Claude review tasks for eligible completed builds.

## Verification Commands

```powershell
cd C:\QM\repo
python -m py_compile tools\strategy_farm\farmctl.py tools\strategy_farm\repair.py tools\strategy_farm\tests\test_review_repair.py
python tools\strategy_farm\farmctl.py status
```

Expected healthy state:

- `ea_review pending` entries are fresh, with recent queue prompts and live logs.
- Old pending rows without active logs are cleared by `farmctl repair`.
- `ea_review done` continues increasing after pump cycles.

## Claude Prompting Guidance

Do not manually prompt Claude just because `ea_review pending` exists. The pump already
spawns Claude for this lane. Manual prompting is useful only when:

- no `farmctl.py pump` process is active,
- pending review rows are older than 30 minutes,
- their review logs are stale or missing,
- and `farmctl repair` did not recreate fresh work.

Otherwise, manual prompting adds duplicate concurrency and can worsen terminal or review
contention.
