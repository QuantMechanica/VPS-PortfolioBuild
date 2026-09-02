# Q09 REQUAL-8 pair 7 governed-smoke containment checkpoint

- Recorded: `2026-09-02T00:35Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256:
  `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR7_SMOKE_REFUSED_NO_CAPACITY_CONTAINMENT_ACTIVE`

## Outcome

The continuation's one authorized real build-smoke attempt used the governed
`run_smoke.ps1` path, `-Terminal any`, the exact reviewed pair-7 EX5 hash, and
the manifest-bound `EURUSD.DWX D1` backtest set. The governed resolver refused
before launch:

```text
Terminal resolution returned no terminal. status=no_capacity error_code=none message=No message.
```

The command exited `1` before selecting or starting a terminal. No pair-7
tester process, report directory, summary, or custom-history reservation was
created. The already-active T7 test was not interrupted. In accordance with
the router continuation, this cycle did not name an explicit terminal, bypass
containment, retry the refusal, retrofit generation-0 evidence, or manufacture
a smoke PASS.

Because no genuine smoke evidence exists, no append-only build-record
successor was written, the manifest enqueue command was not retried, the
pair-7 hold was not released, and pair 8 was not started.

## Exact governed command

```text
pwsh -NoProfile -File C:/QM/repo/framework/scripts/run_smoke.ps1 -EALabel QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8 -Symbol EURUSD.DWX -Year 2024 -Terminal any -Period D1 -SetFile C:/QM/repo/framework/EAs/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8/sets/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8_EURUSD.DWX_D1_backtest.set -MinTrades 1 -SmokeMode -ExpectedExpertSha256 3a3923930ddf97b7249e37e340312f09924775daea930f4fd3c57fc0441931e1
```

## Containment and capacity evidence

At the refusal boundary, the durable containment receipt reported:

- `enabled=true`;
- mode SHA-256
  `109d62f7febdc2e886cb8976e1b5ea02773e0e0798c5c3f87d75dcbed93cb97d`;
- reason `custom_history_gate_exception:CustomHistoryGateError`;
- source `automatic_stop_condition`;
- recorded at `2026-09-01T20:18:47.854185+00:00`.

The global custom-history lease file was write-locked by the active holder.
The reservation ledger bound T7 to
`run_smoke:14172:67882475fa0249a497f1f3efa0e31fb2` until
`2026-09-02T05:02:45.163911+00:00`, with reason
`run_smoke_custom_history_admission`. The post-refusal `mt5-slots` census at
`2026-09-02T00:35:41+00:00` showed:

- exactly one factory terminal process, T7;
- T7 actively running work item
  `3f09f928-da9e-5883-a2ba-0b0088432f33`, `QM5_41196 / XAUUSD.DWX /
  OPT_CENSUS`;
- resident terminal workers T1-T8;
- no duplicate terminal workers and no orphaned terminal processes;
- only T11 and T12 disabled by policy.

Although other factory terminals were process-idle, the governed `any`
resolver returned `status=no_capacity`. This checkpoint records that exact
fail-closed result; it does not reinterpret idle processes as dispatch
authority.

## Sealed artifact verification

The reviewed pair-7 artifact bytes remain unchanged:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `ede8570a029563fadecdfb99b829331903dffa0d2e46a3bb64c6e3cf8af8e91f` |
| EX5 | `3a3923930ddf97b7249e37e340312f09924775daea930f4fd3c57fc0441931e1` |
| EURUSD.DWX D1 backtest set | `ee72ead97a1a8cf2bb1998ad064c52a4a9128c052e365117062b4771666e3bf6` |

The set remains bound to `RISK_FIXED=1000` and `RISK_PERCENT=0`; the EA's
fail-closed news-calendar staleness ceiling remains `336` hours.

Focused checks after the refusal also passed:

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`;
- `validate_build_guardrails.py`: MQ5 and setfile `PASS`, zero findings,
  maximum news staleness `336` hours;
- manifest JSON SHA-256: exact approved hash above;
- evidence `git diff --check`: clean.

## Serial-state verification

Read-only canonical database checks after the refusal found:

- pair-7 Q02 work-item count: zero;
- pair-7 hold `30584122-b7b3-41eb-8e1a-b03517554d4d`:
  `Q09_AWAITING_SEALED_PLAN`, `active=1`, `released_at=NULL`,
  `release_note=NULL`;
- build task `0f36f1bb-924b-4126-b682-c30ba1edfa41`: unchanged
  `done`, generation 0;
- mechanical review `7b301e4c-2cd0-42c7-9bb7-d6fe4200d471`: unchanged
  `done`;
- EA review `58882906-5836-4ea5-9395-ea973cbe3c31`: unchanged `done`;
- pair-8 `QM5_41222`: zero tasks by card and zero work items;
- pair-8 hold `08fe4173-07d9-47e1-97e9-a76b1159ad94`: still active with
  no release timestamp or note.

The protected `QM5_41162 / OPT_CENSUS` snapshot remains exactly 1,161 rows:
237 `done/MEASURED` and 924 `done/SKIPPED_EXCLUDED`. Its canonical ordered-row
SHA-256 is
`fdc02350a0acc2351d9b4beb9efac94866af3dbd1ae7a7a14278cb301d128d4c`,
identical to the preceding pair-7 checkpoints.

No historical work item, hold, review, build result, EA source, EX5, setfile,
registry, protected-program row, terminal policy, AutoTrading setting,
`T_Live` setting, main branch, or `C:/QM/worktrees/cto_main` state was changed.
No pipeline phase ran and no pipeline verdict is asserted.

## Required continuation

After the active governed containment lease clears naturally, retry this exact
hash-pinned command through `-Terminal any`. Do not select a terminal manually
and do not bypass containment. Only a genuine smoke result may be recorded as
an append-only build-generation successor bound to the same MQ5/EX5/setfile
hashes. Fresh generation-matched reviews remain required before the manifest's
single Q02 enqueue, and the pair-7 hold may be released only after exactly one
Q02 row is verified. Pair 8 remains strictly downstream.

## Verdict

`PAIR7_SMOKE_REFUSED_NO_CAPACITY_CONTAINMENT_ACTIVE`: governed dispatch
refused before launch; zero smoke evidence, zero Q02 seeds, zero hold releases,
zero historical mutation, and zero protected-program interruption.
