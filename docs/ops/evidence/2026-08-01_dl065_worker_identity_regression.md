# DL-065 worker-identity regression review and recovery

- Evidence date: 2026-08-01
- Router task: `c1427cb7-1449-4a12-a191-e8438925102a`
- Review target: `c4dc83a84e4b5f7573b5e0191546e8378d4ad22b`
- Regression-test commit: `8742a168aac4a35b02ac572f662f52f6370b4e9e`
- Code verdict: **FIX_SOUND**
- Operational verdict: **OWNER_REBIND_REQUIRED_BEFORE_ANY_FUTURE_FACTORY_ON**

## Executive result

The two `os.environ.setdefault("QM_AGENT_ID", "controller")` additions in
`start_terminal_workers.main()` and `terminal_worker.main()` are the correct
minimal DL-065 fix. Terminal workers are deterministic factory machinery, not
prompt-spawned agents, and `controller` is the implementation's trusted-base
identity. `setdefault` fills only an absent identity: an explicit narrower
identity remains present and is still enforced by the scope guard. An explicitly
empty value also remains fail-closed.

The incident set was exactly 27 PASS parents with a READY next-phase
classification and no successor linked by `payload.predecessor_task_id`. The 27
parents match the 27 `unknown` / `mt5.backtest.dispatch` denial traces in the
terminal-worker stderr logs. All 27 were recovered through the guarded canonical
per-parent enqueue command. The recovery created exactly 27 successor tasks and
50 work items. The immediate post-recovery query found zero READY parents without
a successor. Thirteen older `DEFERRED_FACTORY_OFF` parents were deliberately not
touched.

The code fix changes the signed worker-launcher source. The current decision
`FACTORY_RUNTIME_ACTIVATION_20260731_OWNER_SESSION_GO` both expired at
`2026-08-01T05:39:59Z` and binds a different launcher hash/blob. No Factory_ON
action is authorized against this source until OWNER issues a new, source-bound
decision. This review did not mint or alter an OWNER decision.

## True regression timeline

1. `0e0744ef708b137d7f1cbe0caa767ecd127dc7d8` added the
   `mt5.backtest.dispatch` guard on 2026-06-01 11:56:19 +02:00. An unset
   `QM_AGENT_ID` has resolved to `unknown` and failed closed since that commit.
2. `git log --all -S"QM_AGENT_ID"` across `start_terminal_workers.py`,
   `terminal_worker.py`, `Factory_ON.ps1`, `factory_watchdog.ps1`, and
   `run_in_console_session.ps1` finds no historical worker-launch export. Its only
   hit is the reviewed fix. The workers did not previously receive an identity
   from a repository launch chain.
3. Before 2026-07-29, the worker-local successor map contained only legacy phase
   keys. Q-native Q02 and Q03 parents bypassed the successor enqueue, so the
   guarded function was normally not reached by the live Q-native flow.
4. `b62cf063878fa4ff43bd7e48d74e2c04d2fefa4d` (2026-07-29 15:00:47
   +02:00, `maintenance: implement 2026-07-29 convergence plan`) is the causal
   regression commit. It introduced the unified `PARENT_PROGRESSION_MAP` with
   Q02 -> Q03 and Q03 -> Q04, `_auto_enqueue_parent_progression()`, and
   `aggregate_finished_parent_cas()`, then delegated terminal-worker closure to
   that path. A PASS now reached guarded `enqueue_backtest()` from an identity-
   unset worker.
5. The first identified missing successor closed at
   `2026-07-31T08:43:11Z`; this is consistent with deployment/worker-adoption lag
   after the July 29 code commit. The last identified one closed at
   `2026-08-01T15:14:04Z`.
6. `c4dc83a84e4b5f7573b5e0191546e8378d4ad22b` landed at
   2026-08-01 17:24:56 +02:00 and defaults both worker entrypoints to the
   deterministic controller identity.

The three proposed candidates are not causal:

