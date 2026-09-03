# DL-089 measurement siblings, wave 3 — the recompiled pairs (2026-09-03)

Router task `262f7959-4179-4ab9-b363-a68d0cd3f852` (ops_issue, Claude lane), executed as Opus workflow
`wg8u1drba` (one isolated worktree per sibling, one adversarial verifier each; all three ok=true), CEO merge
`5e6f19a61a`, governed allocations `270019d078` / `129c6e887e` / `3e8cd06ec1`.

Why: after OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903 batch 1, the three recompiled pairs are
contiguous through Q11 (12710 Q11 PASS 11:25Z, 11910 Q10_NEWS CONFIG_LOCKED 11:42Z, 10700 in Q10_NEWS) but
`dl089_matrix_service` defers their Q12 program rows with `expected one approved _opt sibling for <ea>/<symbol>,
found 0` — the census runs on a measurement sibling carrying the pattern-permission corset, never on the parent.

| Sibling | Parent | Symbol / TF | Magic | Compile row |
|---|---|---|---|---|
| QM5_41331_commodity-tsmom-12m-atr-opt | QM5_12710 (ex5 11474d4c…, recompiled 03:xxZ) | XTIUSD.DWX D1 | 413310000 | 98bfe19a |
| QM5_41332_larry-williams-18ma-2outside-bars-d1-opt | QM5_11910 (ex5 e18d477e…) | NZDUSD.DWX D1 | 413320000 | fa3cff26 |
| QM5_41333_tv-liq-break-opt | QM5_10700 (ex5 5fbf2ba0…) | XAUUSD.DWX H1 | 413330000 | c299634e |

Recipe (wave 2 = QM5_41321–41324, task 57bc396f): parent `.mq5` at the recompiled corset-repaired revision
(`5afa209e41`) + DL-089 corset (`QM_PATTERN_PERMISSION_EA_MANAGED`, `QM_PatternPermission.mqh`, 6 `opt_pp_buy/sell`
inputs, `Pattern_AllowsRequest` before every order, `QM_FrameworkTrackOpenPositionMae()` first in OnTick,
`ZeroMemory` on `QM_EntryRequest`), `qm_ea_id` = sibling id; measurement-only card (parent_ea_id, `Target symbols:`
line, g0_status APPROVED, 'No live or pipeline verdict is authorized'); backtest set copied from the parent
(RISK_FIXED, no build_hash line — `release_compile_wave` injects it); SPEC. Verifier notes (all non-material):
41331 report wording ('all parameters byte-identical' — qm_ea_id differs by design); 41332 em-dash in a comment
(normalized to ASCII+CRLF by the CEO before merge, all three sources are now ASCII/CRLF like wave 2); 41333
cosmetic header/log-string differences and the parent's retired news-filter inputs absent from the set (correct).
`build_gate_hardening.py` PASS for all three in the canonical checkout after normalization.

Governed steps (CEO, 12:1xZ–12:2xZ): cards copied to `D:/QM/strategy_farm/artifacts/cards_approved/` and
`C:/QM/repo/artifacts/cards_approved/`; `governed_magic_allocator --card` serially with a registry commit between
allocations (the allocator's clean-registry guard; it also aborted first on the uncommitted mailbox reservation
41325 → committed `8a4bd604fe`); `farmctl enqueue-compile <label>` ×3 (rows hold COMPILE_EA_WORKER_ROLLOUT_PENDING);
`release_compile_wave.py --apply --backup-reuse-max-age-minutes 0 --max-items 3` released the three EARLIEST
held rows instead (August siblings QM5_41175/41177/41182 — legitimate governed rows, left released), so the wave-3
rows were released by `--work-item-id`; all three marked priority_track (claim positions 53–55 at 12:22Z).

Next: COMPILE_OK + build gate → `dl089_matrix_service` seeds the Q02 census prerequisite per sibling → the Q12 rows
(12710 `9384656c` at queue rank 5; 11910/10700 once minted) materialize census cells in their slots.
`framework/registry/dxz23_execution_contracts.json` carries an uncommitted news-calendar sha refresh from the daily
calendar task — deliberately NOT committed by the CEO (live execution contract file).
