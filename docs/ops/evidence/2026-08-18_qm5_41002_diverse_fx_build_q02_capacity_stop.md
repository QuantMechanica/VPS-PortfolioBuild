# QM5_41002 Diverse FX Build — Q02 Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `BUILD PASS; Q02 NOT ENQUEUED — TESTER CAPACITY AND CPU CEILING`

## Selection And Boundary

`QM5_41002_robert-pardo-checkmate-breakout-engine` was the highest-priority
unclaimed low-frequency FX card in the approved build backlog after checking
the live farm database for existing tasks, work items, and paced-agent claims.
The build was claimed as agent task
`5d5cc9f6-e096-44a3-af78-99abc2d9e7ed` by
`codex:agents/board-advisor`. Competing approved cards already claimed by
other paced agents were not touched.

The card is OWNER-authorized with `g0_status: APPROVED` and cites Robert
Pardo, *The Evaluation and Optimization of Trading Strategies* (Wiley,
2008). This unit implements a structural H4 FX breakout rather than adding
another index, metal, or energy build. It makes no profitability,
walk-forward, certification, portfolio-admission, or decorrelation claim.

## Implemented Mechanic

- Exact hosts: `EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`; exact period H4.
- Entry: Close[1] breaks the prior ten-bar Donchian boundary, shifts [2..11],
  while ATR(14)[1] is greater than ATR(14)[5]. The prior-channel convention
  resolves the card's otherwise impossible self-inclusive close breakout and
  is disclosed in `SPEC.md`.
- Initial stop: `1.5 * ATR(14)[1]`; target: `2R`; open-position stop follows
  the opposite ten-bar completed-channel boundary.
- One owned position per host/magic; 23:55-00:05 broker-time rollover block;
  spread no wider than `1.8 * ATR`; entry deviation capped at three ticks.
- Framework daily-loss halt is 2%, total-drawdown signal threshold is 5%, and
  non-fixed percent risk is capped at 0.5%.
- No ML, grid, martingale, averaging, banned indicator, external data feed,
  or live-trading path is present.

## Deterministic Allocation And Presets

The governed allocator added only these active registry routes and regenerated
the resolver without dropping any existing row:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `EURUSD.DWX` | `410020000` |
| 1 | `GBPUSD.DWX` | `410020001` |
| 2 | `USDJPY.DWX` | `410020002` |

Allocation evidence:
`docs/ops/evidence/5d5cc9f6_qm5_41002_magic_allocation_2026-08-18.json`.
The registry gained exactly three rows; the generated resolver now preserves
17,516 active rows and reports registry SHA-256 prefix
`0994F01642CE0CBE`.

All three generated `*_backtest.set` files lock
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Their
normalized-content build hashes are:

- EURUSD slot 0: `fa11728f03b8f088fe921983a2c4f7f8779b79084233dc0d362bd4a9c3922112`
- GBPUSD slot 1: `ff01beb7ace8aef717a4423e251e086964949f9c9fcd12d5471baf2d962e7089`
- USDJPY slot 2: `575376dc42f3034f1bc944849b69f98a32c352d6ee8effd7df026651703dccac`

## Build Evidence

- Strict targeted MetaEditor compile: `PASS`, 0 errors and 0 warnings.
- Compile log:
  `framework/build/compile/20260818_043319/QM5_41002_robert-pardo-checkmate-breakout-engine.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260818_043319/summary.csv`.
- Deterministic V5 build check: `PASS`, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260818_043318.json`.
- Static build guardrails: `PASS`, four files checked, no findings.
- `SPEC.md` validation: `PASS` (1/1).
- Magic-resolver dry run: 17,516 rows kept, 0 dropped.
- MQ5 SHA-256:
  `8D886C0564BF1FE620C853F982E292F198CE5EC1F241B3F75500C4D724D84CA3`.
- EX5 SHA-256:
  `6A8B189114F2770C8B248BF42FB9BC18A5522CB04BE62ED421DAE3FA2E184B30`.
- Build-check report SHA-256:
  `52777D02E08F34AF05B5E7D36C33B27D100979E5C1B2E08FD7ECAB5FEBF1C31E`.

No manual tester, smoke test, pipeline-phase runner, dispatcher tick, or
backtest was invoked during this build-only unit.

## Q02 Capacity Stop

The read-only `farmctl.py mt5-slots` census at
`2026-08-18T04:36:10Z` found eight active governed research terminals:
`T1`, `T2`, `T3`, `T4`, `T5`, `T6`, `T8`, and `T10`. This exceeds the
governed seven-terminal ceiling. A contemporaneous whole-host CIM reading
reported 100% processor load. `T_Live` and an unrelated FTMO process appeared
only in the census and were not touched.

Per the mission's explicit CPU-ceiling stop condition, no enqueue command was
run. The immediate read-only query
`farmctl.py work-items --ea QM5_41002` returned `count=0`, confirming that no
Q02 row was created for this EA.

## Handoff And Safety

A later paced operator may enqueue the three exact fixed-risk H4 presets only
after fresh governed-terminal and host-CPU checks pass. Q02 must falsify the
mechanic on trade density (at least five completed positions per full
post-warm-up year), governed economics, completed-bar identity, prior-channel
indexing, ATR expansion, stop/target geometry, trailing behavior, lifecycle,
ownership, and determinism.

No AutoTrading action, `T_Live` mutation, deploy or T_Live manifest change,
portfolio-gate edit, portfolio admission, correlation waiver, or live-use
authorization occurred.
