# QM5_20248 Zero-Trades Recovery Record

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: canonical Q02 `ZERO_TRADES`; diagnostic build PASS; recovery proof
deferred at the paced-fleet CPU ceiling

## Classification

The factory-bound Q02 run for `QM5_20248_xng-vr-window` is valid and produced
zero trades. It is not Q02 PASS and is not yet evidence for permanent strategy
rejection. Harness and setup identity passed. The original build emitted no
strategy decision-boundary events, so the first failed entry condition cannot
be distinguished from genuine variance-ratio signal sparsity without one
same-bound diagnostic replay.

The same-lineage build now contains bounded structured diagnostics only. No
entry, exit, window, threshold, statistic, direction, risk, stop, hold,
spread, news, Friday-close, or retry mechanic changed. A recovery proof was not
launched because the exact factory-terminal count reached the binding `7/7`
ceiling.

## Original Bound Q02 Run

- Work item: `178a7b59-3bb7-49e7-9c28-36b7841be600`.
- Summary:
  `D:/QM/reports/work_items/178a7b59-3bb7-49e7-9c28-36b7841be600/QM5_20248/20260806_112323/summary.json`.
- Contract: T9, `XNGUSD.DWX`, D1, real ticks/model 4,
  `2018.07.02` through `2022.12.31`, one run, Q02 minimum 25 trades.
- Result: valid 34,352-byte report, zero trades, `MIN_TRADES_NOT_MET`; no
  OnInit failure or log bomb.
- Source/deployed EX5 and source/deployed setfile hashes matched and stayed
  stable throughout the run.
- Original MQ5 SHA-256:
  `7dbd521599882ce86a0ca3904eeb496e128be82cc51401db79939bd81778cb5c`.
- Original EX5 SHA-256:
  `a27373d02afaeef8f7a9d5bda57af375c420664b1e28f6e9ae84a1eb3a67a11e`.
- Original setfile SHA-256:
  `2db702c2eb1cb23b36a6d862e66daa4adc1c2ffa1b30cb17e182b5b41c5147bb`.
- `run_smoke.ps1` SHA-256:
  `0cb89fb18d76d71263fde5b62c0bf6ba3b89fd63b348bd0727eb8f4336dfa204`.
- The exact-byte structured logger sample contains 1,170 events, SHA-256
  `8da0b52265cec234083b50d12713aad5793f14de35cbb12f38867bdd8c403600`.
  It proves `INIT_OK` plus D1 equity sampling, but the original EA had no
  monthly attempt, reject, or signal-fire instrumentation.
- Tester history generated 1,163 D1 bars from 2018-07-02 through 2022-12-30.
  The thirty-three-close warm-up therefore leaves only the later part of the
  Q02 interval eligible for economic decisions.

## Layer Classification

1. Harness: PASS. Dates, symbol, D1 period, model 4, real-tick marker, report,
   terminal, hashes, and runner identity are bound.
2. Setup: PASS. Inputs deserialized at their locked values, initialization
   succeeded, and source/deployed artifacts matched.
3. Entry hook: UNCLASSIFIED. Zero observable strategy attempt events in the
   original build prevent identifying the first false gate.
4. Order path: NOT REACHED OR UNOBSERVABLE. There are no framework acceptance,
   broker rejection, fill, or close events.
5. Economics: NOT JUDGED. Zero trades is not a passing economic result.

## Same-Lineage Diagnostic Build

The diagnostic change records:

- the frozen strategy inputs in `INIT_OK`;
- one `ENTRY_ATTEMPT` per consumed eligible broker month;
- one explicit `ENTRY_REJECTED` state with history counts, variance ratio,
  z-value, and direction state for every failed monthly condition; and
- one `ENTRY_SIGNAL_FIRE` immediately before framework handoff.

These events are naturally bounded by the card's persisted one-attempt-per-
eligible-month rule. They do not change order eligibility or economics.

- Strict compile: PASS, 0 errors and 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260806_113241/QM5_20248_xng-vr-window.compile.log`.
- Targeted strict V5 build check: PASS, 0 failures and 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260806_113928.json`.
- Diagnostic MQ5 SHA-256:
  `077ed17c6ee8f79d9e1fc9e14a1a701b6b24d6e93bbc5a0bde8aa1605083b64c`.
- Diagnostic EX5 SHA-256:
  `c761eb30d42dabeae4eb59a7e52bcf4f063aee5b6e2a218eaecee669d0f8f864`.
- Refreshed fixed-risk setfile SHA-256:
  `1e06baddda92fe46dd7f0ce67095bef4343e0d19497ed7b496fe5cbce4fbac38`;
  build hash
  `38c98d5ab7fd3614eb690280ad8c59f449385168011252ae4eb101c4d4959804`.

## Paced-Fleet Stop

Only executable paths matching `D:/QM/mt5/T1..T10/terminal64.exe` were counted;
`T_Live` and every other namespace were excluded.

- `2026-08-06T11:33:36.3331358Z`: `6/7` exact factory terminals.
- `2026-08-06T11:34:17.9841350Z`: `7/7` exact factory terminals.

The second sample hit the binding ceiling. No recovery tester, dispatch, or
terminal-control action was launched. The next authorized action is one
evidence-bound T1-T5 replay of the unchanged `2018.07.02-2022.12.31` contract
when a slot is confirmed free and capacity is below the ceiling. Its monthly
events must classify the first false gate before any implementation repair or
strategy disposition.

## Required Recovery Table

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| `QM5_20248` | Q02 `2018.07.02-2022.12.31` | harness/setup PASS; entry-hook cause unclassified because original build exposed no decision events | bounded diagnostics only; no economic change | PASS, 0/0; build check 0/0 | 0 strategy decision events in original run; diagnostic replay deferred | 0 | same-bound replay below CPU ceiling; first-gate classification; Q02 density/economics; costs, OOS/stress, data quality, realized correlation, and portfolio admission |

## Safety

- The canonical setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- No live, demo, shadow, optimization, or stress setfile was created.
- No `T_Live` path, T_Live manifest, deploy manifest, or portfolio gate was
  touched; AutoTrading was not toggled.
- No terminal process was started, stopped, reserved, or reaped by the
  recovery work.