| Commit | Authored (+02:00) | Reason excluded |
|---|---:|---|
| `916e80067158014d0754826488f77e917f99c081` | 2026-07-31 14:46:37 | Batch-coder routing only; authored after the first lost successor. |
| `8e30c206943def87a8a5ea8ce2a0281673d5bf51` | 2026-07-31 23:56:14 | Append-only reruns; authored after the first lost successor. |
| `f8dbdc4939106eb17adcdb1a08ddb409d7268d22` | 2026-08-01 03:07:43 | Guarded append-only Q02 reruns; authored after the first lost successor. |

## Adversarial code review

### Identity class and preservation

- `agent_scopes._TRUSTED_BASE` explicitly contains `controller` and `owner`.
  Terminal workers execute deterministic queue and lifecycle code and expose no
  prompt-agent authority, so `controller` is the appropriate class.
- The default exists in both the spawner and the direct worker entrypoint. The
  spawner makes inherited child state explicit; the worker entrypoint covers the
  watchdog, scheduled-task, direct, and future launch paths.
- `setdefault` does not overwrite a caller-provided `codex`, `gemini`, `claude`,
  or other narrower identity. The guard continues to enforce that identity.
- The repository-root bootstrap inserted before `framework` imports is necessary
  for an absolute-path `terminal_worker.py` launch without `PYTHONPATH`. The
  direct-entrypoint regression test verifies this behavior.

No scope-policy grant was widened, and the fail-closed handling for genuinely
unknown or explicitly empty identities remains intact.

### Separate audit-persistence finding

The incident DENY rows are not durable in the SQLite audit stream. In
`enqueue_backtest()`, the scope audit insert uses the same connection as the
enclosing `with connect(...)` block. `ScopeDenied` unwinds that block, so SQLite
rolls back the just-inserted DENY event. This explains why production `farmctl
audit` does not contain the 27 denial events even though stderr contains the
tracebacks. The stderr/DB correlation below is therefore the incident evidence.
Audit persistence should be corrected in a separately routed change; it was not
silently expanded into this recovery task.

## Incident quantification

The stderr match was exact:

`agent_scopes.ScopeDenied: agent 'unknown' is not allowed scope 'mt5.backtest.dispatch' (tool='enqueue_backtest')`

| Worker log | Matches |
|---|---:|
| T1 | 2 |
| T2 | 4 |
| T3 | 0 |
| T4 | 4 |
| T5 | 3 |
| T6 | 2 |
| T7 | 5 |
| T8 | 2 |
| T9 | 3 |
| T10 | 2 |
| **Total** | **27** |

The DB sweep selected completed PASS parents where
`classification.progression.status = READY` and no task existed with
`payload.predecessor_task_id = parent.id`. Before recovery it returned exactly
27 rows. The following table is the complete set and the exact canonical result.

