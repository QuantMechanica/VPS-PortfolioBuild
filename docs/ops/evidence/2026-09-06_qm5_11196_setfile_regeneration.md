# QM5_11196 Governed Set Regeneration

Date: 2026-09-06
Router task: `e638e0de-26fd-4e93-8089-b0670e4691f1`
State requested after review: `REVIEW`

## Finding

`QM5_11196_ft-heracles.mq5` exposes 18 `strategy_*` inputs. The historical
`QM5_11196_ft-heracles_XAUUSD.DWX_H4_backtest.set` predates those inputs and
contains no `strategy_*` assignments, so Q08 sub-gate 8.5 deterministically
reports `baseline_setfile_defect:empty_strategy_params`.

## Repair

- Preserved the historical set file unchanged.
- Generated the append-only replacement
  `framework/EAs/QM5_11196_ft-heracles/sets/QM5_11196_ft-heracles_XAUUSD.DWX_H4_backtest_s20260906-001.set`
  through `framework/scripts/gen_setfile.ps1` with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and the EA's declared strategy defaults.
- Added a path-specific `.gitattributes` `-text` rule for byte-stable set-file
  identity.
- Updated both approved-card declaration copies so `locked_parameters` exactly
  equals the effective configuration: compiled source defaults overlaid by the
  replacement set. This removes legacy `qm_filter_*` assignments that existed
  only in the historical set and records MT5's serialized H4 value `16388`.

Replacement set SHA-256:
`7cc424d2334be3835815fdbfbf874fc2cabffcdc15d689b64830cffce9c3bf6b`.

## Verification

- `prepare_book_q08_regeneration.setfile_defect(...)`: `None`.
- Single-configuration locked-parameter equality: `True` across 33 effective
  inputs.
- `git check-attr text`: `text: unset` for the replacement set.
- `validate_build_guardrails.py` on the EA source and replacement set: `PASS`;
  `qm_news_stale_max_hours=336`; no findings.
- Disposable-copy replay of `a79887e3-7f60-40f6-a2a8-0d7785acf400` with only
  its set path/hash rebound to the replacement: producer `SEALED`,
  `selection_trial_count=1`, window `2017-01-01` through `2025-12-31`, DSR
  evaluator `PASS` over 656 closed trades.
- Focused tests: 32 DSR tests passed; 58 cascade tests plus 13 subtests passed.

The replay used `D:/QM/tmp/codex_dsr_replay_20260906_acf3637b/farm_state.sqlite`
with `PRAGMA query_only=ON` after fixture rebinding. No production queue row,
stored verdict, terminal, scheduler, `T_Live`, or AutoTrading state was changed.
The replay result is verification evidence, not a pipeline verdict and not
authorization to enqueue.
