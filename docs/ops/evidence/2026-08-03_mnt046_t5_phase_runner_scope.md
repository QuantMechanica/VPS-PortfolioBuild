# MNT-046 — T5 phase-runner scope repair and victim census

Date: 2026-08-03
Router task: `a090a635-f36e-454a-b83a-a35d72076d17`
Code disposition: **BRANCH-ONLY / REVIEW REQUIRED**
Code branch: `codex/mnt046-t5-20260803`
Code commit: `068e811bcd1ea76bc3b72d41926dd987202f07db`

## Outcome

The stale T5 carve-out is repaired on the review branch, not in the canonical
checkout. Phase-runner spawn eligibility and process-reap ownership now derive
from the same live worker-policy source, `disabled_terminals.txt`. With the live
policy file empty, the derived cohort is T1–T10. If T5 is later placed in that
file, both spawn and reap scope remove T5 without another source edit.

A generic spawn refusal now atomically writes all of the following before it
releases the claim:

- `work_items.status=failed`, `verdict=INFRA_FAIL`, and `claimed_by=NULL`;
- `payload_json.verdict_reason` plus a structured `spawn_refusal` record; and
- an `events` row named `runner_spawn_refused` containing phase, terminal,
  reason, and scope-block status.

Both dispatcher-owned and long-running terminal-worker paths use this contract.
No work item was requeued or otherwise mutated during this task.

## Branch-only implementation

Changed runtime behavior:

- `tools/strategy_farm/farmctl.py`
  - removes the literal T5 exclusion;
  - derives `worker_policy_terminals()` and `phase_runner_terminals()` from
    `MT5_TERMINALS - disabled_mt5_terminals()`;
  - uses that cohort for active terminal selection and phase-runner admission;
  - adds the transactional spawn-refusal evidence writer.
- `tools/strategy_farm/factory_process_scope.ps1`
  - reads the same live disabled-terminal policy;
  - builds the terminal matcher from the resulting cohort;
  - classifies T5 as `FACTORY_OWNED` under the current zero-disabled policy and
    `REVIEW_REQUIRED` when T5 is disabled.
- `tools/strategy_farm/terminal_worker.py`
  - routes its generic refusal path through the same evidence writer.

The two runtime-decision-bound files, `farmctl.py` and
`factory_process_scope.ps1`, exist only in branch commit `068e811bc`. They were
not committed or merged into `C:\QM\repo`; coordinated Claude review/merge and
OWNER source rebinding remain required.

## Verification

- Python compile check for both runtime modules and the three modified Python
  test modules: PASS.
- Five focused policy/refusal/cascade tests: **5 passed** in 45.98 seconds.
- Neighboring Python regression set: **69 passed, 2 deselected** in 76.32
  seconds. The two deselections are assertions outside the changed behavior:
  environment-dependent Q09 input discovery and a Factory_ON source-string
  ordering assertion.
- PowerShell process-scope suite: **PASS, 279 assertions**.
- `git diff --check`: PASS.
- Search for the removed `PHASE_RUNNER_TERMINALS`, the stale
  `T(?:[1-4]|[6-9]|10)` selector, and the deliberate T5-exclusion test text:
  no matches in the changed runtime/test scope.
- Live policy evidence at census time:
  `D:\QM\strategy_farm\state\disabled_terminals.txt` is zero bytes with
  SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

No EA source or setfile changed. A full EA guardrail rescan attempted during
this task exceeded the 124-second command limit without returning a verdict;
therefore no PASS is claimed from that attempt. The MNT-046 diff itself cannot
change `qm_news_stale_max_hours`, `RISK_FIXED`, or `RISK_PERCENT` because it
contains no EA/setfile path.

## Bound-source behavior while the factory is running

`factory_runtime_activation.py` binds both changed runtime files in
`SOURCE_BINDING_PATHS`. Production call-site search found only:

1. `Factory_ON.ps1:Get-CanonicalRuntimeActivationAuthorization`, called in the
   Factory_ON preflight; and
2. `maintenance_control.py:release_restart_holds(..., apply=True)`, itself
   invoked as part of the coordinated Factory_ON restart sequence.

No watchdog or continuous loop calls the bound-blob validator after release.
This establishes the following deployment behavior:

- merging the branch does **not** stop or corrupt the already-running factory;
- running Python workers retain their already-imported `farmctl` module, so a
  merge alone also does **not** activate the T5 repair;
- the next Factory_ON/restart attempt will correctly fail closed against stale
  source bindings until a fresh OWNER authorization binds the merged blobs;
