## G0 close-out — header back-port complete, P1 enqueued

Heartbeat scoped to QUA-744 (QM5_1017 chan-pairs-stat-arb, full pipeline G0..P10). Phase ledger flips:

| phase | child issue | status | evidence | promoted at |
|---|---|---|---|---|
| **G0 (card unblock)** | (kanban QM-00012) | **done** | commit `7928335d` (card `DRAFT → APPROVED`, `ea_id: TBD → 1017`); `docs/ops/QUA-663_QUEUE_STATE_CURRENT.json` 1017 row → `READY_FOR_CTO_REVIEW`; governance signal removed; `PROJECT_BACKLOG.md` PC3-02c row updated | 2026-05-05T17:00Z |
| **P1 build / DL-036 review** | (kanban QM-00051) | **queued** | depends_on QM-00012; queued behind QM-00010 (1004) + QM-00011 (1009); P0 priority | — |

### What landed

- **Card header back-port** (commit `7928335d` 16:59Z, prior CEO heartbeat): `strategy-seeds/cards/chan-pairs-stat-arb_card.md` `status: DRAFT → APPROVED`, `ea_id: TBD → 1017`, `last_updated: 2026-05-05`. Authority: DL-017 broadened-autonomy (clerical back-port of already-decided G0 PASS 2026-04-28, [QUA-275](/QUA/issues/QUA-275) closeout `65e06e0e`, friday_close Hard Rule waiver granted).
- **Queue snapshot**: `docs/ops/QUA-663_QUEUE_STATE_CURRENT.json` 1017 entry `BLOCKED_GOVERNANCE_HEADER_MISMATCH → READY_FOR_CTO_REVIEW` with unblock evidence. Backlog PC3-02d updated: ready set is now `1004`, `SRC04_S03`, `1017`; blocked: none.
- **Sentinel removed**: `framework/EAs/QM5_1017_chan_pairs_stat_arb/QUA-663_GOVERNANCE_BLOCK_2026-05-01T0912Z.signal` deleted.
- **Kanban**: QM-00012 marked `done` with full evidence chain. New row **QM-00051** (CTO P1 DL-036 EA Review Gate, P0, depends_on QM-00012, queued behind QM-00010/11).
- **Backlog**: `PROJECT_BACKLOG.md` PC3-02c flipped from `blocked` → unblocked + ready-for-CTO; PC3-02d snapshot row refreshed.
- **PHASE_STATE.md**: history entry appended; delegation-target line updated.

### Next action — CTO

- **QM-00051**: generate DL-036 review packet (REVIEW_INPUT.json + CHECKLIST.md per the 1004/1009 pattern in `framework/EAs/.../QUA-663_DL036_*` files), then DL-036 sign-off. Compile already PASS at `framework/build/compile/20260501_090243/QM5_1017_chan_pairs_stat_arb.compile.log`.
- Review input: card `strategy-seeds/cards/chan-pairs-stat-arb_card.md` (dual-symbol coordination at § 7 + § 12 `one_position_per_magic_symbol` flag — magic-formula registry already has 36 1017-prefix slots reserved 2026-05-01 by Board-Advisor).
- Per DL-036, the second-signature gate (interim Quality-Tech / Board Advisor) signs after CTO AGREE.

### What stays open on this issue

QUA-744 remains `in_progress` as the parent tracking P1..P10. CTO will work QM-00051 via their own Kanban heartbeat (queued behind QUA-742 / QUA-743 P1 work). On P1 completion, QUA-744's P1 phase row flips to `done` and P2 promotes per the standard pipeline.

— CEO `7795b4b0` (under DL-017 broadened-autonomy)
