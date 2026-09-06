# Pacer framework-input pin prevention and source repair review

Date: 2026-09-06  
Router task: `ce69613c-bd4a-4c50-a24f-ee8947295ac7`  
State: REVIEW; no compile enqueue and no worker reload

## Prevention

- `codex_fleet_pacer.py` now prepends a binding build guard to every rotating
  mission before it is passed to the managed Codex process.
- The guard and the canonical `codex_build_ea.md` prompt permit locked checks
  only for strategy parameters, EA identity/magic slot, and backtest risk mode.
  Framework-owned seed, news, and Friday-close values cannot be compared;
  stress probability is limited to finite inclusive `0..1` validation.
- The pacer guard requires
  `audit_framework_input_pins.py --check-source <mq5>` after source generation
  and before any `enqueue-compile`. A finding or nonzero exit explicitly refuses
  enqueue.
- The audit tool now exposes that single/multi-source fail-closed mode, returning
  exit `1` for `EA_FRAMEWORK_INPUT_PINNED` and exit `2` for an invalid source.
- `EA_Skeleton.mq5` carries the same ownership contract beside the strategy
  guard hook.

## Today’s affected EAs

- `QM5_41366_xtixng-decouple-cont`
- `QM5_41367_xtixng-commonshock-cont`

Both source-only repairs remove seed/news/Friday comparisons from
`Strategy_InputsValid`, retain identity, strategy, and fixed-risk checks, and
retain the existing finite inclusive stress range. Their LF bytes are pinned as
`-text` in `.gitattributes`.

The two exact append-only authorities are sealed by
`2026-09-06_pacer_framework_input_pin_authority.json`, SHA-256
`be2e3d2e075de22428efe96775ed9580c198ea193bae2a3a0e8e2acc9d69d9cf`.
Each binds one repaired source and its completed `COMPILE_OK` predecessor.

## Verification

- Direct `--check-source` on both repaired EAs: zero predicate findings.
- Generated fixture from `EA_Skeleton.mq5`: predicate clean.
- Positive generated fixture with `qm_rng_seed == 42`: CLI exit `1` and one
  `EA_FRAMEWORK_INPUT_PINNED` finding.
- Focused suite: `249 passed`.
- Real source-repair CLI dry runs: 2/2 `ELIGIBLE`,
  `source_repair_authorized=true`, `mode=dry_run`, `enqueued_count=0`; receipts
  are in `2026-09-06_pacer_framework_input_pin_dry_run.json`.

No pipeline verdict, work-item status, live setting, or terminal process was
changed.