- activation therefore requires coordinated merge, fresh source binding, and
  a governed factory restart. Until then, no recovery row from this census
  should be released.

This conclusion is based on production call-site/source inspection; no factory
restart or process mutation was performed to test it.

## Original 54-victim census

Census time: `2026-08-03T10:57:39.729Z`
Database: read-only URI for
`D:\QM\strategy_farm\state\farm_state.sqlite`
Log: `D:\QM\strategy_farm\logs\terminal_worker_T5.log`

The accepted incident boundary is the first 54 exact log entries with reason
`phase runner terminal outside MNT-046 scope: T5`, ending at log line 2685 and
work item `4de120bb-284e-45f0-b9f3-53521e72ac5a`. There are two later entries;
they are reported separately below and are not silently folded into this
fixed-size census.

Counts:

- by Q phase: Q04 35, Q05 8, Q06 8, Q07 2, Q08 1;
- original victim rows: 53 `failed/INFRA_FAIL`, 1 `done/INFRA_FAIL`;
- mapped to the latest **exact work identity**: 50 `failed/INFRA_FAIL`, 2
  `done/FAIL`, 1 `done/INFRA_FAIL`, 1 `pending`;
- extant victim evidence files: 1/54; extant victim report roots: 2/54;
- active poison-pill quarantine rows at census time: **0 globally**;
- recovery disposition: 37 append-only-ready, 1 sanctioned same-row transient
  retry, 10 HOLD, 1 later real infrastructure failure, 4 separate successors,
  and 1 older duplicate superseded by a later T5 victim.

“Exact work identity” means `(ea_id, Q phase, symbol, setfile_path)`. Sibling
ablation setfiles are intentionally distinct; a verdict for one does not
silently settle another. “Same” in the latest column means the victim row is
still the latest row for that exact identity.

