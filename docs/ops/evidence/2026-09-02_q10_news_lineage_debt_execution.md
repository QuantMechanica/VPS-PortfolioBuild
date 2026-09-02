# Q10 news lineage-debt execution — router task 45800644

**Executed:** 2026-09-02 14:32–14:57Z  
**Authority:** CEO mandate 2026-09-02; append-only reruns and supersessions only  
**Database:** `D:\QM\strategy_farm\state\farm_state.sqlite`

## Outcome

The live census at 14:46Z contained **33 active held `Q10_NEWS` rows**, not the
44 in the ticket title. Every one is classified below. The execution:

- added five append-only prerequisite reruns with exact predecessors and current
  canonical EX5 hashes; two further prerequisite rows were already pending;
- canonically superseded all 16 malformed Q10 rows from the 12:11–13:19Z
  heuristic cascade in one transaction and one database backup;
- verified one positive autoseal: `QM5_11288/USDJPY.DWX` replacement row
  `bdfeef30-...` was created from regenerated Q08, sealed, dependency-bound,
  and released before a separate runner-spawn abort parked it again;
- left the 18 earlier invalid-identity Q08 attempts refused, listed below; and
- did not mark priority, clear a hold, start a terminal, enable AutoTrading or
  `T_Live`, or infer any pipeline verdict.

## Exact append-only queue additions

Every new row has `append_only_rerun=true`, the cited
`append_only_rerun_of_work_item`, `promoted_from_work_item` equal to the exact
predecessor, and the full current EX5 SHA-256 in
`expected_current_ex5_sha256`.

| Pair | Phase | Exact predecessor | Terminal rerun target | New row / state at 14:57Z | Current EX5 SHA-256 |
|---|---:|---|---|---|---|
| `QM5_10114/SP500.DWX` | Q08 | Q07 `504d0bf7-...` PASS | Q08 `e76e7c6e-...` FAIL_SOFT | `ac972f2a-...` pending | `cdc478d75c90e5bb6a167831a6b1ac49dec106b4a8cd225dac352918cea74277` |
| `QM5_11708/EURUSD.DWX` | Q08 | Q07 `cbe612cd-...` PASS | Q08 `106b5827-...` FAIL_SOFT | `861577c0-...` pending | `baff181fe3c9b5abf404231603f8117f4d2cf9d792c69de7014732a3b6e96d25` |
| `QM5_12823/USDJPY.DWX` | Q08 | Q07 `b6679b2f-...` PASS | Q08 `3180c239-...` FAIL_SOFT | `5ec0f0a6-...` pending | `9f67834c75df85eba897a3e7cc013416c9397b07a9bc452f02d30ec1deda6ebb` |
| `QM5_13213/USDJPY.DWX` | Q08 | Q07 `d50a994c-...` PASS | Q08 `d2783b32-...` FAIL_SOFT | `048643ac-...` pending | `8c99dea16fbf758a4b2da9f49a26db26bfe7fed3589f2066be5120314106a8f0` |
| `QM5_1556/XAUUSD.DWX` | Q07 | Q06 `81362697-...` PASS | failed current Q07 `dcf98277-...` INFRA_FAIL | `377b2832-...` pending | `0962ca65776fd05e76f7ab5f27e838a72cb79a7359a029e2f47ef61a9ae7c88e` |

The first `QM5_1556` request against old Q07 `5b9d5cf2-...` correctly skipped
because current-binary rerun `dcf98277-...` already existed. The second command
preserved that terminal INFRA row and appended `377b2832-...`.

Two authorized chains were already present and were not duplicated:

- `QM5_13013/NDX.DWX`: Q07 `4668562c-...` PASS -> Q08
  `6fdfbae6-...` pending, append-only rerun of `1090a9f7-...`, current EX5
  `bf2cc2ec...44c41`.
- `QM5_12831/QM5_12831_XTI_AUDUSD_BRK_D1`: Q07 `f9b561b3-...`
  pending, append-only rerun of failed Q07 `9398e0b3-...`, exact Q06 predecessor
  `18f396eb-...`, current EX5 `6799630f...1397e`. Its Q08 must wait for Q07 PASS.

## Every active held Q10 row classified

The table is the live 33-row population before the supersede transaction.
Canonical supersession does not rewrite or release the historical hold; the
claim selector excludes a row having a `work_item_supersedes` edge.

