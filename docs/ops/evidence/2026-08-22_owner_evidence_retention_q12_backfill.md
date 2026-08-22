# OWNER evidence-retention Q12 register backfill

Date: 2026-08-22  
Router task: `78b7c6ec-2fd6-43b8-90ca-1b270fc9ffa2`  
Authorization: `OWNER-DEC-EVIDENCE-RETENTION`

## Verdict

PASS — the three OWNER-authorized missing live-sleeve records were appended to
the canonical `portfolio_candidates` register. All three are fail-closed as
`EVIDENCE_STALE`; none qualifies as `Q12_REVIEW_READY` on the retained evidence.
No fund score was synthesized, no existing row was updated, and no live setting
or terminal state was changed.

The row-linked provenance payload is
`C:/QM/repo/docs/ops/evidence/2026-08-22_owner_evidence_retention_q12_backfill.json`.
Its SHA-256 is
`06858f193a990d7875c4a07e3de07be2235640549ede31daf84e482abd03bc8f`.
The legacy register table has no `payload_json` column, so each new row's
`evidence_path` points to that immutable JSON payload. The legacy
`q11_work_item_id` column contains the exact retained Q10 PASS work-item binding.

## Appended rows

| EA / symbol | Bound Q10 work item | Register state | Named evidence gap |
|---|---|---|---|
| `QM5_13301 / GDAXI.DWX` | `90c6f8d4-a5e4-4126-a099-ea83d990b624` | `EVIDENCE_STALE` | No `CONFIG_LOCKED` Q09_NEWS evidence; retained Q09_PORTFOLIO is `FAIL_PORTFOLIO`; Q10 predates the paired-dependency contract. |
| `QM5_13213 / USDJPY.DWX` | `54b9ad23-d10d-493b-80b2-90c77347cffa` | `EVIDENCE_STALE` | No Q09_NEWS work item or `CONFIG_LOCKED` evidence; retained Q08 is `FAIL_SOFT`; Q09_PORTFOLIO is `FAIL_PORTFOLIO`; Q10 predates current recency/dependency evidence. |
| `QM5_12989 / XAUUSD.DWX` | `b0ed83c7-ff92-49e9-aafd-647a37fda30e` | `EVIDENCE_STALE` | Q09_NEWS is `REVIEW_REQUIRED`; Q09_PORTFOLIO is `FAIL_PORTFOLIO` with missing evidence; Q10 predates the paired-dependency contract. |

The JSON payload records the exact retained Q08/Q09/Q10 verdicts and SHA-256
bindings. Its `fund_score` field is explicitly `null` for every row.

## Live and evidence bindings

- Live-book pulse: `D:/QM/reports/state/live_book_pulse.json`, generated
  `2026-08-22T10:00:01Z`, SHA-256
  `20a0f2c976c36e4418dbfba1d645325ebfa25ee92252ef4592b0f9623da5292e`.
- Signed 24-sleeve manifest:
  `D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json`,
  SHA-256
  `8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`.
- Pulse check: 24 manifest sleeves, 24 loaded presets, zero manifest mismatch.
- All three bound Q10 work items were re-read from the canonical farm DB as
  phase `Q10`, status `done`, verdict `PASS`; every evidence path existed and
  matched the SHA-256 recorded in the JSON payload.

## Append-only transaction verification

The mutation ran under `BEGIN IMMEDIATE` and failed closed on any pre-existing
EA/symbol row, missing Q10 binding, non-PASS Q10 verdict, missing evidence file,
or evidence hash drift.

| Check | Before | After |
|---|---:|---:|
| Total `portfolio_candidates` rows | 38 | 41 |
| `Q12_REVIEW_READY` | 30 | 30 |
| `EVIDENCE_STALE` | 6 | 9 |
| `DUPLICATE_SUPERSEDED` | 2 | 2 |

Transaction result: `COMMITTED`; inserted rows: 3; pre-existing rows retained
unchanged: 38. Canonical row-set SHA-256 was
`2905438af3af06ad3a12a1afd8e9e05c5963112e0d9fbea1525043c07146e0f5`
before and
`bd17108d727c02018e7aa81ddcacd52d007942fbd88bce6dbde764157c4b1864`
after. The after-state difference is exactly the three linked rows listed above.

## Operational boundary

This was a register-only evidence-retention action. T_Live was treated as
read-only. AutoTrading was not enabled, no terminal was started or interrupted,
and no pipeline verdict was inferred or changed.
