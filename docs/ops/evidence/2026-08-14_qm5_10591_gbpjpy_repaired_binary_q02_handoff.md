# QM5_10591 GBPJPY repaired-binary Q02 handoff — 2026-08-14

## Outcome

Router task `a058cc4d-bb19-4dff-9c69-5380194bf8c3` authenticated the
post-timeout performance repair for `QM5_10591_mql5-ozym` and appended exactly
one hash-bound `GBPJPY.DWX` Q02 successor. The new work item is
`f8c53f40-9319-443f-bf17-49b186d4ed91`; it was left `pending`, unclaimed, and
without a verdict for the deterministic factory to run.

This is a Q02 queue handoff, not a pipeline verdict or live-use authorization.

## Coordination and exact scope

- Router task: `a058cc4d-bb19-4dff-9c69-5380194bf8c3`
- EA / symbol / timeframe: `QM5_10591` / `GBPJPY.DWX` / `H4`
- Repair commit: `f49c8540cbfc43c6c785719dfeb766cccacce7ca`
- Terminal predecessor: `93077cce-bac0-4d3a-aa77-70e9e9a99353`
- Predecessor state: `failed / INFRA_FAIL`, reason `ACTIVE_TIMEOUT`
- Predecessor binary SHA-256:
  `ce15d6f50c964841af724e52666c376c33d7e69a50c7a33ca1a4411e16d74ed6`
- Spawn lease: the expired router lease was atomically reacquired by `codex`
  for the same `agent_task:<task_id>` key before queue mutation
  (`2026-08-14T16:46:59Z` through `17:16:59Z`).

The predecessor row and its evidence were preserved unchanged. Its retained
report is:

`D:\QM\reports\work_items\93077cce-bac0-4d3a-aa77-70e9e9a99353\QM5_10591\20260728_213017\raw\run_01\report.htm`

The enqueue path sealed that file as SHA-256
`ac3f255d6f6665bb1e5defde6ac8427cbc832c29e95cfc5c0dd2bd3f58613789`.

## Repair authentication

Commit `f49c8540c` moved the Ozymandias structural scan behind the framework
new-bar gate and cached the closed-bar signal for entry and adverse-signal
exit. Current canonical bytes are unchanged from that repair and its retained
evidence:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `55d2237975ce2306c1b1fd29ae48df4792bf3de42c156ffd91ba92ea4ceb4414` |
| EX5 | `0dd503bfd16af2b547a660f02306d098aad9dfd2f401a5ee452ef655fad07c80` |
| GBPJPY H4 backtest set | `bd4fc45528494c90163060de79aebcefc49f63b34049fafac5364cddc471f0e0` |

The same EX5 has completed later deterministic pipeline work on `EURUSD.DWX`:

- Q02 `92290c04-8598-499c-8b2f-f0172990c5d5`: `PASS`, report
  `D:\QM\reports\work_items\92290c04-8598-499c-8b2f-f0172990c5d5\QM5_10591\20260801_023732\summary.json`
- Q03 `991e188c-2305-4241-8ced-d20f7c2d7be3`: `PASS`, report
  `D:\QM\reports\work_items\991e188c-2305-4241-8ced-d20f7c2d7be3\QM5_10591\20260801_144410\summary.json`

Those rows authenticate that the repaired binary finishes governed MT5 runs;
they do not predict or supply a GBPJPY verdict.

## Focused verification

- `git diff f49c8540c..HEAD -- framework/EAs/QM5_10591_mql5-ozym` was empty.
- `validate_build_guardrails.py` passed the MQ5 and exact GBPJPY setfile with
  zero findings and the enforced `qm_news_stale_max_hours <= 336` ceiling.
- The GBPJPY setfile has `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Fresh-Q02 append-only tests: `9 passed, 22 deselected`.
- A second identical enqueue request created no row and returned
  `append_only_rerun_already_exists` for the new pending item.

## Append-only queue result

The legacy-only `seed-fresh-q02` path first refused the predecessor because it
already has all six execution-binding fields. No row was created by that
attempt. The deterministic hint was followed with the authenticated exact-row
rerun path:

```text
farmctl.py enqueue-backtest --ea QM5_10591 --phase Q02 \
  --from-work-item-id 93077cce-bac0-4d3a-aa77-70e9e9a99353 \
  --append-only-rerun-of 93077cce-bac0-4d3a-aa77-70e9e9a99353 \
  --expected-current-ex5-sha256 0dd503bfd16af2b547a660f02306d098aad9dfd2f401a5ee452ef655fad07c80
```

Successor `f8c53f40-9319-443f-bf17-49b186d4ed91` is sealed to:

- expert `QM\QM5_10591_mql5-ozym`
- symbol `GBPJPY.DWX`
- period `H4`
- current MQ5, EX5, and setfile hashes listed above
- `RISK_FIXED=1000.0`, `RISK_PERCENT=0.0`
- `append_only_rerun_of_work_item=93077cce-bac0-4d3a-aa77-70e9e9a99353`
- `rerun_source_repaired_after_infra=true`
- `historical_work_item_preserved=true`

## Capacity and safety

The pre-enqueue slot scan showed seven active factory tests on T1–T5, T9, and
T10. The successor was therefore left for the normal pump/dispatch path. No
terminal was launched, stopped, or interrupted manually. `T_Live` was observed
read-only and was not touched; AutoTrading was not enabled. No portfolio gate,
deploy manifest, live artifact, or pipeline verdict was changed.

The next valid evidence is the factory-produced Q02 result for
`f8c53f40-9319-443f-bf17-49b186d4ed91`.
