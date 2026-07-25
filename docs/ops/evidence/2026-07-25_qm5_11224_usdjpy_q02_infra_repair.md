# QM5_11224 USDJPY Q02 infrastructure repair

Date: 2026-07-25

Branch: `agents/board-advisor`

EA: `QM5_11224_ft-tdseq`

Farm claim: `3bf7770c-bd83-4a40-a44b-55789612aba0`

Q02 work item: `1c4f5354-d44e-4bf1-9dcc-71974b9bbb69`

## Selection

The higher-priority market-neutral candidate `QM5_12840_xti-xng-rspread`
was already built, had passed Q02, and had reached a Q04 strategy verdict.
Rebuilding or re-enqueuing it would have duplicated completed funnel work.

`QM5_11224` was selected under the diverse-instrument infrastructure-repair
priority. Its approved card records a deterministic H1 TD Sequential
price-exhaustion strategy sourced from the public
`freqtrade/freqtrade-strategies` repository at commit
`dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`. The card has G0 and R1-R4 PASS,
targets four liquid `.DWX` instruments, expects 35 entries per year per
symbol, and uses no ML, grid, martingale, or adaptive PnL fitting.

An atomic farm claim confirmed that the EA had no open work item, agent task,
downstream result, or prior equivalent repair. All retained results for its
four symbols were Q02 infrastructure failures; none was an economic strategy
verdict.

## Failure analysis

The selected USDJPY row retained:

- prior verdict `INFRA_FAIL`;
- reason classes `ONINIT_FAILED` and `INCOMPLETE_RUNS`;
- source run dates `2017-01-01` through `2024-12-31`; and
- no Q03 or later result.

The old report directory and tester log had been removed by retention, so the
precise historical ONINIT message could not be reproduced from durable
evidence. Registry review ruled out the common stale-magic explanation:
active slots `112240000` through `112240003` were generated before the old
binary. The old EX5 nevertheless predated the current framework and runtime
classifier fixes, so it was rebuilt without changing the entry or exit
mechanics.

The first current-framework build check then found an independent,
deterministic funnel blocker in `Strategy_NoTradeFilter`: it rejected
`ask == bid`. Darwinex `.DWX` tester data can legitimately model zero spread,
so that comparison made every such bar ineligible and guaranteed zero trades.
The guard now rejects only crossed quotes (`ask < bid`). Positive-price
validation and the ATR-relative maximum-spread rule remain unchanged.

## Repair and validation

The source change is one comparison operator. The EA was rebuilt against the
current committed framework, and all four canonical setfile build hashes were
refreshed. Strategy parameters, registry rows, magic numbers, and risk sizing
were not changed.

- Strict compile: `PASS`, 0 errors, 0 warnings
  - log:
    `C:\QM\repo\framework\build\compile\20260725_020144\QM5_11224_ft-tdseq.compile.log`
  - summary: `D:\QM\reports\compile\20260725_020144\summary.csv`
- Framework build check: `PASS`, 0 failures, 0 warnings
  - report:
    `D:\QM\reports\framework\21\build_check_20260725_015649.json`
- Build guardrails: `PASS`, no findings across the MQ5 and four setfiles
- SPEC validation: `PASS`, 1 of 1
- MQ5 SHA-256:
  `e4f99258521f68d0d1dfb75069f361bb280b4796278e0bc80fb38cb1e66b153d`
- rebuilt EX5 SHA-256:
  `3770229660c2aa642045398bfe3c4ce3aa3f33658abf5b8465fc1f1f6cd109fc`
- USDJPY setfile SHA-256:
  `450d5b2a0f56c4dd36ddce2bae288f67d13f76c84d2b3d9b9deb470f9d7064d6`
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`

## Q02 requeue

At `2026-07-25T01:58:15Z`, the farm had zero active factory terminals, below
the seven-job CPU ceiling. The existing USDJPY work item was atomically
reopened rather than inserting a duplicate:

- status at evidence capture: `pending`;
- attempt count reset to `0`;
- MQ5, EX5, setfile, symbol, period, and expert bindings pinned in the payload;
- priority track: diverse FX funnel recovery; and
- parent task: the farm claim above.

Database backups:

- `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11224_q02_repair_20260725T015458Z.sqlite`
- `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11224_usdjpy_q02_requeue_20260725T015922Z.sqlite`
- `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11224_final_ex5_binding_20260725T020227Z.sqlite`

No manual tester, smoke run, pipeline phase, or worker was launched. `T_Live`,
AutoTrading, the portfolio gate, the deploy manifest, and live setfiles were
not touched.
