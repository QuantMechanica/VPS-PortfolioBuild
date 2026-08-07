# Q09 calendar identity and failure-snapshot poison loop — root cause 2026-08-07

Task: `0a6f77cb-9806-45a0-93d5-f171706a7bc5`

Status: FIX IMPLEMENTED / READY FOR CLAUDE REVIEW

Mode: code, tests, read-only farm/report inspection, and remediation recipe
only. No database mutation, enqueue, terminal action, T_Live write,
AutoTrading change, or Q09 verdict was performed.

Implementation commit: `c298264d6`

## Verdict

The observed three-step poison loop is real, but the proposed calendar-pin
cause is not:

1. **Plan versus FILE_COMMON: MATCH.** Both suspect plans pin bundle
   `q09cal-20150101-20260809-0bb19b5bb9790b76`; the source manifest and
   deployed FILE_COMMON CSV match the plan hashes byte-for-byte. Neither side
   of that proposed mismatch is wrong.
2. **Actual first failure on `d03f6148-7cb4-5397-912f-2c468de539b4`:
   effective-input interface
   missing.** Both authenticated MT5 reports omit all three sealed calendar
   identity inputs. The runner correctly rejects the absent
   `qm_news_calendar_bundle_id`; it did not observe a different deployed
   bundle ID.
3. **Failure recorder defect 1: confirmed MAX_PATH amplification.** Mirroring
   the already-deep run tree under `failure_attempts/attempt_0001.tmp` reaches
   WinError 206 while creating `pre_run_logger_archive`.
4. **Failure recorder defect 2: confirmed allocator collision.** The failed
   copy leaves `attempt_0001.tmp`; the allocator ignored `.tmp`, chose
   occurrence 1 again, and every later claim failed before a sidecar could be
   written.

The fix flattens new immutable attempt snapshots to deterministic short names
while retaining and authenticating every original source-relative path. It
also treats both final `attempt_NNNN` and orphaned `attempt_NNNN.tmp` entries
as consumed occurrence numbers. Existing mirrored v2 sidecars remain
readable; partial directories are preserved rather than deleted.

## Calendar identity — both suspect rows

The authoritative source manifest is
`D:\QM\data\news_calendar\q09_bundles\q09cal-20150101-20260809-0bb19b5bb9790b76\manifest.json`:

| Field | Value |
|---|---|
| bundle ID | `q09cal-20150101-20260809-0bb19b5bb9790b76` |
| bundle identity SHA-256 | `0bb19b5bb9790b76dfc53d87851dff9c7296206aefef9964957efa69aa275bc9` |
| manifest SHA-256 | `b204d1ab9fe40fe32afc254ae4284ed6c1df112829df07483912e5ed54527461` |
| events content SHA-256 | `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1` |
| coverage | `2015-01-01T00:00:00Z` through `2026-08-09T02:00:00Z` |
| common relative path | `QM/q09_news/q09cal-20150101-20260809-0bb19b5bb9790b76/events.csv` |

The source events CSV and deployed copy at
`C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q09_news\q09cal-20150101-20260809-0bb19b5bb9790b76\events.csv`
both hash to
`86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1`.
No calendar refresh or stale-ceiling change is indicated; the hard maximum
remains 336 hours.

| Work item | EA | Plan file SHA-256 | Plan bundle/content | Bound EX5 SHA-256 | Finding |
|---|---|---|---|---|---|
| `d03f6148-7cb4-5397-912f-2c468de539b4` | `QM5_12567` | `c51b4e240f4a291d6f8573605043ecad8be1d7244886f2d3edd542b4a9cbce90` | `q09cal-20150101-20260809-0bb19b5bb9790b76` / `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1` | `5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` | plan, source, and Common match; executed binary report omits bundle inputs |
| `08be2fce-26ca-5297-b139-d9701273af8f` | `QM5_1556` | `18f86c767503412caee62e61c6330246097071f76759660da41899e83555894a` | `q09cal-20150101-20260809-0bb19b5bb9790b76` / `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1` | `9371a8a03008e2fd8a3fc9dbec75586f7ade71ea857e9ff8f9c3fd0fd95cb3cb` | plan, source, and Common match; row has not executed, so an effective-input failure is not observed |

The complete plans are at:

- `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\reruns\d03f6148-7cb4-5397-912f-2c468de539b4\q09_plan\run_plan.json`;
- `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\reruns\08be2fce-26ca-5297-b139-d9701273af8f\q09_plan\run_plan.json`.

Their first cell setfiles hash to `5a87aa8562946fecb324ef081d6fc013e00b5e2d40e05431c1003c71d827fd58`
and `9d9da31a69e60c29233fada61d3d21993ac62e93123fa22b13656cad263ae0b0`
respectively. Both explicitly contain the bundle ID, content hash, Common
path, `RISK_FIXED=1000`, and `RISK_PERCENT=0`.

## Effective-input incompatibility

Work-item log
`D:\QM\strategy_farm\logs\work_item_d03f6148-7cb4-5397-912f-2c468de539b4.log`
(SHA-256
`031da4345c90dc535f792f854e1ad627295c1662921d7fbb1d7541f3ec3a3fe8`)
records the same sequence on two claims:

