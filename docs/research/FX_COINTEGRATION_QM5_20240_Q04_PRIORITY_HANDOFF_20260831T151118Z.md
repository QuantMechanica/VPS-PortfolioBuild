# QM5_20240 FX cointegration Q04 priority handoff

Date: 2026-08-31 UTC (`2026-08-31T15:11:18Z`); 17:11 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `df3b10766076b6d58199743ea1f932e9db856064`

Status: the frozen 66-pair frontier remains fully mechanized, both preferred
anchors remain past Q02, and the existing rank-59 USDCHF/GBPJPY sleeve has
advanced from Q03 PASS to a priority-bound unique Q04 row. No Card, EA,
work-item identity, verdict, tester, terminal, or portfolio object was created.

## Governed frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 scan tested all
66 FX relationships and admitted only two under its published survivor
criterion:

| EA | Pair | Current chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. A fresh
case-insensitive content census found 123 approved cointegration/coint Card
identities, 123 matching EA directories, and zero unbuilt identities.
Creating another scan-derived Card, EA, basket manifest, magic allocation, or
Q02 row would therefore duplicate governed work. The Card-extraction and EA-
build skill gates remained closed, and the existing-forex fallback applied.

## Existing forex fallback advanced

The selected pair is frozen-scan rank 59,
`QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`. It trades `USDCHF.DWX` and
`GBPJPY.DWX`; `USDJPY.DWX` provides conversion history only. The approved
implementation remains structural, fixed-beta, learned-model-free, D1, and
low-frequency. The logical backtest setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The source evidence is deliberately adverse: DEV net Sharpe `-0.079`, OOS
net Sharpe `-0.430`, OOS return `-4.295%`, 15 OOS state changes, and a
`95.663`-D1-bar half-life. This remains a one-shot falsification path, not
permission to refit the beta or add a rescue filter.

Q03 work item `65a8b9cb-2c57-4068-81fb-2158f7b1beb7` completed as an
authenticated deterministic PASS. Its two real-tick runs were identical:
130 trades, PF `0.59`, drawdown `10.99%`, and net profit `-8124.74`, with no
OnInit failure. Q03 establishes repeatability, not economic edge; Q04 remains
the proper economic judge. The summary is
`D:/QM/reports/work_items/65a8b9cb-2c57-4068-81fb-2158f7b1beb7/QM5_20240/20260831_131605/summary.json`
(SHA-256
`f81a73a5616cd15d637ca7d8e8322c9f9438f414925d8ec0779bc0cadd6bde72`).

## Exact in-place queue mutation

Under the global factory mutation lock, an exact compare-and-swap changed only
the payload of existing Q04 row
`85e98029-14f6-4f73-a991-b814d4f3c151`. It added
`priority_track=true`, the bounded reason
`board_advisor_fx_fallback_rank59_q04_after_q03_pass`, and dependency,
capacity, and provenance evidence. The original `updated_at` was preserved.

| Phase | Work item | State |
|---|---|---|
| Q02 | `24154a28-be35-469e-a5be-58881e29733c` | done / PASS |
| Q03 | `65a8b9cb-2c57-4068-81fb-2158f7b1beb7` | done / PASS |
| Q04 | `85e98029-14f6-4f73-a991-b814d4f3c151` | pending, priority-bound, unclaimed, attempt 0 |

The canonical pending rank improved from 6,559 to 1,385. Both the 8,736-row
eligible selector count and 8,949-row raw pending count stayed unchanged.
Exactly one matching open Q04 row remains, with zero active holds, zero
supersession relations, and zero active quarantine rows. Audit event `381130`
records the mutation. No duplicate row or pipeline verdict was created or
changed.

The reversible preimage/postimage journal is
`D:/QM/reports/state/qm5_20240_q04_priority_20260831T151117Z.journal.json`
(SHA-256
`a96f7dbe1b6597e636410b0b2f2d0aac22b64c81c027739a969d9f3ad3dadf1c`,
state `COMMITTED`). The mutation lock released normally.

## Capacity and serialized pacing

The apply-time five-sample CPU window was `87.116200%`, `80.535273%`,
`90.823216%`, `86.140770%`, and `82.922458%`: average `85.507583%`, maximum
`90.823216%`, both below the explicit 97% hard ceiling.

One legitimate multisymbol row already owned the serialized basket lane:
`QM5_20294` XAU/XAG Q03 work item
`9437109a-799b-4f29-a501-89e6b4a3809c` on T8. Accordingly, this wake performed
only the queue-priority handoff. It did not claim Q04, run a dispatch tick,
start MT5, or control any terminal. The resident paced worker may claim the
row only after the basket lane clears.

The first mutation attempt failed closed before writing when the same XAU/XAG
row acquired the lane between the initial read-only snapshot and the exact
transaction. No database mutation or journal resulted. The successful retry
revalidated the unchanged target preimage and recorded the active lane rather
than bypassing it.

## Verification and safety

- Strategy Card schema/ML lint: PASS, with no ML hits or missing sections.
- Basket work-item and manifest regression suites: 65 passed in 8.38 seconds.
- Card, MQ5, EX5, manifest, setfile, Q03 evidence, and journal hashes were
  reverified.
- No strategy logic, binary, setfile, manifest, registry, magic row, or gate
  criterion changed.
- No portfolio admission/KPI/Q08-contribution surface, T_Live manifest or
  terminal, AutoTrading setting, or live/deploy manifest was touched.

Machine-readable evidence is
`artifacts/qm5_20240_q04_priority_20260831T151118Z_board_advisor.json`.

Let the resident paced worker claim the exact Q04 row after the serialized
basket lane clears. Do not enqueue a duplicate or manually force a second
basket. A terminal economic or cadence failure retires the sleeve without
refit or rescue.
