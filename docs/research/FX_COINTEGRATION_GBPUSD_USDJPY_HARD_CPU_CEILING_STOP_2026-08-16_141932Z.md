# FX cointegration GBPUSD/USDJPY — hard CPU ceiling stop

Date: 2026-08-16 Europe/Berlin (`2026-08-16T14:19:32Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; exact repaired FX fallback remains
pending once at Q02; the explicit backtest CPU ceiling is binding

## Outcome

No duplicate Strategy Card, EA, registry row, basket manifest, setfile, or Q02
row was created. The checked-in sign-aware reconciliation covers every one of
the 66 frozen relationships, so there is no unbuilt scan pair to mechanize.
The requested anchors remain beyond Q02 and have no open `ONINIT` or
`NO_HISTORY` repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The selected non-duplicate fallback remains frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. Its exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`.

At the read-only database sample, that row was PENDING and unclaimed at
`attempt_count=2`, with no verdict or evidence path. It remained the only row
and only open row for
`QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`, with no active hold or quarantine.
It was rank 28 of 974 eligible pending rows under the canonical selector.
Enqueueing, requeueing, or restamping it would duplicate an already governed
identity.

## Bound basket contract

The existing Card is `g0_status: APPROVED`, has R1-R4 PASS, and cites Lemishko,
Landi, and Caicedo-Llano (2024), *Cointegration-Based Strategies in Forex Pairs
Trading*, SSRN 4771108. It is structural, low-frequency frozen-OLS residual
reversion with no ML, martingale, grid, adaptive intramonth refit, or banned
indicator.

The manifest binds `GBPUSD.DWX` and `USDJPY.DWX`, with `GBPUSD.DWX` H1 as host.
The logical backtest preset remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Fresh SHA-256 reads still match the queue payload:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest:
  `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- fixed-risk setfile:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`
- approved Card:
  `aa0313ea4218ed418432adcdf3a34b49cd3c4f46e725fefd31ec5b2266b2f9ae`

The prior valid Model-4 run remains a zero-trade `MIN_TRADES_NOT_MET` result.
Its harness and setup layers passed; same-lineage entry and exit conformance
repairs are already committed as `751cb391d`, `f9ef37c1c`, and `82a1bf443`.
The only remaining recovery proof is one worker-owned rerun of the same bound
case. No strategy mechanics or thresholds were changed in this turn.

## Binding CPU stop

Five two-second whole-machine CPU samples were 100.00%, 99.95%, 99.77%,
93.00%, and 97.82%, averaging 98.11% with a 100.00% maximum. This exceeds the
worker contract's 97% hard ceiling. Seven Q02 work items were active across T1,
T2, T3, T4, T5, T7, and T8. Ten resident worker processes were present, no
active work item was multisymbol, and the process scan reported no orphaned
factory terminal. Memory headroom remained above its gates; CPU alone binds.

Per the mission stop condition, no manual tester, targeted worker, normal
dispatch tick, enqueue, requeue, priority mutation, terminal reservation,
Factory control, or containment mutation was attempted. The live and FTMO
terminals were excluded and untouched.

## Non-duplicate delta

Compared with the `12:26:23Z` governed-queue handoff, the exact row advanced
from selector rank 40 to 28 without mutation, while factory occupancy rose from
three to seven active items and sampled CPU rose from 65.87% to 98.11%. The
earlier queue-ownership handoff has therefore become a distinct, explicit hard
CPU-ceiling stop.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_hard_cpu_ceiling_stop_20260816T141932Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, Card, EA, registry,
setfile, basket manifest, external queue row, Factory state, running terminal,
history archive, or containment state was changed. Unrelated untracked work was
left unstaged and untouched.