- runner rejection: `MT5 report effective input qm_news_calendar_bundle_id mismatch`;
- snapshot copy failure: WinError 206 at
  `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\reruns\d03f6148-7cb4-5397-912f-2c468de539b4\q09_plan\cells\control_off__m0__c0__s42\failure_attempts\attempt_0001.tmp\runs\selection\QM5_12567\20260807_072217\raw\run_01\pre_run_logger_archive`;
  and
- next-claim rejection: `cell failure attempt snapshot already exists`.

The underlying reports are:

- `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\reruns\d03f6148-7cb4-5397-912f-2c468de539b4\q09_plan\cells\control_off__m0__c0__s42\runs\selection\QM5_12567\20260807_072217\raw\run_01\report.htm`, SHA-256
  `797829b3277aaeae22db8459f1b4113f04765aa833c4ca4a2aa05bdab267557f`;
- `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\reruns\d03f6148-7cb4-5397-912f-2c468de539b4\q09_plan\cells\control_off__m0__c0__s42\runs\selection\QM5_12567\20260807_075226\raw\run_01\report.htm`, SHA-256
  `858db75c890bbc7380dd8b6f4dcde25774e7ce7eeceaa8dad37efc6867db947e`.

Both report `RISK_FIXED=1000`, `RISK_PERCENT=0`, `qm_news_temporal=0`,
`qm_news_compliance=0`, and `qm_news_stale_max_hours=336`. Both omit
`qm_news_calendar_bundle_id`, `qm_news_calendar_expected_sha256`, and
`qm_news_calendar_common_relative_path` entirely. Therefore the observed
value is **missing**, not a different bundle ID.

The sealed-input interface was introduced by commit `f0102fbcf` on
2026-08-03. The two plans deliberately bind older deployed live binaries:

| EA | Deployed binary | SHA-256 | File timestamp UTC | Current rebuilt EX5 SHA-256 |
|---|---|---|---|---|
| `QM5_12567` | `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\QM5_12567_cum-rsi2-commodity.ex5` | `5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` | `2026-07-31T17:12:52Z` | `8d901924fe7dd2cd00c61dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` |
| `QM5_1556` | `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\QM5_1556_aa-zak-mom12.ex5` | `9371a8a03008e2fd8a3fc9dbec75586f7ade71ea857e9ff8f9c3fd0fd95cb3cb` | `2026-07-13T04:47:49Z` | `0962ca65776fd05e76f7ab5f27e838a72cb79a7359a029e2f47ef61a9ae7c88e` |

For `d03f6148-7cb4-5397-912f-2c468de539b4`, the report is direct proof that
the deployed binary does not expose the sealed identity inputs. For
`08be2fce-26ca-5297-b139-d9701273af8f`, the matching old binary-vintage
condition makes the row unsafe to claim, but no report exists;
its effective-input outcome is therefore **NOT ESTABLISHED**, not fabricated.
A plan rebind alone cannot add inputs to an old EX5.

## Five refresh successors

All five requested refresh-v3/v4 plans pin the same source/Common bundle and
content hashes shown above. Three have durable reports that echo all three
effective inputs exactly; two have no report yet, so only their sealed
plan/source/Common equality is established.

| Work item | EA/symbol | Plan file SHA-256 | Report verification |
|---|---|---|---|
| `ace3f877-e9b4-574f-abae-c90eb983aab0` | `QM5_10440 / NDX.DWX` | `7dfaae8b5ce302ec24a15ed28d17fc0c88bd416ac4206200d6ca47c131f34734` | `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v4\ace3f877-e9b4-574f-abae-c90eb983aab0\q09_plan\cells\control_off__m0__c0__s42\runs\selection\QM5_10440\20260807_085330\raw\run_01\report.htm`, SHA-256 `62d56c02b3fc6f2d1130e25c03dcc232e9d90e1f50d6ca3f386c52f1386af0b1`, exact three-field match |
| `773b0a56-e8d8-53cb-8e1e-a42738680c22` | `QM5_10939 / GBPUSD.DWX` | `f81bbfb4fd33b05aa27ae3d5e2489e82fa41dcce909bb4ecf68771a0aeed8056` | sample `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v4\773b0a56-e8d8-53cb-8e1e-a42738680c22\q09_plan\cells\control_off__m0__c0__s17\runs\full\QM5_10939\20260807_042525\raw\run_01\report.htm`, SHA-256 `9d60a0165677754795e7fb8eb832b46e4716cc3d121059141cdfa4a4a7b7087b`, exact three-field match |
| `0bfb3d97-2953-52d6-b89b-dcd1eb2665c2` | `QM5_10403 / XAUUSD.DWX` | `eb2dcd9d9274a5cde904e48d745a4d742ec8e5958d3b5c0b22c00384b2d66eac` | no report; plan/source/Common match only |
| `23bc80e0-71fb-5f0d-9bad-3538d400bf0a` | `QM5_10513 / XAUUSD.DWX` | `9b6eb93669b0762339af8bfd686034f4a2673cc8a2c473fe35b06c5dbe68e6b2` | sample `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v3\23bc80e0-71fb-5f0d-9bad-3538d400bf0a\q09_plan\cells\control_off__m0__c0__s17\runs\full\QM5_10513\20260807_133620\raw\run_01\report.htm`, SHA-256 `f8d9a8db8f6abd2ff4c54c2f1ea998a168b39603939b8fea1cc65c0ef3484ddf`, exact three-field match |
| `17e78f20-2bae-5473-b54b-5e405cf53239` | `QM5_12989 / XAUUSD.DWX` | `dce4f5583e2ec29a3a429bf576cd66c860bdd85f12e2f81a73a7669ef7be0d34` | no report; plan/source/Common match only |

