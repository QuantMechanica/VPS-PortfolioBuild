# Q10 realignment E1/E2 — implementation and read-only evidence

Task: `9b40ff25-098e-4a7a-a78c-d510ba7b763b` (`OPS-Q10-REALIGN-E1-E2`)

Authority: OWNER decision `decisions/2026-08-22_owner_pipeline_realignment_q09_q11.md`, E1/E2.

Verdict: **READY FOR CLAUDE REVIEW; NO LIVE MIGRATION OR AUTOPILOT ACTION AUTHORIZED BY THIS TASK.**

## Implemented contract

- Q10 requires one authenticated `Q09_NEWS` edge whose required verdict set is exactly
  `CONFIG_LOCKED`. The locked result must still authenticate its evidence hash, exactly two
  arms, and five distinct canonical seeds in each arm.
- A same-Q08-lineage terminal `Q09_PORTFOLIO` sibling is optional information. When present,
  the newest sibling is bound with all terminal outcomes in its required-verdict set:
  `PASS_PORTFOLIO`, `FAIL_PORTFOLIO`, and `FAIL_SYSTEM`. Missing is allowed; present but
  unauthenticated evidence fails closed.
- Q10 confirmation bindings and manifests retain the portfolio object, with all three fields
  null when no sibling exists.
- `candidate_qualifications` no longer requires portfolio fields for `QUALIFIED`. If either
  optional field is supplied, both the work-item and evidence hash are required and the
  terminal verdict, Q10 edge, and common Q08 lineage are authenticated.
- The additive schema version is 6. The v5-to-v6 test rebuilds the qualification trigger,
  verifies the optional-portfolio semantics, and proves the protected legacy-row hash and
  legacy rows are unchanged.
- Both the direct cascade and the repair backfill admit done Q08 `PASS` and `FAIL_SOFT` rows
  without a portfolio prerequisite. The created Q09 row remains under the standard sealed-plan
  hold. The runner continues to authenticate the exact Q08 work item and evidence hash but no
  longer requests a portfolio rescue for `FAIL_SOFT`.

No windows, seeds, cell counts, timeouts, verdict vocabulary, Q08 evidence hashing, or identity
derivation changed.

## Focused verification

Executed from `C:/QM/repo`:

```text
python -m py_compile tools/strategy_farm/farmctl.py \
  tools/strategy_farm/q09_news_runner.py \
  tools/strategy_farm/q09_news_schema.py \
  tools/strategy_farm/q10_confirmation_contract.py \
  tools/strategy_farm/tests/test_q09_news_schema_v2.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py \
  tools/strategy_farm/tests/test_q10_confirmation_contract_v2.py \
  tools/strategy_farm/tests/test_q09_news_migration_v2.py

python -m pytest -q \
  tools/strategy_farm/tests/test_q09_news_schema_v2.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py \
  tools/strategy_farm/tests/test_q10_confirmation_contract_v2.py \
  tools/strategy_farm/tests/test_q09_news_migration_v2.py
```

Final result: `74 passed`. Coverage includes news-only Q10, informational
`FAIL_PORTFOLIO`, no-`CONFIG_LOCKED` refusal, evidence-hash mismatch, fewer than five seeds,
present-but-unreadable portfolio evidence, Q08 `PASS`/`FAIL_SOFT` news-arm creation without a
portfolio row, runner binding of unpaired `FAIL_SOFT`, and v5-to-v6 migration.

`farmctl.py` is a `-text` mixed-line-ending file. Modified CRLF regions remain CRLF and the
pre-existing LF backfill region remains LF; no whole-file normalization was performed.

## Live database dry run (read only)

Observed at `2026-08-23T07:34:37.848Z` against
`D:/QM/strategy_farm/state/farm_state.sqlite` using SQLite URI `mode=ro`,
`PRAGMA query_only=ON`, and a read transaction. No schema installer, farm pump, autopilot,
enqueue, update, or migration command was called by this audit.

Selection:

