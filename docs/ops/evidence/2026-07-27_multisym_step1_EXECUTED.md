# Multi-symbol step 1 — governed execution

Date: 2026-07-27

## Controlled build

Both arms were compiled serially in the same session from the current canonical
tree and include tree. Each compile returned 0 errors and 0 warnings.

- QM5_20181 runner SHA256:
  `60EE13B7828CA2DDDA11A1264CB2391EA2283DA9AF034915895D3DE4852221F9`
- QM5_9936 standalone SHA256:
  `5ACDAB8737C9579107CB7D2C05AC44034CC9FF9B368C13A8D5061255C29E3CD4`

## Governed work items

Both full-window Model-4 runs were submitted to the persistent terminal-worker
queue with priority-track and basket-Q02 dispatch metadata, exact
`2017.01.01`–`2025.12.31` bounds, USDJPY.DWX/H1 setfiles, and a 150-minute inner
budget:

- joint runner: `a343f66e-d9c7-4965-81ac-f1e70166cb75`
- standalone: `588af557-300f-4e25-82a4-81974b04380a`

The setfiles satisfy the build guardrail (`RISK_FIXED=1000`,
`RISK_PERCENT=0`). No terminal was launched manually, reserved factory work was
not interrupted, and neither T5 nor T_Live was touched.

## Three-way comparison

Both governed items completed `PASS` on T7 with zero retries. The durable
summaries are:

- runner:
  `D:\QM\reports\work_items\a343f66e-d9c7-4965-81ac-f1e70166cb75\QM5_20181\20260727_220826\summary.json`
- standalone:
  `D:\QM\reports\work_items\588af557-300f-4e25-82a4-81974b04380a\QM5_9936\20260727_215505\summary.json`

The worker summaries prove the deployed binaries matched the compiled sources
and remained stable during both runs. Both reports contain 1,143 trades,
`net_profit=118545.48`, `profit_factor=1.24`, and drawdown
`25560.71 (14.40%)`.

The extended comparator was run against the task-scoped fresh FILE_COMMON
streams and the archived
`D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\9936_USDJPY_DWX.jsonl`:

| comparison | joint/fresh rows | reference rows | exact | shifted exit | different entry | missing | match rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| 20181 runner vs same-vintage 9936 | 1,143 | 1,143 | 1,143 | 0 | 0 | 0 | **1.000000** |
| same-vintage 9936 vs archive | 1,143 | 1,252 | 1,046 | 72 | 25 | 109 | **0.835463** |
| 20181 runner vs archive | 1,143 | 1,252 | 1,046 | 72 | 25 | 109 | **0.835463** |

For each archive comparison the direct matcher additionally reports 97
unmatched fresh rows and 206 unmatched archived rows. The category classifier
pairs those non-exact rows deterministically, hence its separate `missing=109`
count.

## Verdict

The repaired QM5_20181 runner passes the same-vintage fidelity gate exactly:
**1.0**. The archive does not represent the current 9936 execution stream:
both the standalone and the runner diverge from it identically at
`match_rate=0.835463`. This isolates the divergence to evidence vintage rather
than the repaired joint runner.

One requested condition was not met by the governed harness: both generated
tester INIs record `FromDate=2018.07.02`, not `2017.01.01`; `ToDate`,
model, host, and timeframe are `2025.12.31`, Model 4, USDJPY.DWX, and H1.
The comparison verdict therefore applies to the common observed
2018-07-02–2025-12-31 window. Results before 2018-07-02 are **NOT
ESTABLISHED**.
