# OWNER-DEC-Q12-ADMISSION — cohort-bound admission record (immutable)

- Verdict: **ADMITTED** (cohort-bound, evidence-only). Record kind: immutable admission snapshot. Do not edit in place; corrections land as a new dated record that supersedes this one.
- Machine-readable sidecar: `docs/ops/evidence/2026-09-03_q12-admission_39b77657_execution.json` (SHA-256 `42b0b680dd0680240a5e4e4eea8704ce75b053889906ff1f018f332440156b32`)

## Zusammenfassung für OWNER (DE)

Die zum DB-Snapshot **2026-09-03T06:44:55+00:00** als `Q12_REVIEW_READY` markierte Kohorte umfasst **24 Kandidaten** (16 auditierbar, 8 auf aktiven Tracks ausgeschlossen). Jeder Kandidat ist über den zusammengesetzten Primärschlüssel `(ea_id, symbol, q11_work_item_id)` eindeutig; keine Identität ist mehrdeutig, daher wird die Zulassung **dokumentiert** (nicht REFUSED). Entsprechend dem OWNER-Entscheid **YES** vom 2026-09-03 wird ausschließlich die *gewählte Wirkung* umgesetzt: **Die Zulassung zur Buchbewertung wird festgehalten; Buchbau, Gewichte, Deployment und jede weitere Aktion bleiben separat OWNER-gesteuert.** Dieses Dokument baut kein Buch, erzeugt keine Gewichte, kein Deploy-Artefakt und keinen Live-Zustand. Der reale Zähler steht unverändert bei **qualified_pairs = 5 / 25** (kontiguierte Q14-Ketten) — die Zulassung dieser Kohorte hebt diesen Zähler nicht an und präjudiziert keinen Buchbau. Drift seit dem 08-30-Audit: 6 Retire-Kandidaten sind seit 2026-08-30T08:10:59Z `RETIRED` (30 → 24), 0 neu, 2 Paare von `Q02_NEW_IDENTITY` auf `Q09` hochgestuft (frischere gebundene Q08-Zeile).

## Provenance

- OWNER decision: **OWNER-DEC-Q12-ADMISSION**, choice **YES**, decided **2026-09-03T06:10:01.852785+00:00**
- Receipt id: `39b77657-66a6-4b2f-bb14-5a480c1fd4d7`
- Receipt SHA-256: `690d000129b418ad4afcc2a88b0fafd6cf2f6bef648c101ad290e8f432e407d4`
- Owner notes (verbatim): `wie gesagt:requed`
- Question (verbatim): Soll die aktuell als Q12_REVIEW_READY markierte Kandidatenkohorte zur Buchbewertung zugelassen werden?
- Selected effect (executed exactly): Die Zulassung wird dokumentiert; Buchbau und jede weitere Aktion bleiben separat OWNER-gesteuert.
- Recommendation at decision (superseded by YES): VERTAGT (OWNER 30./31.08.: 'einreihen, wo es Sinn macht' = Kohorten-Wiedereinstiegspfad ist die Umsetzung: 3x Q09 direkt [alle PASS], 13x Q02-Neuidentitaet gestaffelt, 6x Retire, 8 aktive Tracks). Wiedervorlage als Buchkompositions-Dossier, sobald die erste Q14-Kohorte terminal ist.
- Router task: `fc5b6144-2b93-5927-9792-c03cd8d2790d` (task_type `ops_issue`, lane `claude`, skills `owner_decision_execution`)
- Execution contract: schema `qm.owner-decision-execution-contract/v1`, SHA-256 `4a6b247e652ead13e60de6e0bea272d39b38ae6379effcde79354670b95f5b4d`
- Implementation mode: **DOCUMENT_AND_VERIFY**
- Git HEAD: `4884fbbab50342c51de9ffe3b99d796b162a3750`
- DB: `D:\QM\strategy_farm\state\farm_state.sqlite`, snapshot **2026-09-03T06:44:55+00:00**
- Read-only proof: opened `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`; `PRAGMA query_only` = `1`; `PRAGMA quick_check` = `ok`. No queue, verdict, work_item, portfolio_candidate, terminal, worker, or T_Live state was written by this task.

### Read-only queries used (verbatim)

```sql
-- cohort (marker source)
SELECT * FROM portfolio_candidates WHERE state='Q12_REVIEW_READY'
  ORDER BY CAST(REPLACE(ea_id,'QM5_','') AS INTEGER),symbol,q11_work_item_id;
-- per-member gate chain
SELECT id, phase, status, verdict, updated_at, evidence_path, setfile_path,
       gate_contract_version, data_window_start, data_window_end
  FROM work_items WHERE ea_id=? AND symbol=? ORDER BY phase, updated_at DESC, id DESC;
-- retired-pair reconciliation
SELECT ea_id,symbol,q11_work_item_id,state,updated_at FROM portfolio_candidates
  WHERE ea_id=? AND symbol=?;
-- real census counter: rebaseline_census.build_pairs + book_build_guard (Q14 terminal)
```

## Cohort marker — source used and why

The cohort is the exact set of rows in `portfolio_candidates` with `state = 'Q12_REVIEW_READY'`. This is the same source of truth used by:
- `tools/strategy_farm/audit_legacy_q12_anchors.py:151` (the 2026-08-30 audit read its 30-pair cohort from this exact query), and
- `tools/strategy_farm/mission_control_v2_data.py:841` (`COUNT(*) ... WHERE state='Q12_REVIEW_READY'` — the operator surface), and
- `tools/strategy_farm/farmctl.py:17178` (the `portfolio_candidates.state` column whose default is `'Q12_REVIEW_READY'`).

