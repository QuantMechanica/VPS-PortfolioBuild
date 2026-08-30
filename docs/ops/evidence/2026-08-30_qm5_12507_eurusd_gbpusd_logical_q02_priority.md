# QM5_12507 EURUSD/GBPUSD logical Q02 priority advance

Date: 2026-08-30 UTC (`2026-08-30T01:28:56Z`)

Branch: `agents/board-advisor`

Outcome: advanced one existing FX cointegration basket through the governed
fallback path. The exact logical Q02 row remains pending but is now on the
priority track; no duplicate row or manual tester run was created.

## Frontier decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair scan. The durable relationship audit accounts for all 66 pairs with
zero uncovered, so a new Card/EA would duplicate governed coverage. The EA
build skill's preflight is therefore closed for lack of an approved unbuilt
identity.

Neither preferred anchor needs Q02 infrastructure repair:

| EA | Pair | Current canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Historical `ONINIT`, `NO_HISTORY`, invalid, and per-leg rows do not supersede
the later logical-basket Q02 PASS rows.

The mission's existing-card fallback selected
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`, the EURUSD/GBPUSD relationship at
rank 24 in the frozen all-sign scan order. This is an existing approved,
source-backed structural basket, not a newly claimed survivor. The scan result
is below the published survivor bar, so Q02 is a falsification/economics gate;
failure does not authorize refitting or a rescue filter.

## Exact Q02 advance

Worker-bound Q01 work item `7d1a179d-4d25-5d37-a69a-3a52fd78ae63`
completed `PASS` with 632 observed leg trades. Its authenticated receipt had
already admitted exactly one logical Q02 seed:
`547c4fd3-f3fd-4c59-b9dc-654e96521251`.

Under the global factory mutation lock, an exact compare-and-swap changed only
that row's payload. The row identity, status, attempt, claim, verdict, and FIFO
timestamps were preserved.

| Field | Before | After |
|---|---:|---:|
| Open exact Q02 rows | 1 | 1 |
| `priority_track` | absent | `true` |
| Canonical pending rank | 7,816 | 1,860 |
| Status | pending | pending |
| Attempt | 0 | 0 |
| Claimed by | null | null |
| Verdict | null | null |

Audit event `380575` records the mutation. The reversible exact-row journal is
`D:/QM/reports/state/qm5_12507_logical_q02_priority_20260830T012744Z.journal.json`
(SHA-256
`ac080844ef8ea5052b14d42c2347ff260f76cd1ca5d1f2550c943c6ce4952b0b`).
No enqueue or requeue call was made because the exact logical row already
existed.

## Structural and risk contract

- Host/pair: `EURUSD.DWX` / `GBPUSD.DWX`, completed H1 bars.
- Mechanic: bounded Engle-Granger residual/z-score reversion, one two-leg
  package at a time; no intrabar or scalping entry.
- Backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- No ML, adaptive parameter selection, grid, martingale, portfolio feedback,
  or newly added indicator.
- The approved Card forecasts 20 trades/year/symbol, while the Q01 smoke
  observed 632 leg trades. That activity mismatch is disclosed rather than
  tuned away; unchanged Q02 criteria remain the judge.

The basket manifest declares all four symbols the EA warms, including the
NDX/WS30 companion pair, while the selected logical host binds the FX pair.
Current artifact hashes are sealed in the machine-readable receipt.

## Verification and pacing

- `validate_symbol_scope.py`: `BASKET_OK`, zero violations.
- `validate_build_guardrails.py`: PASS, zero findings across seven files.
- `test_fx_basket_manifests.py`: 47 passed.
- Five pre-apply CPU samples averaged `39.165115%`; maximum was
  `41.119331%`, below the explicit `97%` ceiling.
- The serialized multisymbol lane remained owned by `QM5_20294` Q04 on T4.
  No second basket, dispatch tick, terminal reservation, or tester was started.

An initial attempt to make a full SQLite backup was abandoned before its write
transaction because the active WAL repeatedly restarted the backup. The exact
owned Python child was identity-checked and stopped, its dead lock was removed
through the identity-safe stale reaper, and the 138,911,744-byte incomplete
backup was removed. The target row and audit events were verified unchanged
before the successful row-journal/CAS operation.

## Safety

No portfolio admission gate, portfolio KPI, `_q08_contribution`, Q08 verdict,
T_Live manifest, T_Live process, AutoTrading state, or live/deploy artifact was
readied or changed. Existing unrelated shared-worktree changes were preserved.

Machine-readable evidence:
`artifacts/qm5_12507_eurusd_gbpusd_logical_q02_priority_20260830T012744Z_board_advisor.json`.
