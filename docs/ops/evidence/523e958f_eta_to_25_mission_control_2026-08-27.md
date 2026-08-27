# 523e958f — Mission Control ETA zu 25

- Date: 2026-08-27
- Router task: `523e958f-c81a-43d8-9d21-5b2e4b9e31f2`
- State requested: `REVIEW`
- Scope: read-only telemetry and rendering; no queue, worker, flag, verdict, or gate mutation

## Outcome

Mission Control now renders a live **ETA zu 25** independently of the existing
Queue-leer-ETA. The shared read model exposes the v4 Q09 reservoir, authenticated
Q10 `chosen` results, Q11 PASS, raw Q12/Q13/Q14 progress per pair, and measured
seven-day pair-completion rates.

The 25-pair count remains fail-closed and explicitly **provisional**. No lineage
definition was activated by this change.

## Live read-only fixture (2026-08-27)

| Metric | Value |
|---|---:|
| v4 Q09-PASS reservoir | 55 pairs |
| reservoir pairs with authenticated Q10 `chosen` | 2 |
| reservoir pairs with v4 Q11 PASS | 2 |
| reservoir pairs with raw valid Q12 evidence | 1 |
| reservoir pairs with raw valid Q13 evidence | 1 |
| reservoir pairs with raw terminal Q14 evidence | 1 |
| all raw v4 Q10 `chosen` completions, trailing 7d | 3 (0.429/day) |
| all raw v4 Q11 completions, trailing 7d | 3 (0.429/day) |
| all raw v4 Q12 completions, trailing 7d | 3 (0.429/day) |
| all raw v4 Q13 completions, trailing 7d | 3 (0.429/day) |
| all raw v4 Q14 completions, trailing 7d | 3 (0.429/day) |
| provisional strict-v4 qualified count | 0 / 25 |
| measured-rate ETA zu 25 | 58.28 days (`LOW`, sample n=3) |
| prior phase-median/capacity lower bound | 5.78 days (retained as diagnostic only) |

ETA formula: `25 remaining / 0.429 raw v4 Q14 pair completions per day = 58.28 days`.
The three Q14 completions are NO_CHANGE pilots that are not strictly qualified,
so this rate is visibly labelled a low-sample throughput proxy. It is not a
survival model, an OWNER counting decision, or the Queue-leer-ETA.

Database immutability proof:

- SHA-256 before: `b4501b53c2d59a5f27e13927de601a601232c35eba6545afeeb9add36db6341e`
- SHA-256 after: `b4501b53c2d59a5f27e13927de601a601232c35eba6545afeeb9add36db6341e`
- Result: identical

## Counting-definition decision template

Decision question: **Which `(EA, symbol)` rows count toward the OWNER ≥25 trigger
under v4 lineage?** Until sealed, Mission Control renders Option A and shows all
other counts separately.

| Option | Live count | Contract | Trade-off |
|---|---:|---|---|
| **A — STRICT_V4_CONTIGUOUS_Q14 (recommended)** | **0** | Canonical v4 evidence must be contiguous through terminal Q14 (`highest_contiguous_valid_gate=Q14`). | Fail-closed and comparable; excludes pilots and mixed-era labels until explicitly rebound. |
| B — V4_TERMINAL_ROW_ONLY | 3 | Any done v4 Q14 row with `KEEP_INCUMBENT` or `CHALLENGER_PROMOTED`. | Simple, but counts the three NO_CHANGE pilots without proving their full v4 path. |
| C — CONTRACT_EQUIVALENT_TERMINAL | 3 | Any row explicitly translated by the active manifest to terminal v4 Q14 with a pass-class outcome. | Allows legitimate translated evidence, but requires a sealed translation/reuse policy. |
| D — HISTORICAL_Q14_LABEL_INCLUSIVE | 10 | Raw historical rows labelled Q14 with an optimization outcome. | Matches the historical label census but mixes incompatible gate meanings; not recommended. |

Recommendation: **A** until OWNER seals a broader reuse rule. This preserves the
v4 contract and prevents the dashboard from turning three pre-sweep pilots or
historical v3 labels into book-trigger authority.

Requested sealing record:

```text
OWNER_DECISION_ID: OWNER-DEC-Q14-PAIR-COUNT-DEFINITION
CHOICE: A | B | C | D
EFFECTIVE_CONTRACT: v4
EFFECTIVE_AT_UTC: <timestamp>
RATIONALE: <text>
REUSE_REQUIREMENTS_IF_B_OR_C: <hash/lineage requirements>
```

This ticket does not consume or execute that decision.

## Implementation

- `tools/strategy_farm/path_to_25.py`
  - keeps `qualified_pairs` on the canonical contiguous census;
  - adds per-pair raw v4 stage state and authenticated `q09_news_tests` choices;
  - computes seven-day distinct-pair rates and the separate ETA-to-25 contract;
  - emits the provisional definition and alternative live counts.
- `tools/strategy_farm/render_cockpit_v2.py`
  - renders the reservoir, rates, ETA basis/caveat, definition footnote, and a
    collapsible Q09–Q14 per-pair table in the existing dark theme.
- `tools/strategy_farm/mission_control_v2_data.py`
  - validates the expanded `path_to_25` schema.
- `docs/ops/MISSION_CONTROL_V2_DATA_CONTRACT.md`
  - documents the critical-path contract and its non-authoritative boundary.

## Verification

```powershell
python -m py_compile tools/strategy_farm/path_to_25.py tools/strategy_farm/render_cockpit_v2.py tools/strategy_farm/mission_control_v2_data.py
python -m pytest -q tools/strategy_farm/tests/test_path_to_25_metrics.py tools/strategy_farm/tests/test_render_cockpit_v2.py tools/strategy_farm/tests/test_mission_control_v2_data.py
git diff --check -- tools/strategy_farm/path_to_25.py tools/strategy_farm/render_cockpit_v2.py tools/strategy_farm/mission_control_v2_data.py tools/strategy_farm/tests/test_path_to_25_metrics.py docs/ops/MISSION_CONTROL_V2_DATA_CONTRACT.md docs/ops/evidence/523e958f_eta_to_25_mission_control_2026-08-27.md
```

Results:

- Python compile: PASS
- Focused pytest: **25 passed, 1 skipped**
- `git diff --check`: PASS (line-ending conversion warnings only)
- Live render tokens present: `ETA zu 25`, `Queue-leer-ETA`,
  `Zählung PROVISORISCH`, `Q09-Reservoir`
- No T1–T10 process was interrupted; T_Live and AutoTrading were untouched.
