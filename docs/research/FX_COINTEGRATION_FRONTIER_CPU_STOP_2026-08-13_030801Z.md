# FX cointegration frontier paced-capacity stop

Date: 2026-08-13

Branch: `agents/board-advisor`

Status: no unbuilt 66-pair relationship; existing FX fallbacks remain queued;
stopped at the paced backtest CPU ceiling

## Outcome

No new Card, EA, basket manifest, registry row, magic row, setfile, or Q02 work
item was created. The deterministic relationship audit at commit `a80493291`
accounts for all 66 relationships in the frozen sign-aware FX scan, so another
"next-best" Card or build would duplicate governed work.

The requested anchor repair is not applicable:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 PASS and Q04 PASS,
  followed by Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 PASS, followed
  by Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

The highest-ranked existing relationship without a terminal exact logical Q02
verdict remains frozen scan rank 58, `GBPUSD.DWX` / `USDJPY.DWX`, implemented
as slot 8 in the OWNER-approved `QM5_1257_lemishko-fx-cointpair` basket. Its
exact Q02 work item `d4cd660c-c81a-41d3-8a4c-ad21d3319816` is still PENDING,
unclaimed, and at attempt zero. Re-enqueueing it would be a duplicate, and
switching the active umbrella manifest while that immutable row is pending
would put its package identity at risk.

The existing rank-65 `QM5_1156_USDCHF_AUDUSD_COINTEGRATION_M30` row and the
structural `QM5_20292_FX_CARRY_UNWIND_D1` row are likewise still PENDING. They
were preserved without reprioritization or duplicate enqueue.

## Source and risk boundary

The rank-58 fallback is already bound to the approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN cointegration Card. Its fixed-risk package remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No new source
claim, profitability claim, filter, refit, banned indicator, or ML mechanic
was introduced.

## Binding paced CPU ceiling

The read-only capacity sample at `2026-08-13T03:05:36Z` found five factory MT5
terminals running (`T2`, `T3`, `T4`, `T5`, and `T8`) while
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`. The active jobs were
four Q02 runs and the exact `QM5_13029` logical-basket Q04 run on T8. The FTMO
terminal was excluded from the factory count. `T_Live` was not controlled.

Five running jobs exceed the binding paced ceiling of one. Per the mission's
explicit stop rule, no queue mutation, dispatch, reservation, tester launch,
terminal action, or backtest followed the sample.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_cpu_stop_20260813T030801Z_board_advisor.json`.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, live artifact, AutoTrading state, or terminal state
  changed.
- The unrelated pre-existing untracked review evidence file was not staged or
  modified.