| Held Q10 row(s) | Pair | Blocker class | Action / disposition |
|---|---|---|---|
| `9812fc7b-...` | `QM5_10114/SP500.DWX` | C: Q07 seed evidence missing | Q07 already PASS; Q08 `ac972f2a-...` enqueued from exact Q07. Await Q08, then autoseal replacement. |
| `8cc296d0-...` | `QM5_10706/GBPUSD.DWX` | D: EX5 vintage mismatch | Redundant: exact current Q07/Q08 already produced completed Q10 `CONFIG_LOCKED` evidence. No rerun and no priority mutation. |
| `08fe4173-...` | `QM5_11476/USDJPY.DWX` | C: no Q07 lineage | **Dead chain:** no Q07 row exists for the pair, so there is no authentic Q07 rerun target or exact predecessor. Do not synthesize lineage; needs a new governed upstream identity or retirement decision. |
| `f290aa11-...` | `QM5_11708/EURUSD.DWX` | D: setfile vintage mismatch | Q08 `861577c0-...` enqueued from exact Q07 `cbe612cd-...`. Await autoseal replacement. |
| `e6aaf4b4-...` | `QM5_12823/USDJPY.DWX` | C: Q07 seed evidence missing | Q08 `5ec0f0a6-...` enqueued from exact Q07 `b6679b2f-...`. Await autoseal replacement. |
| `84608819-...` | `QM5_12831` logical basket | C: Q07 seed evidence missing | Existing exact Q07 retry `f9b561b3-...` pending; Q08 is sequenced after PASS. |
| `36304cfd-...` | `QM5_13013/NDX.DWX` | C: no Q07 lineage | Existing exact Q07 PASS `4668562c-...`; existing Q08 `6fdfbae6-...` pending. Await autoseal replacement. |
| `72f7d4c1-...` | `QM5_13213/USDJPY.DWX` | D: setfile vintage mismatch | Q08 `048643ac-...` enqueued from exact Q07 `d50a994c-...`. Await autoseal replacement. |
| `d81d9ea8-...` | `QM5_1556/XAUUSD.DWX` | D: old setfile vintage mismatch | Obsolete old hold; newer held row `72992810-...` already names it as superseded. Recovery proceeds through the fresh Q07 below. |
| `72992810-...` | `QM5_1556/XAUUSD.DWX` | C: Q07 seed evidence missing | Q07 `377b2832-...` enqueued from exact Q06. Enqueue Q08 only after Q07 PASS; then autoseal. |
| `7c44c649-...` | `QM5_20048/XTIUSD.DWX` | C: Q07 seed evidence missing | Redundant: the pair already has completed Q10 `CONFIG_LOCKED` evidence. No rerun. |
| `745671a4-...` | `QM5_11129/SP500.DWX` | runner spawn silent abort | Bound row remains fail-closed. Exact process/log review and governed infra rerun are separate work; no hold clear here. |
| `77bd97c2-...` | `QM5_10700/XAUUSD.DWX` | runner spawn silent abort | Same governed infra disposition; no lineage mutation. |
| `dd7b14a0-...` | `QM5_11910/NZDUSD.DWX` | runner spawn silent abort | Same governed infra disposition; no lineage mutation. |
| `678b8cac-...` | `QM5_12710/XTIUSD.DWX` | runner spawn silent abort | Same governed infra disposition; no lineage mutation. |
| `d712832c-...` | `QM5_11422/USDCAD.DWX` | runner spawn silent abort | Redundant to existing completed Q10 `CONFIG_LOCKED`; no rerun. |
| `bdfeef30-...` | `QM5_11288/USDJPY.DWX` | autosealed, then runner spawn silent abort | Positive autoseal evidence below. Row remains fail-closed for governed infra retry; the lineage gate itself is repaired. |
| `bd840961-...` | `QM5_10145/SP500.DWX` | malformed Q09-as-Q08 identity | Canonically superseded in the 16-row batch; no replacement. |
| `cec67ad5-...`, `9d3f470e-...`, `d3312a9e-...`, `1d9a2d26-...` | `QM5_10513/XAUUSD.DWX` | malformed Q09-as-Q08 identities | All four canonically superseded in the batch; no replacements. |
| `70171429-...`, `e8ec3223-...` | `QM5_10569/XAUUSD.DWX` | malformed Q09-as-Q08 identities | Both canonically superseded in the batch; no replacements. |
| `58ae0036-...`, `9f691044-...`, `9b69d492-...`, `f3f1cedc-...`, `42c8debd-...`, `a8e36fba-...`, `15e7deca-...`, `60ce66e6-...`, `120d68ff-...` | `QM5_10692/NDX.DWX` | malformed Q09-as-Q08 identities | All nine canonically superseded in the batch; no replacements. |

`QM5_13128/NDX` row `aa80274f-...` and `QM5_11421/EURUSD` row
`30584122-...` have no active hold in this census and remain owned by
`OWNER-DEC-Q09HOLD-REQUAL-8`. They were not re-held, superseded, or rerun.

## Sixteen-row supersede batch receipt

The one-shot tool is
`tools/strategy_farm/apply_q10_identity_mismatch_supersede.py`; two focused
tests prove the append-only/one-backup path and fail-closed identity drift.

- Plan: `docs/ops/evidence/2026-09-02_q10_identity_mismatch_supersede_plan.json`
  — SHA-256 `d5da262c46aa0d71c7d5a58123b9b1c1ee6f73338d9b6eb8a65ea78e9767198a`.