```sql
WITH eligible AS (
  SELECT q.id,q.ea_id,q.symbol,q.setfile_path,q.verdict,q.evidence_path,q.updated_at,
         ROW_NUMBER() OVER (
           PARTITION BY q.ea_id,q.symbol,q.setfile_path
           ORDER BY q.updated_at DESC,q.id DESC
         ) AS lineage_rank
  FROM work_items q
  WHERE q.phase='Q08' AND q.status='done'
    AND q.verdict IN ('PASS','FAIL_SOFT')
    AND julianday(q.updated_at) >= julianday('now','-30 days')
)
SELECT * FROM eligible q
WHERE NOT EXISTS (
  SELECT 1 FROM work_items n
  WHERE n.phase='Q09_NEWS' AND n.ea_id=q.ea_id
    AND n.symbol=q.symbol AND n.setfile_path=q.setfile_path
)
ORDER BY updated_at,id;
```

Snapshot counts:

- 117 done Q08 `PASS`/`FAIL_SOFT` rows in the 30-day window.
- 45 rows belong to tuples with no Q09_NEWS arm; all 45 are listed below.
- 36 rank-1 rows are current-lineage backfill candidates. The other nine are superseded rows
  of those same tuples; the repair path selects rank 1 to avoid creating multiple simultaneous
  Q09 arms for one EA/symbol/setfile tuple.
- Canonical JSON SHA-256 of the 45 listed rows:
  `05c1089a2a32609844127b29bb996a0b061a17bf7f2ed30b49dd3b977867c42a`.

