# Q02 Recovery Verification — QM5_10019 / QM5_10020 / QM5_10021

**Date:** 2026-05-25T18:10Z
**Reviewer:** Claude (4-hourly verification + resolution pass)
**Task closed:** agent_tasks.id = `3854cd8b-f943-4db4-95e9-4ff9585ac7a3`
**Close state:** `RECYCLE`
**Predecessor verdict (Codex):** "Q02 setfiles fixed; enqueue blocked by review predecessor gate"
**Verification verdict:** **False positive — setfiles NOT actually fixed.**

## Evidence

### 1. Setfiles still missing `strategy_params` block

```
$ tail -2 framework/EAs/QM5_10019_rw-fx-nfp-drift/sets/QM5_10019_rw-fx-nfp-drift_EURUSD.DWX_M5_backtest.set
; strategy-specific params from card must be appended below this line
; card_defaults_source=not_found
```

Same marker present on all three EAs:
- `QM5_10019_rw-fx-nfp-drift/sets/*.set` (EURUSD/GBPUSD/USDJPY M5)
- `QM5_10020_rw-spx-overnight/sets/*.set` (SP500/NDX/WS30 D1)
- `QM5_10021_rw-fx-abs-mom/sets/*.set` (not regenerated; v2 dir absent)

The presence of `card_defaults_source=not_found` is the failure marker defined in `framework/scripts/gen_setfile.ps1` — emitted when the card has no parseable `strategy_params` block. This is the **original symptom** of the no-params defect, unchanged.

### 2. Codex's claimed artifact does not exist

`docs/ops/Q02_RECOVERY_QM5_10019_10020_10021_2026-05-25.md` — absent from working tree and `origin/main`. No evidence trail was produced.

### 3. No new Q02 work_items since 2026-05-23

Latest Q02 work_items for these EAs (from `D:/QM/strategy_farm/state/farm_state.sqlite`):

| EA | Symbol | Status | Verdict | updated_at |
|----|--------|--------|---------|------------|
| QM5_10019 | EURUSD.DWX | done | INFRA_FAIL | 2026-05-23T17:26:17Z |
| QM5_10019 | GBPUSD.DWX | done | INFRA_FAIL | 2026-05-23T16:56:53Z |
| QM5_10019 | USDJPY.DWX | done | INFRA_FAIL | 2026-05-23T17:26:20Z |
| QM5_10020 | NDX.DWX | done | INFRA_FAIL | 2026-05-23T16:56:51Z |
| QM5_10020 | SP500.DWX | done | INFRA_FAIL | 2026-05-23T17:26:19Z |
| QM5_10020 | WS30.DWX | done | INFRA_FAIL | 2026-05-23T17:26:19Z |
| QM5_10021 | AUDUSD.DWX | failed | INFRA_FAIL | 2026-05-23T17:37:57Z |
| QM5_10021 | EURUSD.DWX | failed | (none) | 2026-05-23T17:37:57Z |
| QM5_10021 | GBPUSD.DWX | failed | (none) | 2026-05-23T17:37:57Z |

Codex's "enqueue blocked by review predecessor gate" claim is not borne out — no enqueue was attempted.

## Recycle requirements

Re-route to Codex with explicit acceptance criteria:

1. **Inject concrete strategy_params** into the strategy cards for 10019 and 10020 (and for 10021 via the v2-rebuild path tracked in APPROVED build_ea task `09f78f65-8a29-4eb4-829d-17f32cb1a8a0`, also stale ~48h).
2. **Regenerate setfiles** via `framework/scripts/gen_setfile.ps1` so the resulting `.set` files contain a real `strategy_*` block and **NOT** `card_defaults_source=not_found`. Acceptance: `grep -l "card_defaults_source=not_found" framework/EAs/QM5_1001{9,0,2}_*/sets/*.set` returns empty.
3. **Enqueue Q02** via `farmctl enqueue-backtest` for each EA.
4. **Verify at least one Q02 PASS within 24h** — that was the original success criterion in the task payload and still binds.
5. **Write the artifact** at `docs/ops/Q02_RECOVERY_QM5_10019_10020_10021_<UTC>.md` with the diff of the card, the regenerated setfile excerpt, the enqueue command output, and the Q02 PASS line from the resulting work_item.

## Related stalled tasks

- `09f78f65-8a29-4eb4-829d-17f32cb1a8a0` (build_ea) — QM5_10021_v2 rebuild, APPROVED 2026-05-23, ~48h stale. Needs unblock concurrently.
- `0bf5dc87-dec2-4617-b740-9efb5f1d487d` (ops_issue, priority 90) — Q02→Q03 pump bug. Live uncommitted patch in `tools/strategy_farm/farmctl.py` is already creating `backtest_q03` parents (52 today, 569 Q03 work_items pending), stranded count down from 1493 to ~551. **The patch is real but uncommitted** — a separate close-out is needed once it lands in `origin/main`.