| # | Victim work item (full ID) | Exact pair | Victim state | Latest exact-identity state | Recovery disposition |
|---:|---|---|---|---|---|
| 1 | `780f4548-5480-49b3-9e42-88d760d56750` | QM5_11235 / Q04 / GBPUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 2 | `4c637635-cff3-414b-8d61-fc364f7e30bd` | QM5_1443 / Q04 / EURUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 3 | `6c937014-e8ec-4d72-876c-c96c2b12d270` | QM5_20144 / Q04 / GBPUSD | failed/INFRA_FAIL | `7f31b0e4-de1c-401b-9f3c-b4f385af9755` — done/FAIL | NO_REQUEUE_SEPARATE_SUCCESSOR |
| 4 | `9911f715-1168-475a-97ca-8d7199a49d39` | QM5_10074 / Q04 / GBPUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 5 | `fa86224d-5b03-4f4b-9fe9-220c9fc48e72` | QM5_11015 / Q04 / USDJPY | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 6 | `40af0543-1fd0-4dae-80e1-531cd49df2a6` | QM5_1567 / Q06 / GBPJPY | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 7 | `4dd0e95f-5338-4b69-b2f2-169411cc6da4` | QM5_1567 / Q06 / USDJPY | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 8 | `1db27930-da69-4ab2-9d61-719a187fa9e8` | QM5_1551 / Q05 / USDJPY | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 9 | `fa704429-cd42-4704-886f-126068029513` | QM5_1567 / Q05 / GBPJPY | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 10 | `8f5520af-1b9e-4dc7-870d-1cf5bf823812` | QM5_1567 / Q05 / USDJPY | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 11 | `4b7af90f-5c1e-48d7-8473-6e10183a88aa` | QM5_11470 / Q05 / USDCAD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 12 | `b95fab33-0bed-49fb-b8a5-16e63ec8a7ed` | QM5_11470 / Q04 / AUDUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 13 | `78bd3661-f04a-4bef-9e81-52770ffc4234` | QM5_10083 / Q04 / GBPUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 14 | `f4bacf19-6182-4aa7-a208-7dcbc61c40c4` | QM5_10602 / Q04 / NZDUSD | failed/INFRA_FAIL | `d587050b-8ab3-4850-867f-17ce70df7d37` — failed/INFRA_FAIL | SUPERSEDED_BY_LATER_T5_VICTIM |
| 15 | `5b5bcec5-ea54-4abc-9f7b-533a5c3d1af3` | QM5_10203 / Q04 / GBPUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 16 | `547b0a5e-117b-4abe-9dfb-a515a111c8d3` | QM5_10343 / Q04 / NDX / ablation_01 | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 17 | `59ac74ae-13c4-4663-af44-8a335ef87f61` | QM5_9584 / Q04 / EURUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 18 | `199b5a7a-c330-44ad-9bd5-46ff460f7f59` | QM5_10903 / Q04 / GBPUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 19 | `6d2cedf0-9952-4898-a0b0-2866a54bb472` | QM5_12108 / Q04 / EURUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 20 | `c7ba8eef-8c49-45d0-a43e-599ba6d28eaf` | QM5_1052 / Q04 / EURUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 21 | `2b98118e-7818-483d-b20c-28015f29e04f` | QM5_12796 / Q04 / NDX | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_NO_EXACT_PREDECESSOR |
| 22 | `2086d1d7-02ae-4240-b6b1-18ecc851e124` | QM5_20188 / Q04 / NDX | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_NO_EXACT_PREDECESSOR |
| 23 | `7acf54a8-4f5f-4159-82cc-0ea34f535933` | QM5_9997 / Q04 / NDX | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_NO_EXACT_PREDECESSOR |
| 24 | `ee5f7a63-b5c7-4e2f-bd04-269b31c3f527` | QM5_10343 / Q04 / NDX / default | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_NO_EXACT_PREDECESSOR |
| 25 | `f1efc262-ffeb-4fdc-ac6a-951e01a4c4a9` | QM5_10614 / Q04 / NZDUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_NO_EXACT_PREDECESSOR |
| 26 | `d587050b-8ab3-4850-867f-17ce70df7d37` | QM5_10602 / Q04 / NZDUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_NO_EXACT_PREDECESSOR |
| 27 | `71094103-0d7e-414c-b6a5-2f9fb30f15f1` | QM5_10228 / Q04 / NDX / default | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_NO_EXACT_PREDECESSOR |
| 28 | `a5b4f706-ebad-4c25-aec8-ef0dd39b35eb` | QM5_10127 / Q06 / NDX | done/INFRA_FAIL | same — done/INFRA_FAIL | NO_MNT_REQUEUE_REAL_INFRA |
| 29 | `9ed183b2-a3c9-4177-8506-cf80d9237c53` | QM5_10228 / Q04 / NDX / ablation_02 | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 30 | `6a4b750f-3289-42c3-901b-0e4691b4bcda` | QM5_11521 / Q05 / GBPJPY | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 31 | `421e435f-b79b-42f1-9350-bc9303dcd956` | QM5_10582 / Q08 / XAUUSD | failed/INFRA_FAIL | `e196d30b-e4d4-40b6-961a-4e5391eae918` — pending | NO_REQUEUE_SEPARATE_SUCCESSOR |
| 32 | `d5f7197c-f481-4983-82f7-9f3b8dfc8643` | QM5_10037 / Q04 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 33 | `14164d76-7aff-4992-ba8d-05162160b6d4` | QM5_10792 / Q04 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 34 | `f3a5c40c-6469-4a55-b15e-eadfdda152c7` | QM5_12357 / Q06 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 35 | `76e26ada-4bb5-457e-8233-25feaa209982` | QM5_13144 / Q06 / XTI-XNG logical basket | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 36 | `27c7ea05-d36a-4950-b516-2f7c6a0f7353` | QM5_10809 / Q04 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 37 | `e43aa189-b2fb-46f9-99cd-f4256ad863e1` | QM5_1910 / Q04 / EURUSD | failed/INFRA_FAIL | `e1e2032c-8bfa-4de3-99f8-dbad2a01eb84` — failed/INFRA_FAIL (`ACTIVE_TIMEOUT`) | NO_REQUEUE_SEPARATE_SUCCESSOR |
| 38 | `ae9b8858-9f9d-4960-be2c-16a663d297c5` | QM5_12535 / Q05 / GDAXI | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 39 | `bb754f4d-10e0-4a21-b917-ec7826178f29` | QM5_11451 / Q04 / USDCAD | failed/INFRA_FAIL | `0e8b8a2b-bad2-499b-8d6e-a7cbdc0efa89` — done/FAIL | NO_REQUEUE_SEPARATE_SUCCESSOR |
| 40 | `a8b4cffa-aef8-464a-a18d-58e04f2fc888` | QM5_12567 / Q06 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_PREDECESSOR_EVIDENCE_MISSING |
| 41 | `b3e51ab6-2207-4401-adc7-9b2aaaa31ae6` | QM5_10185 / Q06 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 42 | `93d0ae3b-502f-48bd-bb53-db0693147153` | QM5_10286 / Q05 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 43 | `6e1598dd-9344-40f6-8ec4-50c508ec1557` | QM5_12935 / Q07 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 44 | `7c10c064-413b-4e8b-ac51-b9b0777d894e` | QM5_10175 / Q04 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 45 | `deaa0e2d-9916-4f20-9fd9-11b86750ded8` | QM5_20204 / Q04 / XNGUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_NO_EXACT_PREDECESSOR |
| 46 | `700edaea-66b7-4596-8398-c6a0af3b7ec8` | QM5_12474 / Q04 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | HOLD_NO_EXACT_PREDECESSOR |
| 47 | `9ba8eb3c-2a25-4f32-86f6-e63eff3bcdca` | QM5_10290 / Q04 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 48 | `d3ae6171-bdb7-4841-bb0c-dab2c3a5bdbc` | QM5_11875 / Q04 / EURUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 49 | `c38a757e-5763-49a3-9680-ae920a3b3e3f` | QM5_10090 / Q05 / EURUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 50 | `4dc47ec1-66f1-4761-bad0-ae30fbf293c1` | QM5_11056 / Q04 / EURUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 51 | `95e5af49-483c-4ebc-9da3-6f93206278a3` | QM5_12708 / Q04 / XAUUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 52 | `10643bce-86f3-4da3-bc1a-f4c9bb590661` | QM5_11015 / Q06 / EURUSD | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 53 | `0e1bd70a-f68b-4eec-9b08-512f3c65c10f` | QM5_11166 / Q04 / XAUUSD / ablation_00 | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_APPEND_ONLY |
| 54 | `4de120bb-284e-45f0-b9f3-53521e72ac5a` | QM5_13013 / Q07 / NDX | failed/INFRA_FAIL | same — failed/INFRA_FAIL | READY_SAME_ROW_TRANSIENT_RETRY |

