# QM5_12435 FX Q02 stale-EX5 recovery — 2026-08-15

## Result

`QM5_12435_ea31337-cci` was rebuilt against the current V5 include and magic
resolver state and one authenticated append-only Q02 successor was enqueued for
`EURUSD.DWX` H1. No strategy source or execution parameter was changed.

- Farm coordination task: `18b96981-5522-46db-8b0f-3bb779d42d4a`
  (`ops_issue`, assigned to `codex`).
- Preserved predecessor: `018c358a-588f-4f76-bf55-53a47c70d03a`.
- New pending work item: `8996ae9b-37b0-4e2a-aac9-12e95db4b2de`.
- Host: `EURUSD.DWX`, H1, `2022.07.01` through `2022.12.31`.
- Risk binding: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Why this was a non-duplicate infrastructure recovery

The farm had no open work item or open agent task for `QM5_12435`, and the EA
had no Q04-or-later result. Its predecessor is terminal `INFRA_FAIL`, with
`ONINIT_FAILED`, `INCOMPLETE_RUNS`, and `BARS_ZERO`; it is not a strategy
verdict. The failure summary is:

`D:\QM\reports\work_items\018c358a-588f-4f76-bf55-53a47c70d03a\QM5_12435\20260811_152717\summary.json`

SHA-256: `7ae972c7b7743afacdb0178023d6ae24b6e7596b909745345f99347b4f83737a`.

The failed run deployed EX5 SHA-256
`2f5953e6744a052aa5dca85925d124914ec5f937626dd4b3bdbdd3b7694cf242`.
The run produced no structured logger file. In the V5 initialization order,
magic resolution occurs before logger initialization. The EA inputs were valid
and registry slot 0 is active as `12435,ea31337-cci,0,EURUSD.DWX,124350000`.
This makes an incorrect or stale resolver embedded in the deployed binary the
narrow repair hypothesis; no signal mechanic was changed to force a pass.

The fresher WTI/Brent candidate `QM5_21518` was deliberately not rerun. Its
failure requires `XBRUSD.DWX`, while the canonical venue registry says that
symbol is outside the `.DWX` universe and the available terminal remnants do
not cover its required 2018–2022 history. Farm task
`38e3ff0e-1d6f-41fd-86c3-c966c6a42cad` was released as `BLOCKED` with verdict
`UPSTREAM_R3_DATA_GAP_XBRUSD_NOT_IN_DWX_UNIVERSE_NO_REQUIRED_HISTORY`.

## Repair evidence

The MQ5 source remained byte-identical:

- MQ5 SHA-256: `060fbde58733ebf07ffa1537b3bb04615a330a19895dca42ca90ce3a052dfbe8`.
- Strict compile: `PASS`, 0 errors, 0 warnings.
- Compile summary:
  `D:\QM\reports\compile\20260815_114440\summary.csv`.
- Compile-summary SHA-256:
  `29083aad42f5a6b86f340480e15a9fdede2b0096cf228f06f35b5a8e531735e0`.
- Rebuilt EX5 SHA-256:
  `55a4dee833b7ea9e8eef6998ae7c3c9d6a04ebe2bdc6e28bbe0f86139a17024d`.
- Strict build check: `PASS`, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260815_114505.json`.
- Build-check report SHA-256:
  `59bca962382c96506e9618bdfecdeb56ef409e8600e650c72d6d111e4242e7e2`.

The build checker normalized only the `build_hash` comment in the EA's eight
existing backtest setfiles. Strategy and risk values stayed unchanged. The
enqueued EURUSD H1 setfile is bound to SHA-256
`967e9c13f25071236de05f8b1d2475d658f32dc72bf5f36b22a41e3382b47d26`.

## Append-only Q02 handoff

`farmctl enqueue-backtest` authenticated the predecessor evidence and current
artifacts, preserved the old row, and created exactly one pending successor:

- Work item: `8996ae9b-37b0-4e2a-aac9-12e95db4b2de`.
- `append_only_rerun_of_work_item`:
  `018c358a-588f-4f76-bf55-53a47c70d03a`.
- `repaired_infra_rerun`: `true`.
- Expected MQ5 SHA-256:
  `060fbde58733ebf07ffa1537b3bb04615a330a19895dca42ca90ce3a052dfbe8`.
- Expected EX5 SHA-256:
  `55a4dee833b7ea9e8eef6998ae7c3c9d6a04ebe2bdc6e28bbe0f86139a17024d`.
- Expected setfile SHA-256:
  `967e9c13f25071236de05f8b1d2475d658f32dc72bf5f36b22a41e3382b47d26`.

At handoff, the factory flag was absent, two work items were active, five CPU
samples averaged 25.8%, and 25,768 MB physical memory was free. The successor
was enqueued only; no pump, dispatch tick, smoke test, or backtest was started
by this recovery.

## Safety boundary

No `T_Live` file, deploy manifest, portfolio gate, or AutoTrading state was
readied or changed. This unit changes only the rebuilt research EX5, normalized
backtest-set metadata, this evidence record, and the append-only farm queue.
