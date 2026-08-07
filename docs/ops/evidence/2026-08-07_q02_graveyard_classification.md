# Q02 graveyard classification — terminal routing packet 2026-08-07

Task: `03c41408-9679-4a47-9450-a93f2c5a9688`

Status: READY FOR CLAUDE REVIEW

Mode: read-only classification and routing lists only. No enqueue, retirement,
work-item mutation, terminal launch, or pipeline verdict was performed.

## Result

The complete pre-route Q02 health cohort contains **270 unique EA/symbol
pairs**, not the 269 copied into the routed mission. All 270 are classified
exactly once:

| Routing class | Pairs | Disposition |
|---|---:|---|
| `RETIRE_VALID` | 1 | completed, identity-valid run below its frequency floor; retirement candidate only |
| `REQUEUE_POST_MIGRATION` | 92 | pure attributable infrastructure history; governed post-soak requeue candidate only |
| `INVALID_NEEDS_EVIDENCE_REPAIR` | 177 | deterministic EA/data/configuration defect or insufficient row-bound evidence; do not requeue |
| **Total** | **270** | no action executed |

The 269 count was true in `D:\QM\strategy_farm\state\health_alarms.log` at
`2026-08-07T11:38:06Z`. Before this task was routed, the same log recorded 270
at `2026-08-07T11:52:42Z` and again at `2026-08-07T12:37:59Z`.
`QM5_12538 / GBPUSD.DWX` is the added member: its twelfth infrastructure row,
`6f60d222-18e0-4990-9397-dd2d27948079`, became terminal at
`2026-08-07T11:40:12Z` with `ACTIVE_TIMEOUT`. It is included rather than
silently discarded.

## Frozen evidence boundary

The classification uses the immutable pre-route backup
`D:\QM\strategy_farm\state\backups\farm_state_20260807_1202.sqlite`
(SHA-256
`15bd4362441ebd3d96f689312952ad0c553b689338a161d22896413d30b19709`).
Its Q02 cohort has 3,297 rows; the selected-row digest is
`0721b775b0a365dcf6ce1dd16d2ea6cc17584d8742b7964c2dd20236ec9f361c`.
A live read at `2026-08-07T13:41:07Z` produced the same 270 records and the
same detailed-classification CSV digest
`3cc8e9daaf9c2e57286050b7be5554e56e56dfe2538954216c4ee90e0439e9a1`.

The health predicate was reproduced exactly: group canonical Q02 history by
EA and symbol; require at least 12 `INFRA_FAIL` rows, no queued or active
successor, and no terminal non-infrastructure disposition. The database was
opened read-only. Row-bound summaries, current setfiles, the EA registry, and
canonical EX5 presence were then inspected without modifying any source or
runtime state.

Evidence inventory:

- 359 readable row-bound summaries; zero parse failures and zero calendar-hard
  summaries.
- 257 current setfiles present, 13 missing, and 3 of the present files missing
  required headers. No duplicate header/input finding was observed.
- Every present setfile has `RISK_FIXED > 0` and `RISK_PERCENT = 0`; all 92
  requeue candidates satisfy that contract.
- All 270 registry rows are active and have a canonical EX5 path.

## Classification contract

Precedence is conservative and mutually exclusive:

1. `RETIRE_VALID` requires a completed row-bound aggregate with every run
   `OK`, `MIN_TRADES_NOT_MET`, trades below the row's effective floor, and all
   EA, symbol, date, EX5, setfile, deployment-stability, and news-calendar
   identity checks true.
2. Missing or header-invalid current setfiles route to evidence repair.
3. Any historical `LOG_BOMB`, `ONINIT_FAILED`, calendar-hard, or
   `NO_REAL_TICKS` marker prevents a pure-infrastructure classification. A
   later infrastructure symptom does not erase an earlier deterministic
   defect.
4. A pair with no specific row-bound cause routes to evidence repair; generic
   summary-missing labels are not promoted to infrastructure causality.
5. Only the remainder, with a specific history/cache/reaper/report
   infrastructure signature and no blocker above, routes to
   `REQUEUE_POST_MIGRATION`.

The error-32 investigation establishes why the shared mutable Custom history
topology must be corrected before reuse. It does **not** establish that every
pair below was killed by error 32. The routing uses only each pair's own row
history and does not infer missing causality from fleet-wide context.

## Class detail

### RETIRE_VALID — 1

`QM5_11888 / GBPUSD.DWX`, row
`f25f2758-f4db-4182-843e-8fd78b67b3ba`, has an identity-valid completed
aggregate at
`D:\QM\reports\work_items\f25f2758-f4db-4182-843e-8fd78b67b3ba\QM5_11888\20260727_205654\summary.json`
(SHA-256
`b7abdac2d9a82815d4623609a9d6d332f7d0d7d5d322279b8071432900585c59`).
The run completed `OK` with 6 trades against an effective floor of 25, and all
identity checks pass. The database row's stale infrastructure disposition
does not invalidate the authenticated aggregate. This is a retirement-list
candidate, not an executed retirement.

### REQUEUE_POST_MIGRATION — 92