The existing logs for the first four contain zero calendar-bundle mismatch
occurrences; the fifth had no work-item log at the inspection snapshot. This
finding is limited to calendar identity. Several of these rows independently
hit the same MAX_PATH/orphan-snapshot defects, which the code fix addresses.

## Code correction

Commit `c298264d6` changes only
`tools/strategy_farm/q09_news_runner.py` and
`tools/strategy_farm/tests/test_q09_news_runner_v2.py`:

- new snapshots use `FLAT_INDEXED_SHA256_V1` names under the immutable
  `attempt_NNNN` root;
- the manifest retains `source_relative_path`, exact byte size, SHA-256, and
  deterministic index/path authentication;
- the reader continues to authenticate pre-fix mirrored v2 snapshots;
- `attempt_NNNN.tmp` participates in occurrence allocation, so a partial
  attempt is never overwritten or selected again; and
- no cleanup or mutation of existing production partial snapshots is done.

Focused verification:

```text
python -m py_compile tools/strategy_farm/q09_news_runner.py \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py
PASS

python -m pytest tools/strategy_farm/tests/test_q09_news_runner_v2.py -q
27 passed

python -m pytest tools/strategy_farm/tests/test_q09_live_news_diagnostic.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py -q
26 passed
```

The new regressions construct a source path whose mirrored attempt path is
over 260 characters and prove a short authenticated flat snapshot, then leave
`attempt_0001.tmp` and prove the next immutable sidecar/snapshot uses
occurrence 2 while preserving the orphan.

## Governed remediation recipe — not executed

Do **not** rebind or requeue `d03f6148-7cb4-5397-912f-2c468de539b4` or
`08be2fce-26ca-5297-b139-d9701273af8f` in place. Their sealed plans bind
deployed live EX5 vintages that cannot satisfy the report identity contract,
and the two rows must remain append-only evidence.

The already-existing fresh-build sibling rows are the safe lineage anchors:

| EA | Fresh-build predecessor | EX5 SHA-256 | Plan file SHA-256 | Authenticated stop |
|---|---|---|---|---|
| `QM5_12567` | `4f80a8cf-2cf9-53dd-b59c-414674f24f16` | `8d901924fe7dd2cd00c61dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` | `6e23a1e95504558ca15ce7fd3a22a80727c8bd8f93257d3109466c4eb17c8a27` | `worker_staged_ex5_destination_path_mismatch`, T1 |
| `QM5_1556` | `a122a2e9-8c21-5dc0-97d3-96567bf3825e` | `0962ca65776fd05e76f7ab5f27e838a72cb79a7359a029e2f47ef61a9ae7c88e` | `6c6dd85f53d48fe5f8c8d758b4c422f5fec92447c335573421faecd366088c03` | `worker_staged_ex5_destination_path_mismatch`, T1 |

After Claude accepts and deploys `c298264d6`, and only under a fresh routed
execution task, use the existing append-only generation-rerun command. It
rebuilds a fresh plan from the predecessor's authenticated current bundle and
invokes the existing Q09 binder internally:

```powershell
python tools/strategy_farm/q09_live_news_backfill.py rerun `
  --task-id <CLAUDE_REMEDIATION_TASK_ID> `
  --predecessor-id 4f80a8cf-2cf9-53dd-b59c-414674f24f16 `
  --avoid-terminal T1

python tools/strategy_farm/q09_live_news_backfill.py rerun `
  --task-id <CLAUDE_REMEDIATION_TASK_ID> `
  --predecessor-id a122a2e9-8c21-5dc0-97d3-96567bf3825e `
  --avoid-terminal T1
```

Before allowing either successor to claim, Claude must verify its new plan
binds the exact bundle/manifest/content values above, the fresh EX5 hash in
the table, `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and
`qm_news_stale_max_hours <= 336`; the source and FILE_COMMON CSVs must still
hash-match. Leave execution to the ordinary factory. Do not start a terminal,
interrupt T1–T10 work, touch T_Live, or infer a Q09/pipeline verdict from this
repair.

This recipe deliberately follows the fresh-build siblings rather than the two
poisoned old-binary siblings. That is the existing governed path which both
preserves append-only ancestry and supplies the tester calendar-input
interface; claiming that a calendar-only rebind repairs an old EX5 would be
false.
