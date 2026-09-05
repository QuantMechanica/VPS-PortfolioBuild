# Archive v3.1 retest collapse

RESULT: REVIEW. Router task `efa156a4-c8e9-4f31-b9c2-b7e58bbe18ab`.

The producer now emits one verdict per family, gate, symbol and timeframe. The
latest completed economic observation wins, using the full recorded timestamp
normalised to UTC before dates are exposed. Infrastructure failures and unfinished
rows do not replace economic results. Equal-instant contradictory results resolve
conservatively to FAIL; private row identifiers only stabilise ordering.

Each backtest cell includes `retests: [{recorded_at, verdict}]`, in chronological
order, including the selected observation. Dates contain no times; missing dates
remain null. No metrics, parameters, paths or private identifiers enter this field.
The runtime closed whitelist rejects added fields, duplicate cells, invalid dates
and a selected verdict that differs from the final history entry.

The string entries in `passed_symbols` and `failed_symbols` now identify complete
market cells, for example `EURUSD / H1`. This is a deliberate schema refinement:
symbol-only lists would still contradict each other when different timeframes have
different results. The JSON schema is updated alongside the producer. Consumers
must treat those summary strings as market labels. The existing page generator
renders the structured `backtests` cells and was not edited.

## Verification

`python -m pytest tools/strategy_farm/tests/test_website_archive_v31.py tools/strategy_farm/tests/test_website_archive_contract.py -q`

**116 passed.** Tests cover both verdict directions, same-day timestamp ordering
with UTC offsets, equal-instant conflicts, distinct timeframes, infrastructure
exclusion, missing historical files, payload timeframe resolution and the public
disclosure boundary. Focused `git diff --check` passed.

The [reproducible comparison](2026-09-05_archive_v31_retests_verify.py) validates
the new producer whitelist and schema field contract; its [receipt](2026-09-05_archive_v31_dryrun_v3/verification.json)
records:

| Observation | Dry run v2 | Dry run v3 |
|---|---:|---:|
| Families | 3,339 | 3,340 |
| Families with opposite verdicts for the same cell | 273 | 0 |
| Families with overlapping passed/failed chip lists | 299 | 0 |
| Duplicate gate market cells | 740 | 0 |
| UNKNOWN market timeframes | 88 | 79 |
| Families containing UNKNOWN timeframes | 16 | 13 |
| Families without markets | 359 | 359 |

The live input population gained one family between snapshots. The new snapshot
retains 49,890 dated economic observations. The comparison checks the runtime
whitelist and schema field definitions, not an external JSON Schema engine.

## UNKNOWN timeframe provenance

Nine rows across QM5_1044, QM5_1062 and QM5_1064 are recoverable. Their work-item
payloads contain `host_timeframe` (D1, H1 and D1 respectively); their recorded
governed set filenames independently contain the same timeframe. Those files no
longer exist in the canonical checkout, and the old producer both omitted
`host_timeframe` and skipped filename extraction when a file was missing.

The producer now reads that named payload field and extracts the recorded filename
timeframe independently of file existence. Present set files still contribute only
timeframe-labelled metadata, never arbitrary numeric parameter values. No set
file, strategy or historical work item was changed.

The remaining 79 UNKNOWN markets belong to 13 early research families with no
work-item rows and no governed set files in the canonical checkout. Their market
names come from cards; there is no governed timeframe to infer. The 359 families
without markets also remain unchanged. No market or timeframe was fabricated.

## Review artifacts

The dry run used the CEO naming ledger v2 and canonical source:

```powershell
python C:/QM/repo/tools/strategy_farm/website_archive_v31.py --out-dir C:/QM/repo/docs/ops/evidence/2026-09-05_archive_v31_dryrun_v3 --ledger C:/QM/repo/public-data/naming/strategy_names.v2.json --repo-root C:/QM/repo
python C:/QM/repo/docs/ops/evidence/2026-09-05_archive_v31_retests_verify.py
```

[Snapshot](2026-09-05_archive_v31_dryrun_v3/strategy-archive-v31.json),
[editorial sample](2026-09-05_archive_v31_dryrun_v3/sample_30.md),
[internal audit](2026-09-05_archive_v31_dryrun_v3/audit.json), and
[naming ledger](2026-09-05_archive_v31_dryrun_v3/strategy_names.v1.json).
The output ledger filename is the producer's existing filename; its input is v2.

Work consumed the router's Codex assignment and spawn lease in this scheduled
cycle. The task's `ops` tag is a router capability; no separate applicable ops
SKILL.md was found. Evidence and changes are confined to agents/board-advisor.
No publication, deployment, compilation or pipeline operation was performed.