| # | Parent task | EA | Parent closed (UTC) | Next Q phase | Successor task | Work items |
|---:|---|---|---|---|---|---:|
| 1 | `988399f5-7567-4038-8156-15df53d671be` | QM5_20182 | 2026-07-31 08:43:11 | Q03 | `523e9bf0-958e-47a4-aabd-5d11f1f7283c` | 1 |
| 2 | `8cc811ce-7ccf-48c4-b13a-c26be5b00a75` | QM5_12935 | 2026-07-31 11:03:19 | Q04 | `bc247225-408c-41b0-ac27-6aa1154ee50b` | 1 |
| 3 | `1b16ad11-ac6a-4df7-96ed-c92224fc5099` | QM5_10204 | 2026-07-31 11:05:26 | Q04 | `8e3d0194-f9fe-471f-b8c0-444b67bbf635` | 1 |
| 4 | `3d4a9303-def3-4491-83be-eb1569f8a3fa` | QM5_12796 | 2026-07-31 13:01:49 | Q04 | `e6eb8b03-e1b0-4646-9c8f-72fe84f23359` | 1 |
| 5 | `136e0e58-64c7-4071-b606-badd158d181a` | QM5_10762 | 2026-07-31 14:25:08 | Q04 | `d2128ca3-fa94-4db9-adbc-7cd2ab4dcf14` | 1 |
| 6 | `d7301715-dbd8-48db-b3b8-bb9d7d432ac1` | QM5_10251 | 2026-07-31 14:42:14 | Q04 | `b2aba14f-bde0-4fe5-acd0-1cf76b6de306` | 2 |
| 7 | `e837fc44-bcf9-44c3-ae09-d4e4cdf2f30b` | QM5_11181 | 2026-07-31 15:03:20 | Q04 | `4dcd47b3-b3c2-41ea-b065-2acd011e7e72` | 2 |
| 8 | `638311f5-4a98-4944-a8e2-8862ae163e3b` | QM5_20187 | 2026-07-31 15:53:39 | Q04 | `e3c5ea4e-6779-483f-96a9-759d489a32b0` | 1 |
| 9 | `3e28c306-724c-4d94-bece-93ce8331ac5c` | QM5_11072 | 2026-07-31 16:01:04 | Q04 | `9f11dd38-7980-48c4-b860-b6f1fda057b7` | 1 |
| 10 | `96db796c-17f1-4f17-865c-9c70de347ea0` | QM5_10993 | 2026-07-31 16:18:00 | Q04 | `4584ee74-6c4f-4f33-8a62-8e1f346b16e9` | 1 |
| 11 | `cabb726f-148d-4f30-8e9c-51d6dec90090` | QM5_9997 | 2026-07-31 17:37:46 | Q04 | `5a095eaa-ae98-47d3-8153-3e97b3b3d8cc` | 4 |
| 12 | `8e592371-6087-4bab-ba02-f89af97c558e` | QM5_10713 | 2026-07-31 17:38:37 | Q04 | `acba3820-72b9-4b4f-ab30-3cc842f5e793` | 2 |
| 13 | `be5465ee-b4cf-4f70-a391-e22da674eca5` | QM5_11174 | 2026-07-31 17:53:26 | Q04 | `2746d01d-0aa8-4489-a779-e03f7b63c8c6` | 1 |
| 14 | `118a00d9-c1fe-448d-b0b7-04a6adfd2ca7` | QM5_11916 | 2026-07-31 18:36:12 | Q04 | `8070df08-3e56-4e68-9417-266a5a3db0a9` | 5 |
| 15 | `6977b6ef-a116-4a6b-b3df-dbad6032fab0` | QM5_20188 | 2026-07-31 21:48:29 | Q04 | `084cc633-ee0c-49ae-9720-d1755a26c6fc` | 2 |
| 16 | `949df1df-0cba-49c4-b3e3-b6173bd7a333` | QM5_10614 | 2026-07-31 22:06:25 | Q04 | `2dd66259-6657-4e1a-b698-127c14e0326a` | 2 |
| 17 | `9690dff6-56cf-48bf-92b4-5353e26a1c0b` | QM5_10602 | 2026-07-31 22:38:27 | Q04 | `5f124475-2cfd-406f-9eda-59f95fe521c2` | 1 |
| 18 | `807a9349-4107-48b2-97e2-be0c48ba634f` | QM5_10343 | 2026-07-31 22:58:52 | Q04 | `c918bb2f-8a5d-44c8-8785-7ddd7b9256a5` | 1 |
| 19 | `a02f5416-a147-4f2e-91e7-7056d20b8d89` | QM5_9510 | 2026-07-31 23:38:37 | Q03 | `eeb5e56a-871a-4ada-8c11-2e67e5678a40` | 2 |
| 20 | `cb5a41ed-d7bc-45fc-a4b7-0f0389696fa8` | QM5_12784 | 2026-07-31 23:40:14 | Q04 | `835d31a7-d9d4-4e59-9ca8-5f9d884804b9` | 1 |
| 21 | `8e306dda-8809-4ed9-8904-47a3a109d536` | QM5_11174 | 2026-07-31 23:41:49 | Q03 | `72c9f2fb-218c-47c7-bb3f-195d1323c5a6` | 1 |
| 22 | `e988fca3-f3fc-4e25-9a0f-12b38d0580eb` | QM5_20144 | 2026-07-31 23:47:07 | Q04 | `e72c7516-1b69-4712-becd-765cb0cb23f3` | 2 |
| 23 | `f51d7e7d-38cd-4f73-96ed-a0e8d8b4f8ac` | QM5_12474 | 2026-08-01 00:03:20 | Q04 | `cc3480d2-168e-49eb-90cd-3a4f0ca05fad` | 2 |
| 24 | `6f2b34a8-c11c-4c26-899d-a8a5d2e4cb2d` | QM5_10706 | 2026-08-01 01:17:03 | Q04 | `f6d2e622-66e8-4834-b5fc-05e40557659c` | 2 |
| 25 | `4ae1459e-1a91-4652-8cd7-8ae18ce8c121` | QM5_10608 | 2026-08-01 02:17:37 | Q04 | `11789a94-e498-411a-938c-b02d4e8fbc27` | 1 |
| 26 | `be8bd717-b91f-4a6c-83b8-586a1909bef9` | QM5_10046 | 2026-08-01 03:19:32 | Q03 | `a1455962-9b1f-4375-a1ae-1d48e43f66ee` | 2 |
| 27 | `db1d8853-dcc7-4a52-92de-ca22e116ce1e` | QM5_10127 | 2026-08-01 15:14:04 | Q04 | `c7625748-8fe4-40ed-8f83-ab4a34e019ff` | 7 |
| | | | | **Total** | **27 tasks** | **50** |