The candidate identity is the table's composite primary key `(ea_id, symbol, q11_work_item_id)`; there is no separate surrogate id column. `q11_work_item_id` is used as the per-candidate handle throughout this record.

**Cohort size: 24** — 16 audited (Q02_NEW_IDENTITY=11, Q09=5), 8 excluded on active tracks.

## Unambiguity verdict

Per-member identity completeness was checked on every member: `ea_id`, `symbol`, `q11_work_item_id` all present; the `framework/EAs/QM5_<n>_*` directory resolves to exactly one directory (EX5 present); and gate-history rows exist. **All 24/24 members are unambiguous.** No member has a missing composite key, an ambiguous EA directory, or an empty gate history. Therefore the admission record is written as **ADMITTED** (not REFUSED).

Acceptance mapping: *"A count without exact candidate identities is refused"* — every member below carries its exact composite identity, so the count (24) is backed by identities. *"Cohort drift or missing provenance aborts admission"* — the only drift since 08-30 is the 6 OWNER-approved retirements (pairs left the marker set cleanly) and 2 anchor upgrades from fresher bound Q08 rows; no member of the current cohort has missing provenance (see the reconciliation section). The cohort is stable and fully provenanced at the snapshot instant.

## Counter state (2026-09-03) — no overclaim

- `book_build_guard` real census: **qualified_pairs = 5** (minimum for a book: 25); allowed = `False`; distinct_eas = 5, strategy_families = 5.
- Guard reasons (why no book): ['qualified_pairs_below_minimum: 5 < 25', 'owner_order_missing: venue=dxz order_dir=C:\\QM\\repo\\decisions']
- Terminal requalification gate: `Q14`. The census counts only pairs whose **highest contiguous valid gate** equals the terminal gate.
- The 5 qualified pairs (real census, independent of this admission cohort):
  - `QM5_10706` / `GBPUSD.DWX` — highest contiguous valid gate `Q14`
  - `QM5_11421` / `EURUSD.DWX` — highest contiguous valid gate `Q14`
  - `QM5_11422` / `USDCAD.DWX` — highest contiguous valid gate `Q14`
  - `QM5_13054` / `XTIUSD.DWX` — highest contiguous valid gate `Q14`
  - `QM5_1537` / `XAGUSD.DWX` — highest contiguous valid gate `Q14`

**This admission does not change the counter.** Admitting the 24-member Q12-ready cohort to *book evaluation* neither raises qualified_pairs above 5 nor authorizes a book: three of the five qualified pairs are the active-opt-fork tracks already excluded from this cohort's audit, and the census remains far below the 25-pair floor.

## Correlations

No stored correlation artifact bound to this Q12-ready cohort exists under `docs/ops/evidence/`. The only correlation matrices present (`2026-08-23_sp_f2_sleeve_correlation_matrix.csv`, `ftmo_decorrelation_test_2026-07-10.md`) are scoped to other sleeves/programmes, not to this 24-member set. Per the execution contract this record does **not** compute a new correlation matrix; correlation analysis is part of the separate, OWNER-gated book-evaluation step.

## Per-member provenance

Hash cells show 12-char prefixes; `expected` = hash bound on the DB rows/evidence, `current` = hash of the file in the canonical working tree C:/QM/repo at verification time (branch agents/board-advisor, HEAD f6421cb5, descendant of the git HEAD above; the tree carried uncommitted recompiled ex5 for QM5_10700/11910/12710 — exactly the new-identity signal reported here). `MISMATCH`/`UNBOUND` on EX5 or setfile means the current repo bytes are a **new identity since** the bound evidence (these members re-enter at `Q02_NEW_IDENTITY`). Full gate chains (latest terminal row per phase, with row ids, verdicts, `vclass`, evidence paths+SHA-256) are in the JSON sidecar.

`vclass` is the coarse class from `rebaseline_census.py:vclass` for the anchor row's verdict: `FAIL_SOFT` classifies as **PASS** (economically valid, above the economic floor), `INFRA_FAIL` as **INFRA** (non-economic infrastructure outcome, not a strategy failure). The `verdict/vclass` pair is a provenance readout, not a re-grade.

