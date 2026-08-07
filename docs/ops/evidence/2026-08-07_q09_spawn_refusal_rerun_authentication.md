# Q09 spawn-refusal rerun authentication and staggered recovery

Date: 2026-08-07 (Europe/Berlin)

Router task: `3f59a274-5703-44cb-bb42-f340b73e64af`

Implementation commit: `fc91107802aba75cc5a5badbc1785ce4dbaf2c1e`

Status: IMPLEMENTED, VERIFIED, AND ENQUEUED / REVIEW REQUIRED

Admission status: diagnostic non-admission only; no pipeline or live-use verdict

## Outcome

The Q09 backfill rerun contract now accepts the narrowly documented
`worker_staged_ex5_destination_path_mismatch` spawn-refusal class without
requiring a summary that the refused runner could never have produced.
Acceptance does not rely on an incident-window timestamp. The predecessor's
structured `payload.spawn_refusal` must match both the terminal work-item row
and exactly one durable `runner_spawn_refused` event written by
`record_work_item_spawn_refusal`.

Seven requested append-only successors were created. The two immediate
NDX/GBPUSD rows and five XAUUSD rows all carry authenticated refusal lineage,
sealed 40-cell plan bindings, `diagnostic_concurrency_cap=5`, T1-T5-only
eligibility, `RISK_FIXED=1000`, and `RISK_PERCENT=0`. XAUUSD claim eligibility
is staggered hourly to reduce shared Custom-history contention.

No T_Live file was written, no terminal or AutoTrading setting was changed,
no terminal process was started or stopped, and no canonical Q09 result was
minted.

## Fail-closed contract

The new proof path is allowlisted to one refusal reason:

```text
worker_staged_ex5_destination_path_mismatch
```

For that reason, rerun authorization requires all of the following:

1. predecessor `status=failed`, `verdict=INFRA_FAIL`, `phase=Q09_NEWS`, and no
   active claim;
2. refusal phase `Q09_NEWS`, terminal in T1-T5, and
   `phase_runner_scope_blocked=false`;
3. `payload.verdict_reason` equals the refusal reason;
4. predecessor `updated_at` equals `spawn_refusal.failed_at_utc`, with a
   timezone-aware timestamp;
5. exactly one `events` row for the predecessor with
   `event=runner_spawn_refused`; and
6. the event's parsed `detail_json` exactly equals the payload refusal object.

The successor stores a SHA-256 binding over the complete event record,
including event ID, event timestamp, entity identity, event name, and detail.
The avoidance terminal is read from this authenticated refusal record. The
CLI terminal is only a consistency assertion; a mismatch fails closed.

Existing authenticated paths remain unchanged:

- staged-EX5 preflight drift;
- child exit 1 without a receipt;
- the corrected diagnostic minimum-trade floor; and
- one authenticated successful run after an invalid startup attempt.

A new optional `--launch-not-before-utc` argument preserves an explicit,
timezone-aware claim deferral after plan binding. Its value is included in the
immutable enqueue receipt, and an idempotent generation rerun rejects a
different requested schedule.

## Refusal records authenticated before mutation