| Route reason | Pairs |
|---|---:|
| `PURE_INFRA_BARS_ZERO` | 28 |
| `PURE_INFRA_ACTIVE_TIMEOUT` | 27 |
| `PURE_INFRA_NO_HISTORY_TRANSIENT` | 21 |
| `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | 9 |
| `PURE_INFRA_SHARED_BASES_LOCK_STORM` | 5 |
| `PURE_INFRA_REPORT_MISSING` | 2 |

These are list entries only. Claude should execute no member until the Variant
A migration has an accepted topology check and representative concurrency
soak. Immediately before any governed enqueue, revalidate that the cited row
is still terminal, no successor or non-infrastructure disposition exists,
the bound EX5/setfile hashes still match, both news-calendar copies are fresh
and identical with `qm_news_stale_max_hours <= 336`, and the fixed-risk values
remain valid. No active T1–T10 run may be interrupted.

### INVALID_NEEDS_EVIDENCE_REPAIR — 177

| Route reason | Pairs |
|---|---:|
| `EA_ONINIT_FAILURE_HISTORY` | 111 |
| `NO_SPECIFIC_ROW_BOUND_CAUSE` | 33 |
| `EA_LOG_BOMB_HISTORY` | 16 |
| `CURRENT_SETFILE_MISSING` | 13 |
| `CURRENT_SETFILE_HEADER_INCOMPLETE` | 3 |
| `HISTORY_NO_REAL_TICKS` | 1 |

These rows are not Monday requeue candidates. Repair or recover the exact
evidence/configuration/implementation defect first, then create reviewed
append-only lineage if further testing is authorized. In particular, a
generic missing summary is evidence absence, not permission for a blind run.

## Durable routing lists

- `D:\QM\reports\state\q02_graveyard_20260807\RETIRE_VALID.csv` — 1 row,
  SHA-256 `bfbd3badb64c540b5f39b9421e7583fb35ead1b04968aa841049c621d87f900f`.
- `D:\QM\reports\state\q02_graveyard_20260807\REQUEUE_POST_MIGRATION.csv` —
  92 rows, SHA-256
  `b254e910503710657e4e14707141be44846ac8ee1c8e1fb147634ff3be8d255b`.
- `D:\QM\reports\state\q02_graveyard_20260807\INVALID_NEEDS_EVIDENCE_REPAIR.csv`
  — 177 rows, SHA-256
  `2f778128ab702243db1b8ef04666f3a4c65abf0e4343f26b1437317fa488d7f6`.

The three files have an identical schema, are pair-disjoint, and their union
equals the 270-pair snapshot exactly. Each row includes the source database
row, row-bound path/hash when available, fallback log path, current setfile
hash and risk values, registry/EX5 checks, snapshot digest, and the explicit
`LIST_ONLY_CLAUDE_REVIEW_REQUIRED_NO_ACTION_TAKEN` policy.

## Per-pair routing table

The source row is the exact row supporting the selected reason. `DB snapshot`
means no surviving row-bound file was found; the cited UUID remains the
evidence anchor in the frozen database.

| EA | Symbol | Routing class | Reason | Source row | Row/path anchor |
|---|---|---|---|---|---|
| `QM5_1014` | `EURGBP.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_HEADER_INCOMPLETE` | `dd7101fd-3075-463a-af91-8d193791e5f2` | `C:\QM\repo\framework\EAs\QM5_1014\sets\QM5_1014_EURGBP.DWX_D1_backtest.set` |
| `QM5_1014` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_HEADER_INCOMPLETE` | `8ede5ab7-6f1f-4971-885c-7b9d9a506d51` | `C:\QM\repo\framework\EAs\QM5_1014\sets\QM5_1014_EURUSD.DWX_D1_backtest.set` |
| `QM5_1017` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_HEADER_INCOMPLETE` | `44835bef-4772-4972-80cf-3c99ed6d9c3f` | `C:\QM\repo\framework\EAs\QM5_1017_chan_pairs_stat_arb\sets\QM5_1017_chan_pairs_stat_arb_NDX.DWX_H1_backtest.set` |
| `QM5_1058` | `AUDUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `88bfbc59-641b-4f14-bce2-cba5793d7229` | `D:\QM\strategy_farm\logs\work_item_88bfbc59-641b-4f14-bce2-cba5793d7229.log` |
| `QM5_1058` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `b8fa58d1-64a7-48f2-81be-ed98ae4017ef` | `D:\QM\reports\work_items\b8fa58d1-64a7-48f2-81be-ed98ae4017ef\QM5_1058\20260731_165419\summary.json` |
| `QM5_1058` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `f5cae334-0c45-44f1-99ee-82523afb3a11` | `D:\QM\strategy_farm\logs\work_item_f5cae334-0c45-44f1-99ee-82523afb3a11.log` |
| `QM5_1114` | `JPN225.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `14b6899d-b9a8-448f-98d7-024e3db3eb96` | DB snapshot only |
| `QM5_1114` | `SP500.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `727fe789-dcac-4177-bec8-c294fcca8120` | `D:\QM\reports\work_items\727fe789-dcac-4177-bec8-c294fcca8120\QM5_1114\20260728_191213\summary.json` |
| `QM5_1114` | `XAGUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `41cab174-9a7f-42f7-8e7e-cd17098f00a2` | `D:\QM\reports\work_items\41cab174-9a7f-42f7-8e7e-cd17098f00a2\QM5_1114\20260728_175715\summary.json` |
| `QM5_1114` | `XAUUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `fedcb1f4-a3c9-4e1a-a490-3cdc62ea6a55` | `D:\QM\strategy_farm\logs\work_item_fedcb1f4-a3c9-4e1a-a490-3cdc62ea6a55.log` |
| `QM5_1135` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `abd86078-83b4-4265-9071-fa3dd9887a43` | `D:\QM\reports\work_items\abd86078-83b4-4265-9071-fa3dd9887a43\QM5_1135\20260728_124333\summary.json` |
| `QM5_1180` | `SP500.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `6295d241-ae68-4c1f-a0f4-69457b6eb60f` | DB snapshot only |
| `QM5_1181` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `ce149bf1-5289-4c68-a4ed-a6779d1085c5` | `C:\QM\repo\framework\EAs\QM5_1181_qp-pre-ecb-dax\sets\QM5_1181_qp-pre-ecb-dax_GER40.DWX_D1_backtest.set` (absent) |
| `QM5_1182` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `fa05bee9-8f62-4230-a8e4-bb73744dcdc5` | `C:\QM\repo\framework\EAs\QM5_1182_qp-ecb-d0-dax-short\sets\QM5_1182_qp-ecb-d0-dax-short_GER40.DWX_M15_backtest.set` (absent) |
| `QM5_1185` | `XAUUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `d1ddc909-3bfd-40bb-a593-4408f0db73cc` | `D:\QM\reports\work_items\d1ddc909-3bfd-40bb-a593-4408f0db73cc\QM5_1185\20260728_185353\summary.json` |
| `QM5_1187` | `XCUUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `d35a8936-618b-420f-a9c2-70caf50edf29` | `C:\QM\repo\framework\EAs\QM5_1187_qp-comm-voltarget-mom\sets\QM5_1187_XCUUSD.DWX_D1_backtest.set` (absent) |
| `QM5_1188` | `XTIUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `1b17085a-0620-44a5-9ef1-623a6eed7a67` | `D:\QM\reports\work_items\1b17085a-0620-44a5-9ef1-623a6eed7a67\QM5_1188\20260728_174907\summary.json` |
| `QM5_1192` | `XTIUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `662c278c-2cb2-4f33-99c0-bc7c23c9f642` | `D:\QM\reports\work_items\662c278c-2cb2-4f33-99c0-bc7c23c9f642\log_bomb_evidence.json` |
| `QM5_1193` | `AUDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `32eec24e-bed9-47a3-b597-93848bac57a2` | `D:\QM\reports\work_items\32eec24e-bed9-47a3-b597-93848bac57a2\QM5_1193\20260728_202454\summary.json` |
| `QM5_1193` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `1ab89952-a98d-44ad-8d00-6f5926826b4f` | `D:\QM\reports\work_items\1ab89952-a98d-44ad-8d00-6f5926826b4f\log_bomb_evidence.json` |
| `QM5_1193` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `e3bad09a-bddd-49c5-9ecc-75945ee3a01c` | `D:\QM\reports\work_items\e3bad09a-bddd-49c5-9ecc-75945ee3a01c\log_bomb_evidence.json` |
| `QM5_1193` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `3459cc65-138e-41df-a8af-eff73ed23027` | `D:\QM\reports\work_items\3459cc65-138e-41df-a8af-eff73ed23027\log_bomb_evidence.json` |
| `QM5_1194` | `SP500.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `559f7cbc-a95a-44eb-b0a2-56abbc07cfe2` | `D:\QM\reports\work_items\559f7cbc-a95a-44eb-b0a2-56abbc07cfe2\log_bomb_evidence.json` |
| `QM5_1196` | `AUDUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `bc25ee6c-2922-4df3-bf88-d5e15eaa4c72` | `D:\QM\reports\work_items\bc25ee6c-2922-4df3-bf88-d5e15eaa4c72\QM5_1196\20260802_134545\summary.json` |
| `QM5_1196` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `ef639b97-ac85-4585-b194-f87c3a96ee80` | `D:\QM\reports\work_items\ef639b97-ac85-4585-b194-f87c3a96ee80\QM5_1196\20260728_202524\summary.json` |
| `QM5_1204` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `f4195217-168b-48ff-8d15-14a2ad9638f0` | DB snapshot only |
| `QM5_1207` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `c5011d7a-b512-4e74-95d4-6833bc0acf9f` | `C:\QM\repo\framework\EAs\QM5_1207_bbadx-index-skew\sets\QM5_1207_bbadx-index-skew_GER40.DWX_D1_backtest.set` (absent) |
| `QM5_1207` | `JPN225.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `5ace370b-fc1e-4c44-a1cd-be5dbcc90821` | DB snapshot only |
| `QM5_1208` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `2ceeccc7-1020-41b3-9674-28ddbc1f849a` | `C:\QM\repo\framework\EAs\QM5_1208_carver-normmom\sets\QM5_1208_carver-normmom_GER40.DWX_D1_backtest.set` (absent) |
| `QM5_1225` | `AUDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `3dda93b2-80be-48f3-8a10-5cdf0a5a4bf2` | DB snapshot only |
| `QM5_1225` | `NZDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `3eacd6d8-22b2-4617-b1eb-4b34e9e5c0cf` | DB snapshot only |
| `QM5_1229` | `EURCAD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `4bbd64fb-0a5c-4749-8a8e-72f7ff100659` | `D:\QM\reports\work_items\4bbd64fb-0a5c-4749-8a8e-72f7ff100659\QM5_1229\20260728_155247\summary.json` |
| `QM5_1229` | `EURCHF.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `8870ee05-fbc6-4bc2-a721-b3cba2a334c5` | `D:\QM\reports\work_items\8870ee05-fbc6-4bc2-a721-b3cba2a334c5\QM5_1229\20260728_142608\summary.json` |
| `QM5_1229` | `EURGBP.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `ae5709c6-0cae-4730-95f7-986ada44a1c2` | `D:\QM\reports\work_items\ae5709c6-0cae-4730-95f7-986ada44a1c2\QM5_1229\20260728_153519\summary.json` |
| `QM5_1229` | `EURJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `56a2ef41-095b-49c3-904a-7b0386019cc1` | `D:\QM\reports\work_items\56a2ef41-095b-49c3-904a-7b0386019cc1\QM5_1229\20260728_152105\summary.json` |
| `QM5_1231` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `5b66c5eb-a571-49ed-b722-0c7a355abd75` | `D:\QM\reports\work_items\5b66c5eb-a571-49ed-b722-0c7a355abd75\QM5_1231\20260801_190407\summary.json` |
| `QM5_1231` | `FRA40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `d622938c-ff7a-4505-9f5b-6994a56d9697` | `C:\QM\repo\framework\EAs\QM5_1231_carver-pca-alpha\sets\QM5_1231_FRA40.DWX_D1_backtest.set` (absent) |
| `QM5_1231` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `c0106470-a34a-4cd1-bda7-8d1a7cec762e` | `C:\QM\repo\framework\EAs\QM5_1231_carver-pca-alpha\sets\QM5_1231_GER40.DWX_D1_backtest.set` (absent) |
| `QM5_1231` | `WS30.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_SHARED_BASES_LOCK_STORM` | `78ca5270-e9be-40d5-a000-a99ca2262e8e` | `D:\QM\strategy_farm\logs\work_item_78ca5270-e9be-40d5-a000-a99ca2262e8e.log` |
| `QM5_1232` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `8fa0a85e-600a-436e-8019-d017fe6f7ec9` | `C:\QM\repo\framework\EAs\QM5_1232_carver-fastmom-cost\sets\QM5_1232_GER40.DWX_D1_backtest.set` (absent) |
| `QM5_1236` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `1b921415-5b5e-441a-896d-9304e3ad9392` | `D:\QM\reports\work_items\1b921415-5b5e-441a-896d-9304e3ad9392\QM5_1236\20260728_115044\summary.json` |
| `QM5_1253` | `FRA40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `730d3fca-1347-4f65-a1a3-908e3535f3bb` | `C:\QM\repo\framework\EAs\QM5_1253_carver-lowbeta-rv\sets\QM5_1253_FRA40.DWX_D1_backtest.set` (absent) |
| `QM5_1253` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `200b33e2-b842-45d0-acbb-78747537e2e1` | `C:\QM\repo\framework\EAs\QM5_1253_carver-lowbeta-rv\sets\QM5_1253_GER40.DWX_D1_backtest.set` (absent) |
| `QM5_1536` | `XAGUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `66e131fa-9401-4e5f-81b7-c8058b5d6e52` | `D:\QM\reports\work_items\66e131fa-9401-4e5f-81b7-c8058b5d6e52\QM5_1536\20260728_151813\summary.json` |
| `QM5_1560` | `SP500.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `ffbd3c6f-d355-45ce-91f0-c9a81c0399ca` | `D:\QM\reports\work_items\ffbd3c6f-d355-45ce-91f0-c9a81c0399ca\QM5_1560\20260728_164137\summary.json` |
| `QM5_1560` | `WS30.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `7d2d3966-d16b-44fa-9d04-2d866a97dd0a` | `D:\QM\reports\work_items\7d2d3966-d16b-44fa-9d04-2d866a97dd0a\QM5_1560\20260728_160455\summary.json` |
| `QM5_1634` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `93e9bf32-f6d9-45b9-aaf1-51e3d49af5d9` | DB snapshot only |
| `QM5_1642` | `GDAXI.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `221ce780-c71c-4dee-96c6-85d2da455d94` | `D:\QM\reports\work_items\221ce780-c71c-4dee-96c6-85d2da455d94\QM5_1642\20260723_083742\summary.json` |
| `QM5_9194` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `18372e4c-1193-4b87-915d-9804f5dff7aa` | DB snapshot only |
| `QM5_9194` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `c1e10b3e-0ddc-48a2-8f9a-61bba87a92ac` | DB snapshot only |
| `QM5_9271` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `0262879b-5e49-46cc-937a-4fb69356d64f` | DB snapshot only |
| `QM5_9271` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `12e21324-8d69-47ea-b2a9-4cab0af29a65` | `D:\QM\reports\work_items\12e21324-8d69-47ea-b2a9-4cab0af29a65\QM5_9271\20260727_230921\summary.json` |
| `QM5_9291` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `a4cc0bd1-62af-4913-a634-bfb277cc12ea` | DB snapshot only |
| `QM5_9357` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `0f442640-4f68-4872-b940-577e3b08c961` | `D:\QM\reports\work_items\0f442640-4f68-4872-b940-577e3b08c961\QM5_9357\20260727_230511\summary.json` |
| `QM5_9403` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_SHARED_BASES_LOCK_STORM` | `1d72f99b-2c1a-473b-8cae-6974c51577e8` | `D:\QM\strategy_farm\logs\work_item_1d72f99b-2c1a-473b-8cae-6974c51577e8.log` |
| `QM5_9513` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `463c75bf-a5f5-4ea8-96b0-07960021d2d8` | DB snapshot only |
| `QM5_9525` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `522819e4-db70-4a70-87e3-6cc2d7f0f4a9` | DB snapshot only |
| `QM5_9940` | `EURJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | `aebeeafb-3d68-43fd-b350-c92cd3baca91` | `D:\QM\reports\work_items\aebeeafb-3d68-43fd-b350-c92cd3baca91\QM5_9940\20260807_062121\summary.json` |
| `QM5_9940` | `GBPJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `4003e1f9-c0b6-4cec-83d3-bc1f6b3b7740` | `D:\QM\reports\work_items\4003e1f9-c0b6-4cec-83d3-bc1f6b3b7740\QM5_9940\20260807_000302\summary.json` |
| `QM5_9940` | `USDJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | `b40023ea-eb15-436e-a53c-0a3159b1b282` | `D:\QM\reports\work_items\b40023ea-eb15-436e-a53c-0a3159b1b282\QM5_9940\20260802_235919\summary.json` |
| `QM5_9992` | `EURGBP.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `3dbec427-36b6-479e-8a7a-03eaa024f0c0` | DB snapshot only |
| `QM5_9992` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `24798410-97da-450c-84e7-668d6dd5f833` | DB snapshot only |
| `QM5_9992` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `db002d8d-37a1-4e17-868e-b5a125ee3d76` | DB snapshot only |
| `QM5_9992` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `0d2b08c2-1c71-4868-9204-3e53a60043cc` | DB snapshot only |
| `QM5_10000` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `b6313fe4-c42a-43a4-8667-1ccd25ef3ded` | `D:\QM\reports\work_items\b6313fe4-c42a-43a4-8667-1ccd25ef3ded\QM5_10000\20260728_115429\summary.json` |
| `QM5_10001` | `GBPJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | `f9261c78-302c-4bd8-ae00-f75b2031e9ec` | `D:\QM\reports\work_items\f9261c78-302c-4bd8-ae00-f75b2031e9ec\QM5_10001\20260710_035051\summary.json` |
| `QM5_10001` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | `64ffd2ce-36ba-43a4-ba9d-2b36d3b2f0e6` | `D:\QM\reports\work_items\64ffd2ce-36ba-43a4-ba9d-2b36d3b2f0e6\QM5_10001\20260710_021708\summary.json` |
| `QM5_10001` | `USDJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `4f79476d-dfb8-40c5-b5fa-09543d3c17d8` | DB snapshot only |
| `QM5_10008` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `54ca638d-c63c-42b0-ade5-791fb514e2a0` | DB snapshot only |
| `QM5_10016` | `AUDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `HISTORY_NO_REAL_TICKS` | `a8574364-3c98-4692-bb7d-00e7d2725c95` | DB snapshot only |
| `QM5_10016` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `c6544f4a-c6ae-45f3-9469-c2733e0d3e10` | DB snapshot only |
| `QM5_10016` | `XAUUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `7b5d6879-efb8-48f3-bf99-d7dc45eeff3c` | DB snapshot only |
| `QM5_10037` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `959e1d77-168e-4f55-a00d-77506fa19f85` | `D:\QM\reports\work_items\959e1d77-168e-4f55-a00d-77506fa19f85\QM5_10037\20260727_231728\summary.json` |
| `QM5_10062` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `37414083-1ae3-43a5-800b-ced04c9b647a` | `D:\QM\reports\work_items\37414083-1ae3-43a5-800b-ced04c9b647a\QM5_10062\20260727_231933\summary.json` |
| `QM5_10078` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `071232fd-813e-4081-a1d1-1fca22c30d44` | DB snapshot only |
| `QM5_10082` | `GDAXI.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `54eff91f-f81e-4284-b051-ca27fb081e7b` | DB snapshot only |
| `QM5_10088` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `73113bd0-06c3-4c0b-876c-39f653d85670` | DB snapshot only |
| `QM5_10098` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `15fa00a8-168c-46c0-99a8-96f6ec386e47` | `D:\QM\reports\work_items\15fa00a8-168c-46c0-99a8-96f6ec386e47\QM5_10098\20260728_033423\summary.json` |
| `QM5_10147` | `EURCAD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `44023000-f837-4323-be2e-442c353ca2e8` | `D:\QM\reports\work_items\44023000-f837-4323-be2e-442c353ca2e8\QM5_10147\20260728_084159\summary.json` |
| `QM5_10147` | `EURCHF.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `14111248-8316-4caa-8a0c-66b1075f9871` | `D:\QM\reports\work_items\14111248-8316-4caa-8a0c-66b1075f9871\QM5_10147\20260728_042537\summary.json` |
| `QM5_10147` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `30367366-c6b7-4d84-bf96-016f65899b50` | `D:\QM\reports\work_items\30367366-c6b7-4d84-bf96-016f65899b50\QM5_10147\20260727_232137\summary.json` |
| `QM5_10147` | `XNGUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `9b9d131e-b387-4912-b2cb-494d9c1884f3` | `D:\QM\reports\work_items\9b9d131e-b387-4912-b2cb-494d9c1884f3\QM5_10147\20260727_234931\summary.json` |
| `QM5_10147` | `XTIUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `adbcbf88-f96c-4427-a629-06818030e265` | `D:\QM\reports\work_items\adbcbf88-f96c-4427-a629-06818030e265\QM5_10147\20260727_235002\summary.json` |
| `QM5_10234` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `6f44d27f-a087-4474-a553-2afe947efacf` | `D:\QM\reports\work_items\6f44d27f-a087-4474-a553-2afe947efacf\QM5_10234\20260728_045908\summary.json` |
| `QM5_10253` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `246a194d-04fd-44f3-acd0-472628ddaad7` | `D:\QM\reports\work_items\246a194d-04fd-44f3-acd0-472628ddaad7\QM5_10253\20260728_014551\summary.json` |
| `QM5_10255` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `296c2e10-4561-4063-b981-d514c1ca52a4` | `D:\QM\reports\work_items\296c2e10-4561-4063-b981-d514c1ca52a4\QM5_10255\20260728_063732\summary.json` |
| `QM5_10255` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `ce1eaa3b-2042-4bcc-a31b-7f27facfdcfc` | `D:\QM\reports\work_items\ce1eaa3b-2042-4bcc-a31b-7f27facfdcfc\QM5_10255\20260728_102151\summary.json` |
| `QM5_10255` | `WS30.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `5cc1a7ad-ec2f-48b8-bce7-af08c931e8b4` | DB snapshot only |
| `QM5_10265` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `fff07b98-bdcf-4170-9e41-5359fe3f87fd` | `D:\QM\reports\work_items\fff07b98-bdcf-4170-9e41-5359fe3f87fd\QM5_10265\20260727_225014\summary.json` |
| `QM5_10268` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `32f5e842-0d41-4c8e-9ab0-6d8625f902a9` | `D:\QM\reports\work_items\32f5e842-0d41-4c8e-9ab0-6d8625f902a9\QM5_10268\20260728_011828\summary.json` |
| `QM5_10269` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `9d9c2f6e-6a6c-4a15-b232-928f5d90275c` | `D:\QM\reports\work_items\9d9c2f6e-6a6c-4a15-b232-928f5d90275c\QM5_10269\20260727_224808\summary.json` |
| `QM5_10278` | `NZDUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `dadf2abb-1e85-485b-8589-af2f62d05aed` | DB snapshot only |
| `QM5_10286` | `EURJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `3ccc88e6-c17b-4317-993d-93d8dc8ae9f7` | `D:\QM\reports\work_items\3ccc88e6-c17b-4317-993d-93d8dc8ae9f7\QM5_10286\20260728_092743\summary.json` |
| `QM5_10326` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `50cb506a-bfdb-4ef0-be9e-123e405dcf61` | `D:\QM\reports\work_items\50cb506a-bfdb-4ef0-be9e-123e405dcf61\QM5_10326\20260728_103025\summary.json` |
| `QM5_10326` | `SP500.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | `29beab40-5a9e-463e-b60a-140618556e94` | `D:\QM\reports\work_items\29beab40-5a9e-463e-b60a-140618556e94\QM5_10326\20260728_083530\summary.json` |
| `QM5_10326` | `WS30.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | `785444ba-a207-442f-8111-01b50593e299` | `D:\QM\reports\work_items\785444ba-a207-442f-8111-01b50593e299\QM5_10326\20260728_085001\summary.json` |
| `QM5_10327` | `GDAXI.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | `11ccf611-b70a-47d4-a05c-09ff4139114f` | `D:\QM\reports\work_items\11ccf611-b70a-47d4-a05c-09ff4139114f\QM5_10327\20260728_010538\summary.json` |
| `QM5_10327` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `7e5b48c6-c374-4e07-8836-5cb01b9e1dc6` | `D:\QM\reports\work_items\7e5b48c6-c374-4e07-8836-5cb01b9e1dc6\QM5_10327\20260727_225218\summary.json` |
| `QM5_10327` | `SP500.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | `ed418b10-e4a4-4aa2-8d7d-f8f480d7bcc3` | `D:\QM\reports\work_items\ed418b10-e4a4-4aa2-8d7d-f8f480d7bcc3\QM5_10327\20260727_230144\summary.json` |
| `QM5_10327` | `WS30.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_TIMEOUT_METATESTER_HUNG` | `0a46a7b5-25e6-4307-9184-fcf86bf8dca1` | `D:\QM\reports\work_items\0a46a7b5-25e6-4307-9184-fcf86bf8dca1\QM5_10327\20260727_224449\summary.json` |
| `QM5_10328` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `8abbaa82-9043-455f-892a-b6281e1a4942` | DB snapshot only |
| `QM5_10369` | `SP500.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `113a2f7d-c165-44e8-8c4f-1bf5fd8c7923` | `D:\QM\reports\work_items\113a2f7d-c165-44e8-8c4f-1bf5fd8c7923\QM5_10369\20260728_172351\summary.json` |
| `QM5_10466` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `a3bc8d81-d7b4-49e6-b771-390903382ff3` | `D:\QM\strategy_farm\logs\work_item_a3bc8d81-d7b4-49e6-b771-390903382ff3.log` |
| `QM5_10492` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `676a45ac-576d-4112-b66b-9b0f59e03a01` | DB snapshot only |
| `QM5_10505` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `20e36574-387b-4494-aefd-34900d74b76b` | `D:\QM\reports\work_items\20e36574-387b-4494-aefd-34900d74b76b\QM5_10505\20260728_173144\summary.json` |
| `QM5_10505` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `4f28d0d2-90ca-41d7-9671-c8032d36d1c4` | `D:\QM\reports\work_items\4f28d0d2-90ca-41d7-9671-c8032d36d1c4\QM5_10505\20260728_113308\summary.json` |
| `QM5_10505` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `c6d4cbf6-0c1d-412e-8e94-98dc53abff64` | `D:\QM\reports\work_items\c6d4cbf6-0c1d-412e-8e94-98dc53abff64\QM5_10505\20260728_114015\summary.json` |
| `QM5_10517` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `743f2301-5346-40c0-8b24-029342d67b55` | DB snapshot only |
| `QM5_10518` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `9bc184aa-cfc9-4f06-a1c8-d4fe52b1d885` | DB snapshot only |
| `QM5_10565` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `7ceeb1b3-2936-488e-ad1f-222aab61faff` | DB snapshot only |
| `QM5_10565` | `XAUUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `9fb32a34-0bef-4023-a25f-24c4968f1c0a` | DB snapshot only |
| `QM5_10577` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `f8ffc100-ca7f-47c3-9050-e2b3753ef5a3` | DB snapshot only |
| `QM5_10591` | `GBPJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_SHARED_BASES_LOCK_STORM` | `93077cce-bac0-4d3a-aa77-70e9e9a99353` | `D:\QM\reports\work_items\93077cce-bac0-4d3a-aa77-70e9e9a99353\QM5_10591\20260728_213017\raw\run_01\report.htm` |
| `QM5_10591` | `USDJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `ee59cf7e-22a3-4281-a6ba-69181441a547` | DB snapshot only |
| `QM5_10591` | `XAUUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_SHARED_BASES_LOCK_STORM` | `0b2e8803-4ba2-4b55-9053-81a901a127c7` | DB snapshot only |
| `QM5_10598` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `0971bc5d-e272-4aa7-9ef6-69c82ac8bfb6` | DB snapshot only |
| `QM5_10598` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `37520f8b-51f0-46a2-9b4f-346fe4bf30f5` | DB snapshot only |
| `QM5_10598` | `USDCHF.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `21fd66bd-0a5b-4e6e-aaad-d0ff1fd8f425` | DB snapshot only |
| `QM5_10598` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `ed62c7ed-c598-4ae5-973b-c54bbbb02b37` | DB snapshot only |
| `QM5_10710` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `34905d17-b8a5-4d1f-97d6-43dd2b7596d1` | DB snapshot only |
| `QM5_10710` | `XAUUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `8e2a791a-56b4-4d74-8c4e-57701947f722` | DB snapshot only |
| `QM5_10718` | `AUDCAD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `024189a5-bc3e-4124-b0c8-6925890634e9` | `D:\QM\reports\work_items\024189a5-bc3e-4124-b0c8-6925890634e9\QM5_10718\20260728_061451\summary.json` |
| `QM5_10718` | `AUDCHF.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `161826ad-c31a-4cca-8d7c-0d212b2dcc6e` | DB snapshot only |
| `QM5_10718` | `AUDJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `173317cf-d930-4e61-b41c-84117e4da28a` | `D:\QM\reports\work_items\173317cf-d930-4e61-b41c-84117e4da28a\QM5_10718\20260728_215824\summary.json` |
| `QM5_10718` | `AUDNZD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `0e5408ba-214e-4c9d-87cb-17c22719184d` | `D:\QM\reports\work_items\0e5408ba-214e-4c9d-87cb-17c22719184d\QM5_10718\20260728_221217\summary.json` |
| `QM5_10718` | `AUDUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `073d06e0-aa0e-4d6b-b2b6-c61784d64021` | `D:\QM\reports\work_items\073d06e0-aa0e-4d6b-b2b6-c61784d64021\QM5_10718\20260728_074235\raw\run_01\report.htm` |
| `QM5_10718` | `CADCHF.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `0af68164-219e-4924-bd7e-05ad0fe5f063` | `D:\QM\reports\work_items\0af68164-219e-4924-bd7e-05ad0fe5f063\QM5_10718\20260728_223934\summary.json` |
| `QM5_10718` | `CADJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `1bb97ebf-774d-46b1-8118-e97c4587a4f3` | `D:\QM\reports\work_items\1bb97ebf-774d-46b1-8118-e97c4587a4f3\QM5_10718\20260728_090310\summary.json` |
| `QM5_10718` | `CHFJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `017aba27-23db-4e88-b290-8d4f8804e9bc` | `D:\QM\reports\work_items\017aba27-23db-4e88-b290-8d4f8804e9bc\QM5_10718\20260728_230643\summary.json` |
| `QM5_10718` | `EURAUD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `2a009621-bb34-4d23-a63c-f102f2475cf4` | `D:\QM\reports\work_items\2a009621-bb34-4d23-a63c-f102f2475cf4\QM5_10718\20260728_224546\summary.json` |
| `QM5_10718` | `EURGBP.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `35a7c376-7393-4280-a348-26bc69b4856f` | `D:\QM\reports\work_items\35a7c376-7393-4280-a348-26bc69b4856f\QM5_10718\20260728_143240\summary.json` |
| `QM5_10718` | `EURJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `07c5e522-2ab6-420d-aea3-96f2f6f4dfb2` | `D:\QM\reports\work_items\07c5e522-2ab6-420d-aea3-96f2f6f4dfb2\QM5_10718\20260728_215107\summary.json` |
| `QM5_10718` | `EURNZD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `2186794f-30d2-4f13-8837-c49a08b2fb62` | `D:\QM\reports\work_items\2186794f-30d2-4f13-8837-c49a08b2fb62\QM5_10718\20260728_214449\summary.json` |
| `QM5_10718` | `GBPAUD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `0d9b4471-7bdd-46e1-940b-7c74eb3874c8` | `D:\QM\reports\work_items\0d9b4471-7bdd-46e1-940b-7c74eb3874c8\QM5_10718\20260728_220527\summary.json` |
| `QM5_10718` | `GBPCAD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `0b895411-0404-46a7-aa93-07a1b709e7d7` | `D:\QM\reports\work_items\0b895411-0404-46a7-aa93-07a1b709e7d7\QM5_10718\20260728_225237\summary.json` |
| `QM5_10718` | `GBPCHF.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `00fd266c-f06b-466b-b388-366c6bb08b03` | `D:\QM\reports\work_items\00fd266c-f06b-466b-b388-366c6bb08b03\QM5_10718\20260728_165223\summary.json` |
| `QM5_10718` | `GBPJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `1acf7591-3cd7-4b23-b8b8-06d273f9ba3c` | `D:\QM\reports\work_items\1acf7591-3cd7-4b23-b8b8-06d273f9ba3c\QM5_10718\20260728_233733\summary.json` |
| `QM5_10718` | `GBPNZD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `0d30dec5-c0be-4df2-9e75-675acba98fc3` | `D:\QM\reports\work_items\0d30dec5-c0be-4df2-9e75-675acba98fc3\QM5_10718\20260728_231621\summary.json` |
| `QM5_10718` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `124a66c5-3b9d-49d1-ba37-8e91f2b06a36` | `D:\QM\reports\work_items\124a66c5-3b9d-49d1-ba37-8e91f2b06a36\QM5_10718\20260728_095601\summary.json` |
| `QM5_10718` | `NZDCAD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `049a6201-dd30-4735-8be6-74d638aec254` | `D:\QM\reports\work_items\049a6201-dd30-4735-8be6-74d638aec254\QM5_10718\20260728_225902\summary.json` |
| `QM5_10718` | `NZDCHF.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `0c5d403e-b36c-43d1-a544-fa67e1c3d306` | `D:\QM\reports\work_items\0c5d403e-b36c-43d1-a544-fa67e1c3d306\QM5_10718\20260728_163804\summary.json` |
| `QM5_10718` | `NZDJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `2c3015cc-9d87-43dd-99ee-91123f89bd18` | `D:\QM\reports\work_items\2c3015cc-9d87-43dd-99ee-91123f89bd18\QM5_10718\20260728_055511\summary.json` |
| `QM5_10718` | `USDCAD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `170ff7d9-c390-4933-b157-f3dcd798719f` | `D:\QM\reports\work_items\170ff7d9-c390-4933-b157-f3dcd798719f\QM5_10718\20260728_084255\summary.json` |
| `QM5_10782` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `158ce101-f31d-4c6e-88e2-95ca670f1ab6` | `D:\QM\reports\work_items\158ce101-f31d-4c6e-88e2-95ca670f1ab6\QM5_10782\20260728_173939\summary.json` |
| `QM5_10782` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `4b590d82-863d-43e8-a986-f25559ad5a1a` | `D:\QM\reports\work_items\4b590d82-863d-43e8-a986-f25559ad5a1a\QM5_10782\20260728_154318\summary.json` |
| `QM5_10782` | `GDAXI.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `7e4faadc-ee28-47d4-b0c9-a4dc3b1138ba` | `D:\QM\reports\work_items\7e4faadc-ee28-47d4-b0c9-a4dc3b1138ba\QM5_10782\20260728_111539\summary.json` |
| `QM5_10782` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `86cce1dd-caf3-46a2-96cd-063b24547d91` | `D:\QM\reports\work_items\86cce1dd-caf3-46a2-96cd-063b24547d91\QM5_10782\20260728_172224\summary.json` |
| `QM5_10782` | `WS30.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `dc293f55-9318-4e50-8434-57eb0734636e` | `D:\QM\reports\work_items\dc293f55-9318-4e50-8434-57eb0734636e\QM5_10782\20260728_103252\summary.json` |
| `QM5_10782` | `XAUUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `953f9158-7e88-4de8-b53a-b06c3b248160` | `D:\QM\reports\work_items\953f9158-7e88-4de8-b53a-b06c3b248160\QM5_10782\20260731_114607\summary.json` |
| `QM5_10794` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `ced46101-c8d5-44eb-8322-9890f89239ca` | DB snapshot only |
| `QM5_10794` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `0714fe52-8a20-4c83-8f25-8558e15fab1b` | `D:\QM\reports\work_items\0714fe52-8a20-4c83-8f25-8558e15fab1b\QM5_10794\20260727_225432\summary.json` |
| `QM5_10795` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `0e6a9d44-713f-437d-8103-664fec0e0ee7` | `D:\QM\reports\work_items\0e6a9d44-713f-437d-8103-664fec0e0ee7\QM5_10795\20260727_225635\summary.json` |
| `QM5_10850` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `133f2023-7786-40ea-ba08-83ccd02a93bd` | `D:\QM\reports\work_items\133f2023-7786-40ea-ba08-83ccd02a93bd\QM5_10850\20260728_005305\summary.json` |
| `QM5_10850` | `GDAXI.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `01bbbb6a-8e54-4a1d-87e7-9fedb4568e09` | `D:\QM\reports\work_items\01bbbb6a-8e54-4a1d-87e7-9fedb4568e09\QM5_10850\20260728_013555\summary.json` |
| `QM5_10850` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `50a1e9b5-3cf3-4649-8d21-368eac3f076d` | `D:\QM\reports\work_items\50a1e9b5-3cf3-4649-8d21-368eac3f076d\QM5_10850\20260727_230719\summary.json` |
| `QM5_10850` | `WS30.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `28fe4a90-71d1-4f9a-a70e-0f7a40cdec35` | `D:\QM\reports\work_items\28fe4a90-71d1-4f9a-a70e-0f7a40cdec35\QM5_10850\20260727_231913\summary.json` |
| `QM5_10850` | `XAUUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `15d6d0fd-210d-42fe-9c68-2cc88d99c117` | `D:\QM\reports\work_items\15d6d0fd-210d-42fe-9c68-2cc88d99c117\QM5_10850\20260728_145144\summary.json` |
| `QM5_10882` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `2402163d-4370-4065-89b9-00124e1c566f` | `D:\QM\reports\work_items\2402163d-4370-4065-89b9-00124e1c566f\QM5_10882\20260729_064630\summary.json` |
| `QM5_10882` | `SP500.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `9cb9395b-b882-4d52-9d0e-0ce71cd3fb5d` | `D:\QM\reports\work_items\9cb9395b-b882-4d52-9d0e-0ce71cd3fb5d\QM5_10882\20260728_183310\summary.json` |
| `QM5_10882` | `WS30.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `047210eb-272b-4e26-88ab-ed23f0fd525f` | `D:\QM\reports\work_items\047210eb-272b-4e26-88ab-ed23f0fd525f\QM5_10882\20260728_183542\summary.json` |
| `QM5_10907` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `b6a1c8c2-0b01-4104-a441-b643babc2dbd` | DB snapshot only |
| `QM5_10977` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `b9fc8a59-c929-4fd8-aff2-6e7747f9b99b` | DB snapshot only |
| `QM5_11029` | `EURJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `96732da9-2117-4d89-99e3-0df574faef97` | DB snapshot only |
| `QM5_11029` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `7de98e70-9aab-4169-8e83-b144f8fd5065` | DB snapshot only |
| `QM5_11029` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `7f472a60-ae41-4515-b783-27f0dac6cf6f` | DB snapshot only |
| `QM5_11029` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `4fa13f1d-29d8-4643-b9b0-cf2b8b278588` | DB snapshot only |
| `QM5_11062` | `AUDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_LOG_BOMB_HISTORY` | `0b919d67-60ce-4188-9073-e6ac904a58ce` | `D:\QM\reports\work_items\0b919d67-60ce-4188-9073-e6ac904a58ce\QM5_11062\20260728_141533\summary.json` |
| `QM5_11062` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `dd6ecd29-3bbc-41d8-b34a-7240e8d3bfc5` | `D:\QM\reports\work_items\dd6ecd29-3bbc-41d8-b34a-7240e8d3bfc5\QM5_11062\20260728_164919\summary.json` |
| `QM5_11062` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `e012f2d0-4c96-4a13-84e0-7ab0187239dd` | `D:\QM\reports\work_items\e012f2d0-4c96-4a13-84e0-7ab0187239dd\QM5_11062\20260728_144616\summary.json` |
| `QM5_11078` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `b72d8cb8-f07f-46cd-8864-1566fb8a88df` | `D:\QM\reports\work_items\b72d8cb8-f07f-46cd-8864-1566fb8a88df\QM5_11078\20260728_170028\summary.json` |
| `QM5_11078` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `f42e4787-01cc-405f-9b81-84b723073587` | `D:\QM\reports\work_items\f42e4787-01cc-405f-9b81-84b723073587\QM5_11078\20260728_114230\summary.json` |
| `QM5_11078` | `USDCAD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `8b32696d-b5cf-45c0-bd4e-429b799b7e59` | DB snapshot only |
| `QM5_11091` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `139a4999-c82d-4453-bbb4-686faea1512e` | `D:\QM\reports\work_items\139a4999-c82d-4453-bbb4-686faea1512e\QM5_11091\20260727_224559\summary.json` |
| `QM5_11091` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `13c8e7af-cc28-463a-8749-261472858b74` | `D:\QM\reports\work_items\13c8e7af-cc28-463a-8749-261472858b74\QM5_11091\20260728_000847\summary.json` |
| `QM5_11091` | `XAUUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `2c4658b1-07a3-48c2-886c-7bf51c0b0767` | `D:\QM\reports\work_items\2c4658b1-07a3-48c2-886c-7bf51c0b0767\QM5_11091\20260728_144101\summary.json` |
| `QM5_11096` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `19692f23-7fa5-46ff-b5cd-152d7b5055b3` | `D:\QM\reports\work_items\19692f23-7fa5-46ff-b5cd-152d7b5055b3\QM5_11096\20260728_173437\summary.json` |
| `QM5_11096` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `3d452e18-76f4-430b-9a94-8de2b1a91da9` | `D:\QM\reports\work_items\3d452e18-76f4-430b-9a94-8de2b1a91da9\QM5_11096\20260728_125712\raw\run_01\report.htm` |
| `QM5_11096` | `USDJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `48e9c802-b915-49b3-9ccd-3a44327ae1da` | DB snapshot only |
| `QM5_11096` | `XAUUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `533c2222-bff6-4276-b0d2-ff2a136f7721` | `D:\QM\strategy_farm\logs\work_item_533c2222-bff6-4276-b0d2-ff2a136f7721.log` |
| `QM5_11100` | `AUDUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `3047390b-7336-448a-a62d-93b86defe021` | `D:\QM\strategy_farm\logs\work_item_3047390b-7336-448a-a62d-93b86defe021.log` |
| `QM5_11145` | `GER40.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_REPORT_MISSING` | `1e550769-acdd-4b02-87c1-36560504d04a` | DB snapshot only |
| `QM5_11147` | `FTSE100.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `27cbab9d-0e29-4c13-9caa-39ff9d4c86d7` | `C:\QM\repo\framework\EAs\QM5_11147_clenow-vam-rot\sets\QM5_11147_clenow-vam-rot_FTSE100.DWX_D1_backtest.set` (absent) |
| `QM5_11147` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `af578b68-ba7a-47f5-bd47-9dd1d35d6465` | `C:\QM\repo\framework\EAs\QM5_11147_clenow-vam-rot\sets\QM5_11147_clenow-vam-rot_GER40.DWX_D1_backtest.set` (absent) |
| `QM5_11160` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `CURRENT_SETFILE_MISSING` | `00ed8067-60fe-4df8-922d-2563b77f54d2` | `C:\QM\repo\framework\EAs\QM5_11160_dwx-brk-risk\sets\QM5_11160_dwx-brk-risk_GER40.DWX_H1_backtest.set` (absent) |
| `QM5_11223` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `0fd26a14-b6eb-4d7a-a001-3e82de22c465` | DB snapshot only |
| `QM5_11223` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `11076597-bb17-47dc-98f5-5bb593757cee` | `D:\QM\reports\work_items\11076597-bb17-47dc-98f5-5bb593757cee\QM5_11223\20260727_235632\summary.json` |
| `QM5_11223` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `238fa71b-85a6-4212-839f-3f02abc8b029` | `D:\QM\reports\work_items\238fa71b-85a6-4212-839f-3f02abc8b029\QM5_11223\20260728_001727\summary.json` |
| `QM5_11223` | `XAUUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `14a4ad85-e3a2-469a-bf82-badd22d57955` | `D:\QM\reports\work_items\14a4ad85-e3a2-469a-bf82-badd22d57955\QM5_11223\20260728_151758\summary.json` |
| `QM5_11224` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `161dff44-eaf8-4f83-8b7a-a91e2e97e79b` | DB snapshot only |
| `QM5_11224` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `966ef766-c3e3-4051-82a5-398cbbcc05a7` | DB snapshot only |
| `QM5_11232` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `ade32976-0d7a-4b37-a36d-12b1ca4033e1` | `D:\QM\reports\work_items\ade32976-0d7a-4b37-a36d-12b1ca4033e1\QM5_11232\20260724_001239\summary.json` |
| `QM5_11257` | `GER40.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_REPORT_MISSING` | `bc5ef9bf-518a-4feb-95da-dbf58a898a19` | DB snapshot only |
| `QM5_11257` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `4a64b7be-4d7f-49b9-ab05-81765c502925` | `D:\QM\reports\work_items\4a64b7be-4d7f-49b9-ab05-81765c502925\QM5_11257\20260728_193154\summary.json` |
| `QM5_11261` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_SHARED_BASES_LOCK_STORM` | `c82f684d-f56b-43a0-b0b1-64817835f516` | `D:\QM\reports\work_items\c82f684d-f56b-43a0-b0b1-64817835f516\QM5_11261\20260728_185608\raw\run_01\report.htm` |
| `QM5_11261` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `13f047e5-05b9-46c3-834d-636753f5e6c8` | DB snapshot only |
| `QM5_11261` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `ef91b81e-555d-4c9d-ac55-c70699cec46c` | `D:\QM\reports\work_items\ef91b81e-555d-4c9d-ac55-c70699cec46c\QM5_11261\20260728_194224\summary.json` |
| `QM5_11332` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `623af057-2bbe-47b4-be2b-3e99582a2b31` | DB snapshot only |
| `QM5_11332` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `00ea8576-0179-4882-91ed-6a2b1062d30c` | DB snapshot only |
| `QM5_11353` | `AUDCHF.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `dda4325b-572a-4ae8-b796-14815bd5ac90` | `D:\QM\reports\work_items\dda4325b-572a-4ae8-b796-14815bd5ac90\QM5_11353\20260728_150536\summary.json` |
| `QM5_11353` | `AUDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `c2600156-a1d6-48b2-ac5b-909596c6b539` | `D:\QM\reports\work_items\c2600156-a1d6-48b2-ac5b-909596c6b539\QM5_11353\20260728_162137\summary.json` |
| `QM5_11353` | `AUDNZD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `bbc12e4b-7681-406e-8533-faf84884c74f` | `D:\QM\reports\work_items\bbc12e4b-7681-406e-8533-faf84884c74f\QM5_11353\20260728_155750\summary.json` |
| `QM5_11354` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `7a371379-01f8-4392-bf4e-1e430abae580` | DB snapshot only |
| `QM5_11354` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `aad787cc-d43d-4ab1-a0af-ccbaab3f93ec` | DB snapshot only |
| `QM5_11354` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `d4ad7816-5711-4dcf-908c-feec799ae413` | DB snapshot only |
| `QM5_11521` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `dde45e0d-a2a2-4e4a-89e5-db0b3a916eb1` | DB snapshot only |
| `QM5_11528` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `774a2200-bf30-4921-875e-966deaf9ca11` | DB snapshot only |
| `QM5_11528` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `6b3893cf-8922-44a5-89c5-085607d911e3` | DB snapshot only |
| `QM5_11554` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `86f13495-1975-4cb0-9360-06e3e965dabb` | DB snapshot only |
| `QM5_11555` | `AUDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `4acd1b1d-fa93-4403-b4e2-cf886db4c9d8` | DB snapshot only |
| `QM5_11555` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `ff642cfc-c3f1-4b65-b7a5-2ceec0e076d8` | DB snapshot only |
| `QM5_11555` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `ae6fe3ec-683a-4f88-9263-f97cbc4b9792` | DB snapshot only |
| `QM5_11555` | `USDCHF.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `33a06142-0ea7-43b3-9392-f509d96487e4` | DB snapshot only |
| `QM5_11556` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `f07e77fa-be0a-4d2b-961d-9b661ceb1fa3` | DB snapshot only |
| `QM5_11605` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `e4d954ab-d641-4da8-89ce-5b62451ad919` | DB snapshot only |
| `QM5_11619` | `AUDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `2321e54c-5f39-4842-b27b-931841c6090b` | `D:\QM\reports\work_items\2321e54c-5f39-4842-b27b-931841c6090b\QM5_11619\20260802_161644\summary.json` |
| `QM5_11619` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `d547c131-5013-49a6-acb8-028d666293c1` | `D:\QM\reports\work_items\d547c131-5013-49a6-acb8-028d666293c1\QM5_11619\20260805_070944\summary.json` |
| `QM5_11619` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `cb6dee0a-ab14-4fca-b08a-14e8dbe90f40` | `D:\QM\reports\work_items\cb6dee0a-ab14-4fca-b08a-14e8dbe90f40\QM5_11619\20260802_161700\summary.json` |
| `QM5_11625` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `238952c9-ee65-4b55-a1c7-d03427712213` | `D:\QM\reports\work_items\238952c9-ee65-4b55-a1c7-d03427712213\QM5_11625\20260728_220627\summary.json` |
| `QM5_11673` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `b22edf66-19f5-485c-ad2d-c51729a3faad` | `D:\QM\reports\work_items\b22edf66-19f5-485c-ad2d-c51729a3faad\QM5_11673\20260728_173706\summary.json` |
| `QM5_11673` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `12b555b8-9156-4475-bd32-06a41d11cd14` | DB snapshot only |
| `QM5_11721` | `GBPJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `6d3177c9-51b1-4b72-b998-3f4d223523af` | DB snapshot only |
| `QM5_11721` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `c2e658de-f7cf-466e-8c9e-4719521fff88` | DB snapshot only |
| `QM5_11807` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `9bdef369-efb6-42f2-9700-4deb3dfac974` | DB snapshot only |
| `QM5_11888` | `EURJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `e3f6e275-a3ae-4e4d-9ead-f60b4f27a9d5` | DB snapshot only |
| `QM5_11888` | `GBPUSD.DWX` | `RETIRE_VALID` | `COMPLETED_BELOW_FREQUENCY_FLOOR` | `f25f2758-f4db-4182-843e-8fd78b67b3ba` | `D:\QM\reports\work_items\f25f2758-f4db-4182-843e-8fd78b67b3ba\QM5_11888\20260727_205654\summary.json` |
| `QM5_11895` | `AUDJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `5be0b313-788d-4bb0-a287-f9f421c31368` | DB snapshot only |
| `QM5_11895` | `AUDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `838a59a2-db31-47e6-8406-78557cbe3716` | `D:\QM\reports\work_items\838a59a2-db31-47e6-8406-78557cbe3716\QM5_11895\20260728_130844\summary.json` |
| `QM5_11895` | `EURJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `2eb1f1ea-f8df-4691-a295-15d42fa1b4e5` | `D:\QM\reports\work_items\2eb1f1ea-f8df-4691-a295-15d42fa1b4e5\QM5_11895\20260728_130630\summary.json` |
| `QM5_11895` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `c51acfce-2864-438e-890e-881973a6e13c` | `D:\QM\reports\work_items\c51acfce-2864-438e-890e-881973a6e13c\QM5_11895\20260728_230540\summary.json` |
| `QM5_11895` | `GBPJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `895a0974-0d0b-42af-b9a9-9f5b37c1ea25` | `D:\QM\reports\work_items\895a0974-0d0b-42af-b9a9-9f5b37c1ea25\QM5_11895\20260728_131255\summary.json` |
| `QM5_11895` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `7a2b5aeb-fcf9-45da-bc50-549ef103c8e8` | `D:\QM\reports\work_items\7a2b5aeb-fcf9-45da-bc50-549ef103c8e8\QM5_11895\20260728_192835\summary.json` |
| `QM5_11895` | `NZDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `543b5c7f-801e-4465-8415-df35b26b19db` | `D:\QM\reports\work_items\543b5c7f-801e-4465-8415-df35b26b19db\QM5_11895\20260728_131340\summary.json` |
| `QM5_11895` | `USDCAD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `27348255-1564-4104-a430-ecbd14477246` | `D:\QM\reports\work_items\27348255-1564-4104-a430-ecbd14477246\QM5_11895\20260728_131459\summary.json` |
| `QM5_11895` | `USDCHF.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `2ac64dda-88ff-48aa-8335-b41a3f67a389` | `D:\QM\reports\work_items\2ac64dda-88ff-48aa-8335-b41a3f67a389\QM5_11895\20260728_131607\summary.json` |
| `QM5_11895` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `3971ccfc-49b6-4385-84cb-b06fe7f2ac6b` | `D:\QM\reports\work_items\3971ccfc-49b6-4385-84cb-b06fe7f2ac6b\QM5_11895\20260728_154302\summary.json` |
| `QM5_11896` | `EURJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `f94405fd-98de-462f-a483-06544c0b9271` | `D:\QM\reports\work_items\f94405fd-98de-462f-a483-06544c0b9271\QM5_11896\20260728_092017\summary.json` |
| `QM5_11900` | `AUDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `7eb8a129-07d5-4e36-b96a-9d0366412f66` | `D:\QM\reports\work_items\7eb8a129-07d5-4e36-b96a-9d0366412f66\QM5_11900\20260728_131837\summary.json` |
| `QM5_11900` | `AUDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `d268ec2b-56b5-48b3-b5d6-87bef428ce49` | `D:\QM\reports\work_items\d268ec2b-56b5-48b3-b5d6-87bef428ce49\QM5_11900\20260728_132127\summary.json` |
| `QM5_11900` | `EURJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `542453c1-e135-4986-94e1-f64115b4268a` | `D:\QM\reports\work_items\542453c1-e135-4986-94e1-f64115b4268a\QM5_11900\20260728_132445\summary.json` |
| `QM5_11900` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `7b64c967-501b-4b2e-abe4-d5c250594649` | `D:\QM\reports\work_items\7b64c967-501b-4b2e-abe4-d5c250594649\QM5_11900\20260728_233536\summary.json` |
| `QM5_11900` | `GBPJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `eb017ddc-4abe-4f08-86ce-8fc379c9134b` | `D:\QM\reports\work_items\eb017ddc-4abe-4f08-86ce-8fc379c9134b\QM5_11900\20260728_132620\summary.json` |
| `QM5_11900` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `5f17a010-5ac9-4975-85e8-155fa8b6715c` | `D:\QM\reports\work_items\5f17a010-5ac9-4975-85e8-155fa8b6715c\QM5_11900\20260728_211225\summary.json` |
| `QM5_11900` | `NZDUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `a4dfe743-af07-4d1a-b4ca-3e83857d2966` | `D:\QM\reports\work_items\a4dfe743-af07-4d1a-b4ca-3e83857d2966\QM5_11900\20260728_132745\summary.json` |
| `QM5_11900` | `USDCAD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `616d6820-3807-47f4-a9d1-2b1c9a77e3ff` | `D:\QM\reports\work_items\616d6820-3807-47f4-a9d1-2b1c9a77e3ff\QM5_11900\20260728_133036\summary.json` |
| `QM5_11900` | `USDCHF.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `cc20795e-fa50-4a65-9107-f205308593c2` | DB snapshot only |
| `QM5_11900` | `USDJPY.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `eaef2f55-53ea-4970-b650-5e374a3b6931` | `D:\QM\reports\work_items\eaef2f55-53ea-4970-b650-5e374a3b6931\QM5_11900\20260728_154523\summary.json` |
| `QM5_12348` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `fb973bb0-b008-48b5-b81c-f9092c2e0b73` | DB snapshot only |
| `QM5_12348` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `4f9e07df-9425-4ded-85a7-af1c1b0b69af` | `D:\QM\reports\work_items\4f9e07df-9425-4ded-85a7-af1c1b0b69af\QM5_12348\20260728_204459\summary.json` |
| `QM5_12349` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `303d358d-8102-41c4-bd03-f70e9701e0a8` | `D:\QM\reports\work_items\303d358d-8102-41c4-bd03-f70e9701e0a8\QM5_12349\20260728_164329\summary.json` |
| `QM5_12361` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `caf70551-b1e9-45c0-bbb7-1ebd80715bd3` | `D:\QM\reports\work_items\caf70551-b1e9-45c0-bbb7-1ebd80715bd3\QM5_12361\20260728_145427\summary.json` |
| `QM5_12361` | `GER40.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `NO_SPECIFIC_ROW_BOUND_CAUSE` | `3021d75d-f972-4e4c-8070-6390ca0bd9d4` | DB snapshot only |
| `QM5_12382` | `XAGUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_BARS_ZERO` | `b9e67420-f853-458b-997f-01b66fb0ccd9` | `D:\QM\reports\work_items\b9e67420-f853-458b-997f-01b66fb0ccd9\QM5_12382\20260804_074752\summary.json` |
| `QM5_12405` | `GDAXI.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `12493b78-3c18-4be8-9eb2-1fbd0ee1855b` | `D:\QM\reports\work_items\12493b78-3c18-4be8-9eb2-1fbd0ee1855b\QM5_12405\20260728_173540\summary.json` |
| `QM5_12405` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `7da67529-1673-403f-b725-598b5386a7d0` | `D:\QM\reports\work_items\7da67529-1673-403f-b725-598b5386a7d0\QM5_12405\20260729_012004\summary.json` |
| `QM5_12405` | `SP500.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `d119f278-5901-4ab5-93de-089201323756` | `D:\QM\reports\work_items\d119f278-5901-4ab5-93de-089201323756\QM5_12405\20260728_184738\summary.json` |
| `QM5_12405` | `WS30.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `4d50854c-3a75-498e-b100-6b88bb273485` | `D:\QM\reports\work_items\4d50854c-3a75-498e-b100-6b88bb273485\QM5_12405\20260728_190943\summary.json` |
| `QM5_12406` | `NDX.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `b9741f07-c26d-4860-b9f4-44999d7109d9` | `D:\QM\reports\work_items\b9741f07-c26d-4860-b9f4-44999d7109d9\QM5_12406\20260727_185537\summary.json` |
| `QM5_12449` | `EURUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_NO_HISTORY_TRANSIENT` | `f29ee2de-3abf-4824-adfa-5d99ce267978` | `D:\QM\reports\work_items\f29ee2de-3abf-4824-adfa-5d99ce267978\QM5_12449\20260728_155933\summary.json` |
| `QM5_12455` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `2cb70bd8-ebaa-4470-80ad-3f541a578344` | `D:\QM\reports\work_items\2cb70bd8-ebaa-4470-80ad-3f541a578344\QM5_12455\20260728_164622\summary.json` |
| `QM5_12538` | `GBPUSD.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `6f60d222-18e0-4990-9397-dd2d27948079` | `D:\QM\strategy_farm\logs\work_item_6f60d222-18e0-4990-9397-dd2d27948079.log` |
| `QM5_12538` | `USDJPY.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `97e5b05f-8367-4c15-ad8a-7c81f9ddea39` | `D:\QM\strategy_farm\logs\work_item_97e5b05f-8367-4c15-ad8a-7c81f9ddea39.log` |
| `QM5_12582` | `XNGUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `028d4e54-7a7b-4a8f-b47b-29fa1e826841` | `D:\QM\reports\work_items\028d4e54-7a7b-4a8f-b47b-29fa1e826841\QM5_12582\20260728_164935\summary.json` |
| `QM5_12705` | `XNGUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `a8f560a0-f4e7-45d3-a7fd-3e4f0363a96e` | `D:\QM\reports\work_items\a8f560a0-f4e7-45d3-a7fd-3e4f0363a96e\QM5_12705\20260728_171122\summary.json` |
| `QM5_12975` | `NDX.DWX` | `REQUEUE_POST_MIGRATION` | `PURE_INFRA_ACTIVE_TIMEOUT` | `676c2c4a-1068-433c-80b9-802a7a1a63d1` | `D:\QM\strategy_farm\logs\work_item_676c2c4a-1068-433c-80b9-802a7a1a63d1.log` |
| `QM5_12997` | `XNGUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `23b7ed51-bff7-4a16-9400-04f64af30014` | `D:\QM\reports\work_items\23b7ed51-bff7-4a16-9400-04f64af30014\QM5_12997\20260728_170234\summary.json` |
| `QM5_13037` | `XNGUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `bc7e341b-9473-4e5b-a263-9f0ba1fc2b8c` | `D:\QM\reports\work_items\bc7e341b-9473-4e5b-a263-9f0ba1fc2b8c\QM5_13037\20260728_171413\summary.json` |
| `QM5_13212` | `SP500.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `7a722809-7747-47d2-97c3-58df881f62d9` | `D:\QM\reports\work_items\7a722809-7747-47d2-97c3-58df881f62d9\QM5_13212\20260728_172616\summary.json` |
| `QM5_20143` | `EURUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `57af5db0-b07d-4288-a8da-a6bffd08efed` | `D:\QM\reports\work_items\57af5db0-b07d-4288-a8da-a6bffd08efed\QM5_20143\20260805_070259\summary.json` |
| `QM5_20143` | `GBPUSD.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `97c83ebb-2290-4d75-916a-db0ce34d85ab` | `D:\QM\reports\work_items\97c83ebb-2290-4d75-916a-db0ce34d85ab\QM5_20143\20260801_011933\summary.json` |
| `QM5_20144` | `USDCHF.DWX` | `INVALID_NEEDS_EVIDENCE_REPAIR` | `EA_ONINIT_FAILURE_HISTORY` | `c0d0e446-29c7-4193-8aa8-54e279f8a041` | `D:\QM\reports\work_items\c0d0e446-29c7-4193-8aa8-54e279f8a041\QM5_20144\20260728_225320\summary.json` |

## Focused verification

- Parsed all three CSVs: 270 rows, 270 unique `(ea_id, symbol)` keys, disjoint
  classes, and exact union with the frozen health cohort.
- Every pair has at least 12 infrastructure rows and zero open or terminal
  non-infrastructure rows in the snapshot.
- Requeue assertions passed for all 92 rows: active registry status, canonical
  EX5 present, setfile present with no static finding, `RISK_FIXED > 0`, and
  `RISK_PERCENT = 0`.
- The single retirement aggregate still exists, hash-matches, reports 6 trades
  below floor 25, and passes every identity check.
- The CSV route-reason totals reproduce the class counts above. No database
  write statement, enqueue, retirement, process action, or guarded-file edit
  occurred.

This packet is classification evidence only. It grants no pipeline or live-use
verdict.
