# QM5_20224 FX cointegration Q03 false-progress recovery

Date: 2026-08-29 UTC (`2026-08-29T17:31:54Z`); 19:31 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `3a269f16e88c2ae8fb840109bb5f0920c0648901`

Status: the existing EURUSD/EURJPY logical-basket Q03 row was falsely reaped
while its tester was demonstrably alive. The governed exact-row recovery
operator returned that same row to pending. No Card, EA, setfile, manifest,
work item, tester, terminal, or portfolio-gate object was created.

## Outcome

Q03 work item `3c74eb04-7e19-4aa0-8dcf-3f004faaa946` had changed from active
to `failed / INFRA_FAIL` at `16:53:46Z` with reason
`active_timeout:NO_FORWARD_PROGRESS`. The reaper acted only 32.51 minutes into
a 450-minute absolute budget and treated `16:21:16Z` as the latest progress.

The bounded recovery dry run found stronger work-item-bound evidence inside
that exact blind window: the T4 MT5 journal recorded the tester at 94% at
`16:47:15Z`. This is after the operator's 30-second proof margin and before
the kill. It proves that the run was alive when it was classified as stalled;
the row has no economic verdict to preserve.

`tools/strategy_farm/requeue_false_progress_reap.py` was applied with
`--only 3c74eb04-7e19-4aa0-8dcf-3f004faaa946`. Its mutation lock and guarded
transaction changed exactly one row. Verification found the same work-item ID
`pending`, unclaimed, attempt zero, and unverdict. Its existing
`priority_track=true` and reason `board_advisor_fx_fallback_rank46_q03` remain
intact. Exactly one matching open Q03 row exists; no successor or duplicate was
enqueued.

The reversible runtime journal is
`D:/QM/reports/state/qm5_20224_q03_false_progress_requeue_20260829T173134Z.journal.json`
(SHA-256
`93be194d466dbd33b530868845863609bebba57349a7e7363606fd7439e049cf`).
The guarded payload changed from SHA-256
`9d41113c21e01620032c57134dd40329e4ac6b85cf0ef7b4b840167517caaced`
to
`b9e8294d644b5d450601ea7eb7456e83165716f52e6b4a5cabf4e8f95eb484b4`.
The historical `EVIDENCE_UNAVAILABLE:active_timeout:NO_FORWARD_PROGRESS`
path remains on the pending row because the supported operator preserves it
as provenance.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3 hard
criterion selected only two relationships from the 66-pair scan:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current logical Q02 `ONINIT` or `NO_HISTORY` blocker.
Historical invalid per-leg rows do not supersede their later logical-basket
Q02 PASS rows.

The committed sign-aware coverage artifact
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships with zero uncovered. The preceding broader
census found a matching EA directory for every approved cointegration Card.
Creating another Card or build would duplicate governed coverage, so the
strategy-card extraction and EA-build skill gates remained closed.

## Existing sleeve and sealed package

The selected fallback remains scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX` on D1 with frozen beta `-0.236324029`; `USDJPY.DWX` is
conversion-history-only. Its adverse source evidence—DEV net Sharpe `0.473267`,
OOS net Sharpe `-0.118543`, OOS return `-1.026394%`, 17 state changes, and a
`137.788`-D1-bar half-life—permits a one-shot falsification, not refitting or
rescue tuning.

The source/build package was reverified unchanged:

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Card schema/ML lint passed with no ML hits. The logical backtest setfile still
uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The Card
and EA remain structural, fixed-beta, low-frequency, deterministic, and free
of ML, adaptive refit, banned indicators, grid, martingale, or portfolio
feedback.

Current lineage:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending after exact-row
  infrastructure recovery.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and not advanced ahead
  of Q03.

## Capacity and paced-fleet boundary

The five one-second whole-host CPU samples immediately before apply were
`89.749746%`, `82.471962%`, `81.350001%`, `83.108725%`, and `83.310610%`.
Average CPU was `83.998209%` and maximum CPU was `89.749746%`, both below the
explicit `97%` ceiling. Free physical RAM was `28.732681 GB`, above the 12 GB
multisymbol floor, and commit headroom was `81.544010 GB`, above the 48 GB
floor.

Another legitimate multisymbol Q04 run already owns the serialized basket
lane: `QM5_41057_XAU_XAG_WFLOWAGREEFADE_D1`, work item
`64a15953-f1cc-4b98-938e-b6f89d88fe9b`, on T8. The recovered FX row was not
manually dispatched. The resident worker can claim it after that lane clears
and its normal admission guards pass.

## Safety boundary

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, Q08 state, T_Live, AutoTrading, live/deploy manifest,
Card, EA source, EX5, setfile, basket manifest, registry, magic row, resolver,
new queue row, tester, reservation, worker, or terminal was created or changed.
Unrelated shared-worktree changes were preserved and excluded from this
handoff.

Machine-readable evidence:
`artifacts/qm5_20224_q03_false_progress_requeue_20260829T173154Z_board_advisor.json`.

## Continuation condition

Let the resident worker reclaim this exact priority-bound Q03 row after the
active basket releases the serialized lane. Only a canonical Q03 PASS permits
advancing Q04. Do not enqueue a duplicate or blindly retry another
infrastructure failure.
