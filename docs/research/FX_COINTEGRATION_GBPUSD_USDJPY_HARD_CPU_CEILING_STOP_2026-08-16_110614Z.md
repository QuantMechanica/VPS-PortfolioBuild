# FX cointegration GBPUSD/USDJPY — hard CPU ceiling stop

Date: 2026-08-16 Europe/Berlin (`2026-08-16T11:06:14Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; exact repaired fallback remains
pending once at Q02; CPU and multisymbol serialization ceilings are active

## Outcome

No duplicate Strategy Card, EA, registry row, manifest, setfile, or Q02 row
was created. The signed frontier reconciliation remains binding: all 66 frozen
relationships are already mechanized. The requested anchors remain beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback remains frozen-scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, implemented as slot 8 in the approved and built
`QM5_1257_lemishko-fx-cointpair`. Its same-lineage entry and exit defects were
already repaired and strictly compiled. This pass did not launch its governed
rerun because the explicit CPU ceiling was crossed while the only multisymbol
lane remained occupied.

## Exact fallback state

| Field | Value |
| --- | --- |
| Work item | `d4cd660c-c81a-41d3-8a4c-ad21d3319816` |
| Logical symbol | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Phase / status | Q02 / `pending`, unclaimed |
| Attempts / verdict / evidence | 2 / none / none |
| Exact identity rows / open rows | 1 / 1 |
| Active holds | 0 |
| Priority track | true |

Fresh SHA-256 reads match the row bindings:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest:
  `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- logical backtest setfile:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

The manifest still binds `GBPUSD.DWX` and `USDJPY.DWX` with `GBPUSD.DWX` H1
as host. The preset remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No strategy threshold, market hypothesis, filter, or
economics changed.

## Binding backtest ceilings

Five two-second CPU samples were 93.36%, 97.47%, 94.76%, 98.65%, and
100.00%, averaging 96.85%. The 97% hard ceiling was crossed in three samples.
The database concurrently grew from four active work items in the prior sample
to seven active work items claimed across T2, T4, T5, T6, T7, T8, and T9.

The one active multisymbol row is still
`92235bb9-1fc0-4aeb-90c3-f8771ca9e2bd`,
`QM5_20233_XAU_XAG_SKEW_RANK_D1` at Q02 on T8. Read-only process inspection
confirmed its runner, terminal, and tester chain remains live and path-bound to
`D:/QM/mt5/T8`; it declares `XAUUSD.DWX` and `XAGUSD.DWX` and retains its
governed 25,200-second timeout. No process was stopped or controlled.

Free physical memory was 27,700,908 KiB and D: had 163,300,052,992 bytes
free. Neither changes the result: the hard CPU trip and one-active-multisymbol
rule independently prohibit starting the FX basket. Per the mission's explicit
ceiling instruction, no retry, dispatch tick, enqueue, or queue mutation
followed.

## Non-duplicate delta

The prior committed sample at `2026-08-16T09:49:31Z` saw four active work
items, 72.17% average CPU, a 74.59% maximum, and no hard CPU trip. This sample
sees seven active rows, 96.85% average CPU, a 100% maximum, and a hard trip.
It therefore records a materially different binding condition while proving
that the FX target remains hash-clean, unheld, priority-tracked, and pending
exactly once.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_hard_cpu_ceiling_stop_20260816T110614Z_board_advisor.json`.

## Zero-trades recovery handoff

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gap |
| --- | --- | --- | --- | --- | ---: | ---: | --- |
| QM5_1257 GBPUSD/USDJPY | `20260815_082908` | Entry/exit implementation defects | Same-lineage repair already applied and queue-bound | Prior strict PASS, 0/0 | Pending rerun | Pending rerun | One governed Q02 run after both ceilings clear |

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, Card, EA, registry,
setfile, basket manifest, external queue row, factory process, or running
terminal was changed. Concurrent unrelated worktree files were left unstaged
and untouched.
