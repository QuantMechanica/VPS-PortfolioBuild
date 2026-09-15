# Weg 2 disposition — Q08 NOT_APPLICABLE for the ledger-less window-sweep arms and QM5_12115 (2026-09-15)

OWNER 2026-09-14: way 1 (window-sweep ledger as DSR search history) in a Codex ticket; delivered PARTIAL (task 7d9dd3b5 / 67dfadf6):
no sealed `qm.window-sweep.v1` ledger, no OPT_CENSUS work items and no approved card exist for the 8 non-41380 rows, so no search-history
cohort can be assembled for them (`docs/ops/evidence/2026-09-14_q08-sweep-arm-context-20260914_9e6ddd6b_execution.md`). Under the
OWNER Freifahrtsschein (2026-09-14/15) the orchestrator takes the card's alternative **Weg 2**: the standalone Q08 DSR gate is
NOT_APPLICABLE for these rows; the EAs are evaluated exclusively through the Q13/Q14 best-settings head-to-head programme path.

Effect: NO append-only Q08 rerun is enqueued for these rows; their existing terminal verdicts stay untouched (append-only evidence);
no gate threshold, DSR/FDR formula or candidate universe changes. 41380 already carries a card-declared single configuration and is
listed for completeness only. QM5_12115 rows are included as decided on 2026-09-14 (ledger-less, same class).

| work item | ea_id | symbol | status | verdict (stored, unchanged) | created |
|---|---|---|---|---|---|
| `910ecfea-c90c-4cc3-b957-6e6e2164e8a7` | QM5_12115 | XAUUSD.DWX | done | INVALID | 2026-09-12 |
| `882ca28e-e9e6-41de-b795-dfb2f7bb6757` | QM5_12115 | XAUUSD.DWX | done | INVALID | 2026-09-12 |
| `9a4cbb43-9eb0-43b1-94b6-311a5ce9dcf6` | QM5_41115 | XTIUSD.DWX | done | INVALID | 2026-09-07 |
| `3fa17615-6fac-4c8b-a958-b02d111c9e4b` | QM5_41131 | XTIUSD.DWX | done | INVALID | 2026-09-10 |
| `ed38c5b7-cf11-4591-897f-e2aec1e6a1d8` | QM5_41158 | XTIUSD.DWX | done | INVALID | 2026-09-08 |
| `07d14cb3-d786-410b-97b3-9bd5d6da1e2e` | QM5_41176 | XTIUSD.DWX | done | INVALID | 2026-09-09 |
| `f9d5b1ec-c350-4214-9a7c-be1a43a0d993` | QM5_41380 | XTIUSD.DWX | done | INVALID | 2026-09-09 |
| `fd7dd094-be29-4184-be15-21f48977968a` | QM5_41380 | XTIUSD.DWX | done | INVALID | 2026-09-14 |
| `48c5d851-995d-4f86-99c8-fd720a8356af` | QM5_41381 | XTIUSD.DWX | done | INVALID | 2026-09-10 |
| `bea72ee4-cdfb-41d8-9200-aabcbe1e4aab` | QM5_41423 | XTIUSD.DWX | done | INVALID | 2026-09-10 |

Recorded by Orchestrator Claude 2026-09-15T10:10:33Z; read-only DB query; no row mutated.
