# EA-ID cross-source duplicate allocation in research/G0 step

- **UTC discovered**: 2026-05-19T07:51Z
- **Severity**: Class-2 structural (autonomous wake explicitly flagged "Board-Advisor structural-fix needed")
- **Origin wake**: `QM_StrategyFarm_BoardAdvisor_Hourly` @ 2026-05-19T07:47Z (observe)
- **Boundary**: fix touches autonomous_loop.md / farmctl research allocator — requires OWNER sign-off per `board_advisor_observe.md` "DO NOT modify the autonomous_wake decision tree without OWNER sign-off".

## Symptom

`ea_id_registry.csv` now contains the same `ea_id` allocated to two different slugs from two different source UUIDs:

| ea_id | slug (source-A) | slug (source-B) | sources |
|-------|-----------------|-----------------|---------|
| 1223 | bhatti-fx-zscore-mr | hopwood-dmi-cross-h1 | AllocateSmartly + ForexFactory |
| 1224 | white-okunev-fx-xmom | antor-mtf-macd-scalper | AllocateSmartly + ForexFactory |
| 1225 | dahlquist-fx-econmom | channel-cci-bollinger-mr | AllocateSmartly + ForexFactory |
| 1226 | psaradellis-oil-channel | 4h-box-frankfurt-london | AllocateSmartly + ForexFactory |
| 1227 | neely-fx-channel | pip-hunter-heiken-ashi | AllocateSmartly + ForexFactory |
| 1619 | mql5-ma2-slope (registered) | aa-overnight-mom (build_ea blocked) | MQL5 CodeBase + Alpha Architect |

Pattern flagged in autonomous wake structured log at 2026-05-19T01:23Z, 02:36Z, 03:26Z under `registry_dup_id_flag` / `dup_id_flag` keys.

## QM5_1619 manifestation (live re-fire loop)

Most acute current symptom — 7 build_ea tasks created in 30 min, all blocked:

```
id                                    kind     status   updated_at                  card_id    reason
70a6a632-adc8-4a96-b1c2-6fe0449daa1d  build_ea blocked  2026-05-19T07:48:37+00:00  QM5_1619  card path not found D:/QM/strategy_farm/artifacts/cards_approved/QM5_1624_aa-overnight-mom.md
a462a580-0ebd-4708-b174-251016594216  build_ea blocked  2026-05-19T07:47:21+00:00  QM5_1619  (same)
3e3c4361-e255-4c93-8678-7e780ace05fa  build_ea blocked  2026-05-19T07:46:35+00:00  QM5_1619  (same)
a5c9a109-86bd-4524-a5e6-e495c4313e65  build_ea blocked  2026-05-19T07:45:41+00:00  QM5_1619  (same)
bf123917-d283-463f-a082-05d598b93da0  build_ea blocked  2026-05-19T07:44:28+00:00  QM5_1619  (only draft QM5_1643_aa-overnight-mom.md with g0=PENDING on disk)
b8b43bc5-96d1-4a20-9332-349389763a73  build_ea blocked  2026-05-19T07:32:05+00:00  QM5_1619  card path missing
90118a1d-d434-481e-ac4a-ebfd72e45e3d  build_ea pending  2026-05-19T07:20:26+00:00  QM5_1619  card not APPROVED
```

Frontmatter snapshot embedded in payload says:
- `ea_id: QM5_1619` / `slug: aa-overnight-mom` / `g0_status: APPROVED` / `source_id: ede348b4-...` (Alpha Architect)

But the only `aa-overnight-mom` file actually on disk is:
- `D:/QM/strategy_farm/artifacts/cards_draft/QM5_1643_aa-overnight-mom.md` (g0_status=PENDING)
- No `cards_approved/QM5_1624_*` and no `cards_approved/QM5_1619_*` exist

So three different `ea_id`s (1619, 1624, 1643) are attached to the same slug across the system state.

## Root cause hypothesis

Parallel research wakes on different active sources each pick the same "next free" `ea_id` from `ea_id_registry.csv` without atomic reservation. The autonomous_loop allocates the ID, builds the card, and writes the registry row — but no lock prevents two concurrent wakes from picking the same ID. The card file then gets renamed/re-IDed by a later wake when it detects the collision, but the build_ea task's snapshot of `card_path` and `frontmatter.ea_id` is stale and Codex (correctly) refuses to proceed.

HR16 (one active source at a time) is supposed to prevent this. The wake log notes "2 active sources" appearing repeatedly with comment "resume-mining flipped without event" — that's the suspected hole: `resume-mining` does not enforce single-active.

## Recommended fix scope (OWNER decision)

1. **Allocator atomicity** — wrap ea_id assignment + registry CSV append in a file lock (e.g. `D:/QM/strategy_farm/state/locks/ea_id_alloc.lock`) or move to a SQLite table with `UNIQUE(ea_id)`.
2. **HR16 enforcement on resume-mining** — refuse to flip `cards_ready → active` if another source is already active.
3. **Self-heal filter extension** — add `card not found at` / `card path missing` to the same `superseded_by` exclusion list (controller-side, not in autonomous_wake decision tree).
4. **One-shot cleanup**: reassign the duplicate slugs to fresh IDs (1700+ block currently unused) and rebuild the affected EAs.

None of these are in scope for an observe wake under current boundaries. Awaiting OWNER sign-off.

## Action taken by this observe wake

- This escalation document written (no DB mutation, no registry edit, no autonomous_loop.md edit).
- Active codex pump (20+ live `codex.exe` processes, started 09:43–09:50 local) NOT interrupted — they are progressing other EAs unrelated to this collision.
- The 7 stuck QM5_1619 tasks are tombstones that will keep re-firing every 1–2 min until OWNER resolves the allocator. Volume is bounded (no DB growth crisis), pump is not blocked on this EA.

## Related open escalations

- `2026-05-19_claude_g0_pump_oauth_stale.md` (claude pump OAuth fails — independent issue)
- `2026-05-17_codex_auth_401_websocket.md` (codex auth.json id_token stale — independent issue)
- `2026-05-17_smoke_first_run_intermittent_report_missing.md` (METATESTER_HUNG cluster — independent, explains 27 framework_smoke_infra failures in current self-heal output)
