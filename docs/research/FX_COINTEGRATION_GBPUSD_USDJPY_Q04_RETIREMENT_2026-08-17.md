# FX cointegration GBPUSD/USDJPY — Q04 retirement

Date: 2026-08-17 Europe/Berlin (`2026-08-16T23:51:34Z`)

Branch: `agents/board-advisor`

Status: the frozen 66-pair frontier is fully mechanized; the selected existing
FX fallback reached a terminal Q04 strategy failure and is retired

## Outcome

No new Strategy Card or EA was created. The committed sign-aware
reconciliation of `analyze_cross_asset_v3.py --include-negative-hedges`
accounts for all 66 relationships in the frozen FX scan, so another build
would be duplicate work. The requested anchor triage is unchanged:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback remained frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. It is the structural, fixed-hedge-ratio
Lemishko-Landi-Caicedo cointegration package with no ML, grid, martingale,
online refit, banned indicator, or rescue filter. Its canonical backtest
binding remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The exact logical Q02 work item
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` remains `PASS` and canonical
automation promoted it exactly once to Q04 work item
`d48dfb37-d28b-4e9d-aebe-376b7afe12dd`. A read-only query of
`D:/QM/strategy_farm/state/farm_state.sqlite` (`PRAGMA quick_check=ok`) found
that Q04 row `done` with strategy-taxonomy verdict `FAIL`, no open row for the
logical basket, and no Q05-or-later successor.

## Bound Q04 verdict

The canonical aggregate is:

`D:/QM/reports/pipeline/QM5_1257/Q04/QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1__d48dfb37-d28b-4e9d-aebe-376b7afe12dd/aggregate.json`

Its SHA-256 is
`eea6f86baaaeb436ef19705f90ca6ef0d7891e23dcb0788f3e9ef2e83804557d`;
its embedded aggregate identity is
`c4dcc89d0163e8005524a5242ea2ecb69790bd2d3f8d71cb4951051b05058e7f`.

| Fold | OOS year | Trades | PF net | Verdict evidence |
|---|---:|---:|---:|---|
| F1 | 2023 | 72 | 0.82 | `STRATEGY_PF_AT_OR_BELOW_FLOOR` |
| F2 | 2024 | 0 | n/a | `STRATEGY_ZERO_TRADES` |
| F3 | 2025 | 52 | 1.90 | fold complete |

The aggregate reason is
`F1:pf_net=0.820;F2:trades=0;F3:pf_net=1.900`. Each fold preflight resolved
both `GBPUSD.DWX` and `USDJPY.DWX` history, every `invalid_reason` is null,
and the work-item taxonomy is `strategy`; this is not an ONINIT, NO_HISTORY,
or other setup classification. The single good 2025 fold cannot override the
PF failure and zero-trade fold.

The run is cryptographically bound to the unchanged artifacts:

- EX5 SHA-256:
  `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest SHA-256:
  `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- fixed-risk setfile SHA-256:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

## Retirement decision

The build-local approved Card is reconciled from `Q04_PENDING` to `DEAD`.
The Card's own falsification boundary requires retirement after an economic
failure and forbids a refit, added filter, parameter rescue, or substituted
pair. No Q05 work item was enqueued, and no existing row was requeued,
reprioritized, or restamped.

No backtest, dispatch tick, or terminal launch was attempted in this session;
the terminal Q04 verdict leaves no eligible downstream run, so CPU capacity
was not consumed or used to bypass the paced fleet.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_q04_retirement_20260816T235134Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- No EA, EX5, setfile, basket manifest, registry, magic row, or runtime queue
  row changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
