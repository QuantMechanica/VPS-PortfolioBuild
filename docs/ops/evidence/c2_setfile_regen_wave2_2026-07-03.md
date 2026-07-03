---
title: C2 Setfile Regen Wave-2 Evidence
task_id: 9485fdd2
date: 2026-07-03
author: claude
commit: 35a5fd044
---

# C2 Setfile Regen Wave-2 — Evidence

## Summary

Wave-2 of the C2 param-empty setfile recovery (task 9485fdd2). Preceding wave-1 (task bffea48b, 05:45Z)
regenerated 7 base EAs and requeued 34 Q02 work_items. This wave completes the remaining 42 scan EAs.

## Scope

- **Scan list**: 49 param-empty EAs from `c2_param_empty_scan_2026-07-03.json`
- **Wave-2 targets**: 42 EAs still showing `card_defaults_source=not_found` in base setfiles
- **Priority EAs verified**: QM5_10307 (narang-blend, PF 4.84) and QM5_1328 (brooks-3bar) already
  had setfiles fixed and are in-pipeline (QM5_10307: 10 pending Q02; QM5_1328: 2 pending Q02)

## Actions Taken

### 1. Setfile Regeneration
- **Tool**: `framework/scripts/gen_setfile.ps1` (fix b4c4d179 in place)
- **Result**: 285 setfiles regenerated, 0 failures
- **Method**: Iterated all base setfiles (no ablation/grid suffix) still containing `card_defaults_source=not_found`
  for each of the 42 EAs; called gen_setfile per symbol+TF
- **Verification**: Gen_setfile extracts strategy params from .mq5 input group as fallback when card lacks strategy_params
- **Evidence file**: `D:/QM/strategy_farm/artifacts/ops/c2_wave2_regen_results.json`

### 2. Git Commit
- **Branch**: agents/board-advisor (C:/QM/repo main checkout)
- **Commit**: 35a5fd044
- **Files**: 223 setfiles across 42 EA directories (+priority pair 10307/1328)
- **Diff**: 2957 insertions, 1444 deletions (content replaced from boilerplate to strategy params)

### 3. Q02 Requeue (wave-2)
- **DB backup**: `D:/QM/strategy_farm/state/farm_state_backup_c2wave2_20260703T082355.sqlite`
- **Selection**: Q02 work_items for 42 scan EAs, non-FX symbols only
  (NDX, SP500, WS30, GDAXI, XAUUSD, XAGUSD, XNGUSD, XTIUSD, UK100)
- **Excluded EAs**: Checked against `requeue_excluded_eas.txt` (163 cost-doomed FX EAs)
- **Requeued**: 66 items (status: failed/done → pending)
- **EAs affected**: QM5_10050, QM5_1060, QM5_10605, QM5_1088, QM5_1096, QM5_1097,
  QM5_1118, QM5_1132, QM5_1237, QM5_1371
- **Evidence file**: `D:/QM/strategy_farm/artifacts/ops/c2_requeue_wave2_2026-07-03.json`

## Wave Cap Status

| Wave | Task | Requeued | Cap |
|------|------|----------|-----|
| Wave-1 | bffea48b (Codex) | 34 | 100 |
| Wave-2 | 9485fdd2 (Claude) | 66 | 100 |
| **Total** | | **100** | **100** |

Cap reached. Further requeuing (remaining 1206 eligible non-FX items + all FX items)
deferred to wave-3 (separate task).

## Remaining Work (Deferred)

- 1206 additional eligible Q02 failed items for the 42 EAs (non-FX, not yet requeued due to cap)
- FX symbols for QM5_1095 and FX setfiles across all 42 EAs (low priority, commission-killed)
- Ablation/grid setfiles still showing `not_found` (separate concern from base backtest setfiles)
- EAs in requeue_excluded_eas.txt (163 FX cost-doomed, skip permanently)

## Risks / Blockers

- Setfiles were regenerated from .mq5 compiled defaults — if card strategy_params diverge from
  compiled defaults, the card should be updated separately. No card was edited (params came from .mq5).
- QM5_1095 (qp-dollar-carry-basket) is FX-only; setfiles regenerated but NOT requeued (commission kills FX).

## Next Step

OWNER to review wave-2 summary. Wave-3 requeue (remove per-wave cap or raise it) is a
separate ops_issue if the 1206 remaining items are worth pursuing.