- Receipt: `docs/ops/evidence/2026-09-02_q10_identity_mismatch_supersede_receipt.json`
  — SHA-256 `63d9a4a291acaf83fe13a075ec2b49e8f2c401aecefbd28f2b25d396e631677a`.
- Backup: `D:\QM\strategy_farm\state\backups\farm_state_before_q10_identity_mismatch_20260902T145609Z_e3fab33b.sqlite`
  — SHA-256 `35375df6e09c151cb086ded088353a36899369cb8a681831e36625d20a44bd22`.
- Readback: 16 edges with source encoding
  `router:q10-identity-mismatch-batch:45800644-c186-4215-895c-a0fc67925a8d`,
  all successor IDs NULL, 16 audit events, zero historical work-item updates,
  zero historical hold updates, zero replacement rows, `PRAGMA quick_check=ok`.

## Positive autoseal evidence

Autoseal created replacement Q10 `bdfeef30-7105-4ab4-984e-b2acb147f05b`
for `QM5_11288/USDJPY.DWX` at 11:45:51Z from regenerated Q08
`0d5ec1cc-dcce-435e-a7f7-be86df7c656f` (`FAIL_SOFT`). The row records
`promotion_source=q09_autoseal_regenerated_q08` and was bound at
11:46:14.332651Z.

- Its `Q08_INPUT` dependency names exact parent `0d5ec1cc-...`, required
  verdict `FAIL_SOFT`, and evidence SHA-256
  `44d661de41b52ae2f8782fda1342abe79a27b02a49b1a4eb68baafbb86ba3721`;
  direct file readback matches.
- Its exact Q07 is `124269b0-...`, with bound evidence SHA-256
  `a4a95d55f9248c087da5664862a79b18ce2e576ccbfb2b785842b737fb7c5c4d`.
- Sealed plan
  `D:\QM\reports\work_items\bdfeef30-7105-4ab4-984e-b2acb147f05b\q09_contract_v3\run_plan.json`
  exists and direct SHA-256 readback equals the payload binding
  `d4ea3812c88e972b9d234367c5a5e55ff0726c5fc9df5b416bf8dd6db99ab2fb`.
- Old held Q10 `3583e7be-...` is `done/SUPERSEDED`; its activation hold was
  released at 11:46:14Z with note `superseded after regenerated Q08 replacement
  plan bound`.
- The replacement later became held under
  `NEWS_RUNNER_SPAWN_SILENT_ABORT`. That is a downstream infra failure, not an
  autoseal failure, and no pipeline verdict is claimed.

## Dead/refused identity cohort

At 12:11:57–12:12:34Z, 18 Q08 requests were refused with exact event reason
`expected_current_ex5_sha256_required_or_invalid`; no work item was created.
Per the task authority these are dead old-identity chains and were not forced:

`QM5_10127/AUDCAD` (`ce315625`), `10815/EURUSD` (`a4efdfd3`),
`10145/CHFJPY` (`db7f2e4c`), `10919/XTIUSD` (`8e45588c`),
`11124/SP500` (`07c63d71`), `10553/XAUUSD` (`3164f57f`),
`10494/XAUUSD` (`a5ba6ccc`), `9929/XAUUSD` (`7083e456`),
`10920/XAUUSD` (`dc93311a`), `12958/XAUUSD` (`19e3cd97`),
`10940/XAUUSD` (`0c185c6d`), `11132/SP500` (`c894d56e`),
`10291/SP500` (`f8a1aadf`), `11132/NDX` (`43ef6eba`),
`11128/SP500` (`0e5936e3`), `11128/NDX` (`fbf3c7c5`),
`10440/NDX` (`23db1caf`), and `11063/USDJPY` (`ff6a2b1a`).

`QM5_13013/NDX` initially logged the same refusal at 14:23:25Z because its
expected hash argument was empty. It is not dead: the corrected exact-hash
enqueue produced pending Q08 `6fdfbae6-...` at 14:23:44Z.

## Focused verification

- `python -m pytest -q tools/strategy_farm/tests/test_apply_q10_identity_mismatch_supersede.py`
  -> `2 passed`.
- `python -m py_compile tools/strategy_farm/apply_q10_identity_mismatch_supersede.py`
  -> PASS.
- Live DB readback -> 16 task-scoped supersession edges; all seven current
  recovery rows preserve their exact rerun target, predecessor and current EX5
  binding; `PRAGMA quick_check=ok`.
- No priority flags were set. The normal factory scheduler owns execution order
  and RAM pacing.

## Remaining sequence

This task repairs/enqueues the debt but does not claim future terminal results.
After each pending Q07/Q08 reaches an acceptable terminal verdict, the existing
replacement/autoseal mechanism must append and bind the new Q10 row. Q08 for
`QM5_1556` and `QM5_12831` is deliberately not enqueued before Q07 PASS.
`QM5_11476` remains a dead lineage chain requiring upstream governance.