| # | Candidate (ea_id / symbol / q11_work_item_id) | TF | Excl / Anchor 08-30 → 09-03 | Q08 anchor row (verdict / vclass) | EX5 exp/cur | Setfile exp/cur | MQ5 exp/cur |
|---|---|---|---|---|---|---|---|
| 1 | `QM5_1556` / `XAUUSD.DWX` / `e241bacd-5681-4172-a785-a475fd25140b` | D1 | — / Q02_NEW_IDENTITY → Q09 | `ea0cd059` FAIL_SOFT/PASS | 0962ca65776f/0962ca65776f MATCH | 01163a9b4bf3/01163a9b4bf3 MATCH | 3b44aa66f7ff/3b44aa66f7ff MATCH |
| 2 | `QM5_1567` / `EURUSD.DWX` / `89acf6eb-581b-411b-9aaf-2f19c12c68c5` | H4 | REQUAL8 / EXCLUDED_ACTIVE_TRACK → EXCLUDED_ACTIVE_TRACK | `e8c1e63a` FAIL_SOFT/PASS | aee0eb60798e/aee0eb60798e MATCH | 1282e2adba70/2e9347a132ed MISMATCH | 685af902fd61/a9531d333dbb MISMATCH |
| 3 | `QM5_10403` / `XAUUSD.DWX` / `e12845b9-04fe-4d97-af43-93d37268f2f4` | D1 | — / Q09 → Q09 | `7fd4caf6` FAIL_SOFT/PASS | f927f07f4657/f927f07f4657 MATCH | 9a6fab053d38/9a6fab053d38 MATCH | b38cfd471fd3/b38cfd471fd3 MATCH |
| 4 | `QM5_10513` / `XAUUSD.DWX` / `dd06ad11-3e9e-4d2b-b850-308253539768` | D1 | ACTIVE_NEWS_MATRIX / EXCLUDED_ACTIVE_TRACK → EXCLUDED_ACTIVE_TRACK | `da5dc579` PASS/PASS | 3c7f46a1da2d/3c7f46a1da2d MATCH | 4810a3486b6d/34b992479314 MISMATCH | dfccacd6fe90/dfccacd6fe90 MATCH |
| 5 | `QM5_10700` / `XAUUSD.DWX` / `55af03d6-12d2-485e-a154-e890cb02790a` | H1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `fb35a79a` FAIL_SOFT/PASS | UNBOUND/5fbf2ba00482 UNBOUND | UNBOUND/a684dad25b6c UNBOUND | UNBOUND/064d670b736e UNBOUND |
| 6 | `QM5_10706` / `GBPUSD.DWX` / `22fca5c5-4480-4c49-95ef-0194086e5de3` | H1 | ACTIVE_OPT_FORK / EXCLUDED_ACTIVE_TRACK → EXCLUDED_ACTIVE_TRACK | `7855588a` PASS/PASS | eaffda6f03c8/eaffda6f03c8 MATCH | 056f2c12c1be/e39ea2ffa324 MISMATCH | 909327914d7f/909327914d7f MATCH |
| 7 | `QM5_10815` / `EURUSD.DWX` / `a7398b69-db24-4d47-99d7-ee7bf1584583` | H1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `a4efdfd3` FAIL_SOFT/PASS | UNBOUND/af1b535b3cd6 UNBOUND | UNBOUND/4a22648d750f UNBOUND | UNBOUND/cdbf22e77035 UNBOUND |
| 8 | `QM5_10815` / `GDAXI.DWX` / `ae828ece-f1ab-4670-9f87-214b0400dc5a` | H1 | REQUAL8 / EXCLUDED_ACTIVE_TRACK → EXCLUDED_ACTIVE_TRACK | `e1112871` FAIL_SOFT/PASS | UNBOUND/af1b535b3cd6 UNBOUND | UNBOUND/01a4f1dc97a8 UNBOUND | UNBOUND/cdbf22e77035 UNBOUND |
| 9 | `QM5_10911` / `GDAXI.DWX` / `545758f3-e272-447c-985b-6976fe06c6ac` | H1 | — / Q09 → Q09 | `55256268` FAIL_SOFT/PASS | 5199e260020b/5199e260020b MATCH | bfc76e20be73/bfc76e20be73 MATCH | 122d1a4e3248/122d1a4e3248 MATCH |
| 10 | `QM5_10939` / `GBPUSD.DWX` / `dfeb6afb-61e6-4deb-9e61-d8873271eb70` | H4 | REQUAL8 / EXCLUDED_ACTIVE_TRACK → EXCLUDED_ACTIVE_TRACK | `8234812d` INFRA_FAIL/INFRA | 812fc52a90f0/812fc52a90f0 MATCH | dc7c216b8559/dc7c216b8559 MATCH | 619331975f50/619331975f50 MATCH |
| 11 | `QM5_10940` / `XAUUSD.DWX` / `e25da444-2e84-402c-9ff1-a4f7493731a6` | H4 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `0c185c6d` FAIL_SOFT/PASS | UNBOUND/cb0ff3098e40 UNBOUND | UNBOUND/0aa3751aa5ea UNBOUND | UNBOUND/1104f8e76c55 UNBOUND |
| 12 | `QM5_11132` / `SP500.DWX` / `1ea996fd-ef55-48ce-93d8-2b0a13c4f19a` | D1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `1759533d` INFRA_FAIL/INFRA | e3dea054cce0/e3dea054cce0 MATCH | 8610f1e0d1d0/d404e79c605e MISMATCH | 5839af64779d/5839af64779d MATCH |
| 13 | `QM5_11165` / `AUDCAD.DWX` / `7a8c7433-07d2-451d-a96d-4570d7fc5c17` | H1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `565b76a0` INFRA_FAIL/INFRA | b109a902f98f/b109a902f98f MATCH | 5e8a0752c1cc/ca58fdbf50a2 MISMATCH | e79d176ddf3b/e79d176ddf3b MATCH |
| 14 | `QM5_11165` / `EURUSD.DWX` / `80bcdc1b-74ae-40f4-82be-b0b87771d4ea` | H1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `d528948d` INFRA_FAIL/INFRA | b109a902f98f/b109a902f98f MATCH | 8277892cf2f7/2ad91fe57685 MISMATCH | e79d176ddf3b/e79d176ddf3b MATCH |
| 15 | `QM5_11421` / `EURUSD.DWX` / `6c25bcc5-2050-44a4-ab52-bbbb4bffb5d6` | D1 | REQUAL8,ACTIVE_OPT_FORK / EXCLUDED_ACTIVE_TRACK → EXCLUDED_ACTIVE_TRACK | `c93263aa` PASS/PASS | 9dd7facd1da7/9dd7facd1da7 MATCH | 7b87dbf2a4a6/7b87dbf2a4a6 MATCH | b5dfd159b462/b5dfd159b462 MATCH |
| 16 | `QM5_11422` / `USDCAD.DWX` / `99ab79c9-1c13-40ff-8b71-0b72fd05db91` | D1 | ACTIVE_OPT_FORK / EXCLUDED_ACTIVE_TRACK → EXCLUDED_ACTIVE_TRACK | `d3907c1a` PASS/PASS | 2b98e9e90231/2b98e9e90231 MATCH | 715bce2fb876/715bce2fb876 MATCH | a68b9f02372e/a68b9f02372e MATCH |
| 17 | `QM5_11708` / `EURUSD.DWX` / `790edb77-fe2d-4ba8-8127-0c8e5cfb5d33` | D1 | — / Q02_NEW_IDENTITY → Q09 | `861577c0` FAIL_SOFT/PASS | baff181fe3c9/baff181fe3c9 MATCH | 75fa2768b440/75fa2768b440 MATCH | 9b4c843be029/9b4c843be029 MATCH |
| 18 | `QM5_11910` / `NZDUSD.DWX` / `8b849344-89e4-42a4-b697-026e81ff6a65` | D1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `6757567a` FAIL_SOFT/PASS | 40fc2b902178/e18d477e63c4 MISMATCH | 262faae61afa/84b6dee70e76 MISMATCH | b1c7e241ad27/47ccfa2c699e MISMATCH |
| 19 | `QM5_12567` / `XAUUSD.DWX` / `d0dae336-db27-4b85-b6ea-c91f6717b5ef` | D1 | REQUAL8 / EXCLUDED_ACTIVE_TRACK → EXCLUDED_ACTIVE_TRACK | `c089a98d` INFRA_FAIL/INFRA | 8d901924fe7d/8d901924fe7d MATCH | 12c1dfe5d4e7/12c1dfe5d4e7 MATCH | 8a5dc80942f8/8a5dc80942f8 MATCH |
| 20 | `QM5_12580` / `AUDUSD.DWX` / `cb8e8ece-98ef-4a25-9eac-2f25656ab594` | D1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `92e319b4` FAIL_SOFT/PASS | UNBOUND/1494d2ef979b UNBOUND | UNBOUND/eed48aabeb4c UNBOUND | UNBOUND/d3183e40c540 UNBOUND |
| 21 | `QM5_12710` / `XTIUSD.DWX` / `c60924a7-3fd4-49d9-a39a-7b9e67a9dd62` | D1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `95a0e11a` FAIL_SOFT/PASS | UNBOUND/11474d4cffcc UNBOUND | UNBOUND/e3ccc3412fd8 UNBOUND | UNBOUND/d90652c32fc3 UNBOUND |
| 22 | `QM5_12778` / `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` / `0b1fddba-6c4e-47ec-b9b3-6b54273e5832` | D1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `8637b758` FAIL_SOFT/PASS | UNBOUND/2a105cfbb364 UNBOUND | UNBOUND/0e7949276927 UNBOUND | UNBOUND/132a501d9468 UNBOUND |
| 23 | `QM5_12966` / `GDAXI.DWX` / `f260dabb-deb6-4117-8174-5046678cfd3a` | D1 | — / Q02_NEW_IDENTITY → Q02_NEW_IDENTITY | `9c11e621` FAIL_SOFT/PASS | UNBOUND/ad317e73663c UNBOUND | UNBOUND/0d760a0e7048 UNBOUND | UNBOUND/7e39f7732739 UNBOUND |
| 24 | `QM5_12969` / `USDJPY.DWX` / `de65a075-6bd9-49c9-a775-624a32fc4214` | M30 | — / Q09 → Q09 | `f14ad921` FAIL_SOFT/PASS | 938a35aa6b6d/938a35aa6b6d MATCH | abaac898cfee/abaac898cfee MATCH | 4e9503fd61e9/4e9503fd61e9 MATCH |