Victim 28 is not a T5-scope recovery candidate. Its row was subsequently
executed and now carries real retained evidence with reason
`invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,HISTORY_CONTEXT_INVALID,INCOMPLETE_RUNS,M0_1970_PERIOD,NO_HISTORY,RUN_STATUS_INVALID`.
Blindly relabeling or rerunning it as MNT-046 would erase that distinction.

## Ready append-only cohort

At census time, all 37 rows below had an exact `promoted_from_work_item`, an
eligible predecessor verdict for the target Q phase, matching symbol/setfile,
and an extant predecessor evidence file. These facts must be revalidated at
release time.

| Q phase | Failed target | Exact predecessor |
|---|---|---|
| Q04 | `780f4548-5480-49b3-9e42-88d760d56750` | `99ddea4f-2888-46ef-b426-8e4097bcad52` |
| Q04 | `4c637635-cff3-414b-8d61-fc364f7e30bd` | `d0d79d5a-a079-4efe-8be2-eb737b77f441` |
| Q04 | `9911f715-1168-475a-97ca-8d7199a49d39` | `01e38c5d-1dbf-4f66-83cd-dcc95d06cd70` |
| Q04 | `fa86224d-5b03-4f4b-9fe9-220c9fc48e72` | `4ae19999-0171-422e-b59c-9b5afaf76c92` |
| Q04 | `b95fab33-0bed-49fb-b8a5-16e63ec8a7ed` | `d194d388-a686-41a4-932d-1d867fad0e0a` |
| Q04 | `78bd3661-f04a-4bef-9e81-52770ffc4234` | `ad90a4f6-1068-443c-9a12-27b91d28ff2e` |
| Q04 | `5b5bcec5-ea54-4abc-9f7b-533a5c3d1af3` | `ac754271-f92e-4795-93e0-584ca5128492` |
| Q04 | `547b0a5e-117b-4abe-9dfb-a515a111c8d3` | `5f72cc00-133c-4b41-94d6-c2feb23f566e` |
| Q04 | `59ac74ae-13c4-4663-af44-8a335ef87f61` | `f14e1e69-8565-412b-8d51-ea3951c68372` |
| Q04 | `199b5a7a-c330-44ad-9bd5-46ff460f7f59` | `8fd2dbb8-00ac-440c-a0a3-c4920c29c751` |
| Q04 | `6d2cedf0-9952-4898-a0b0-2866a54bb472` | `294efa45-be08-4030-88e1-9c65a72731b3` |
| Q04 | `c7ba8eef-8c49-45d0-a43e-599ba6d28eaf` | `0cec8989-20a9-411e-b0de-3c9ecc19726e` |
| Q04 | `9ed183b2-a3c9-4177-8506-cf80d9237c53` | `b59f420e-d2e6-4869-ba9b-7b7f6b43f6a4` |
| Q04 | `d5f7197c-f481-4983-82f7-9f3b8dfc8643` | `5bce5e44-96cd-4330-a1cb-fac1a9813a36` |
| Q04 | `14164d76-7aff-4992-ba8d-05162160b6d4` | `0f61af7d-c955-4886-b64e-c973b9c245c6` |
| Q04 | `27c7ea05-d36a-4950-b516-2f7c6a0f7353` | `393e6404-4e13-441e-85d5-3f9caa9f7f88` |
| Q04 | `7c10c064-413b-4e8b-ac51-b9b0777d894e` | `425d19ab-7487-44c0-89f6-8bbbc2156e5e` |
| Q04 | `9ba8eb3c-2a25-4f32-86f6-e63eff3bcdca` | `7742727e-80f3-4509-9011-fc4c3cf97ac1` |
| Q04 | `d3ae6171-bdb7-4841-bb0c-dab2c3a5bdbc` | `4f0a3e44-1173-4a08-89ea-dc2fc4da0306` |
| Q04 | `4dc47ec1-66f1-4761-bad0-ae30fbf293c1` | `e10b73ce-3d7c-4443-801f-4d4a14b8edb2` |
| Q04 | `95e5af49-483c-4ebc-9da3-6f93206278a3` | `8d31b6ad-b937-4e37-8bde-c751cc56801f` |
| Q04 | `0e1bd70a-f68b-4eec-9b08-512f3c65c10f` | `c06541af-750c-4860-83f0-0b4d54da5352` |
| Q05 | `1db27930-da69-4ab2-9d61-719a187fa9e8` | `c86e3533-9eda-4f2e-9eb2-e72f364893bd` |
| Q05 | `fa704429-cd42-4704-886f-126068029513` | `d04d3025-638e-42b4-acc0-e76bb260e928` |
| Q05 | `8f5520af-1b9e-4dc7-870d-1cf5bf823812` | `672282a9-bc23-4776-8cc5-0db4e9f88012` |
| Q05 | `4b7af90f-5c1e-48d7-8473-6e10183a88aa` | `88a13e89-6f77-4938-bdc9-86f38885cb26` |
| Q05 | `6a4b750f-3289-42c3-901b-0e4691b4bcda` | `5218bf1c-f9f8-4820-9056-fdb946ef0ce9` |
| Q05 | `ae9b8858-9f9d-4960-be2c-16a663d297c5` | `43fd8672-15cc-47c9-874b-abdb3c7b9521` |
| Q05 | `93d0ae3b-502f-48bd-bb53-db0693147153` | `49e22a6c-f3bc-41f4-93c9-e4c364999e1a` |
| Q05 | `c38a757e-5763-49a3-9680-ae920a3b3e3f` | `01a5b8bd-976a-4df3-b178-db2665c69f92` |
| Q06 | `40af0543-1fd0-4dae-80e1-531cd49df2a6` | `470b5cb7-32f9-4ff2-98b1-86fc2e73bb1c` |
| Q06 | `4dd0e95f-5338-4b69-b2f2-169411cc6da4` | `5b5cc1f0-813c-4123-ba4b-313a8abd585e` |
| Q06 | `f3a5c40c-6469-4a55-b15e-eadfdda152c7` | `2e949b6a-06aa-48af-a50c-572e05a5d25e` |
| Q06 | `76e26ada-4bb5-457e-8233-25feaa209982` | `0dd5d466-aea8-462f-901e-7fda4211fe30` |
| Q06 | `b3e51ab6-2207-4401-adc7-9b2aaaa31ae6` | `67254c37-e543-4e6c-95c7-871ad05f4394` |
| Q06 | `10643bce-86f3-4da3-bc1a-f4c9bb590661` | `b4393c78-e289-4876-8c86-5fccc5af10b2` |
| Q07 | `6e1598dd-9344-40f6-8ec4-50c508ec1557` | `ad3cb9ef-105a-4f44-853c-bdacb5c576b9` |

