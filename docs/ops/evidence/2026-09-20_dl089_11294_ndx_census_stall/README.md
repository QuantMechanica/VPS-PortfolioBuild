# DL089 QM5_11294/QM5_41347 NDX.DWX OPT_CENSUS stall — root cause + claim-order diagnosis

Task: `14a9cbf1-94bf-412c-8b8d-ae6ee3766594` (router `ops_issue`, origin: Fable 2026-09-20
counter path 11294/NDX). No verdict mutation performed. All timestamps UTC.

## Scope

`QM5_41347_cs-ichi-cloud-opt` is the governed optimization-slot successor of
`QM5_11294_cs-ichi-cloud` (magic registry: ea_id 41347, allocated 2026-09-05). Its
`OPT_CENSUS` batch for `NDX.DWX` (work items created `2026-09-20T08:08:41.396889Z`,
1085 rows total) stalled at:

- 18 `MEASURED` (`2026-09-20T08:11:46Z` … `08:31:35Z`)
- 8 `INFRA_FAIL` (`2026-09-20T08:31:49Z` … `08:34:31Z`) — work items
  `a714d062-7bbe-55a7-a77d-9a82b4a58278`, `9326c580-de6e-5e6e-850e-ceb395e5f93a`,
  `e437391f-bcb4-5ac2-8274-2638ff97ae2a`, `2233671b-f4f9-555c-a30d-b777481e6131`,
  `88b687d4-92c5-5fd9-bc52-e962f6970e91`, `a89b49a8-b54f-590f-8e0c-ec8bfa8acaa4`,
  `eade8a6f-d670-5a42-9d1a-efbe77d3728f`, `910c695a-4f59-55af-bb8a-c220e79ee8fe`
- 1059 `pending`, never returning to the claimable pool.

## 1. Root cause of the 8 ONINIT_FAILED cells — stale compiled magic-resolver table

All 8 tester logs (`raw/run_01/20260920.log` under each work item's `evidence_path`)
end with the identical signature:

```
QM5_41347_cs-ichi-cloud-opt (NDX.DWX,H4)  2019.01.01 00:00:00  EA_MAGIC_NOT_REGISTERED: ea_id=41347 slot=1 magic=413470001
Tester  tester stopped because OnInit returns non-zero code 1
```

`qm_magic_slot_offset=1` (`magic 413470001 = ea_id*10000 + slot`) is rejected by
`framework/include/QM/QM_MagicResolver.mqh`'s baked-in registry lookup
(`framework/include/QM/QM_MagicResolver.mqh:195`, `QM_Errors.mqh` constant
`EA_MAGIC_NOT_REGISTERED`) — this is a **compiled-in identity failure**, not a
copy-on-claim history problem or a generic launch race.

This is a **stale-include-closure race**, not a missing registry row:

- `framework/registry/magic_numbers.csv:18248-18249` already carries both rows —
  slot 0 (`XAUUSD.DWX`, allocated 2026-09-05) and **slot 1 (`NDX.DWX`, allocated
  2026-09-19, "claude governed slot add", active)**.
- The canonical `framework/include/QM/QM_MagicResolver.mqh` (regenerated
  `2026-09-19T18:20:57Z`, confirmed by parsing its `QM_MAGIC_REG_EA_ID` /
  `QM_MAGIC_REG_SLOT` arrays) **already contains both rows** for ea_id 41347
  (array indices 18179/18180: slot 0 and slot 1).
- `work_item_transition_ledger` records, at `2026-09-20T08:00:14Z`:
  `release_hold` on work item `20cce28d-23d8-4f54-8b96-b3f983e24586`, reason
  *"Fable 2026-09-20: QM5_41347 STALE_INCLUDE_CLOSURE rebuild (authority
  router_ops_issue:340b228c) for the NDX.DWX measurement slot"* — matching the
  `STALE_INCLUDE_CLOSURE_REGISTRATIONS` entry for
  `router_ops_issue:340b228c-5d85-4980-826a-243fd95bcae8:QM5_41347` in
  `tools/strategy_farm/compile_work_items.py:3464-3482`. This authorized a rebuild
  of the EA specifically because its previously-compiled `.ex5` no longer matched
  the live resolver.
- The rebuilt `.ex5` was deployed to **T1**
  (`D:\QM\mt5\T1\MQL5\Experts\QM\QM5_41347_cs-ichi-cloud-opt.ex5`,
  `last_write_utc = 2026-09-20T08:30:14.0282881Z`, sha256
  `3e475c8b7b6bf1596233768fc6b5852c0881f5c020d6ca08ec9b6f55abaa517d`, per the
  `execution_identity.expert_binary` block of every one of the 8 `INFRA_FAIL`
  summaries).
- T1's **local** include mirror
  (`D:\QM\mt5\T1\MQL5\Include\QM\QM_MagicResolver.mqh`) was not overwritten with
  the canonical (slot-1-bearing) content until **`2026-09-20T09:04:02Z`** —
  **34 minutes after** the `.ex5` above was already compiled and deployed.