| Q08 work item | EA | Symbol | Verdict | Updated UTC | Rank |
|---|---|---|---|---|---:|
| `e423a41b-954b-42c0-8efe-8c99a68dda21` | QM5_11124 | WS30.DWX | FAIL_SOFT | 2026-07-25T21:18:01+00:00 | 2 |
| `8dbe6748-b73e-446b-a966-78ea2e296ead` | QM5_13213 | USDJPY.DWX | FAIL_SOFT | 2026-07-25T21:48:43+00:00 | 3 |
| `b4d48a09-bba7-4925-9c32-b72c159fd610` | QM5_13213 | USDJPY.DWX | FAIL_SOFT | 2026-07-25T22:21:09+00:00 | 2 |
| `9611dbac-49e5-44fc-b86f-a66b38b5f031` | QM5_11124 | SP500.DWX | FAIL_SOFT | 2026-07-25T23:01:37+00:00 | 1 |
| `55813535-5da2-4c00-b2b9-6b824e02135b` | QM5_10939 | GBPUSD.DWX | FAIL_SOFT | 2026-07-26T08:30:15+00:00 | 2 |
| `df2bb9ec-cfb6-45b3-b82e-59640e821b86` | QM5_10094 | GDAXI.DWX | FAIL_SOFT | 2026-07-26T19:49:29+00:00 | 2 |
| `804a2f4d-5c38-453b-a5db-c12891b20164` | QM5_13059 | QM5_13059_XTI_AUDJPY_RSPREAD_D1 | FAIL_SOFT | 2026-07-26T20:43:37+00:00 | 1 |
| `7be51839-1a9e-421c-a6bc-fd2bcb76733c` | QM5_9936 | USDJPY.DWX | FAIL_SOFT | 2026-07-27T05:56:26+00:00 | 2 |
| `f247b61d-3663-42e3-9050-0eb300c35c1d` | QM5_20010 | XAUUSD.DWX | FAIL_SOFT | 2026-07-27T15:01:25+00:00 | 2 |
| `d1bb96a2-888c-4336-a959-d36842a4194b` | QM5_10939 | XAUUSD.DWX | FAIL_SOFT | 2026-07-31T18:43:11+00:00 | 2 |
| `eeeed7c8-bac3-4ba0-b057-68fbf0e0f147` | QM5_11147 | SP500.DWX | FAIL_SOFT | 2026-08-08T14:36:51+00:00 | 1 |
| `0808e295-5de2-4aba-9c7d-ae9097785066` | QM5_11660 | NDX.DWX | FAIL_SOFT | 2026-08-12T10:00:18+00:00 | 2 |
| `a9cccf5c-d8dd-4456-bf58-5e8831698cec` | QM5_20086 | NDX.DWX | FAIL_SOFT | 2026-08-17T06:53:52+00:00 | 1 |
| `0fd00da5-b4c2-4aa2-a5d2-99fe5b62be9c` | QM5_11660 | NDX.DWX | FAIL_SOFT | 2026-08-17T23:06:53+00:00 | 1 |
| `a3e17e53-ff08-4794-9073-ef5af719e2ef` | QM5_10145 | SP500.DWX | FAIL_SOFT | 2026-08-18T00:25:57+00:00 | 1 |
| `d9223a2f-012d-43c6-885b-e8bd6b2e85a3` | QM5_10094 | GDAXI.DWX | FAIL_SOFT | 2026-08-18T00:37:32+00:00 | 1 |
| `a4d1c0a6-7692-44c3-b633-6efc79891e02` | QM5_10403 | XAUUSD.DWX | FAIL_SOFT | 2026-08-18T02:00:15+00:00 | 1 |
| `0b384c46-911f-4daa-92c9-0f261be21e70` | QM5_10939 | XAUUSD.DWX | FAIL_SOFT | 2026-08-18T02:11:56+00:00 | 1 |
| `0ed64130-4131-4575-8438-cb3bef1641f0` | QM5_10115 | GDAXI.DWX | FAIL_SOFT | 2026-08-18T03:05:45+00:00 | 1 |
| `375d7f67-fb0e-4793-ac60-7bebb4f9986b` | QM5_10513 | XAUUSD.DWX | FAIL_SOFT | 2026-08-18T03:08:49+00:00 | 1 |
| `e76e7c6e-cd62-4633-be47-4b077f6e93f1` | QM5_10114 | SP500.DWX | FAIL_SOFT | 2026-08-18T03:15:19+00:00 | 1 |
| `b3fe5bc3-cdcd-420d-b68e-2da748e641cd` | QM5_11124 | WS30.DWX | FAIL_SOFT | 2026-08-18T03:56:47+00:00 | 1 |
| `577cc034-e74e-4914-ba36-57fa0414ad9e` | QM5_9403 | GDAXI.DWX | FAIL_SOFT | 2026-08-18T04:09:35+00:00 | 1 |
| `87da806d-0f8a-4faa-be55-850f1644ed83` | QM5_9502 | SP500.DWX | FAIL_SOFT | 2026-08-18T04:18:52+00:00 | 1 |
| `591f7453-2d44-4ae3-9cd9-8378bf4f8de7` | QM5_12915 | SP500.DWX | FAIL_SOFT | 2026-08-18T04:54:50+00:00 | 1 |
| `36d46f72-a638-4e59-be41-4bbecbe3e495` | QM5_1556 | XAUUSD.DWX | FAIL_SOFT | 2026-08-18T05:12:20+00:00 | 1 |
| `0ac2f29e-7d8c-4f3c-9b0b-cdf20db3de0e` | QM5_20047 | XTIUSD.DWX | FAIL_SOFT | 2026-08-18T05:25:08+00:00 | 1 |
| `37894f9c-0a12-4e40-ac36-ba1fc8e56b88` | QM5_13108 | XTIUSD.DWX | FAIL_SOFT | 2026-08-18T05:25:24+00:00 | 1 |
| `a370af27-1f45-4d21-834e-aad479a538b1` | QM5_10123 | XAUUSD.DWX | FAIL_SOFT | 2026-08-18T06:56:52+00:00 | 1 |
| `811fc617-ee41-456b-8e3a-ce672f93c73c` | QM5_10939 | GBPUSD.DWX | FAIL_SOFT | 2026-08-18T08:03:53+00:00 | 1 |
| `106b5827-acda-4294-9d06-9e215333819a` | QM5_11708 | EURUSD.DWX | FAIL_SOFT | 2026-08-18T10:26:33+00:00 | 1 |
| `be9beb50-8353-49d5-bba5-0db04d24e51a` | QM5_10848 | XAUUSD.DWX | FAIL_SOFT | 2026-08-18T10:53:43+00:00 | 1 |
| `43c9d9d7-2b2c-43a3-bf4a-a1348d1f0ce5` | QM5_11476 | USDJPY.DWX | FAIL_SOFT | 2026-08-18T12:05:26+00:00 | 1 |
| `05eaa42c-a3f3-496a-a89f-cbc32d021b78` | QM5_20010 | XAUUSD.DWX | FAIL_SOFT | 2026-08-18T12:10:03+00:00 | 1 |
| `d2783b32-78fd-4068-b4e4-2b778c47b417` | QM5_13213 | USDJPY.DWX | FAIL_SOFT | 2026-08-18T12:52:37+00:00 | 1 |
| `196efa7a-d01a-4d2d-8416-d6d189ca16dd` | QM5_9503 | USDJPY.DWX | FAIL_SOFT | 2026-08-18T13:30:18+00:00 | 1 |
| `4b5171cc-afe4-4c0d-b08c-2de8ba20d2e6` | QM5_9936 | USDJPY.DWX | FAIL_SOFT | 2026-08-18T13:52:56+00:00 | 1 |
| `5a42fc9d-c996-44bf-afff-869f02eb6e0e` | QM5_12831 | QM5_12831_XTI_AUDUSD_BRK_D1 | FAIL_SOFT | 2026-08-18T19:25:57+00:00 | 1 |
| `b9fd15a8-ee74-4e65-a3a1-69f88fb251eb` | QM5_21506 | XAUUSD.DWX | FAIL_SOFT | 2026-08-19T21:30:04+00:00 | 1 |
| `4c7f3264-99c0-46c7-a829-80b2f2fc98bf` | QM5_11754 | USDCAD.DWX | FAIL_SOFT | 2026-08-19T22:30:33+00:00 | 1 |
| `0dbc6aab-8e71-4841-a46b-5c7a50de22e2` | QM5_21502 | XAUUSD.DWX | FAIL_SOFT | 2026-08-19T23:14:14+00:00 | 1 |
| `837ea578-a2d9-4c7f-9294-7d7cf406ca9b` | QM5_21507 | XAUUSD.DWX | FAIL_SOFT | 2026-08-19T23:53:21+00:00 | 1 |
| `60176c38-2022-4997-98ab-92dc87b277a6` | QM5_10114 | GDAXI.DWX | FAIL_SOFT | 2026-08-20T05:10:11+00:00 | 1 |
| `850d7b31-c36d-4d24-94bf-0a174b1b940c` | QM5_9510 | XAUUSD.DWX | FAIL_SOFT | 2026-08-20T08:53:24+00:00 | 1 |
| `396763f6-25e2-49c7-87d8-5ce2796e0965` | QM5_10916 | GDAXI.DWX | FAIL_SOFT | 2026-08-21T16:15:47+00:00 | 1 |

