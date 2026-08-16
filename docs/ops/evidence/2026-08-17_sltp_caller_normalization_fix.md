# SL/TP caller normalization audit and fix

- Router task: `9cb41afa-eb3a-42c4-a014-c11b36ccaf26`
- Audit date: 2026-08-17 (Europe/Berlin)
- Scope: every direct `QM_TM_MoveSL` and `QM_TM_TrailATR` call in `framework/EAs/*/*.mq5`, `QM_TradeManagement.mqh`, and `framework/include/QM/modules/*.mqh`
- Machine-readable inventory: `docs/ops/evidence/2026-08-17_sltp_caller_normalization_audit.json`

## Outcome

The inventory contains all 638 direct caller sites and gives every site one of the required verdicts:

| Verdict | Calls |
|---|---:|
| `fixed here` | 170 |
| `already normalized` | 221 |
| `not a comparison` | 247 |

There are no remaining raw comparisons. The 170 corrections span 124 EA source files, and every modified EA path maps to at least one `fixed here` row in the inventory.

The reusable audit is `tools/strategy_farm/audit_sltp_caller_normalization.py`. It masks comments and strings, parses balanced management-call arguments, limits comparison discovery to the enclosing function, recognizes direct relational and difference-to-threshold comparisons, and compares the working tree with `HEAD` to distinguish `fixed here` from pre-existing normalization.

## Shared helper and module audit

No shared include required a source change. Direct calls in the following shared components were already normalized before comparison:

- `framework/include/QM/QM_TradeManagement.mqh`: three calls, all `already normalized` (`QM_TM_MoveToBreakEven`, `QM_TM_TrailATR`, and `QM_TM_TrailStep` normalize their candidate before comparing it with the stored stop).
- `QM_Mod_EtTurtle20x.mqh`: two calls, both `already normalized`.
- `QM_Mod_FtmoJointRangeBreakout_20180.mqh`: one call, `already normalized`.
- `QM_Mod_GrimesNestedPbV2.mqh`: one `already normalized` call and one `not a comparison` call.

## Mechanical-neutrality argument

Before these changes, `QM_TM_MoveSL` ultimately passed its target through `QM_TM_SendSLTPModify`, which normalizes the value to symbol digits before sending it to the server. The defective callers compared an unnormalized candidate with `POSITION_SL`, although the stored stop represented the normalized value. The fixes make the caller comparison use the same normalized value that is sent.

Consequently, price selection, signal generation, entry timing, position sizing, initial risk, take-profit selection, and the target actually submitted are unchanged. The only changed behavior is the send/no-send decision when the raw candidate differs from the stored stop but both resolve to the same normalized price. Such requests are redundant and can produce repeated no-op/invalid-stop modify attempts. Normalization was kept local to stop-management candidates or comparisons; exploratory changes that could have rounded entry prices used in risk calculations were removed.

No `.ex5`, setfile, registry, resolver, news-calendar, risk mode, or pipeline verdict was changed. In particular, this work did not rebuild or replace the queued/live `QM5_20176` binary.

## Verification

Audit commands:

```text
python -m py_compile tools/strategy_farm/audit_sltp_caller_normalization.py
python tools/strategy_farm/audit_sltp_caller_normalization.py --manifest docs/ops/evidence/2026-08-17_sltp_caller_normalization_audit.json
```

Result: exit 0; current scan is 391 `already normalized`, 247 `not a comparison`, and zero raw comparisons. The manifest's `HEAD` comparison reclassifies 170 of the 391 normalized sites as `fixed here`.

Twelve representative current-source copies were compiled serially with `D:\QM\mt5\DEV1\MetaEditor64.exe /portable`. Each staged `.mq5` SHA-256 matched the repository source at compile time, and each log ended with `Result: 0 errors, 0 warnings`:

- `QM5_1012_lien-fader`
- `QM5_10214_tv-gvto-trend`
- `QM5_10933_grimes-cup-hndl`
- `QM5_11045_roman-ma-rev`
- `QM5_11160_dwx-brk-risk`
- `QM5_11412_wilder-volatility-system-atr-sar-d1`
- `QM5_1388_brooks-micro-channel-failed-test-h1`
- `QM5_1443_demark-td-lines-h4`
- `QM5_20122_bb-stoch-bandcross-h1`
- `QM5_20176_hopwood-ts5-standalone-h4-r1-recovery`
- `QM5_20180_ftmo-joint-sim-backtest-only` (FTMO joint-range module representative)
- `QM5_MXAU_master-xauusd` (EtTurtle/Grimes module representative)

Compile evidence is isolated under `D:\QM\reports\compile\sltp_caller_normalization_20260817\`; no compiled output was copied into the repository or any terminal.

`git diff --check` passed. `validate_build_guardrails.py` checked all 124 modified EA paths using a maximum news-staleness value of 336 hours: 91 paths passed and 33 reported only pre-existing `time_sensitive_strategy_params_missing` findings in existing setfiles. The diff contains no change to `qm_news_stale_max_hours`, `RISK_FIXED`, or `RISK_PERCENT`.

## Append-only canary status

The prior GBPUSD.DWX Q02 baseline work item `899fb1b4-3532-4cac-9f28-40485ea8c448` is PASS with the required reference metrics: net profit `-1930.20`, profit factor `0.89`, 51 trades, and drawdown `6435.34`.

The append-only canary work item `ef31c371-fbe9-4eff-b0c2-9087e1df49b7` did not start a tester run. At 2026-08-16 22:19:38 UTC its fail-closed preflight returned `INFRA_FAIL` / `staged_ex5_preflight_failed` with `dispatch_ex5_source_sha256_mismatch`. Therefore there is no post-change pipeline result and no exact-equivalence claim. The binary was deliberately not rebuilt or replaced; the canary gate remains for reviewer disposition under the normal build/review flow.