Eligible predecessor verdicts were Q04←Q02/Q03 `PASS`, Q05←Q04
`PASS|PASS_SOFT|PASS_LOWFREQ`, Q06←Q05 `PASS`, and Q07←Q06 `PASS`.

## HOLD cohort

These rows must not be requeued from inference:

- Missing exact `promoted_from_work_item` lineage:
  - `2b98118e-7818-483d-b20c-28015f29e04f`
  - `2086d1d7-02ae-4240-b6b1-18ecc851e124`
  - `7acf54a8-4f5f-4159-82cc-0ea34f535933`
  - `ee5f7a63-b5c7-4e2f-bd04-269b31c3f527`
  - `f1efc262-ffeb-4fdc-ac6a-951e01a4c4a9`
  - `d587050b-8ab3-4850-867f-17ce70df7d37`
  - `71094103-0d7e-414c-b6a5-2f9fb30f15f1`
  - `deaa0e2d-9916-4f20-9fd9-11b86750ded8`
  - `700edaea-66b7-4596-8398-c6a0af3b7ec8`
- `a8b4cffa-aef8-464a-a18d-58e04f2fc888` has exact predecessor
  `232b6803-b145-4fcb-a815-ba11a931ab60` at `done/PASS`, but its referenced
  predecessor evidence file is no longer present. It remains HOLD pending a
  separately evidenced recovery; a PASS label without retained evidence is not
  enough.

