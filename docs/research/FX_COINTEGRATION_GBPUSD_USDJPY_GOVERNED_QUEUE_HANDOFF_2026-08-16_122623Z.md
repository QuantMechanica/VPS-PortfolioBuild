# FX cointegration GBPUSD/USDJPY — governed Q02 queue handoff

Date: 2026-08-16 Europe/Berlin (`2026-08-16T12:26:23Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; repaired existing FX fallback is
enqueued exactly once at Q02; current resources are clear and the paced worker
selector owns the rerun

## Outcome

No duplicate Strategy Card, EA, registry row, basket manifest, setfile, or Q02
row was created. The checked-in sign-aware reconciliation covers every one of
the 66 frozen relationships, so there is no unbuilt scan pair to mechanize.
The requested anchors are already beyond Q02 and have no open `ONINIT` or
`NO_HISTORY` repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback therefore remains frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. Its existing logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`.

At `2026-08-16T12:26:23Z`, that row was pending and unclaimed at
`attempt_count=2`, with no verdict or evidence path. It remained the only row
and the only open row for
`QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`, with no active hold or quarantine.
It is priority-tracked and ranked 40 of 978 eligible pending rows under the
canonical downstream-first selector. Enqueueing, requeueing, or restamping it
would duplicate an already governed identity.

## Approved basket contract

The existing Card is `g0_status: APPROVED`, has R1-R4 PASS, and cites Lemishko,
Landi, and Caicedo-Llano (2024), *Cointegration-Based Strategies in Forex Pairs
Trading*, SSRN 4771108. It uses frozen-OLS residual reversion, is structural and
low-frequency, and contains no ML, martingale, grid, adaptive intramonth refit,
or banned indicator. The repository card-schema/ML lint passed.

The basket manifest binds `GBPUSD.DWX` and `USDJPY.DWX`, with `GBPUSD.DWX` H1
as host. The logical backtest preset remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Fresh SHA-256 reads match the exact queue payload:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest:
  `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- fixed-risk setfile:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

## Zero-trades recovery status

The prior worker-owned run at `20260815_082908` is a valid Model-4 real-tick
report, not `ONINIT`, `NO_HISTORY`, or `NO_REPORT`. It completed the bound
2018-2022 window with zero trades and failed `MIN_TRADES_NOT_MET`. The harness
and setup layers passed; the first failed layer was entry implementation.

Same-lineage repairs already corrected stationary half-life math, relative
spread-cost units, negative-beta leg direction, per-leg magic identity, atomic
two-leg entry, bounded monthly diagnostics, reachable directional mean-cross
exit, and the D1 structural-stop read. These are Card-conformance repairs, not
threshold or market-hypothesis changes:

- entry repair: `751cb391d8f388f5b61641ba3299011cdf9a09ed`;
- exit repair: `f9ef37c1c26686758567b493b0411c65079286d8`; and
- set metadata restoration: `82a1bf44319a26fee1dbe5eb8463c7986f0304e6`.

The bound validation remains clean:

```text
card schema / ML lint: PASS
strict compile:         PASS, 0 errors, 0 warnings
strict build check:     PASS, 0 failures, 0 warnings
FX basket regressions:  45 passed in 1.55s
```

The remaining proof is one governed rerun of the same Q02 case. Non-zero trades
would show only `trade-capable`; all ordinary Q02 and downstream gates would
still apply. If the corrected Card rules legitimately yield zero entries, this
adverse rank-58 binding should retire without refitting or rescue tuning.

## Paced execution boundary

Five two-second CPU samples were 73.68%, 59.66%, 69.68%, 58.16%, and 68.17%,
averaging 65.87% with a 73.68% maximum. The 97% hard CPU ceiling was not
crossed. The database had three active work items and zero active multisymbol
items; free physical memory was 46.44 GiB and free system commit was 102.01
GiB. The basket resource gate is currently clear.

The live Factory has all ten resident terminal workers and is not OFF. Its
canonical selector, claim spacing, symbol locks, and single-basket rule own the
pending row. The only supported targeted work-item mode requires
`FACTORY_OFF.flag`; disabling Factory solely to jump rank 40 was not authorized
and would bypass the governed queue. A normal dispatch tick cannot select this
row out of order. No manual tester, targeted worker, dispatch tick, enqueue,
requeue, priority mutation, terminal reservation, or Factory control was used.

This is materially different from the prior `11:06:14Z` hard-CPU stop: active
work fell from seven to three, the hard CPU trip cleared, and the active
multisymbol count fell from one to zero. The remaining boundary is queue
ownership, not resource exhaustion.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_governed_queue_handoff_20260816T122623Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, Card, EA, registry,
setfile, basket manifest, external queue row, Factory state, or running terminal
was changed. The unrelated untracked `QM5_21514` directory and
`session_offset_minutes.csv` were left unstaged and untouched.
