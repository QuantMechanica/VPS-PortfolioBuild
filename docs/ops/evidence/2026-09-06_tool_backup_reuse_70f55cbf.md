# Governed tool-backup reuse and cap — REVIEW

Router task `70f55cbf-7f1e-4619-bff2-fab9fb22c394`, priority 84. Implementation commit `bccca81307ff3873ad11f1bbe32f106721cd2bec` is on isolated branch `agents/codex-tool-backup-reuse-20260906`, based on `agents/board-advisor` commit `8e619f1aec`. This evidence is committed separately on `agents/board-advisor`.

No production backup, work-item, hold, queue, worker, terminal, setfile, EA, or pipeline state was changed. Cap behavior was exercised only in temporary test directories. The 67 MB benchmark directory was verified under `C:\Windows\TEMP\qm_backup_cost_*` and removed after Windows briefly retained its SQLite handle; it is not recoverable and contained synthetic zero-filled data only.

## Result

- Governed tool calls reuse one rollback anchor during the default 60-minute window. The stable match key is resolved database path plus SQLite schema generation. Main-file mtime/size remain recorded for audit, but DML row-count and WAL growth are no longer false mismatch keys. A schema change or expired window still forces a fresh online backup.
- `release_compile_wave.py --work-item-ids <id...>` accepts an exact tranche, preserves the single-ID form, and cannot pick up foreign held rows. Explicit selectors are not constrained by the ordinary 10-row broad-wave ceiling.
- `farmctl` hold release, first-Q02 intake, and fresh-Q02 seed use the same resolver. Existing governed callers (`q01_smoke_successor`, canonical-setfile apply, news-calendar taint, OOS window repair) remain supported through sanitized backup-class labels.
- Every governed tool-backup class is capped at its newest three `.sqlite` files. Deletions are restricted to the resolved backup directory, sidecars are removed with their backup, and each non-empty cap action writes a `qm.tool-backup-cap/v1` receipt with exact paths and byte counts. Hourly `farm_state_YYYYMMDD_HHMM.sqlite` snapshots do not match the tool-class glob and remain under the separate retention policy.

## Verification

```powershell
python -m pytest tools/strategy_farm/tests/test_release_compile_wave.py tools/strategy_farm/tests/test_first_q02_intake.py tools/strategy_farm/tests/test_candidate_repair_enqueue.py tools/strategy_farm/tests/test_governed_work_item_hold.py tools/strategy_farm/tests/test_canonical_setfile_apply.py tools/strategy_farm/tests/test_news_calendar_taint.py tools/strategy_farm/tests/test_oos_2026_confirmation.py -q
# 137 passed in 35.30s
```

Acceptance-specific controls prove:

- twelve exact release rows produce one `_backup` call and leave an older foreign held row active;
- a first governed backup and a later first-Q02-class call reuse the same path/SHA after intervening event-table DML;
- five backups in one tool class become the newest three, with a receipt for two removed files/two bytes;
- an expired sidecar, disabled reuse window, or changed SQLite schema creates a fresh anchor.

Synthetic measured cost (67,186,688-byte SQLite file, one intervening DML commit):

| Operation | Seconds |
|---|---:|
| Initial online backup | 0.437162 |
| Rolling-window reuse | 0.001806 |
| Measured speed-up | 242.1x |
| Backup files after both calls | 1 |

This remains a `REVIEW` candidate. It does not authorize release execution, worker reload, or any pipeline verdict.