### Q08 anchor evidence paths + SHA-256 (per member)

1. `QM5_1556`/`XAUUSD.DWX` — Q08 wi `ea0cd059-07f1-47c0-ab19-42d97f49fa04` (done/FAIL_SOFT, contract `v4`), evidence `D:\QM\reports\work_items\ea0cd059-07f1-47c0-ab19-42d97f49fa04\QM5_1556\Q08\XAUUSD_DWX\aggregate.json` (sha256 `35f897ce641dfe5f607b8727f1a79f99b1c8e7d0e8bddfb3fa5996753a923dc3`); portfolio/Q11 wi `e241bacd-5681-4172-a785-a475fd25140b` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\e241bacd-5681-4172-a785-a475fd25140b\QM5_1556\Q09_PORTFOLIO\XAUUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
2. `QM5_1567`/`EURUSD.DWX` — Q08 wi `e8c1e63a-e06c-4988-9ae7-54771bc1fe8c` (done/FAIL_SOFT, contract `legacy`), evidence `D:\QM\reports\work_items\e8c1e63a-e06c-4988-9ae7-54771bc1fe8c\QM5_1567\Q08\EURUSD_DWX\aggregate.json` (sha256 `248346ccb524ad7927c931a71136c9ab55fe22089e5efb5de9dcd6aeef012bc6`); portfolio/Q11 wi `89acf6eb-581b-411b-9aaf-2f19c12c68c5` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\89acf6eb-581b-411b-9aaf-2f19c12c68c5\QM5_1567\Q09_PORTFOLIO\EURUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
3. `QM5_10403`/`XAUUSD.DWX` — Q08 wi `7fd4caf6-b599-4833-a431-a132a404b60b` (done/FAIL_SOFT, contract `v4`), evidence `D:\QM\reports\work_items\7fd4caf6-b599-4833-a431-a132a404b60b\QM5_10403\Q08\XAUUSD_DWX\aggregate.json` (sha256 `bb57935abf1f48a0aeda30a3ac9d124f34108d85369cc1da504bc773d724556e`); portfolio/Q11 wi `e12845b9-04fe-4d97-af43-93d37268f2f4` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\e12845b9-04fe-4d97-af43-93d37268f2f4\QM5_10403\Q09_PORTFOLIO\XAUUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
4. `QM5_10513`/`XAUUSD.DWX` — Q08 wi `da5dc579-3d0a-4591-80e8-dc64eb52d81e` (done/PASS, contract `v4`), evidence `D:\QM\reports\work_items\da5dc579-3d0a-4591-80e8-dc64eb52d81e\QM5_10513\Q08\XAUUSD_DWX\aggregate.json` (sha256 `950338ecd652f27f2e15f0a44d1ba638c1ffcfe6142bed6bedd1ce1a73f8bedd`); portfolio/Q11 wi `dd06ad11-3e9e-4d2b-b850-308253539768` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\portfolio\recert_20260627T113037+0000\summary.json` (sha256 `49670bb3bb7c7e7106113bbe5ec14b651d0bf9daf329c33073a05918e26206e7`).
5. `QM5_10700`/`XAUUSD.DWX` — Q08 wi `fb35a79a-1541-4a35-90a4-056f3e5363db` (done/FAIL_SOFT, contract `legacy`), evidence `D:\QM\reports\work_items\fb35a79a-1541-4a35-90a4-056f3e5363db\QM5_10700\Q08\XAUUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`); portfolio/Q11 wi `55af03d6-12d2-485e-a154-e890cb02790a` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\55af03d6-12d2-485e-a154-e890cb02790a\QM5_10700\Q09_PORTFOLIO\XAUUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
6. `QM5_10706`/`GBPUSD.DWX` — Q08 wi `7855588a-9ff8-4896-8d8d-16e1fdc25f72` (done/PASS, contract `v4`), evidence `D:\QM\reports\work_items\7855588a-9ff8-4896-8d8d-16e1fdc25f72\QM5_10706\Q08\GBPUSD_DWX\aggregate.json` (sha256 `acd4b422ccfd41c7a20b234782afdd35acd4ea34c48874ff2e71a5840c2ef83d`); portfolio/Q11 wi `22fca5c5-4480-4c49-95ef-0194086e5de3` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\22fca5c5-4480-4c49-95ef-0194086e5de3\QM5_10706\Q09_PORTFOLIO\GBPUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
7. `QM5_10815`/`EURUSD.DWX` — Q08 wi `a4efdfd3-e2a1-4f15-a40f-871a5bde9a2d` (done/FAIL_SOFT, contract `legacy`), evidence `D:\QM\reports\work_items\a4efdfd3-e2a1-4f15-a40f-871a5bde9a2d\QM5_10815\Q08\EURUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`); portfolio/Q11 wi `a7398b69-db24-4d47-99d7-ee7bf1584583` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\a7398b69-db24-4d47-99d7-ee7bf1584583\QM5_10815\Q09_PORTFOLIO\EURUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
8. `QM5_10815`/`GDAXI.DWX` — Q08 wi `e1112871-12a0-4ee9-a565-9f9f19ff54aa` (done/FAIL_SOFT, contract `legacy`), evidence `D:\QM\reports\work_items\e1112871-12a0-4ee9-a565-9f9f19ff54aa\QM5_10815\Q08\GDAXI_DWX\aggregate.json` (sha256 `FILE_ABSENT`); portfolio/Q11 wi `ae828ece-f1ab-4670-9f87-214b0400dc5a` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\ae828ece-f1ab-4670-9f87-214b0400dc5a\QM5_10815\Q09_PORTFOLIO\GDAXI_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
9. `QM5_10911`/`GDAXI.DWX` — Q08 wi `55256268-50f8-4d94-8d9a-83652c64b013` (done/FAIL_SOFT, contract `v4`), evidence `D:\QM\reports\work_items\55256268-50f8-4d94-8d9a-83652c64b013\QM5_10911\Q08\GDAXI_DWX\aggregate.json` (sha256 `df2d728c96af9e853f0eebfb09e371340d8f4a6018f67465baecfff4374ede37`); portfolio/Q11 wi `545758f3-e272-447c-985b-6976fe06c6ac` phase `Q08` (v4≈`Q08`) evidence `D:\QM\reports\work_items\545758f3-e272-447c-985b-6976fe06c6ac\QM5_10911\Q08\GDAXI_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
10. `QM5_10939`/`GBPUSD.DWX` — Q08 wi `8234812d-b9ff-4652-b4a3-48bcdc41c2b5` (done/INFRA_FAIL, contract `v4`), evidence `D:\QM\reports\work_items\8234812d-b9ff-4652-b4a3-48bcdc41c2b5\QM5_10939\Q08\GBPUSD_DWX\aggregate.json` (sha256 `460099aed83e2834c5f35ad63e09def42ec8a0dc2ebb4416cb33e5fe04021ad3`); portfolio/Q11 wi `dfeb6afb-61e6-4deb-9e61-d8873271eb70` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\dfeb6afb-61e6-4deb-9e61-d8873271eb70\QM5_10939\Q09_PORTFOLIO\GBPUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
11. `QM5_10940`/`XAUUSD.DWX` — Q08 wi `0c185c6d-f25c-4e5c-bf71-0932f9e61cee` (done/FAIL_SOFT, contract `legacy`), evidence `D:\QM\reports\work_items\0c185c6d-f25c-4e5c-bf71-0932f9e61cee\QM5_10940\Q08\XAUUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`); portfolio/Q11 wi `e25da444-2e84-402c-9ff1-a4f7493731a6` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\portfolio\recert_20260627T113037+0000\summary.json` (sha256 `49670bb3bb7c7e7106113bbe5ec14b651d0bf9daf329c33073a05918e26206e7`).
12. `QM5_11132`/`SP500.DWX` — Q08 wi `1759533d-7600-40d1-ad1c-914d7c47c534` (done/INFRA_FAIL, contract `legacy`), evidence `D:\QM\reports\work_items\1759533d-7600-40d1-ad1c-914d7c47c534\QM5_11132\Q08\SP500_DWX\aggregate.json` (sha256 `ca357ca15c83d5cfedc5c8682786b113764e99bff9cf570dccd05f310b26f645`); portfolio/Q11 wi `1ea996fd-ef55-48ce-93d8-2b0a13c4f19a` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\portfolio\recert_20260627T113037+0000\summary.json` (sha256 `49670bb3bb7c7e7106113bbe5ec14b651d0bf9daf329c33073a05918e26206e7`).
13. `QM5_11165`/`AUDCAD.DWX` — Q08 wi `565b76a0-a74c-40b2-ba4a-e5f29c334b96` (done/INFRA_FAIL, contract `legacy`), evidence `D:\QM\reports\work_items\565b76a0-a74c-40b2-ba4a-e5f29c334b96\QM5_11165\Q08\AUDCAD_DWX\aggregate.json` (sha256 `db5daed6cd6b00d96b0240c4776e16caa35645cb5986bac8cdf7fbb27304aac8`); portfolio/Q11 wi `7a8c7433-07d2-451d-a96d-4570d7fc5c17` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\7a8c7433-07d2-451d-a96d-4570d7fc5c17\QM5_11165\Q09_PORTFOLIO\AUDCAD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
14. `QM5_11165`/`EURUSD.DWX` — Q08 wi `d528948d-222a-4279-bbe8-dee17f70f3d4` (done/INFRA_FAIL, contract `legacy`), evidence `D:\QM\reports\work_items\d528948d-222a-4279-bbe8-dee17f70f3d4\QM5_11165\Q08\EURUSD_DWX\aggregate.json` (sha256 `b2637f9c37768e896556483957e2a5e6f6c3cab5b0a5779a21cd462010b50444`); portfolio/Q11 wi `80bcdc1b-74ae-40f4-82be-b0b87771d4ea` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\80bcdc1b-74ae-40f4-82be-b0b87771d4ea\QM5_11165\Q09_PORTFOLIO\EURUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
15. `QM5_11421`/`EURUSD.DWX` — Q08 wi `c93263aa-a707-45ea-a915-204ec59df077` (done/PASS, contract `v4`), evidence `D:\QM\reports\work_items\c93263aa-a707-45ea-a915-204ec59df077\QM5_11421\Q08\EURUSD_DWX\aggregate.json` (sha256 `d465366150d1e41836c5cfd4ab31b5273095f29848496a9302800dd80d2f090d`); portfolio/Q11 wi `6c25bcc5-2050-44a4-ab52-bbbb4bffb5d6` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\6c25bcc5-2050-44a4-ab52-bbbb4bffb5d6\QM5_11421\Q09_PORTFOLIO\EURUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
16. `QM5_11422`/`USDCAD.DWX` — Q08 wi `d3907c1a-dc69-4498-be2f-80b064a2c02f` (done/PASS, contract `legacy`), evidence `D:\QM\reports\work_items\d3907c1a-dc69-4498-be2f-80b064a2c02f\QM5_11422\Q08\USDCAD_DWX\aggregate.json` (sha256 `be78ca200e8fc4186a0311b0850eaa8de07e5d2d1aea4a03b95550a46ce92b9a`); portfolio/Q11 wi `99ab79c9-1c13-40ff-8b71-0b72fd05db91` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\99ab79c9-1c13-40ff-8b71-0b72fd05db91\QM5_11422\Q09_PORTFOLIO\USDCAD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
17. `QM5_11708`/`EURUSD.DWX` — Q08 wi `861577c0-2a5b-42a2-9a6a-2ea9cfb9caf5` (done/FAIL_SOFT, contract `v4`), evidence `D:\QM\reports\work_items\861577c0-2a5b-42a2-9a6a-2ea9cfb9caf5\QM5_11708\Q08\EURUSD_DWX\aggregate.json` (sha256 `56db787415587ae4a63b9b4f99ad9b0cc45c9ad80a0bdc04b311f1bc2c92ba31`); portfolio/Q11 wi `790edb77-fe2d-4ba8-8127-0c8e5cfb5d33` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\790edb77-fe2d-4ba8-8127-0c8e5cfb5d33\QM5_11708\Q09_PORTFOLIO\EURUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
18. `QM5_11910`/`NZDUSD.DWX` — Q08 wi `6757567a-000b-4bcb-b292-75c8cdc2f460` (done/FAIL_SOFT, contract `v4`), evidence `D:\QM\reports\work_items\6757567a-000b-4bcb-b292-75c8cdc2f460\QM5_11910\Q08\NZDUSD_DWX\aggregate.json` (sha256 `1b6323ade3d27f41b48b080da87c34bfb5ffbdab3f964570c1d3c2dfd12c0181`); portfolio/Q11 wi `8b849344-89e4-42a4-b697-026e81ff6a65` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\8b849344-89e4-42a4-b697-026e81ff6a65\QM5_11910\Q09_PORTFOLIO\NZDUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
19. `QM5_12567`/`XAUUSD.DWX` — Q08 wi `c089a98d-2879-4151-8bb4-fbe722cb1b46` (done/INFRA_FAIL, contract `v4`), evidence `D:\QM\reports\work_items\c089a98d-2879-4151-8bb4-fbe722cb1b46\QM5_12567\Q08\XAUUSD_DWX\aggregate.json` (sha256 `3653803ad4210c69384d1399991531d17f5778814e6dc690a2838cc4fc9da817`); portfolio/Q11 wi `d0dae336-db27-4b85-b6ea-c91f6717b5ef` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\d0dae336-db27-4b85-b6ea-c91f6717b5ef\QM5_12567\Q09_PORTFOLIO\XAUUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
20. `QM5_12580`/`AUDUSD.DWX` — Q08 wi `92e319b4-b40d-4db1-961c-e212c3f93d67` (done/FAIL_SOFT, contract `legacy`), evidence `D:\QM\reports\work_items\92e319b4-b40d-4db1-961c-e212c3f93d67\QM5_12580\Q08\AUDUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`); portfolio/Q11 wi `cb8e8ece-98ef-4a25-9eac-2f25656ab594` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\cb8e8ece-98ef-4a25-9eac-2f25656ab594\QM5_12580\Q09_PORTFOLIO\AUDUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
21. `QM5_12710`/`XTIUSD.DWX` — Q08 wi `95a0e11a-d8f0-45bb-89e2-3e5cc16642ca` (done/FAIL_SOFT, contract `legacy`), evidence `D:\QM\reports\work_items\95a0e11a-d8f0-45bb-89e2-3e5cc16642ca\QM5_12710\Q08\XTIUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`); portfolio/Q11 wi `c60924a7-3fd4-49d9-a39a-7b9e67a9dd62` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\c60924a7-3fd4-49d9-a39a-7b9e67a9dd62\QM5_12710\Q09_PORTFOLIO\XTIUSD_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
22. `QM5_12778`/`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` — Q08 wi `8637b758-4763-4a1c-a88e-f2001a1da7b4` (done/FAIL_SOFT, contract `legacy`), evidence `D:\QM\reports\work_items\8637b758-4763-4a1c-a88e-f2001a1da7b4\QM5_12778\Q08\QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1\aggregate.json` (sha256 `FILE_ABSENT`); portfolio/Q11 wi `0b1fddba-6c4e-47ec-b9b3-6b54273e5832` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\0b1fddba-6c4e-47ec-b9b3-6b54273e5832\QM5_12778\Q09_PORTFOLIO\QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1\aggregate.json` (sha256 `FILE_ABSENT`).
23. `QM5_12966`/`GDAXI.DWX` — Q08 wi `9c11e621-8558-4677-b7ee-d4fc13e9e67e` (done/FAIL_SOFT, contract `legacy`), evidence `D:\QM\reports\work_items\9c11e621-8558-4677-b7ee-d4fc13e9e67e\QM5_12966\Q08\GDAXI_DWX\aggregate.json` (sha256 `FILE_ABSENT`); portfolio/Q11 wi `f260dabb-deb6-4117-8174-5046678cfd3a` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\f260dabb-deb6-4117-8174-5046678cfd3a\QM5_12966\Q09_PORTFOLIO\GDAXI_DWX\aggregate.json` (sha256 `FILE_ABSENT`).
24. `QM5_12969`/`USDJPY.DWX` — Q08 wi `f14ad921-721e-413d-a2de-6506ceaf8483` (done/FAIL_SOFT, contract `v4`), evidence `D:\QM\reports\work_items\f14ad921-721e-413d-a2de-6506ceaf8483\QM5_12969\Q08\USDJPY_DWX\aggregate.json` (sha256 `f47e8f6ee06c9650343941dacebe7b5b58394532f8f0baf1644241ec00b3cfeb`); portfolio/Q11 wi `de65a075-6bd9-49c9-a775-624a32fc4214` phase `Q09_PORTFOLIO` (v4≈`Q10_PORTFOLIO`) evidence `D:\QM\reports\work_items\de65a075-6bd9-49c9-a775-624a32fc4214\QM5_12969\Q09_PORTFOLIO\USDJPY_DWX\aggregate.json` (sha256 `FILE_ABSENT`).

