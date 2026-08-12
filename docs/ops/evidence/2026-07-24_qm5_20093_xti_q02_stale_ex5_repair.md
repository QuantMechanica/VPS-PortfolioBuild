# QM5_20093 XTIUSD Q02 stale-EX5 repair

Date: 2026-07-24  
EA: `QM5_20093_wti-summer-short`  
Failed work item: `f876ec96-a222-4f7f-a4c0-7494a0f1885a`  
Pending Q02 work item: `9a53408e-dadd-4197-b87d-4c3d36509b43`  
Coordination task: `ae90ff15-0da9-4ea1-938a-2cda76bd7a81`

## Failure evidence

- Q02 summary:
  `D:\QM\reports\work_items\f876ec96-a222-4f7f-a4c0-7494a0f1885a\QM5_20093\20260724_010837\summary.json`
- Verdict: `INFRA_FAIL`
- Reason classes: `ONINIT_FAILED`, `INCOMPLETE_RUNS`
- The failed source and deployed binaries matched at SHA-256
  `054b47cb03757c9e0e6a89c2c5121f3a150decc4eed3fe0c8b6c102853be9421`,
  excluding a deployment-copy mismatch.
- The governed magic registry contains the active row
  `20093,wti-summer-short,0,XTIUSD.DWX,200930000,...,active`.
- The current generated `QM_MagicResolver.mqh` contains EA `20093` and magic
  `200930000`. The failed EX5 predated that resolver state, matching the
  stale-resolver-binary failure already confirmed for XTIUSD EA 12583.

## Repair

Recompiled the unchanged MQ5 source against the current generated resolver:

```text
framework/scripts/compile_one.ps1
  -EAPath framework/EAs/QM5_20093_wti-summer-short/QM5_20093_wti-summer-short.mq5
  -Strict
```

Result: PASS, 0 errors, 0 warnings.

- Compile log:
  `C:\QM\repo\framework\build\compile\20260724_021621\QM5_20093_wti-summer-short.compile.log`
- Compile summary:
  `D:\QM\reports\compile\20260724_021621\summary.csv`
- Rebuilt EX5 SHA-256:
  `b719222f3cdb07d6b961f526aa9209c10eb1adad6e17c813386510610a2cc51d`

Q02 work item `9a53408e-dadd-4197-b87d-4c3d36509b43` is pending and
unclaimed for the factory to bind to the rebuilt binary. No backtest was
launched manually. No live terminal, AutoTrading setting, portfolio gate,
deploy manifest, or T_Live artifact was touched.
