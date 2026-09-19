# Kimi Code quota bucket mapping repair

Router task: `1b891ee2-673f-42e8-8778-4d079ae06453`  
Related fail-closed ticket: `d797e68f`  
Implementation commit: `67209e5e7a`  
Disposition: **PASS — Kimi Code rolling windows now map to the enforced buckets**

## Finding

The endpoint remains the authenticated, read-only
`GET https://api.kimi.com/coding/v1/usages`. Its live response contains two
different quota families:

| Normalized window | Enforced Kimi Code field | Formula |
|---|---|---|
| `rolling_5h` | the `limits[]` entry whose `window` is 300 minutes, then `detail` | `(limit - remaining) / limit` |
| `rolling_7d` | top-level `usage` | `used / limit` |

The previous implementation instead read sibling
`usages.limit_5h.used_ratio` and `usages.limit_7d.used_ratio`. Those values are
a different dashboard bucket and did not describe the capacity enforced for
`kimi-code/kimi-for-coding`.

A sanitized live read on 2026-09-19 made the mismatch conclusive:

- top-level `usage`: `limit=100`, `used=100`, weekly reset
  `2026-09-22T09:31:53.721072Z`;
- 300-minute `limits[].detail`: `limit=100`, `remaining=100`, reset
  `2026-09-19T13:31:53.721072Z`;
- sibling `usages.limit_7d.used_ratio`: `0.000011` with the same weekly reset;
- sibling `usages.limit_5h.used_ratio`: `0.0` with the same five-hour reset.

The root capacity fields therefore match both the observed Kimi Code state
(7-day 100%, 5-hour 0%) and the model's hard weekly-limit 403 from ticket
`d797e68f`; the former mapping reported approximately 0% for the same reset
window.

## Change

`kimi_quota_fetcher.normalize` now:

- derives the 7-day Code ratio from top-level `usage`;
- selects the 5-hour Code bucket by duration rather than array position;
- accepts numeric strings and either `used` or `remaining` capacity shapes;
- continues using `usages.limit_month_total` / `limit_month_code` only for the
  separate monthly total and breakdown fields;
- never uses `usages.limit_5h` / `limit_7d` for Code rolling capacity.

No threshold, flag, retry, routing, governor, or Kimi adapter logic changed.
`tools/strategy_farm/kimi_governor.py` has the same Git blob before and after
the repair: `0e837f4ba746832e048901604ac89d1614f66dc9`.

## Verification

- Focused suite:
  `python -m pytest -q tools/strategy_farm/tests/test_kimi_quota_fetcher.py tools/strategy_farm/tests/test_kimi_governor.py tools/strategy_farm/tests/test_kimi_adapter.py`
  → **92 passed**.
- The regression fixture deliberately makes the two quota families disagree;
  normalized rolling values follow only the enforced Code fields.
- A fresh live `fetch --no-write --print-redacted` returned
  `rolling_5h.used_ratio=0.0` and `rolling_7d.used_ratio=1.0`, with
  `fetch_status=ok` and no runtime-state write.
- Secret hygiene remains intact: only sanitized response fields were recorded;
  no access or refresh token was printed or persisted.
- The tests covering a single `quota_exhausted` occurrence and its precedence
  over apparently normal telemetry still pass. The `d797e68f` fail-closed
  escalation is unchanged.

RESULT: `PASS_KIMI_CODE_QUOTA_BUCKET_MAPPING_REPAIRED`.
