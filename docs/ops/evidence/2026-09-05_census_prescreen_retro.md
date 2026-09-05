# Retrospective census prescreen — REVIEW

Task `c3779c25-3795-4535-a3bf-66ee862d72b9`. **Applied 2,555 active `PRESCREEN_SKIPPED` holds, all with `release_on_restart=0`, and appended 15 program receipt rows.** Twelve dry-run targets had advanced and were preserved. No existing work-item status, verdict, payload, evidence path or other column was changed by the hold transactions. All 16,275 declared annual rows and every 154-arm declaration remain present.

Code commit `ca772cc904` on `agents/codex-census-retro-20260905`; no main/cto_main integration. Authority: OWNER-DEC-D1-PRESCREEN-20260905, receipt row 13. Both the arm and baseline must have valid MEASURED evidence in **2019 and 2020** before retrospective classification. B5 requires at least five fires in each year; B2 reuses the existing Decimal +5% net-profit comparison against strictly positive baselines in both years. Missing stage-one evidence is UNKNOWN. Holds cover only rejected arms' pending, unclaimed **2021–2025** cells.

The task's earlier snapshot named 17 live programs. The read-only dry-run at 10:40 UTC found 15 still live, with 10,777 pending annual cells. Completed programs were omitted. It proposed 2,567 holds and was committed **before apply** as `ae4403ba7820554956097bc5dc592268366646a1` at 10:46:26 UTC. Exact dry-run SHA256: `dc85616ca80a5890c0b5459682240c6aa95ec628ca11bfcd776e25c9c9c236bc`.

| Program (source EA / symbol) | ADMIT | SKIP | UNKNOWN | Proposed holds | Applied holds |
|---|---:|---:|---:|---:|---:|
| 10145 / XAUUSD | 0 | 43 | 111 | 215 | 215 |
| 10403 / XAUUSD | 0 | 0 | 154 | 0 | 0 |
| 10513 / XAUUSD | 0 | 12 | 142 | 50 | 50 |
| 10700 / XAUUSD | 0 | 0 | 154 | 0 | 0 |
| 10706 / GBPUSD | 1 | 139 | 14 | 650 | 650 |
| 11422 / USDCAD | 0 | 98 | 56 | 490 | 490 |
| 11708 / EURUSD | 0 | 0 | 154 | 0 | 0 |
| 11881 / GBPUSD | 0 | 131 | 23 | 655 | 655 |
| 12710 / XTIUSD | 0 | 144 | 10 | 85 | 83 |
| 12849 / XTIUSD | 0 | 0 | 154 | 0 | 0 |
| 12855 / XTIUSD | 0 | 0 | 154 | 0 | 0 |
| 20266 / XTIUSD | 1 | 153 | 0 | 149 | 146 |
| 21501 / USDJPY | 0 | 0 | 154 | 0 | 0 |
| 21507 / XAUUSD | 0 | 154 | 0 | 51 | 48 |
| 41097 / USDJPY | 0 | 152 | 2 | 222 | 218 |
| **Total** | **2** | **1,026** | **1,282** | **2,567** | **2,555** |

The measured aggregate rate was **97 annual MEASURED cells/hour** (194 completions in the trailing two wall-clock hours). The dry-run estimate was 26.46 hours; the applied holds represent **26.34 hours** at that same observed rate. This is a workload estimate. Per-program hours and pending counts are in [the committed dry-run table](2026-09-05_census_prescreen_retro/DRY_RUN.md).

Apply reused the canonical `governed_work_item_hold.py` inspection/backup implementation and canonical shared `FactoryMutationLock`, with a separate `BEGIN IMMEDIATE` transaction per program. Each transaction rechecked pending/unclaimed state, existing holds, declaration identity and hash-bound stage-one evidence, then inserted holds and one `events` receipt row. It compared all program work-item rows before/after and refused any change. A busy global mutation lock stopped the first attempt after six programs; a resumption recognized all six existing receipts without duplicate holds or receipt rows and finished the remaining programs. Existing active/done work continued. The final apply record accounts for 1,150 new holds plus 1,405 already held, totaling 2,555.

The pre-apply SQLite backup is `D:/QM/strategy_farm/state/backups/prescreen_retro/farm_state_before_governed_hold_20260905T104944Z.sqlite`, SHA256 `ad450b372069e66c70d8120a8f152bb7380048d58456d5bdb55e1e9502cde75c`. Its receipt also pins the canonical hold backend. Every active hold reason binds its program JSON receipt's exact byte hash, dry-run hash and OWNER decision. JSON files have local `-text` attributes to preserve their hashes across checkouts.

**Counter reconciliation:** raw rows remain pending with no verdict, claim or fabricated measurement. The tested consumer projection validates the active hold, immutable receipt, append-only program event and classification proof, and resolves exactly **2,555** cells as unmeasured `SKIPPED_EXCLUDED` equivalents. The selector, arm frontier, refill path and Q12 completion evidence use this projection. Rebaseline reports the count separately from gate evidence. A read-only, same-SQLite-snapshot comparison of canonical and revised rebaseline reproduced identical pair rows, finer rows and all existing gate counters, including **eight fully contiguous Q14 pairs**. Prescreen holds alone do not advance the 8/25 qualified-pair counter.

**194 tests passed:** 40 focused classifier/receipt/contiguity checks plus 154 selector, matrix-service, atomic-claim and census regressions. Coverage includes exact thresholds, missing measurements, active/done races, preservation of inactive foreign holds, idempotency, missing program receipt refusal and changed native evidence refusal. K/L/G settings remain unchanged. No terminal was started or interrupted for this task.

The holds are effective through the existing generic claim guard. **The consumer code remains on the review branch and was not integrated into the canonical runtime.** Read-only verification exercised that proposed projection; Claude+OWNER integration is still needed for canonical progress/completion consumers to report it. No pipeline verdict was issued by this task.

Evidence: [reconciliation](2026-09-05_census_prescreen_retro/reconciliation.json), [verification script](2026-09-05_census_prescreen_retro_verify.py), [before rebaseline](2026-09-05_census_prescreen_retro/before/census_2026-09-05.json), [after rebaseline](2026-09-05_census_prescreen_retro/after/census_2026-09-05.json), all 15 `program_*.json` receipts and the `apply_*.json` record in the evidence directory, plus `2026-09-05_census_prescreen_retro.patch`. Leave REVIEW.
