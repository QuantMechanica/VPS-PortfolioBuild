# QM5_20246 FX cointegration Q04 priority handoff

Date: 2026-08-31 UTC (`2026-08-31T11:01:41Z`); 13:01 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `0e88dd3f466eb1b5e5527849228d019014207ea8`

Status: the frozen 66-pair scan remains fully mechanized, both preferred
anchors remain past Q02, and the unique rank-60 USDJPY/EURGBP fallback has
advanced from Q03 PASS to a priority-bound existing Q04 row. No Card, EA,
work-item identity, verdict, claim, tester, terminal, or portfolio object was
created.

## Governed frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 scan tested all
66 FX relationships and admitted only two under its published survivor
criterion. Current canonical state confirms:

| EA | Pair | Current chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. A fresh
case-insensitive approved-card census found 121 cointegration/coint identities,
121 matching EA directories, and zero unbuilt identities. Creating another
Card, EA, basket manifest, magic allocation, or Q02 row would therefore
duplicate governed work. The Strategy Card extraction and EA-build gates
remained closed, and the existing-forex fallback applied.

## Existing forex fallback advanced

The selected concrete pair is frozen-scan rank 60,
`QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1`. It trades `USDJPY.DWX` and
`EURGBP.DWX`; `GBPUSD.DWX` and `EURUSD.DWX` provide conversion history only.
The approved Card and sealed EA remain fixed-beta, structural, learned-model-
free, D1, and low-frequency. The logical backtest setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The source evidence is deliberately adverse: DEV net Sharpe `0.253`, OOS net
Sharpe `-0.457`, OOS return `-6.372%`, 13 OOS state changes, and a
`132.813`-D1-bar half-life. This remains a one-shot falsification path, not
permission to refit the beta or add a rescue filter.

Q03 work item `46c97cb3-45f9-475d-8e6b-aa7bdd40df0e` completed as an
authenticated deterministic PASS. Its two real-tick runs were identical:
136 trades, PF `1.11`, drawdown `5.43%`, and net profit `1610.27`, with no
OnInit failure. The summary is
`D:/QM/reports/work_items/46c97cb3-45f9-475d-8e6b-aa7bdd40df0e/QM5_20246/20260831_091513/summary.json`
(SHA-256
`738f0308deba533cec14b8fc5623a9037dc05e511450ae00294ba02f77fbf55f`).

## Exact in-place queue mutation

Under the global factory mutation lock, an exact compare-and-swap changed
only the payload of the already-existing Q04 row
`1a269ff4-cbef-429b-afa4-47a3cc692916`. It added
`priority_track=true`, the bounded reason
`board_advisor_fx_fallback_rank60_q04_after_q03_pass`, and dependency,
capacity, and provenance evidence. The original `updated_at` was preserved.

| Phase | Work item | State |
|---|---|---|
| Q02 | `d8619249-7764-4d80-a714-6b7922b73b4b` | done / PASS |
| Q03 | `46c97cb3-45f9-475d-8e6b-aa7bdd40df0e` | done / PASS |
| Q04 | `1a269ff4-cbef-429b-afa4-47a3cc692916` | pending, priority-bound, unclaimed, attempt 0 |

The canonical pending rank improved from 6,830 to 1,381. Both the 9,012-row
eligible selector count and the 9,223-row raw pending count stayed unchanged.
Exactly one matching open Q04 row remains, with zero active holds, zero
supersession relations, and zero active quarantine rows. Audit event `381107`
records the mutation. No duplicate row or pipeline verdict was created or
changed.

The reversible preimage/postimage journal is
`D:/QM/reports/state/qm5_20246_q04_priority_20260831T110141Z.journal.json`
(SHA-256
`418a5e463084e989ddd2ba3b00919568d604f3d439e122fed8a6da43f8acf9f0`,
state `COMMITTED`). The mutation lock released normally.

## Capacity and serialized pacing

The apply-time five-sample CPU window was `92.393512%`, `76.467789%`,
`84.669589%`, `88.876396%`, and `85.562840%`: average `85.594025%`, maximum
`92.393512%`, both below the explicit 97% hard ceiling.

One legitimate multisymbol row already owned the serialized basket lane:
`QM5_20224` Q07 work item `b38e2753-1d57-45d9-8562-3cafc0e105a0` on T9.
Accordingly, this wake performed only the queue-priority handoff. It did not
claim Q04, run a dispatch tick, start MT5, or control any terminal. The
resident paced worker may claim the row after the basket lane clears.

## Failed-closed preview and safety

The first rank-preview attempt failed before any mutation because the generic
in-memory priority helper had not copied the current selector's
`work_item_supersedes` table. SQLite raised `no such table:
work_item_supersedes`; the transaction rolled back, no journal or event was
created, and the exact target preimage was reverified. The successful retry
used the unchanged canonical selector inside a rolled-back SQLite savepoint.
No shared controller or selector criterion was edited.

No strategy source, binary, setfile, manifest, registry, magic row, verdict,
terminal, or worker changed. The portfolio gate and its
`portfolio_admission`, `_kpi`, and `_q08_contribution` surfaces, the T_Live
manifest and terminal, AutoTrading, and all live/deploy manifests were
untouched. Concurrent unrelated worktree changes were preserved.

Machine-readable evidence is
`artifacts/qm5_20246_q04_priority_20260831T110141Z_board_advisor.json`.

Let the resident paced worker claim this exact Q04 row only after the
serialized multisymbol lane clears. Do not enqueue a duplicate or manually
force a second basket. A terminal economic or cadence failure retires the
sleeve without refit or rescue.
