# QM5_10116 FX stale-resolver recovery — governed compile enqueued

Date: 2026-09-09
Branch: `agents/board-advisor`
EA: `QM5_10116_tv-multi-ma-exit`
Farm task: `9c554c55-bf38-4b06-b24f-e5c3c44c8400`
Outcome: **STALE-RESOLVER CAUSE ISOLATED; FRAMEWORK-CONFORMANCE REPAIR
APPLIED; PACER AUDIT PASS; GOVERNED COMPILE ENQUEUED**

## Diversity selection and collision control

The only nominal rates build in the pending build inventory,
`QM5_1457_as-predict-bonds`, is not build-eligible: its approved card explicitly
records `r3_data_available: FAIL` because the Treasury, cash and commodity
inputs do not have approved DWX series. The other uncompiled legacy placeholder,
`QM5_1459_as-lumber-gold`, likewise has no binary or setfiles and lacks its
required lumber carrier. Viable forex backlog entries are already compiled and
have economic Q02/Q04 rows. Priority 1 therefore had no eligible non-duplicate
candidate.

QM5_10116 was the highest-value unclaimed priority-2 recovery found after
excluding active farm claims for QM5_10069 and QM5_36007. Its fixed H1
MA50/MA100 trend entry and MA9 exit already have Q02 PASS results on original
slots, while newly allocated FX slots fail before any bars or trades.

An atomic collision recheck found no open `infra_repair` task and no active or
claimed work item for QM5_10116. It then inserted the exclusive
`infra_repair / active` task above, assigned to
`codex:agents/board-advisor`. The pre-claim online SQLite backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10116_stale_resolver_claim_20260909T055434Z.sqlite`

Backup SHA-256:
`fe19ec74b678e089e5b473fec46c52dfe51535a62318c23c4fa774624724aa4c`.

## Bound failure and root cause

The selected immutable Q02 row is
`b31bd6bc-b399-46ae-88c4-9fcc609a31c2` (`USDCAD.DWX / H1`,
`done / INFRA_FAIL`). Its canonical summary is:

`D:\QM\reports\work_items\b31bd6bc-b399-46ae-88c4-9fcc609a31c2\QM5_10116\20260908_115540\summary.json`

Summary SHA-256:
`2bbba505d1182c3f1fef098f13476e2429927dfd5bb4d97d0d0d2caa7f2edd53`.

The summary binds the old EX5 SHA-256
`cf4c53f382fb3c8bc6227bac02b5b221c04ab82ade01b40cf1ab5d97ea2ad694`
and its 2026-06-21 timestamp. The retained T7 tester-agent journal supplies the
decisive line:

`EA_MAGIC_NOT_REGISTERED: ea_id=10116 slot=9 magic=101160009`

The USDCAD setfile independently binds `qm_magic_slot_offset=9`,
`RISK_FIXED=1000`, and `RISK_PERCENT=0`. The active registry added slots 4-12
on 2026-08-23; the current generated resolver contains all thirteen active
QM5_10116 mappings, including slot 9 / magic 101160009. The same old binary
also produced ONINIT failures on added AUDUSD, NZDUSD and USDCAD rows while
the original EURUSD, GBPUSD, NDX and XAUUSD slots have Q02 PASS evidence.
This is stale compiled-resolver infrastructure, not missing history or an
economic zero-trade result.

## Repair and exact compile authority

The EA source retains the approved strategy arithmetic. The repair only:

- rebuilds the unchanged strategy against the current generated resolver;
- restores first-statement framework MAE sampling;
- keeps position management and protective exits active through news windows;
- zero-initializes `QM_EntryRequest` before strategy population.

The resulting MQ5 SHA-256 is
`2f0922a9a70cbaf2f90d9da85cb77c4ee6abbdcb21793ab84244a85aac06b2a5`.
The current resolver SHA-256 is
`4709728b029a22a364f49b9980e0bf8d851717a5aa466b6c8fdbc2a410a78ab8`.

`compile_work_items.py` recognizes exactly one authority/task/EA pair:

`router_q02_infra_repair:9c554c55-bf38-4b06-b24f-e5c3c44c8400`

for `QM5_10116_tv-multi-ma-exit` only. Focused regression tests prove the
wrong-label and wrong-task cases remain closed and that the exact authority can
append one compile recovery despite the historical binary/work rows:

`python -m pytest tools/strategy_farm/tests/test_compile_work_items.py -k "10069 or 10116" -q`

Result: `4 passed, 76 deselected`.

## Binding PACER guard and handoff

Immediately before compile enqueue, the binding audit ran against the absolute
source path:

`python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_10116_tv-multi-ma-exit/QM5_10116_tv-multi-ma-exit.mq5"`

Result: `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.

The pre-enqueue CPU sample was 95.90%, 93.38%, 94.54%, 88.79%, and 89.08%
(average 92.34%, peak 95.90%) with six `terminal64` processes, below the 97%
ceiling. The governed enqueue accepted exactly one utility row:

- COMPILE_EA work item: `86375b14-6d96-4111-a05d-a4af0fa71813`;
- status: `pending`;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- source hash: `2f0922a9a70cbaf2f90d9da85cb77c4ee6abbdcb21793ab84244a85aac06b2a5`;
- 13 registered symbols, H1, fixed-risk contract;
- no gate verdict.

The compile remains in the normal resident-worker path. A Q02 successor must
not be appended until this row reaches `COMPILE_OK` with a changed EX5 hash and
strict build-check PASS. The failed rows remain immutable evidence.

## Safety boundary

No T_Live file or process, AutoTrading setting, live setfile, deploy manifest,
portfolio gate, portfolio KPI artifact or certification verdict was changed.
No manual tester or ad-hoc MetaEditor compile was launched.
