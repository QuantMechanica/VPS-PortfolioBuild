# QUA-346 Operator Runbook (2026-04-28)

Use this sequence immediately after unblock decision is made.

## 1) Refresh readiness

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA346Readiness.ps1
```

Required before execution:
- `card_exists=true`
- `source_exists=true`
- `manifest_exists=true`
- `manifest_missing_fields=[]`

## 2) Fill run manifest

File:
- `C:\QM\repo\artifacts\qua-346\src04_s07_run_manifest_template.json`

Required fields to fill:
- `required_fields.symbols`
- `required_fields.from`
- `required_fields.to`
- `required_fields.ea_name`
- `required_fields.setfile_path`

## 3) Execute first full baseline cohort

Use CTO-provided baseline runner for `SRC04_S07` with:
- trigger symbol/window from manifest (no smoke substitution),
- factory scope only (`T1`-`T5`),
- output root `D:\QM\reports\baseline\QUA-346\SRC04_S07`.

## 4) V5 evidence checks (mandatory)

1. Filesystem-truth:
- count actual `.htm` reports in output root,
- compare against tracker counters.
2. NO_REPORT disambiguation:
- check report byte size before EA weakness claims.

## 5) Post-run artifacts

Update:
- `docs/ops/QUA-346_READINESS_CHECK_2026-04-28.json`
- `docs/ops/QUA-346_ISSUE_COMMENT_2026-04-28.md`

Add:
- run evidence artifact under `docs/ops/` with:
  - file counts,
  - report sizes,
  - terminal allocation used,
  - output root path.
