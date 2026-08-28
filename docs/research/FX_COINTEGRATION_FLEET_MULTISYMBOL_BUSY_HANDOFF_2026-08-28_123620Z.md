# FX cointegration fleet — multisymbol admission handoff

Date: 2026-08-28 UTC (`2026-08-28T12:36:20.7539152Z`); 2026-08-28
14:36 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `4fe80e6e0ead47818f2706f3500792cba1407737`

Status: the host is below the explicit CPU ceiling, but a legitimate active
multisymbol claim occupies the basket lane. No duplicate Card, EA, queue row,
claim, priority change, tester, or terminal action was taken.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3
criterion selected only two relationships from the 66-pair scan:
`QM5_12532` AUDUSD/NZDUSD and `QM5_12533` EURJPY/GBPJPY. Both are built, and
the committed sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships. A fresh approved-card/EA-directory census
also found 25 approved cointegration Cards and 25 matching EA directories,
with zero approved cointegration Cards left unbuilt.

Durable canonical evidence records both preferred anchors beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, then Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The historical ONINIT/NO_HISTORY attempts therefore do not authorize another
repair or duplicate Q02 enqueue. With no new scan-qualified unbuilt identity,
the Strategy Card extraction and V5 build skill gates remained closed.

## Existing FX fallback

The concrete non-duplicate fallback remains
`QM5_20255_USDCHF_EURJPY_COINTEGRATION_D1` in
`framework/EAs/QM5_20255_usdchf-eurjpy`. Its current canonical rows are:

- Q02 `72ca17ca-f9df-40d5-806d-1d815ee4ea08`: PASS.
- Q03 `d50b8721-4691-4ab3-b0b4-14012ecb6f6a`: PASS.
- Q04 `265024c2-9c2c-457e-8696-b22b75b7d722`: pending, unclaimed, attempt 0.

The Q04 row already carries the logical basket identity and manifest. The
sealed logical-basket setfile remains `RISK_FIXED=1000` and `RISK_PERCENT=0`;
its SHA-256 remains
`b4fb11d85874f8a382c3785c16783761ec791add216a89cb3dee0a8308bf3eec`.
No duplicate successor or queue-priority mutation was made.

The immediately preceding branch commit also added the distinct FX sleeve
`QM5_41140_NZDJPY_CARRY_UNWIND_CRISIS_MOMENTUM_D1`. Its compile row is
COMPILE_OK and its Q02 row `381b2608-c3f1-4493-88f8-9ed119e61d69` is already
pending with `priority_track=true`. It was not enqueued again.

## Capacity and binding admission state

Five one-second whole-host CPU readings at `2026-08-28T12:30:54.9778200Z`
were `93.073652%`, `85.000142%`, `72.851492%`, `67.012072%`, and
`80.078345%`. Average CPU was `79.603141%` and maximum CPU was `93.073652%`;
both are strictly below the governed `97%` ceiling.

The supported `farmctl mt5-slots` snapshot at `2026-08-28T12:33:36Z` found
only T10 running a factory terminal, with ten terminal-worker daemons, no
duplicate workers, and no orphaned factory terminal. T_Live and an unrelated
FTMO terminal were observed only to exclude them; neither was controlled.

The canonical DB nevertheless has an active multisymbol Q02 claim:
`QM5_41083_XAU_XAG_WLEGDIV_RV_D1`, work item
`5beefa38-44e0-4c60-89d0-0f487fb47ba7`, claimed by T1. Its identity-bound
payload records claim time `2026-08-28T08:12:47Z`, start time
`2026-08-28T08:21:51Z`, a 450-minute timeout, and the XAUUSD/XAGUSD basket
manifest. At observation time that governed window had not elapsed. The
supported reconciliation command returned no repair action. Absence of a T1
terminal process alone was not treated as proof of a stale claim.

`terminal_worker.py` deliberately refuses a new multisymbol claim while any
multisymbol row is active. That admission rule currently blocks both
`QM5_20255` Q04 and `QM5_41140` Q02. Bypassing or reclaiming the valid active
row would collide with the paced fleet, so neither basket was dispatched.

## Non-duplicate delta and safety boundary

This differs materially from the preceding FX receipt at
`2026-08-28T06:00:51Z`: CPU fell from a binding 98.206839% average / 100%
maximum to a non-binding 79.603141% / 93.073652%, the visible factory roster
contracted from T4/T6/T10 to T10, and the new QM5_41140 Q02 row appeared. The
current stop is the occupied multisymbol lane, not the CPU ceiling.

No Card, EA source, EX5, setfile, basket manifest, registry, magic row,
resolver, build result, queue row, claim, priority, status, verdict,
reservation, worker, terminal, or backtest was created or changed. The
portfolio gate, `portfolio_admission`, `_kpi`, `_q08_contribution`, T_Live,
AutoTrading, and live/deploy manifests were untouched. Existing unrelated
shared-worktree changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_multisymbol_busy_handoff_20260828T123620Z_board_advisor.json`.

## Continuation condition

On the next paced wake, first confirm that
`5beefa38-44e0-4c60-89d0-0f487fb47ba7` has reached a canonical terminal state.
Then take a fresh five-sample CPU window. If both CPU measures remain strictly
below 97% and no other multisymbol claim is active, allow the deterministic
fleet to advance exactly one already-pending FX basket row; do not enqueue a
duplicate.
