# FX cointegration GBPUSD/USDJPY — post-selector hard CPU stop

Date: 2026-08-16 Europe/Berlin (`2026-08-16T16:18:44Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; repaired existing FX fallback is
still enqueued exactly once at Q02; the explicit backtest CPU ceiling is
binding

## Outcome

No duplicate Strategy Card, EA, registry row, basket manifest, setfile, or Q02
row was created. The checked-in relationship audit covers all 66 frozen scan
pairs, so no unbuilt scan pair remains. The requested anchors are already past
Q02 and have no open `ONINIT` or `NO_HISTORY` repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback remains frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. Its logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`.

The read-only database sample found exactly one identity row and one open row:
PENDING, unclaimed, attempt 2, with no verdict or evidence path. It is already
priority-tracked and retains the governed `avoid_terminals=[T4,T8]` binding.
Enqueueing, requeueing, or restamping it would duplicate the existing work.

## Post-selector advancement

Commit `7ed9ef10e` repaired the canonical selector's whitespace-sensitive
basket classification. The compact payload's
`"portfolio_scope":"basket"` now evaluates to `_basket_q02_rank=0`.

Against the live database, the exact row is now rank 3 of 975 eligible pending
items, versus rank 28 of 974 in the prior CPU-stop snapshot. That is a real
non-mutating queue advancement: the existing row is correctly exposed near
the head of the governed selector without a duplicate row or priority write.
Resident workers retain ownership of claim timing and the single-basket lane.

## Bound contract

The existing Card is `g0_status: APPROVED`, has R1-R4 PASS, and cites Lemishko,
Landi, and Caicedo-Llano (2024), *Cointegration-Based Strategies in Forex Pairs
Trading*, SSRN 4771108. It is structural, low-frequency frozen-OLS residual
reversion with no ML, martingale, grid, adaptive intramonth refit, or banned
indicator.

The basket manifest binds `GBPUSD.DWX` and `USDJPY.DWX`, with `GBPUSD.DWX` H1
as host. The logical backtest preset remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Repository hashes remain:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- approved Card: `aa0313ea4218ed418432adcdf3a34b49cd3c4f46e725fefd31ec5b2266b2f9ae`
- basket manifest: `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- fixed-risk setfile: `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

## Binding CPU stop

Five two-second whole-machine CPU samples were 100.00%, 100.00%, 100.00%,
99.56%, and 98.78%, averaging 99.67% with a 100.00% maximum. This exceeds the
worker contract's 97% hard ceiling. The database grew from seven active items
in the prior snapshot to nine active items; memory remained above its gate.

Per the mission stop condition, no tester, dispatch tick, enqueue, requeue,
priority mutation, terminal reservation, Factory transition, or containment
mutation was attempted. The live and FTMO terminals were excluded and
untouched.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_post_selector_cpu_ceiling_stop_20260816T161844Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, manifest, registry, magic row, or queue row changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
