# Codex router build pre-flight block: QM5_11291, QM5_11292, QM5_11294, QM5_11299, QM5_11300

Date: 2026-08-10  
Role: Codex / Development  
Scope: one deterministic router cycle; five `build_ea` tasks at numeric priority 50  
Verdict: `PRECHECK_BLOCK_MAGIC_ROWS_MISSING`

## Outcome

No EA implementation, registry mutation, compile, smoke test, pipeline phase, terminal launch, or queue mutation was performed for this cohort.

All five approved cards have a matching active row in the canonical EA-ID registry, but none has any row in the canonical magic-number registry. The selected `qm-build-ea-from-card` procedure requires the allocated EA-ID and all required `(ea_id, symbol_slot)` magic rows to exist before Development starts, and explicitly excludes allocating either registry from the build scope.

## Router tasks checked

| Priority | Task ID | EA | Card slug | Canonical EA-ID rows | Canonical magic rows | Result |
|---:|---|---|---|---:|---:|---|
| 50 | `aa43aa9c-27b9-4ee3-b71c-58c1a4abd0f5` | `QM5_11291` | `tc20-ema18-28-wma5-12-rsi21-h1` | 1 | 0 | pre-flight block |
| 50 | `56e67144-da6b-48b8-89ae-ba7048da97a9` | `QM5_11292` | `trix14-signal-cross` | 1 | 0 | pre-flight block |
| 50 | `a53520bc-d92a-4aa2-b6fb-3e24d974cba8` | `QM5_11294` | `cs-ichi-cloud` | 1 | 0 | pre-flight block |
| 50 | `ea624d92-20db-425b-9deb-840b11c83d40` | `QM5_11299` | `lwma144-smma5-fractal-m5-scalp` | 1 | 0 | pre-flight block |
| 50 | `03dbc26e-174f-4879-bbbc-ac69b07ec692` | `QM5_11300` | `macd-psar-atr-trender-h4` | 1 | 0 | pre-flight block |

All cards were read from `D:/QM/strategy_farm/artifacts/cards_approved/` and each declares `g0_status: APPROVED`. Canonical EA-ID slugs exactly match the card and task slugs.

## Missing governed allocations

The approved-card target baskets that require governed magic rows are:

- `QM5_11291`: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`
- `QM5_11292`: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`
- `QM5_11294`: `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`, `GDAXI.DWX`, `NDX.DWX`
- `QM5_11299`: `EURUSD.DWX`, `GBPUSD.DWX`
- `QM5_11300`: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`

The symbol list above records card intent only; it is not an allocation and does not reserve slots.

## Repository state observed

Canonical sources checked:

- `C:/QM/repo/framework/registry/ea_id_registry.csv`
- `C:/QM/repo/framework/registry/magic_numbers.csv`

The scheduled-task worktree at `C:/QM/worktrees/codex-orchestration-1` is behind the canonical registry and lacks even these five EA-ID rows. The canonical checkout does contain the EA-ID rows.

Five pre-existing, untracked `.mq5` scaffold files were also present in `C:/QM/repo/framework/EAs/`, all created at approximately `2026-08-10T15:33:13+02:00`. They contain no durable compile or pipeline evidence and were not modified or accepted by this cycle. No `.ex5` or setfile was present in those folders at pre-flight.

## Focused verification

The registry check used exact CSV-field matching for both numeric and legacy `QM5_`-prefixed forms of `ea_id`. Results were:

```text
ea_id      ea_registry_rows  registry_slug                              magic_rows
QM5_11291  1                 tc20-ema18-28-wma5-12-rsi21-h1             0
QM5_11292  1                 trix14-signal-cross                        0
QM5_11294  1                 cs-ichi-cloud                              0
QM5_11299  1                 lwma144-smma5-fractal-m5-scalp             0
QM5_11300  1                 macd-psar-atr-trender-h4                   0
```

This is a deterministic precondition failure, not a compile verdict or pipeline verdict.

## Required next action

Allocate and activate the required magic rows through the OWNER-governed deterministic registry workflow, synchronize the registered Development worktree to the canonical registry, and then reroute the build tasks. Development must not invent or self-allocate the missing rows inside a build wake.
