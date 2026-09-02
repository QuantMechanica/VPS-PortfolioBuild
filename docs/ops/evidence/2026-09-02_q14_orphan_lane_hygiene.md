# Q14 orphan lane hygiene — 2026-09-02

Task: `5bcdf6f4-b1b8-4dbb-a952-252270d68d2f`

Authority: CEO mandate recorded in `docs/ops/CEO_AUDIT_2026-09-02.md`. This is an
append-only control-plane repair. It does not change a sealed criterion, mutate a
historical work item, or write to `T_Live`.

## Finding

The optimization-fork service created two Q13/Q14 chains from generic Q12 `PASS`
rows. Those chains are not contiguous with the governed pattern-census Q12 rows and
must not remain executable/reportable as the active Q14 lane.

| Orphan row | State before repair | Generic parent | Canonical successor |
|---|---|---|---|
| `8751e042-2639-50d4-95b3-135b1fd4afec` (11421 Q13) | `done / NO_PARAMETER_CHANGE` | `d0e53004-659c-563c-8314-c24ad4ab2a68` | `2518ae77-a149-5243-982e-90c094c55b32` (governed Q13) |
| `f81a14df-14ef-5f15-b808-d19b8c13348c` (11421 Q14) | `pending` | orphan Q13 above | `ff733cf6-52a1-5aad-9bff-4f8c31ef4dc6` (`KEEP_INCUMBENT`) |
| `7bacc182-40f4-5232-ba7f-9e517d2abf75` (10706 Q13) | `done / NO_PARAMETER_CHANGE` | `dfca24fa-28df-5f5e-818f-8dcf53611822` | `e1e86d92-52c6-519b-b628-b865309c42c5` (governed Q13) |
| `64604d7a-9bbe-561c-a70c-44667cdb2e12` (10706 Q14) | `pending` | orphan Q13 above | `b5e18759-1377-5af7-9634-9f66bd293d0c` (`KEEP_INCUMBENT`) |

The 11421 canonical chain is
`c4bc189b-372d-54c9-be45-046ac77b245b` →
`2518ae77-a149-5243-982e-90c094c55b32` →
`ff733cf6-52a1-5aad-9bff-4f8c31ef4dc6`. The 10706 terminal chain is
`48c41285-5849-534d-aeac-836deb9a9cb8` →
`e1e86d92-52c6-519b-b628-b865309c42c5` →
`b5e18759-1377-5af7-9634-9f66bd293d0c`.

## Action and verification

Each edge was planned and then recorded with the canonical
`tools/strategy_farm/work_item_supersedes.py record` command. That command takes a
database backup, writes `work_item_supersedes` under `BEGIN IMMEDIATE`, and appends a
`work_item_superseded` event. Post-apply verification requires exactly four
`operator:record` edges with the mappings above and confirms that both formerly
pending Q14 rows are excluded by the canonical supersession claim guard.

Rollback is append-only: record a later OWNER-authorized supersession/disposition;
do not delete these edges or rewrite the historical rows.