| EA / symbol | Predecessor | Durable event | Refusal terminal | Event-record SHA-256 |
|---|---|---:|---|---|
| QM5_12567 / XAUUSD.DWX | `aca92ad6-8929-5c04-850f-e8ee65fc28bc` | 341835 | T2 | `cd927b17a74fd6c790bce9bc5ce999e03d138db9d66ad2086b40743162cfde2a` |
| QM5_1556 / XAUUSD.DWX | `8419449d-5474-5a2c-a58a-d2b6caf57b27` | 341836 | T2 | `76d26bc2ba7451f2fd954bc411b593bfff2a1b6abb4dac65256f5fa162d589a8` |
| QM5_10440 / NDX.DWX | `2b792348-db4a-500f-a221-c26595ca3c83` | 341831 | T2 | `8f916f33819d44e1e043c9155c5d8947ee960c0f4d6a460f3754d0ee51b255e6` |
| QM5_10939 / GBPUSD.DWX | `2b74dd61-a521-53e9-8d31-1a4deb209338` | 341841 | T1 | `5adaa7faf39e2aedaa1baaa96e2f78438a3d72224d1a172548c9086468e0c23e` |
| QM5_10403 / XAUUSD.DWX | `e525cbb6-136c-5eaf-9b06-ac62229ae0f3` | 341834 | T2 | `0227cf5c2a112c941fdc968de93803da8393d70fff44359ea17067947018a90b` |
| QM5_10513 / XAUUSD.DWX | `75f9a966-c7fe-5c48-a5cb-97f1bf77c07d` | 341832 | T2 | `3b0d05084383bed683f26af03927c1dcff8f1c991197f793c6ba4df09af1b76e` |
| QM5_12989 / XAUUSD.DWX | `5c382e2d-55ff-5a49-bd20-9a2b5f35191d` | 341833 | T2 | `72d854eed0d0e9f32f69a17c34fea74fc932b762981cbf6968a3cfa2499a62ec` |

Every row matched the requested EA/symbol, was terminal
`failed/INFRA_FAIL`, and had no pre-existing successor for this router task.

## Append-only successors

| EA / symbol | Successor | Lineage form | Claim not before (UTC) | Receipt SHA-256 |
|---|---|---|---|---|
| QM5_10440 / NDX.DWX | `ace3f877-e9b4-574f-abae-c90eb983aab0` | generation 4 | immediate | `059a9c6c00040847b469ec24a4a63161815b34e0d3d2adc1c276f83a45e7ae06` |
| QM5_10939 / GBPUSD.DWX | `773b0a56-e8d8-53cb-8e1e-a42738680c22` | generation 4 | immediate | `3bc5346acb9bcb08dd2284133954d6ce6ab91969682600d89b037a08e399db69` |
| QM5_12567 / XAUUSD.DWX | `d03f6148-7cb4-5397-912f-2c468de539b4` | original-campaign append-only rerun | 04:30 | `20f8437a1567b3fa59bd1e6c06fd586461a93d6c63f182bf40a472703b275ac8` |
| QM5_1556 / XAUUSD.DWX | `08be2fce-26ca-5297-b139-d9701273af8f` | original-campaign append-only rerun | 05:30 | `857ed21c8801de4440e9dc4d7fe08d2e7f4ae69541f082ccfd055ab6509ade4b` |
| QM5_10403 / XAUUSD.DWX | `0bfb3d97-2953-52d6-b89b-dcd1eb2665c2` | generation 3 from wave-2 predecessor | 06:30 | `4543a0037a6d2d5f767ed68b626a8f1aa1966f53c677e1c8437deb87b9b7394c` |
| QM5_10513 / XAUUSD.DWX | `23bc80e0-71fb-5f0d-9bad-3538d400bf0a` | generation 3 from wave-2 predecessor | 07:30 | `b401edd5c1453ecd3c05b29da657d9a6967fd60ade2ce52aeed214d602113e79` |
| QM5_12989 / XAUUSD.DWX | `17e78f20-2bae-5473-b54b-5e405cf53239` | generation 3 from wave-2 predecessor | 08:30 | `7f318f6e06d1531dd92aa02ecef5fad22e5727e9fa7c59a967f22c571b2b0c9f` |

The task described the recovery batch as “gen-4.” The exact sealed lineage is
recorded above rather than manufacturing generation numbers: the two gen-3
predecessors correctly advance to gen-4, the three wave-2/gen-2 predecessors
advance to gen-3, and the two original campaign rows use the existing
append-only rerun identity because they have no `diagnostic_generation` field.
Skipping or inventing generations would change the established lineage.

Receipt roots:

```text
D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v4\ace3f877-e9b4-574f-abae-c90eb983aab0\enqueue_receipt.json
D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v4\773b0a56-e8d8-53cb-8e1e-a42738680c22\enqueue_receipt.json
D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\reruns\d03f6148-7cb4-5397-912f-2c468de539b4\enqueue_receipt.json
D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\reruns\08be2fce-26ca-5297-b139-d9701273af8f\enqueue_receipt.json
D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v3\0bfb3d97-2953-52d6-b89b-dcd1eb2665c2\enqueue_receipt.json
D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v3\23bc80e0-71fb-5f0d-9bad-3538d400bf0a\enqueue_receipt.json
D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v3\17e78f20-2bae-5473-b54b-5e405cf53239\enqueue_receipt.json
```

## Verification

Implementation verification from the clean task worktree:

```text
python -m py_compile tools/strategy_farm/q09_live_news_backfill.py \
  tools/strategy_farm/tests/test_q09_live_news_diagnostic.py
PASS

python -m pytest tools/strategy_farm/tests/test_q09_live_news_diagnostic.py -q
16 passed

python -m pytest \
  tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py \
  tools/strategy_farm/tests/test_phase_runner_process_lineage.py::test_dispatch_spawn_refusal_records_reason_and_event \
  tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py::TerminalWorkerAtomicClaimTests::test_spawn_refusal_persists_reason_and_event_before_releasing_claim -q
11 passed

git diff --check
PASS
```

The regressions cover:

- a generation-3 predecessor with no evidence summary advancing via the
  authenticated refusal event;
- an original predecessor with no `last_launch_fault_terminal` advancing via
  `spawn_refusal.terminal`;
- preservation of a staggered `launch_not_before_utc`; and
- rejection of an incident-looking payload timestamp when the durable event is
  absent.

Post-enqueue verification found all seven successors `pending`, unclaimed,
plan/receipt hashes matched, every plan had 40 cells, fixed-risk fields were
exact, and the authenticated proof kind was present. At the snapshot there was
one active diagnostic row (`57f403c0...`, QM5_11421 on T1), below the cap of
five. The seven successors had zero rows in `q09_news_tests`, as required for
diagnostic non-admission.

The T1-T5 worker processes were created after the reviewed EX5 spawn-gate
rework, so none was carrying the pre-fix in-memory module that caused the
00:53 refusal incident.

## Review boundary

This is builder evidence. The router task must remain in `REVIEW` until Claude
independently reviews commit `fc9110780`, the proof contract, receipt bindings,
and staggered queue state. The pending diagnostics do not constitute pipeline
evidence, economic acceptance, Q09 admission, deployment approval, or live-use
authorization.

## Append-only T4 chronology correction

Router task `77203161-f3eb-4381-bd01-1a572132f29a` requested a correction
claiming that the T4 worker with PID 19976 started before commit `590362fa0` and
therefore retained the pre-fix staged-EX5 basename behavior. The retained
evidence contradicts that proposed correction, so it is not adopted:

- commit `590362fa0900ed878d116a073be05e0b20f2e046` has author and committer
  time `2026-08-07T02:16:50+02:00`;
- the routed task records PID 19976 as created at
  `2026-08-07T02:20:27+02:00`, 3 minutes 37 seconds after that commit;
- `D:\QM\strategy_farm\logs\terminal_worker_T4.log` records
  `worker_start` for PID 19976 and later its claim of work item
  `d03f6148-7cb4-5397-912f-2c468de539b4`;
- that row's database payload binds `claimed_by_worker_pid=19976`,
  `claimed_at_iso=2026-08-07T07:52:14+00:00`, and terminal `T4`; and
- the row log at
  `D:\QM\strategy_farm\logs\work_item_d03f6148-7cb4-5397-912f-2c468de539b4.log`
  shows the 07:52:24 UTC runner command used expert
  `QM\QM5_12567_cum-rsi2-commodity`, the full basename produced by the
  `590362fa0` fallback rather than the pre-fix numeric-only expert name.

The retained traceback instead records a
`qm_news_calendar_bundle_id` effective-input mismatch followed by a collision
with the existing `attempt_0001` failure snapshot. It does not reproduce the
pre-fix staged-EX5 basename refusal. The preceding statement that T4 was not
carrying that pre-fix in-memory module therefore remains supported for this
worker. This chronology is diagnostic evidence only and creates no Q09 or
pipeline verdict.