## Sanctioned same-row transient retry

`4de120bb-284e-45f0-b9f3-53521e72ac5a` is the explicit exception requested by
the task. At census time it had:

- `failed/INFRA_FAIL`, unclaimed, no `evidence_path`;
- no report directory at
  `D:\QM\reports\work_items\4de120bb-284e-45f0-b9f3-53521e72ac5a`;
- 0 `events`, 0 `ea_metrics`, and 0 transition-ledger rows;
- exact Q06 predecessor `33442389-ee02-46a8-9a82-baf053393d20`;
- payload-bound `RISK_FIXED=1000`, `RISK_PERCENT=0`, current-execution hashes,
  and Q07 requalification lineage.

After the code is merged, rebound, and active, this row may receive one
transactional same-row transient retry. Before that mutation, the operator must
take a database backup and row preimage/hash; revalidate the exact predecessor,
execution hashes, fixed-risk contract, no successor/open identity, no poison
row, and still-zero artifacts; record a durable repair event; clear only
claim-ephemeral fields; and move it to pending. Any newly discovered artifact,
successor, quarantine, or non-T5 failure cancels the exception.

## Staged recovery plan — not executed

1. **Deployment gate.** Claude reviews and merges `068e811bc`; OWNER publishes
   fresh runtime source bindings; the coordinated restart completes; then prove
   that live workers and process scope use the merged blobs. Do not release any
   recovery row before this gate.
2. **Fresh fail-closed census.** Back up the database and re-read every target
   in one snapshot. Require the same terminal T5-scope failure, no newer
   terminal verdict, no pending/active exact identity, an extant and eligible
   exact predecessor/evidence file, current EX5/setfile hashes, fresh news
   calendar, fixed-risk settings (`RISK_FIXED>0`, `RISK_PERCENT=0`), and no
   active poison/log-bomb quarantine. Any mismatch becomes HOLD.
3. **Append-only creation.** For each of the 37 ready rows, use the governed
   `farmctl.py enqueue-backtest` contract with exact `--ea`, Q-only `--phase`,
   `--from-work-item-id`, `--append-only-rerun-of`, an MNT-046 reason, and a
   freshly computed `--expected-current-ex5-sha256`. Preserve every victim row.
4. **Wave discipline.** Q04 has 22 ready rows: release bounded waves of at most
   five, still respecting the global symbol lock. Q05 has 8, Q06 has 6, and the
   append-only Q07 cohort has 1: for Q05+ allow exactly one recovery item active
   at a time and require its terminal evidence before the next release. Run the
   sanctioned QM5_13013 Q07 same-row exception as its own one-item wave.
5. **Stop conditions.** Stop the wave on poison classification, LOG_BOMB,
   missing/changed predecessor evidence, hash drift, stale news, history/input
   failure, or any non-MNT-046 verdict. Pipeline conclusions may come only from
   the resulting governed evidence.

No row in the HOLD cohort is part of these release counts.

## Post-cutoff T5 failures

The live log contains two additional matching failures after the accepted
54-row boundary:

- `ebdf4812-fbb3-4ae9-993f-a59d87cc4768` — QM5_20048 / Q06 / XTIUSD,
  currently failed/INFRA_FAIL;
- `80c6800b-8ff6-4642-a739-2abd3e2988c8` — QM5_10128 / Q08 / XAUUSD
  ablation_00, currently failed/INFRA_FAIL.

They require a separate live recensus under the same gates. They are not
included in the original 54 counts or staged release list.