### Exclusions (active-track members reported for complete cohort coverage)

| Candidate | Exclusion |
|---|---|
| `QM5_1567` / `EURUSD.DWX` | REQUAL8 |
| `QM5_10513` / `XAUUSD.DWX` | ACTIVE_NEWS_MATRIX |
| `QM5_10706` / `GBPUSD.DWX` | ACTIVE_OPT_FORK |
| `QM5_10815` / `GDAXI.DWX` | REQUAL8 |
| `QM5_10939` / `GBPUSD.DWX` | REQUAL8 |
| `QM5_11421` / `EURUSD.DWX` | REQUAL8+ACTIVE_OPT_FORK |
| `QM5_11422` / `USDCAD.DWX` | ACTIVE_OPT_FORK |
| `QM5_12567` / `XAUUSD.DWX` | REQUAL8 |

No member's identity is ambiguous; the only per-member carve-outs are the 8 active-track exclusions above (audited-for-anchor only when off an active track, exactly as in the 08-30 audit).

## Reconciliation against the 2026-08-30 audit

- 08-30 audit (`docs/ops/evidence/2026-08-30_359988fb_legacy_q12_anchor_audit.md`, md SHA-256 `0451794fc1ffa6868bee7ae88fad00a18d718d7b76247ff58b1d7c438e43292b`; json SHA-256 `574ae1fdad48cbecd933ddd6f17fc34d9797eda7d0e1a47d666e35e18a4daaf8`): 30-pair cohort, 22 audited, 8 excluded, anchors Q02_NEW_IDENTITY=13 / Q09=3 / RETIRE_CANDIDATE=6.
- 09-03 cohort: 24-pair cohort, 16 audited, 8 excluded, anchors Q02_NEW_IDENTITY=11 / Q09=5.
- **Retired (left the marker, 30 → 24):** the 6 08-30 `RETIRE_CANDIDATE` pairs are now `portfolio_candidates.state='RETIRED'` (updated 2026-08-30T08:10:59Z) via the OWNER-approved append-only retirement (`tools/strategy_farm/apply_legacy_cohort_retire6.py`, decision `docs/ops/evidence/2026-08-30_7d561f89_legacy_cohort_retire6.md`): `QM5_10476/USDCAD.DWX`, `QM5_10919/XTIUSD.DWX`, `QM5_11421/AUDUSD.DWX`, `QM5_12567/XNGUSD.DWX`, `QM5_13117/…COINTEGRATION_D1`, `QM5_1567/XAGUSD.DWX`.
- **Re-entered / added:** none (0 new members since 08-30).
- **Anchor upgrades (gained a fresher v4-reusable Q08 row):** `QM5_1556/XAUUSD.DWX` and `QM5_11708/EURUSD.DWX` moved `Q02_NEW_IDENTITY → Q09` — a newer `Q08` `done` row (ids `ea0cd059…` and `861577c0…`) now binds the current working-copy setfile (setfile hash MISMATCH → MATCH), so the hash-bound Q08 is reusable and the pair re-enters at Q09.
- No other member changed anchor class. The remaining 3 08-30 `Q09` pairs (`QM5_10403/XAUUSD`, `QM5_10911/GDAXI`, `QM5_12969/USDJPY`) are still `Q09`; the 08-30 `Q02_NEW_IDENTITY` set minus the 2 upgrades is unchanged.