### Required QM5_13213 check

`QM5_13213 / USDJPY.DWX` is an actionable rank-1 candidate:

- Q08 `d2783b32-78fd-4068-b4e4-2b778c47b417`, verdict `FAIL_SOFT`;
- no Q09_NEWS row exists for its EA/symbol/setfile tuple;
- portfolio sibling `b8887bd1-f549-4f1c-b870-dbda85df66e1`, verdict
  `FAIL_PORTFOLIO`;
- the sibling's `Q08_INPUT` edge binds the required Q08 and evidence SHA-256
  `c80c2bc29607b535a9e605cbaba9de5ac3381275e1f112283d1be524c5a56306`.

The portfolio failure therefore cannot prevent creation or runner binding of the Q09_NEWS arm.
If that sibling remains the newest terminal result when Q10 is later created, it is bound as an
informational edge with all three terminal verdicts.

## Migration-state observation

The read-only snapshot reported `q09_news_schema_meta.schema_version = 6` before any explicit
migration action in this task. No `q09_news_migration.py apply` or revert command was run. The
canonical checkout already contained inherited, uncommitted v6 implementation changes when the
scheduled cycle began, and the mandatory initial health command also predates this read-only
observation. The metadata row alone cannot establish which earlier initializer installed v6.
Claude should treat the already-observed live version as a deployment-state finding during review;
this task does not mutate or attempt to roll it back.
