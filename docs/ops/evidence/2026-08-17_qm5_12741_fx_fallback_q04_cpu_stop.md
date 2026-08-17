# QM5_12741 FX fallback — Q04 CPU-ceiling handoff

Date: 2026-08-17 Europe/Berlin (`2026-08-17T14:31:08Z`)

Branch: `agents/board-advisor`

Status: the frozen 66-pair FX cointegration frontier has no unbuilt
relationship; the selected existing FX fallback is eligible for one Q04
infrastructure retry, but the explicit 97% backtest CPU ceiling stopped this
session before any queue mutation

## Frontier and anchor reconciliation

The source-qualified positive-hedge scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` has only the two strict
survivors already represented by `QM5_12532` and `QM5_12533`. The committed
sign-aware 66-relationship reconciliation is also fully mechanized. The final
previously open fallback, frozen-scan rank 58 `GBPUSD.DWX` / `USDJPY.DWX` in
`QM5_1257`, has since reached a terminal Q04 strategy failure. A current
read-only farm-state reconciliation found no unbuilt relationship and no
cointegration pair with an eligible, absent successor phase.

The requested anchor-first check found no Q02 infrastructure blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 `PASS`, Q04 `PASS`, Q05 `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 `PASS`, Q04 `FAIL`.

Creating another pair Card, allocating another EA ID, or re-enqueueing either
anchor would therefore duplicate terminal work or override an economic
verdict. The strategy-card and build contracts correctly leave both paths
closed.

## Selected existing-FX fallback

The one qualified fallback is `QM5_12741_nnfx-fx-basket-pooled`, an existing
OWNER-approved D1 pooled FX trend sleeve. This is not presented as a new
cointegration pair. It is selected under the mission's explicit fallback to
advance an existing forex Card after the pair frontier is exhausted.

Its checked-in contract satisfies the requested execution constraints:

- approved Card with R1-R4 `PASS` and a published canonical NNFX source;
- D1 closed-bar operation with about three trades per member per year;
- fixed, deterministic parameters with no ML, martingale, grid, online refit,
  or banned indicator;
- logical four-member `basket_manifest.json` with host `AUDUSD.DWX`;
- backtest setfile has `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The exact logical work-item chain is:

| Phase | Work item | State | Verdict |
|---|---|---|---|
| Q02 | `cab41d73-7573-4648-b58d-ce9fa6df26b3` | done | PASS |
| Q03 | `bf4f1a14-2d2f-4caf-9d94-8076560d8b8d` | done | PASS |
| Q04 | `fc9e29f1-9729-478f-96fb-dd7dcdb5978d` | done | INFRA_FAIL |

Q04 failed only on fold F3 with
`BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,HISTORY_CONTEXT_INVALID,INCOMPLETE_RUNS,`
`M0_1970_PERIOD,NO_HISTORY,RUN_STATUS_INVALID`. Its taxonomy is `infra`, and
there is no pending/running Q04 row or Q05 successor for the logical basket.
The current factory automatically clamps Q04 to the latest complete shared
history window, so this is eligible for exactly one canonical append-only Q04
retry after resource headroom returns; it does not authorize a strategy
parameter change.

## Binding resource stop

Five whole-machine CPU samples were `87.02%`, `79.08%`, `89.36%`, `95.91%`,
and `98.10%`. The maximum crossed the explicit `97%` hard ceiling while the
factory already owned active tester work. Per the mission stop condition, no
Q04 row, tester, dispatch tick, terminal reservation, priority mutation, or
factory-state transition was created.

After the ceiling clears, the next operator should first repeat the exact
logical duplicate query. If the row remains absent, the bounded action is one
canonical `farmctl enqueue-backtest --ea QM5_12741 --phase Q04`; normal
automation must own execution.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution file changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry, magic row, or farm-state
  row changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
