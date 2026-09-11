# QM5_12919 Q02 history-dependency recovery

Date: 2026-09-11  
Branch: `agents/board-advisor`  
Router task: `f68b8454-5ca3-4070-a8b0-91541c001440`  
Disposition: `REPAIRED / Q02_ENQUEUED`

## Outcome

The latest fixed-risk USDJPY.DWX Q02 attempt for
`QM5_12919_amp-value-momentum-xasset` failed during `OnInit` because the work
item declared only its physical execution symbol. The EA reads eight D1 series,
but the missing dependency manifest caused Q02 to classify it as a normal
single-symbol job, choose the six-month prescreen, and privatize only USDJPY
history.

The repair adds the deterministic eight-symbol dependency manifest already
implied by the approved card and source. This makes append-only Q02 routing
classify the physical-host row as multisymbol, provision all eight custom
histories, skip the single-symbol prescreen, and apply the governed 450-minute
basket ceiling. No MQ5, EX5, setfile, strategy parameter, risk value, or
economic rule changed.

One exact successor was appended:

- predecessor: `4ae565d6-d87b-4c9e-8ac5-38f97ad95e56`, retained as
  `done / INFRA_FAIL`;
- successor: `6de52a30-72d0-4ec3-bb76-1b3d92c58889`, `Q02 / pending`;
- host: `USDJPY.DWX / M30`;
- artifact identity: MQ5
  `c729116f626f7c6b2d930a160a070b3319f198f2a565ad5310c4d49dfa53526a`,
  EX5 `6e915491196f60baf3d4fa98d900495be6aed295dd37605d3b6c65a6024383f9`,
  setfile `02f18620b8b7044e462194632e6bbe9eb7c42860cbbf44aa2a80c0dca3445e0d`;
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- requested Q02 years: 2017 through 2022;
- dependency count: eight;
- custom-history admission: `ACTIVE`, 824 archive rows across USDJPY, GDAXI,
  NDX, UK100, WS30, EURUSD, GBPUSD, and AUDUSD;
- Q02 timeout floor: 450 minutes.

## Diagnosis

The bound tester journal established the first failed layer before any strategy
mechanics were considered:

- framework and news initialization succeeded;
- all eight symbols synchronized;
- `BASKET_WARMUP` requested and loaded every declared symbol;
- the tester had only about 376-389 pre-start D1 bars per foreign symbol;
- the approved signal requires 1,286 D1 bars (21-day skip + 1,260-day value
  lookback + safety margin);
- readiness was `0`, below the required four symbols, followed by
  `SETUP_DATA_MISSING` and `INIT_FAILED`.

The predecessor payload confirms the routing mismatch: it recorded
`p2_run_stage=prescreen`, dates `2022.07.01..2022.12.31`, and selected only
USDJPY in `custom_history_archive_admission`, despite the source's eight-symbol
read dependency. This is a setup/dispatch defect, not a zero-edge result and not
a stale-binary condition.

## Coordination and verification

- The recovery was claimed atomically as router task
  `f68b8454-5ca3-4070-a8b0-91541c001440` after checking for open QM5_12919
  tasks and work items.
- Pre-claim SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12919_history_contract_claim_20260911T015242Z.sqlite`;
  SHA-256
  `2e7392403c25c7a3e34a19a087ed1a267f120fff2fedf66ebeb04be9f4059010`.
- Focused history and append-only enqueue tests: `53 passed`.
- Build-guard audit of the unchanged MQ5: `PASS`, zero findings.
- Immediate pre-enqueue CPU samples averaged 65.27% and peaked at 80.19%,
  below the binding 97% ceiling.
- The successor payload binds `basket_symbol_count=8`, the exact symbol list,
  `host_symbol=USDJPY.DWX`, and `host_timeframe=M30`.
- No compile was required or enqueued because MQ5 and EX5 bytes are unchanged.

## Zero-trades recovery comparison

| EA | Bound run | First failed layer | Repair | Compile | Entry evidence | Trades | Remaining gap |
|---|---|---|---|---|---|---:|---|
| QM5_12919 | `4ae565d6`, USDJPY.DWX M30, 2022-07-01..2022-12-31 | Setup: eight-series EA dispatched as a one-series six-month prescreen | Declare all eight dependencies; full-window multisymbol Q02 successor | Not needed; binary unchanged | Predecessor stopped in `OnInit`; successor pending | Not an economic result | Worker must execute the queued successor and publish its Q02 verdict |

## Safety boundary

No terminal, tester, optimizer, or compile process was started manually. No
`T_Live` process or file, AutoTrading state, deploy manifest, live manifest,
portfolio gate, or portfolio artifact was touched. The queued row is a
fixed-risk non-live backtest only and makes no efficacy, certification, or
portfolio-admission claim.
