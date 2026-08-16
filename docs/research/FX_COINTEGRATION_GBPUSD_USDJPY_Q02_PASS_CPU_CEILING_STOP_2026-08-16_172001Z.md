# FX cointegration GBPUSD/USDJPY — Q02 PASS and CPU-ceiling stop

Date: 2026-08-16 Europe/Berlin (`2026-08-16T17:20:01Z`)

Branch: `agents/board-advisor`

Status: the frozen 66-pair frontier remains fully mechanized; the repaired
existing FX fallback has advanced through Q02, and the hard CPU ceiling stops
this session before any downstream enqueue or tester launch

## Outcome

The scan anchors are not Q02-blocked:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` passed Q02 and Q04, then failed Q05.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` passed Q02, then failed Q04.

The checked-in sign-aware reconciliation covers all 66 frozen scan
relationships, so creating another Card or EA would be a duplicate. The
governed fallback therefore remained frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`.

Its exact logical work item
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` completed at
`2026-08-16T17:14:14Z` with `Q02 PASS`. This is the first clean terminal
verdict after the Card-conformance repairs documented in the preceding
handoffs.

## Bound Q02 evidence

The Model-4 run covered 2018-07-02 through 2022-12-31 and produced 290 trades
against the 25-trade Q02 minimum. It had no ONINIT failure, reason class `OK`,
and stable bound binary and setfile hashes:

- summary:
  `D:/QM/reports/work_items/d4cd660c-c81a-41d3-8a4c-ad21d3319816/QM5_1257/20260816_165134/summary.json`
- summary SHA-256:
  `caeaee89354ae7d68a1700eed1eca07ab25e2cae1af77df07f446712993e079f`
- EX5 SHA-256:
  `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- fixed-risk setfile SHA-256:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

Q02 is only a trade-capability and infrastructure gate. The run was adverse:
PF 0.65, net profit -7,003.44, and drawdown 7,920.49 (7.90%). Nothing in this
handoff promotes, rescues, or waives that result. Ordinary downstream gates
remain the judge.

## Binding CPU stop

Five two-second whole-machine samples were 96.27%, 99.95%, 99.95%, 97.86%,
and 89.41%. The maximum was 99.95%, crossing the explicit 97% backtest CPU
ceiling while seven factory terminal processes had already been observed
running.

Per the mission stop condition, no Q04 row, duplicate Q02 row, manual tester,
dispatch tick, priority/timestamp mutation, terminal reservation, or Factory
transition was created. After load clears, the next operator should first
reconcile whether normal automation created the exact logical Q04 row and use
only the canonical non-duplicate downstream path if it did not.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_q02_pass_cpu_ceiling_stop_20260816T172001Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry, magic row, or runtime
  queue row changed.
- Concurrent unrelated untracked work was left unstaged and untouched.