- Verified now (post-sync): T1's include and the canonical repo include are
  byte-identical — SHA256 `1ede6377f740f18c86858a60b5081e480185995fae639efeadce093d27878e66`
  on both `D:\QM\mt5\T1\MQL5\Include\QM\QM_MagicResolver.mqh` and
  `C:\QM\repo\framework\include\QM\QM_MagicResolver.mqh` — so the *include tree* is
  fixed, but the **already-deployed `.ex5` was compiled before that fix landed on
  T1** and still has the stale table baked in.
- Timing corroboration: the last successful `MEASURED` cell on this batch
  completed at `08:31:35Z`; the first `INFRA_FAIL` began 14 seconds later at
  `08:31:49Z` — i.e. the swap from the old (correctly-matched, slot-0-only or
  pre-041347-slot1 census leg) `.ex5` to the new stale-relative-to-T1 rebuild
  landed **mid-census**, not before it started. That is why 18 cells measured
  cleanly and then every subsequent claim on T1 failed identically.
- Conclusion: `classify_candidate`'s `include_closure_sha256` staleness check
  (`tools/strategy_farm/compile_work_items.py:4960-4992`) compares a work item's
  *recorded* closure hash against the canonical repo's *current* embedded
  `QM_MAGIC_REGISTRY_SHA256` — it detects staleness relative to the **repo**, but
  nothing in the observed chain gates *dispatch to a specific terminal* on that
  terminal's **local** include mirror actually matching the same hash before
  cells are run there. The rebuild's release-hold fired before terminal T1's
  include mirror sync had caught up, so the fresh `.ex5` shipped with the T1-local
  (still stale) resolver table baked in.

## 2. Why the remaining 1059 cells are outside claim order

Not a program hang/freeze. `farm_state.sqlite:poison_pill_quarantine` shows an
**active, automatic circuit-breaker** row:

```
ea_id=QM5_41347  symbol=NDX.DWX  phase=OPT_CENSUS  active=1
verdict_reason='run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS'
consecutive_failures=8  successes_ever=0
quarantined_at=2026-09-20T14:34:03Z
evidence_path=D:\QM\reports\work_items\910c695a-4f59-55af-bb8a-c220e79ee8fe\QM5_41347\20260920_083413\summary.json
released_at=NULL
```

This is the farm's existing poison-pill safety mechanism (8/8 consecutive
`INFRA_FAIL`, 0 successes in that failure streak) withholding the
`(ea_id=QM5_41347, symbol=NDX.DWX, phase=OPT_CENSUS)` tuple from the claim pool —
by design, to stop burning tester capacity against a binary that cannot pass
`OnInit`. That is consistent with `work_items` state:

- 1056 pending rows: `updated_at == created_at` (`2026-09-20T08:08:41.396889Z`) —
  never claimed at all.
- 3 pending rows: `updated_at = 2026-09-20T08:38:29.949495Z` — one further
  claim-eligibility pass touched them (~4 min after the last `INFRA_FAIL`,
  consistent with the health/dispatch sweep that evaluates and then withholds
  quarantined tuples) but they were not claimed.

No `work_item_holds` row exists per-item for this batch — the block is at the
`(ea_id, symbol, phase)` quarantine level, not a per-row hold.

## 3. Governed recovery (recommended — not executed by this ticket)

Recompiling `QM5_41347_cs-ichi-cloud-opt` in active inventory is **ROT** per the
Stehende Vollmacht (never autonomous) — it is named here for OWNER/Codex-governed
execution, not performed by this task:

1. Recompile `QM5_41347_cs-ichi-cloud-opt` now that T1's local
   `QM_MagicResolver.mqh` matches canonical (confirmed above); verify pre-dispatch
   SHA256 match on every terminal in the OPT_CENSUS dispatch pool before the new
   `.ex5` is used, not just T1.
2. Confirm (smoke/Q02-style single-cell check) that the rebuilt `.ex5` passes
   `OnInit` for `ea_id=41347 slot=1` before resuming volume.
3. Append-only reruns of the 8 `INFRA_FAIL` cells
   (`farmctl enqueue-backtest --append-only-rerun-of <id>` for each of the 8 ids
   above) — GRÜN-authorized; the original `INFRA_FAIL` rows stay as evidence,
   never overwritten.
4. Release the `poison_pill_quarantine` row for
   `(QM5_41347, NDX.DWX, OPT_CENSUS)` only after step 2's smoke check passes —
   test-first, per the GRÜN infra-repair condition (blast radius: this one
   (ea_id, symbol, phase) tuple only).
5. Once released, the 1059 pending cells re-enter normal claim order and the
   census resumes toward its next level (L=2).

No `work_items` verdict, `poison_pill_quarantine` row, or registry file was
modified by this diagnostic pass. Supporting facts (hashes, row ids, timestamps)
are bound in `state.json` alongside this file.