Four legacy Q02 parent rows advertised a non-Q alias in their stored progression.
The current Q-only CLI correctly refused that alias; the bounded replay used Q03
for those four rows. All operator-facing recovery phases remained Q-only.

The codebase at the reviewed commit has no dedicated sweep for READY completed
parents, and a general pump does not re-aggregate already completed parents. A
broad pump could also fan out unrelated queue work. Recovery therefore used the
narrow canonical command once per identified parent:

```text
python tools/strategy_farm/farmctl.py enqueue-backtest \
  --review-task-id <exact-parent-task-id> --phase <Q03-or-Q04>
```

This path executes the DL-065 guard, normal predecessor validation,
`create_task()`, and normal work-item fanout. No SQLite row was hand-inserted.
The recovery shell explicitly set `QM_AGENT_ID=controller`; `farmctl.main()` also
has the same trusted-base default.

### Explicit exclusions

The following 13 predecessor rows were already durably classified
`DEFERRED_FACTORY_OFF` by the July 29 reconciliation and are not part of the
identity crash set:

`19437c5e-cbef-40dd-b0f7-423fe73547ce`,
`3907548b-669f-4163-abb1-4070998f87f3`,
`3b6a2482-b8c5-49f5-8d29-fd60e55facea`,
`3c39e461-d78e-46d7-8fda-d62eead66da4`,
`5e8e31a0-8202-4c59-b33d-60a425d21b1a`,
`6ba23d80-8683-40ff-af37-eca93c2ff616`,
`8434a1f4-8c45-4ea0-8b78-fbb7bfb4bb96`,
`b825a264-3700-44f9-a49e-dd40a152225a`,
`bddb1fa3-85f3-4653-a12c-50c513cd43c1`,
`cbbfaba4-e2cb-4344-9ed9-de064cd488e5`,
`d6fd8823-8b6e-4f64-8ffb-56d76bd0aee1`,
`ef7fa077-9327-4280-a972-9bcedd55a7ad`, and
`f8a52f59-bd6f-4b2f-a62c-939a6e58a7d8`.

