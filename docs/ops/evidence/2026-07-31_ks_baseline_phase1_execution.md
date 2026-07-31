# KS baseline gap — Phase 1 execution evidence (Topic B)

**Executed:** 2026-07-31 (Claude) · **Authorization:** OWNER weekend-programme
directive 2026-07-31 + Codex R1 approval 94 % (ticket `252f7381`,
`docs/ops/evidence/2026-07-31_ks_baseline_gap_plan_review.md`).
**Machine evidence:** `D:\QM\reports\state\ks_phase1_execution_20260731.json`
(per-file SHA-256 tables for every step).

## What was done (file-side only; terminal-local tree read-only throughout)

1. **Backup (condition 2):** `D:\QM\reports\state\ks_common_backup_20260731\`
   was absent, then created — **54 files / 185,470 bytes** (exactly the review's
   pre-census) with per-file SHA-256 in `_manifest.json`.
2. **Mirror alignment (condition 1):** all **40** book alias paths (20 divergent
   sleeves x both alias names `QM5_<id>_<sym>.json` / `..._DWX.json`) copied
   byte-identical terminal-local -> Common. 40/40 rewritten, 40/40 post-SHA ==
   source-SHA.
3. **Missing deploys:** staged baselines for **1567|EURUSD** and **13117|EURGBP**
   deployed from `D:\QM\reports\state\q10_baselines_staging\` as **4** new alias
   files (staged alias pairs byte-identical before copy). 10513 (provenance
   defect) and 10440 (Q10 FAIL dd 31.01 %) intentionally NOT deployed.
4. **Post-state verification (condition 4):** Common now **58/58 expected
   files**, zero missing, zero extra, zero drift among the 14 untouched files
   (SHA vs backup manifest).
5. **Pulse re-run (read-only):** fresh `live_book_pulse.json` shows
   **`mirror_divergences: 0`** (was 20), `missing_files: ['10440|NDX',
   '10513|XAUUSD']` (the two intentional holds), dormant now includes the two
   new deploys (expected until arming). Overall verdict remains ALARM solely on
   dormancy — that is the designed Phase-2 residual.

## Rollback (condition 3)

Delete exactly the 4 created paths (`QM5_1567_EURUSD.json`,
`QM5_1567_EURUSD_DWX.json`, `QM5_13117_EURGBP.json`,
`QM5_13117_EURGBP_DWX.json`), restore the 54 backed-up files from
`ks_common_backup_20260731`, verify per-file SHA-256 against `_manifest.json`.

## Phase 2 residual (OWNER+Claude, Sunday session)

Arming requires a T_Live re-init (baselines load once at OnInit). Preconditions
per review §5: fresh account/position snapshot immediately before restart
(review-time magics `15560004`/`114210003`/`105130003` — re-census, do not
reuse), market-closed window ~Sun 22:00-23:00Z, standing restart procedure,
post-init full-log `KS_BASELINE_LOADED` table for every covered sleeve
(expected uncovered: 10440; 10513 unless re-confirmed). Combine with 12778
chart restore + swap capture.
