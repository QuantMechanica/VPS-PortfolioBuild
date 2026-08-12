# Q08-8.5 markerless `strategy_` parser fallback

Router task: `1235062d-ec44-43b6-b58c-7c9f53d49822`  
Implementation commit: `12629f507`  
Reviewer after handoff: Claude

## Outcome

**IMPLEMENTATION PASS; 10582 four-file acceptance conflict requires reviewer
resolution.** The narrow markerless fallback is implemented and its regression
suite passes. The base 10582 setfile now parses six assignments without any
byte change. The three evidence-bound ablation children, however, each contain
two six-key strategy blocks (12 exact assignments, six duplicate keys), so the
explicitly retained duplicate-key guard rejects them fail-closed. Claiming a
positive parse count for those three would require weakening that guard or
introducing an unapproved last-block/last-value-wins rule.

No setfile, database row, queue item, Factory state, terminal, T5, T_Live or
AutoTrading state was changed. No Q08 requeue was attempted.

## Implemented parser boundary

`framework/scripts/q08_5_neighborhood_runner.py::parse_setfile_assignments`
now performs a two-path parse:

1. If any line starts (case-insensitively after trimming) with the established
   `; strategy-specific params` marker, the pre-existing marker path is used
   unchanged: assignments before the marker are ignored; post-marker parsing,
   framework exclusions, cells and failures retain their prior semantics.
2. Only when no marker exists, the fallback accepts exact column-zero lines
   matching `^strategy_[A-Za-z0-9_]+=`. Leading whitespace, case variants,
   spaces before `=`, hyphenated names, prefixed names, comments, framework
   inputs and other assignments are ignored.

Both paths share the existing duplicate-key, empty-RHS, scalar/optimizer-cell
parsing and framework-parameter checks.

## Regression verification

New focused tests cover:

- marked files and unchanged marker-block semantics;
- legacy markerless assignments and optimizer lattice metadata;
- exact-syntax near misses;
- marker-present mixed files (fallback must remain disabled);
- duplicate keys;
- empty values;
- non-strategy/framework assignments before and after the legacy strategy
  assignments.

```text
python -m pytest framework/scripts/tests/test_q08_setfile_parser_fallback.py -q
11 passed in 0.88s

python -m pytest framework/scripts/tests/test_q08_davey_subgates.py -q
82 passed in 2.41s
```

`python -m py_compile` and `git diff --check` also passed for the changed parser
and test. Aggregate relevant result: **93 passed**.

## Setfile identity and parse result

Hashes, byte counts and mtimes were captured before and after implementation;
all remained identical and Git reports no setfile change.

| Setfile | Bytes | SHA-256 before = after | Parser result after fix |
|---|---:|---|---|
| base | 770 | `082028275fbb0870d5e0665f5c3131d2d360bb8ff36597aada955c3692eb9d04` | PASS, 6 assignments |
| ablation_00 | 1,008 | `8d47c4cc8191e067af31920bceb3cdcb1af2ebea63b4ddb8df954b9a975cb4f3` | fail-closed duplicate `strategy_fast_ema_period` |
| ablation_01 | 1,008 | `f2bf459a3255c09eaf4b2333d870eb1a7d06462132c18e0d85dc3a06ac73d5d6` | fail-closed duplicate `strategy_fast_ema_period` |
| ablation_02 | 1,008 | `477bc9142a10fc09e590d32aad14e056af0710d520f35882525313e4babc6cf1` | fail-closed duplicate `strategy_fast_ema_period` |

The base assignments are `strategy_fast_ema_period`,
`strategy_slow_ema_period`, `strategy_atr_period`, `strategy_atr_sl_mult`,
`strategy_take_profit_rr`, and `strategy_max_spread_points`.

Each ablation child contains those same six keys at lines 21-26 and again at
lines 28-33, separated by its ablation-child comment. For example, ablation_00
has base `strategy_atr_period=14` at line 23 and override
`strategy_atr_period=16` at line 30. Across each file: 12 exact strategy lines,
six distinct keys, and all six keys duplicated. This was latent while the old
marker-only parser returned an empty mapping.

## Why the fourth requested proof cannot be claimed

The brief simultaneously requires:

- duplicate keys remain fail-closed; and
- all four current, byte-identical files return more than zero assignments.

The three current ablation byte streams make those requirements mutually
exclusive. The implementation therefore preserves the safety invariant and
reports the contradiction rather than silently choosing one duplicate value.

Acceptable next decisions require separate authority:

1. Specify and review a markerless multi-block precedence rule (for example an
   exact ablation-child block contract), explicitly amending the global
   duplicate fail-closed requirement; or
2. establish a new evidence vintage with corrected single-assignment setfiles
   and decide which Q02-Q07 lineage must be regenerated/requalified.

Neither is authorized by this ticket. Editing the current files would break
their evidence-bound hashes.

## Queue boundary

Read-only immutable-DB inspection still shows work item
`95015420-11d0-4c11-bb98-25fa2a361048` as Q08 `done/INFRA_FAIL`, with reason
`neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params`
and update timestamp `2026-07-27T04:36:23+00:00`. The global MNT-007
non-retryable classification was not changed. Re-admission still requires the
separately authorized single-target requalification controller named in the
brief.

Verdict: **READY_FOR_CLAUDE_REVIEW_WITH_ACCEPTANCE_CONFLICT**.
