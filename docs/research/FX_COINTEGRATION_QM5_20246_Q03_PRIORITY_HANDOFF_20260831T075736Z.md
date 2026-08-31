# QM5_20246 FX cointegration Q03 priority handoff

Date: 2026-08-31 UTC (`2026-08-31T07:57:36Z`); 09:57 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `e6b1f0e27d74d47cad0dc9cbb88639660989a3cb`

Status: the frozen 66-pair scan has no unbuilt relationship, both preferred
anchors are beyond Q02, and the unique rank-60 USDJPY/EURGBP fallback has been
advanced by priority-binding its existing Q03 row in place. No Card, EA,
work-item identity, verdict, claim, tester, or terminal was created.

## Governed frontier decision

The reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3
criterion admitted only the AUDUSD/NZDUSD and EURJPY/GBPJPY anchors. Current
canonical state confirms:

| EA | Pair | Current chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The durable
sign-aware audit accounts for all 66 scan relationships, with zero uncovered.
A fresh approved-card census found 120 cointegration/coint EA identities, 120
matching EA directories, and no unbuilt identity. Creating another Card, EA,
manifest, or Q02 row would therefore duplicate governed work or weaken the
published source criterion. The strategy-card extraction and EA-build skill
gates correctly remained closed.

## Existing forex fallback advanced

The selected concrete pair is frozen-scan rank 60,
`QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1`. It trades `USDJPY.DWX` and
`EURGBP.DWX`; `GBPUSD.DWX` and `EURUSD.DWX` provide conversion history only.
The EA is structural fixed-beta D1 residual reversion, with no learned model,
adaptive refit, banned indicator, grid, or martingale.

The source evidence remains deliberately adverse: DEV net Sharpe `0.253`, OOS
net Sharpe `-0.457`, OOS return `-6.372%`, 13 OOS state changes, and a
`132.813`-D1-bar half-life. This is a one-shot falsification path, not
permission to refit the beta or add a rescue filter.

Fresh package checks passed:

- Strategy Card schema/ML lint: PASS, no missing sections or ML hits.
- Basket manifest: two traded legs and two conversion-history-only symbols.
- Q02 evidence: PASS, 136 trades, PF 1.11, 5.43% drawdown, no OnInit failure.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Exact in-place queue mutation

Under the global factory mutation lock, an exact compare-and-swap changed only
the existing Q03 payload. It added `priority_track=true`, the bounded priority
reason, and the source/dependency/capacity provenance. The original
`updated_at` was preserved.

| Phase | Work item | State |
|---|---|---|
| Q02 | `d8619249-7764-4d80-a714-6b7922b73b4b` | done / PASS |
| Q03 | `46c97cb3-45f9-475d-8e6b-aa7bdd40df0e` | pending, priority-bound, unclaimed, attempt 0 |
| Q04 | `1a269ff4-cbef-429b-afa4-47a3cc692916` | pending and deliberately untouched behind Q03 |

The pending-row count stayed 9,119 inside the transaction. Canonical rank
improved from 8,360 to 1,424. A post-commit read observed rank 1,426 and 9,118
pending rows because unrelated workers resumed queue claims after the lock was
released; the target remained unique and priority-bound.

There is exactly one matching Q03 identity, with zero active holds, zero
supersession relations, zero active quarantine rows, and one audit event
(`381084`). The reversible journal is
`D:/QM/reports/state/qm5_20246_q03_priority_20260831T075736Z.journal.json`
(SHA-256
`2f01271e7597908fc4963d7e9dd3dc1c16f12489a96ceb46fb026575cabbe7a9`,
state `COMMITTED`). The mutation lock released normally.

## Capacity and pacing

The apply-time five-sample CPU window was `75.698361%`, `65.319275%`,
`64.261691%`, `64.675439%`, and `63.905973%`: average `66.772148%`, maximum
`75.698361%`, both below the explicit 97% ceiling. No multisymbol work item was
active inside the locked transaction.

Two earlier attempts failed closed before SQLite because concurrent workers
held the live mutation lock. The lock was neither reaped nor bypassed. The
successful action did not dispatch Q03 or start MT5; the resident paced worker
owns the eventual claim.

## Safety and continuation

No strategy, Card, MQ5, EX5, setfile, basket manifest, registry, magic row,
queue identity, status, claim, attempt, verdict, terminal, worker, compile,
smoke test, or backtest changed apart from the bounded Q03 payload handoff and
its audit event. The portfolio gate and its admission/KPI/Q08-contribution
surfaces, the T_Live manifest and terminal, AutoTrading, and all live/deploy
manifests were untouched. Concurrent unrelated worktree changes were
preserved.

Machine-readable evidence is
`artifacts/qm5_20246_q03_priority_20260831T075736Z_board_advisor.json`.

Let the resident paced worker claim this exact Q03 row. Do not enqueue a
duplicate, manually force a second basket, or advance Q04 before authenticated
Q03 PASS. A terminal economic failure retires the sleeve rather than
authorizing parameter rescue.
