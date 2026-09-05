# M05 evidence-loss adjudication — 2026-09-05

Task `7ef6444b-17ba-4d98-b3b0-b01740d42a0c`. Status: REVIEW; unexplained loss remains open.

The watcher tests literal paths and saves its baseline when invoked (`tools/strategy_farm/evidence_cohort_watch.py:151`); this audit read that baseline without invoking the writer. Its 02:20 observation precedes today's 02:21 retention completion. Current measurement: **786 of 1,205 literal paths absent**, with 419 present.

| Classification | Watcher's 750 | Recorded +32 delta | Current 786 |
|---|---:|---:|---:|
| Recoverable gzip, consistent with DL-090 compression | 585 | 31 | 619 |
| Exact relative path in retention quarantine | 9 | 1 | 11 |
| UNEXPLAINED | 156 | 0 | 156 |

The +32 observation is recoverable; calling all of it deleted evidence is incorrect. All gzip copies were decompressed and JSON-parsed, and both stored/decoded hashes are in `snapshot_final/recovery_manifest.json`. Baseline entries contain no original hashes. These are observed recovery bindings, not proof of original byte identity or a historical signed archive manifest. DL-090 (`decisions/DL-090_backtest_report_retention_policy.md:31`) permits compression of kept artifacts; batch logs are copied with their paths and hashes retained in the evidence inventory. No exact per-file purge hit proves any of the 156 unexplained losses. The current retention classifier says **126 KEEP / 30 AGE_OUT** among those 156; present-day eligibility is not a deletion receipt, and none was reclassified as lawful loss.

The dependency inventory conservatively includes 71 historical Q11 PASS-class rows across 54 pairs (not a claim of 54 current release candidates), declared parent links, 24 DL-089 ledgers and their path references, and the 24 live sleeves. It lists 26,561 references: 61 with matching expected hashes, 62 raw byte mismatches, 24,234 located without expected hashes, and 2,204 absent. The absent references comprise **2,166 set paths, 37 journals, one aggregate**. Planned set references do not prove prior production; these are unresolved dependencies, not 2,166 proven deletions. Journals are outside the DL-090 keep set. Hash mismatches include mutable custom-history manifests/receipts and require their own binding adjudication; raw byte comparisons are not a canonical-JSON equivalence decision.

The missing Q11 lineage aggregate is `D:/QM/reports/work_items/312d2888-9381-4866-9701-ad99ccb611c3/QM5_1328/Q10/EURJPY_DWX/aggregate.json` (historical storage name, active Q11 semantics). Among the 156 baseline losses, `6f4fff24-3a6d-40e3-aaca-773b5195f6d2` / QM5_13128 NDX overlaps a live sleeve and historical Q11 success. This is a potential dependency, not a proven exact live-binary lineage. The FTMO acceptance-test receipt remains ready for ratification; no ratified acceptance seal was located or presumed. Full per-reference identities and statuses are in `snapshot_final/inventory.json`.

Purge protection: two proposals were saved **before** their respective code changes. The existing 40-pair guard now includes 27 additional Q11/program subject pairs and 24 census harness pairs: **91 protected pairs**. Registry/read errors fail closed. The read-only guard scans 91 cache targets (90 in the earlier dry run) and finds no gate JSON in them today; 33 campaign/native-export source exclusions remain. Thus no extra cache target is withheld in this observation, but future gate JSON belonging to those research pairs is protected. Reports, ledgers and live manifests are outside the tester-cache deletion roots. This does not make report retention safe for every semantic dependency; the unexplained KEEP losses still require recovery/adjudication.

The protective guard change and all artifacts await Codex/CEO close-out in REVIEW. `protective_change_receipt.json` binds the two prior dry runs, final source, resulting counts, and 15 passing focused tests (including malformed/missing registry failure, historical version translation, database-byte preservation, gzip corruption and quarantine provenance). Only protection code was applied. No purge, deletion, movement, terminal control, factory control or verdict mutation was performed.

Daily heartbeat command (choose a new canonical output directory each run):

```powershell
python C:/QM/repo/docs/ops/evidence/2026-09-05_m05_evidence_loss_adjudication/audit.py --out C:/QM/repo/docs/ops/evidence/YYYY-MM-DD_m05_delta --previous C:/QM/repo/docs/ops/evidence/2026-09-05_m05_evidence_loss_adjudication/snapshot_final/inventory.json
```

It records literal-path survival, recoverable copies, unexplained count, dependency bindings and classification deltas without touching the watcher baseline or database. Full source logs and the baseline snapshot accompany the inventory. OWNER/CEO next action: assign the 126 unexplained KEEP cases and the missing QM5_1328 aggregate for evidence recovery; do not convert them into passing pipeline verdicts.
