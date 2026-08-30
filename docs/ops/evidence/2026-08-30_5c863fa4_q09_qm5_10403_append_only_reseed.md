# QM5_10403 exact Q09 append-only reseed

- Router task: `5c863fa4-61fe-430c-a615-583bc10f67fb`
- Scope: exactly `QM5_10403/XAUUSD.DWX`
- Authority chain: approved task `f3cacf27-bd47-4e70-bc7d-66506d9a8281` and sealed audit `359988fb-db68-4c80-b1f1-eab42196dcc7`
- Execution time: `2026-08-30T10:06:50Z`
- Canonical path: `farmctl.py enqueue-backtest --phase Q09 --from-work-item-id --append-only-rerun-of --q09-anchor-binding-file`

## Result

The canonical append-only path created exactly one new Q09 work item:

| Field | Value |
|---|---|
| New row | `478451a5-1f51-43b1-99f6-abe07bb45aa8` |
| EA / symbol / phase | `QM5_10403` / `XAUUSD.DWX` / `Q09` |
| State at verification | `pending`, unclaimed, verdict unset |
| Gate contract | `v4` |
| Immutable rerun target | `ee4062b1-3940-45ce-bd66-b463e55afc1e` |
| Exact Q08 anchor | `7fd4caf6-b599-4833-a431-a132a404b60b` |
| Q08 dossier SHA-256 | `bb57935abf1f48a0aeda30a3ac9d124f34108d85369cc1da504bc773d724556e` |
| Audit SHA-256 | `0451794fc1ffa6868bee7ae88fad00a18d718d7b76247ff58b1d7c438e43292b` |
| MQ5 SHA-256 | `b38cfd471fd31811bb23a5447c430cc1bfcc1f370eb816236c99bb88be55d251` |
| EX5 SHA-256 | `f927f07f46579bbb9a1bdcfdb7caa9b246e9d7555935fbb878f7fc01afbf7ab3` |
| Setfile SHA-256 | `9a6fab053d3814077a015eb9f3a864a0c8a703fbe220ae03e74da195960f4c72` |
| Risk contract | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

The new payload carries `EXACT_Q08_TO_Q09_APPEND_ONLY_REENTRY`, the exact Q08
dossier path/hash, the sealed audit path/hash, the prior OWNER authority, all
three current execution-artifact hashes, and
`append_only_rerun_of_work_item=ee4062b1-3940-45ce-bd66-b463e55afc1e`.

## Append-only verification

- `ee4062b1-3940-45ce-bd66-b463e55afc1e` remains terminal `done / INFRA_FAIL`,
  unclaimed, with unchanged `updated_at=2026-08-30T09:03:09+00:00`.
- Its canonical full-row SHA-256 was
  `6a868792b3c12c5321ce0e9c972fb1125f3c4714e2ff64e904030ce30f73ad68`
  before enqueue and the same value after enqueue.
- The exact Q08 anchor full-row SHA-256 likewise remained
  `20c95d9603da4c548f4114290245cd64b7a93a1a72e1f669ed3e22266f2efb38`.
- Exactly one work item references `ee4062b1...` as its append-only rerun target.
- Exactly one new row was created in the requested EA/symbol/phase scope; no
  other pair was seeded.
- SQLite `PRAGMA quick_check` returned `ok`.

Verdict: `PASS_ONE_Q09_APPEND_ONLY_RESEED_ANCHOR_BOUND_HISTORY_UNTOUCHED`.
