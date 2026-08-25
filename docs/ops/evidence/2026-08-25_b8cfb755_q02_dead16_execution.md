# OWNER-DEC-Q02-DEAD16 execution

Router task: `b8cfb755-3e59-4051-948b-5d73239b2202`  
OWNER decision: `OWNER-DEC-Q02-DEAD16-20260825`  
Applied: 2026-08-25 21:24:38 UTC  
Result: **PASS — 16 append-only INVALID dispositions inserted; all historical rows preserved.**

## Authority and exact scope

The decision is recorded in
[`decisions/2026-08-25_owner_hma_requal_ftmo_park_q02_dead16.md`](../../../decisions/2026-08-25_owner_hma_requal_ftmo_park_q02_dead16.md),
section 3. It authorizes administrative disposition of only the 16 dead pairs
from the approved task `9e23d73f-7b94-494f-95f1-0ccd83013501` census:

- 14 `LIKELY_DEAD_DETERMINISTIC_ONINIT` pairs with identical
  `ONINIT_FAILED;INCOMPLETE_RUNS` evidence across 12/12 attempts.
- 2 `LIKELY_DEAD_DETERMINISTIC_SINGLE_REASON` pairs with identical
  `LOG_BOMB;INCOMPLETE_RUNS` evidence across 12/12 attempts.

The source census is
[`2026-08-24_q02_stranded_pairs_census.csv`](2026-08-24_q02_stranded_pairs_census.csv).
The exact source and appended row IDs are in
[`2026-08-25_b8cfb755_q02_dead16_dispositions.csv`](2026-08-25_b8cfb755_q02_dead16_dispositions.csv).

## Governed apply

`apply_q02_dead16_dispositions.py` first created a read-only plan bound to:

- the complete approved 88-row census and its exact 16-row dead subset;
- the OWNER decision document SHA-256;
- each cited source row's `(ea_id, symbol, phase, status, verdict)` identity;
- each source row's exact `payload_json` SHA-256;
- deterministic append-only destination IDs.

Plan:
`D:\QM\reports\state\b8cfb755_q02_dead16_plan_20260825.json`  
Plan SHA-256:
`cbbdb1ece87d7b908d21a5d16e2e999d835efae2512db2eac426cef225930c98`  
Target-list SHA-256:
`87281b5752be5a9be05993d1273403d6af706a3bf3161e5b5ff4f21839a7030c`

Apply revalidated all bindings under the shared factory mutation lock, then
inserted 16 new rows with:

- `status=failed`, `verdict=INVALID`;
- `disposition_only=true`;
- `owner_decision_id=OWNER-DEC-Q02-DEAD16-20260825`;
- `backtest_enqueued=false`;
- `historical_infra_rows_preserved=true`;
- SH-1 cache pair `verdict_taxonomy_stored=invalid`,
  `clean_status_stored=failed` and canonical taxonomy `invalid`.

The correct cache values avoid the representation drift identified after the
older STRANDED-182 batch. No source row was updated, deleted, or requeued.

Receipt:
`D:\QM\reports\state\b8cfb755_q02_dead16_receipt_20260825.json`  
Receipt SHA-256:
`fd7bec6b7e6a25dd854ee2f148a9dca50260dedebd95e5418296d306a6a3c359`  
Pre-apply online backup:
`D:\QM\strategy_farm\state\backups\farm_state_before_q02_dead16_20260825T212348Z_5e78e5fa.sqlite`  
Backup SHA-256:
`e7f947cbc1e4c97890dfae3ea88345b10066ecb278b5cd44958798d8ae3049ef`

## Verification and health delta

The focused `q02_stranded_exhausted_pairs` health invariant was evaluated with
the same canonical SQL immediately before and after the transaction:

| Check | Before | After |
|---|---:|---:|
| Stranded Q02 pairs | 50 | 34 |
| Exact approved dead pairs still stranded | 16 | 0 |
| DEAD16 disposition rows | 0 | 16 |

The exact delta is **−16**. Health correctly remains `FAIL` at 34 because those
remaining pairs are outside this OWNER decision; this task did not invent a
disposition for them.

Independent read-only verification after apply returned:

- disposition rows: 16; contract mismatches: 0;
- source rows with status/verdict/payload drift: 0;
- appended disposition events: 16;
- historical verdict rows updated: 0;
- `PRAGMA quick_check`: `ok`.

Focused regression:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_apply_q02_dead16_dispositions.py \
  tools/strategy_farm/tests/test_stranded182_q02_bypass.py \
  tools/strategy_farm/tests/test_health_q02_stranded.py
16 passed
```

`python -m py_compile tools/strategy_farm/apply_q02_dead16_dispositions.py`
also passed. Implementation commit on `agents/board-advisor`: `bc96f4957`.

No backtest, T_Live, AutoTrading, deployment, terminal launch, gate change,
historical verdict rewrite, deletion, merge, or main-worktree operation occurred.
