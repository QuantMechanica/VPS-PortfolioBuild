# Population telemetry: exact Q08 rerun and poor-shape diagnosis

**Router task:** `d8a61daa-721f-40a2-9e38-3cfc491d552d`  
**Date:** 2026-08-19  
**Baseline snapshot:** `3472a5d2e1b5`  
**Scope:** `QM5_11132/NDX.DWX` and `QM5_11288/USDJPY.DWX` only

## Outcome

- `QM5_11132/NDX.DWX`: exactly one append-only Q08 rerun was enqueued as work item
  `796a235d-3ea6-4876-8a6a-61f20580f654`. It is pending in the governed worker queue. No terminal
  was started manually and no pipeline verdict is inferred.
- `QM5_11288/USDJPY.DWX`: no rerun was enqueued. The fresh 2026-08-18 Q08 run already used the
  exact current canonical EX5 and reproduced the poor nine-field stream shape on all 436 rows.
  The EX5 bytes are from a 2026-06-25 build, before the 2026-07-30 full-lifecycle emitter landed.
  An unchanged rerun cannot improve telemetry; a rebuild would be required and is outside this
  task's explicit no-recompile boundary.
- The merged batch remains blocked under OQ-8/OQ-12. No gate, threshold, EA source, binary,
  setfile, `T_Live`, or AutoTrading state was changed.

## `QM5_11132/NDX.DWX`: governed rerun

The archived population stream is stale:

- `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/11132_NDX_DWX.jsonl`
- 35 JSON rows; `entry_time=0%`, `mae_acct=0%`, `money_basis=0%`
- SHA-256 `72094b9980f5b01c8852890cbc562ab5a34682d839f039fef589ea51b8669660`

The Common-file copy is newer than that archive but still predates the current binary:

- `C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/QM/q08_trades/11132_NDX_DWX.jsonl`
- 72 JSON rows; `entry_time=100%`, `mae_acct=100%`, `money_basis=0%`
- mtime 2026-07-14; the current EX5 was committed on 2026-08-05 after the 2026-07-30 rich-emitter
  change.

Preflight was clean:

- Compile receipt: `COMPILED`, exit 0, 0 errors, 0 warnings, timestamp 2026-07-31T17:11:28Z.
- Canonical EX5 SHA-256:
  `e3dea054cce04aba5aec82ceb9a8a0a530acc43c6b4d3783ee5f70d89064a66e`.
- Registry row `11132,tm-cum-rsi2,1,NDX.DWX,111320001,...,active` is active.
- Exact D1 setfile SHA-256:
  `7ce0edd5967a1cfc9514fc0112ba6e3024aebc9e9ddfd877db4fd91c09cb8a33`.
- Setfile contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, news filter enabled in mode 3.
- D: free space was 154.13 GB; T1-T5 were not all busy.

The enqueue preserved terminal Q08 row `43ef6eba-c9c1-46e8-9508-684a17378592`, bound the exact
Q07 predecessor `9275f769-2c6d-4cfd-a598-40cf68921c0d`, and created only:

```text
796a235d-3ea6-4876-8a6a-61f20580f654  QM5_11132  NDX.DWX  Q08  pending
```

The new row carries immutable expected EX5, MQ5, setfile, symbol, period, and expert bindings plus
active custom-history archive admission. A post-run acceptance check must read the newly bound
portfolio stream and require at least 99% non-null coverage for both `entry_time` and
`money_basis`. Pending is not PASS.

## `QM5_11288/USDJPY.DWX`: why the poor shape is real

Latest Q08 work item `0473327d-7a7b-40f0-b0eb-366e74d0e68a` finished on 2026-08-18 with evidence:

- Aggregate:
  `D:/QM/reports/work_items/0473327d-7a7b-40f0-b0eb-366e74d0e68a/QM5_11288/Q08/USDJPY_DWX/aggregate.json`
- Baseline EX5 SHA-256:
  `c9f20a0ec3456c5086dd5ad92e27b9fe3de99f417052bece66c8d79680b47310`.
- Canonical EX5 SHA-256 at diagnosis: the same `c9f20a0...b47310`.
- The worker's staging receipt says the same source and destination hash was verified and no
  restage was needed.
- Bound portfolio stream:
  `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/11288_USDJPY_DWX.jsonl`, SHA-256
  `e30f6b0c3f1777907744250c55d78506f62be84143881ff0de21985b1d39a999`, 70,016 bytes, 436 rows.

Every row has exactly:

```text
commission,event,net,notional,profit,swap,symbol,time,volume
```

Coverage across the 436 valid JSON rows is `entry_time=0%`, `mae_acct=0%`, and
`money_basis=0%`. This is not an archive-selection or stale Common-file explanation: the Q08
aggregate identifies it as `fresh_baseline_common_stream` and binds it to the exact baseline
report, summary, EX5, MQ5, and setfile.

Git provenance closes the apparent timestamp contradiction. The canonical EX5's current bytes
were last committed in `79bce8f9fd471418ae1c876f49ea6dd857111621` on 2026-06-25, with the same
SHA-256 `c9f20a0...b47310`. The full-lifecycle writer entered `QM_Common.mqh` in commit
`85db6178cd676abc6da2b2c611eabdebe049ab1b` on 2026-07-30. The EA includes
`<QM/QM_Common.mqh>`, but its EX5 has not been rebuilt since June. Its 2026-08-17 filesystem mtime
is therefore staging time, not build provenance.

### Re-run-helpfulness check

Do not rerun this pair unchanged. A future rerun is useful only after all of these are true:

1. an authorized rebuild produces a canonical EX5 SHA-256 different from `c9f20a0...b47310`;
2. its compile receipt proves the build used the post-2026-07-30 full-lifecycle framework and
   compiled with 0 errors and 0 warnings;
3. the Q08 row binds that new EX5 hash before dispatch;
4. the resulting fresh stream reaches at least 99% non-null `entry_time` and `money_basis`.

Under the current no-recompile constraint, condition 1 is false, so spending another Q08 run
cannot help.

## Focused verification

- Read-only DB check after enqueue found exactly one new Q08 row created at or after
  2026-08-19T07:56:00Z: `796a235d-3ea6-4876-8a6a-61f20580f654`.
- That row remains `pending`, unclaimed, and without evidence or verdict at artifact time.
- No `QM5_11288/USDJPY.DWX` work item was created by this task.
- No active terminal was interrupted; the worker queue retains dispatch authority.
- No pipeline outcome is asserted by this artifact.