Post-recovery counts were:

- exact incident parents with exactly one linked successor: 27/27;
- linked successor tasks: 27 pending;
- linked work items: 50;
- READY PASS parents without a linked successor: 0;
- `DEFERRED_FACTORY_OFF` PASS parents without a linked successor: 13.

## Focused verification

The dedicated tests cover both requested identity cases and the adjacent direct
entrypoint failure found in the crash logs:

- unset direct worker defaults to `controller` and passes
  `mt5.backtest.dispatch`;
- explicit `gemini` identity survives worker startup and is denied the dispatch
  scope;
- unset spawner exports `controller` to the child process;
- absolute-path worker startup without `PYTHONPATH` resolves repository imports.

Commands and results:

```text
python -m pytest \
  tools/strategy_farm/tests/test_terminal_worker_identity.py \
  tools/strategy_farm/tests/test_agent_scopes.py \
  tools/strategy_farm/tests/test_mnt009_010_reconciliation.py -q

41 passed in 2.79s

python -m py_compile \
  tools/strategy_farm/start_terminal_workers.py \
  tools/strategy_farm/terminal_worker.py

exit 0
```

## Runtime binding and optional defense in depth

The signed activation decision binds `tools/strategy_farm/start_terminal_workers.py`
as follows:

| Binding | Decision | Reviewed working source |
|---|---|---|
| SHA-256 | `f6ff763ef05be34eb46ca6d2a08d840ab5038d2c7f26e3317f9160c8f9eefc47` | `3bd62af8f20ac567aa9ffde1876df4103ece45aa897f37199b63eff9dc682ef5` |
| Git blob | `53835723f65a8a5857722b8d41c12b0eab49e7ae` | `bcf0833bb92c6e881c48ad395513bc20d32b3b4a` |

The mismatch is expected because the fix edits the bound launcher, but it means
strict activation validation must fail until OWNER rebinds the new source. The
existing decision is also expired. This is an activation gate, not a reason to
weaken the scope guard or revert the worker-identity correction.

No defense-in-depth export was added to `Factory_ON.ps1`,
`factory_watchdog.ps1`, or the `QM_StrategyFarm_WorkerDedupe` installer/action.
The entrypoint fix already covers all three paths. Editing Factory_ON would
change another decision-bound source; editing the installed task would require
an explicit installer/re-registration change. If OWNER wants redundant exports,
those paths and their new hashes must be listed in the replacement decision.

The installed WorkerDedupe task currently runs as SYSTEM and launches the
spawner through `run_in_console_session.ps1`; its action contains no identity
export. Its last recorded run was 2026-07-26 20:00 +02:00 with result
`0x800710E0`. No scheduled task was changed in this review.

## Live-fleet residual and safety record

At the review snapshot, all ten worker processes were present. Five began before
the 17:24:56 +02:00 fix (T1, T2, T4, T6, T9) and therefore had not loaded the
new entrypoint; five began at 17:31:50 +02:00 after the fix (T3, T5, T7, T8,
T10). The pre-fix workers were not interrupted, in accordance with the active
backtest rule. Until they exit and are naturally replaced, a newly completed
Q02/Q03 parent on one of those processes could reproduce one missing successor;
the closing orphan query is therefore the authoritative cycle snapshot, not a
claim that those old processes were hot-patched.

This review did not enable T_Live or AutoTrading, did not start
`terminal64.exe`, did not stop a terminal or backtest, did not change a pipeline
verdict, and did not invoke Factory_ON.

## Reviewer handoff

1. Accept the code logic in `c4dc83a84` together with regression tests in
   `8742a168a`.
2. Require a new OWNER-signed activation decision bound to the resulting runtime
   sources before any future Factory_ON.
3. Preserve the exact 27-row recovery set; do not sweep the 13 Factory-OFF
   deferrals into this incident.
4. Route the rolled-back DENY-audit behavior separately if durable denial audit
   evidence is required.