## What this record does NOT do

- It does **not** build a book, portfolio manifest, sleeve, or basket.
- It does **not** compute or store weights, allocations, or a correlation matrix.
- It does **not** create a deploy artifact, manifest, or any T_Live/live-book state.
- It does **not** change any gate threshold, gate criterion, verdict, trade stream, queue row, `portfolio_candidates` state, or the real census counter.
- It does **not** enable AutoTrading, place orders, or authorize deployment.
- Later book construction, weighting, and deployment each remain a **separate OWNER decision** with its own authorization; this admission authorizes only evidence-backed *book evaluation* of the frozen cohort.

## Shadow book-evaluation task (to be commissioned separately — NOT enqueued here)

Per the contract's allowed action "Commission a separate shadow book-evaluation task", the CEO/orchestrator may enqueue the evidence-only evaluation below. This record does **not** enqueue it. Suggested router command (run from `C:/QM/repo`):

```powershell
cd C:/QM/repo
python tools/strategy_farm/agent_router.py enqueue ops_issue --priority 55 \
  --payload-json '{
    "operation": "shadow_book_evaluation",
    "title": "Shadow book-evaluation of the OWNER-DEC-Q12-ADMISSION cohort (evidence-only)",
    "target_agent_profile": "claude",
    "required_capabilities": ["summary"],
    "admission_record": "docs/ops/evidence/2026-09-03_q12-admission_39b77657_execution.md",
    "admission_record_sidecar": "docs/ops/evidence/2026-09-03_q12-admission_39b77657_execution.json",
    "scope": "evidence_only",
    "allowed_actions": ["read-only correlation/among-cohort analysis", "draft a book-composition dossier for OWNER"],
    "forbidden_actions": ["book construction", "weights", "deploy artifact", "live/T_Live mutation", "gate/verdict/queue mutation"],
    "review_required": "INDEPENDENT_ORCHESTRATOR_CLOSEOUT"
  }'
```

The evaluation stays read-only and produces only an OWNER-facing dossier; a book is built only after a further explicit OWNER decision and once the real census clears its floor (currently 5/25).

## Verification & acceptance

- DB opened read-only (`mode=ro`, `PRAGMA query_only=ON`, `quick_check=ok`); no runtime, queue, verdict, or live state mutated.
- Cohort read from `portfolio_candidates.state='Q12_REVIEW_READY'`; every member carries its exact composite identity; anchors, hashes and evidence SHA-256 computed from the canonical checkout at the git HEAD above.
- Acceptance criteria satisfied: exact candidate identities present (count backed by identities); no cohort drift or missing provenance for current members (retirements/upgrades reconciled); no book manifest / weights / deploy artifact / live state created; later book construction left as a separate OWNER decision.
- Selected effect executed exactly (DOCUMENT_AND_VERIFY): admission documented; everything else stays OWNER-gated.

Verdict: **ADMITTED — COHORT-BOUND, EVIDENCE-ONLY, IMMUTABLE.**
