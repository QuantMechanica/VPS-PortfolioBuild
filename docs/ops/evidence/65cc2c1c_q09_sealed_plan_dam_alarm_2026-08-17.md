# Q09_NEWS sealed-plan dam: binary-vintage adjudication and health alarm

- Router task: `65cc2c1c-3b98-4331-b9e6-c1f104494a88`
- Cycle time: 2026-08-17 UTC
- Scope: read-only adjudication of the eight held Q09_NEWS rows plus health/cockpit alarm wiring.
- Safety outcome: no hold was weakened or released, no plan was falsely bound, and no terminal was started or interrupted.

## Per-row binary-vintage result

Every current canonical EX5 still equals the SHA-256 sealed in its Q08 aggregate, and every current MQ5 still equals the Q08 MQ5 SHA-256. This proves these are not accidental current-source/Q08 mismatches. It also makes the blocker conclusive: each exact Q08-tested source lacks all three sealed calendar identity inputs required by the Q09 v2 interface:

- `qm_news_calendar_bundle_id`
- `qm_news_calendar_expected_sha256`
- `qm_news_calendar_common_relative_path`

The planner can append those names to a generated setfile, but the tested binaries do not expose them. Binding such a plan would reproduce the known pre-interface failure: the report cannot emit the calendar identity and the validator correctly fails closed.

| Q09 row | EA | Q08 row | Q08/current EX5 SHA-256 | Q08/current MQ5 SHA-256 | Result |
|---|---|---|---|---|---|
| `1bc0c677` | QM5_11288 | `c27cab86` | `c9f20a0ec3456c5086dd5ad92e27b9fe3de99f417052bece66c8d79680b47310` | `0af257d4ca10bcf13b0f17e19c16bd99e19354615349f24f9d3b52eeb49ad142` | BLOCKED: exact Q08 binary predates sealed calendar inputs |
| `4263d6b3` | QM5_20266 | `87731bac` | `8760402ac1ba34d9631b125989d13e63a737a0a305f6b3d6b00f3d1b6e128fed` | `26965c9164b887e81e533837eb9b8005a3981d027619b718bcab014ab874394c` | BLOCKED: exact Q08 binary predates sealed calendar inputs |
| `494651b2` | QM5_9641 | `879ab322` | `21eda8527f66dd25bddd9ea6f50f727d5d7e58cc33f44725eb2fbfcccec40a21` | `82dba156ebc91aa4b2000241c1481600ae76410f5d07152ca470ff5df7e0fb5f` | BLOCKED: exact Q08 binary predates sealed calendar inputs |
| `cfa98980` | QM5_12855 | `80352115` | `1e141304275473b0b36160602ec0743635c9ae9ee2e7bbdbe2e7a770fb075f18` | `07c82d1358b1f0d1e9604b5792a15b34fd3678c0728a9c3ece39a059670bdd17` | BLOCKED: exact Q08 binary predates sealed calendar inputs |
| `db92d69a` | QM5_12849 | `bdd1662a` | `c9166d7a34d637b6ef8aeb0ea90c72b50675e24f4552704ef96e28b6147f9fe4` | `d72f373782ce6ae26b702b1d2ffaf75d4e9711712311726aaa19c7b767299af9` | BLOCKED: exact Q08 binary predates sealed calendar inputs |
| `3a44e240` | QM5_12708 | `034497fc` | `bc339e1813b1a211d4c589decdd35baf503ee3c0cda39899da4fb30ff6d57ff2` | `d3dd951e58effae0eee5cb7817ddf191ef2830fceab0787e71f0fdc3098b788e` | BLOCKED: exact Q08 binary predates sealed calendar inputs |
| `8f760c32` | QM5_13054 | `42f1dc63` | `2e65488fccdbd985f78318861a223a305d820a4fce3d2ebdcafae6ce956fd96d` | `326b188c2be5160f6e5285060f821b82f64d319d1ae5595e0f6134f86cbd6be3` | BLOCKED: exact Q08 binary predates sealed calendar inputs |
| `c665c1aa` | QM5_1537 | `00c6e188` | `142a019e773a493def0640722efb9d591d094650b35a69d5de39f6af3a048106` | `7edf9ade3dec02496e739c3cf1c653eb33bcc4339a223907877f2c78a393fc32` | BLOCKED: exact Q08 binary predates sealed calendar inputs |

Each row therefore needs a source/interface repair, a fresh compile, and pipeline requalification that produces a new Q08 identity before a valid Q09 plan can be authored. Rebuilding and then binding the old Q08 row would contradict the sealed Q08 EX5 identity, so it was not done in this task.

## Claimability and bind output

No `bind-q09-plan` command was issued because no row passed the prerequisite vintage check. Consequently there is no legitimate plan path or plan SHA-256 to report. All eight rows retain active `Q09_AWAITING_SEALED_PLAN` holds and lack the complete `q09-news-dispatch-binding/v1` payload. Both halves of the ordinary claim predicate therefore remain false, as required.

## End of the silent hand-operated step

Deterministic plan authoring is not safe for a pre-interface Q08 binary: it requires the judgement-bearing decision to rebuild and requalify that EA. The accepted fallback was implemented in `health.py`.

`q09_sealed_plan_hold_age` is a FAIL-level check when any pending Q09_NEWS row has an active `Q09_AWAITING_SEALED_PLAN` hold older than six hours. Six hours is intentionally much longer than the historical one-to-two-minute binding latency, but short enough to alarm inside the same operator shift. The detail contains:

- completions in the trailing 24 hours;
- total Q09_NEWS pending count;
- every stale row's short ID, EA, symbol, and age; and
- a fail-closed action hint that forbids releasing the hold without a validated bound plan.

Production read-only verification returned:

`FAIL; completions_24h=0; pending=8; stale sealed-plan holds=8; threshold=6h`

Before service-rate line: `Q09_NEWS completions/24h=0; pending=8`.

After service-rate line: `Q09_NEWS completions/24h=0; pending=8` (unchanged because all eight exact Q08 binaries failed vintage; the new health surface is red rather than silently green).

## Focused verification

`python -m pytest -q tools/strategy_farm/tests/test_health_q09_sealed_plan_hold_age.py tools/strategy_farm/tests/test_health_registry_uniqueness.py tools/strategy_farm/tests/test_health_terminal_account_profiles.py`

Result: 13 tests passed. Python bytecode compilation and `git diff --check` also passed.
