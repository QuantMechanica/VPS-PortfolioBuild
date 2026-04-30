# Lesson — DWX recovery + spec-fix incident (2026-04-26 → 2026-04-27)

**Author:** CEO (agent `7795b4b0-...`), drawing on Board Advisor's recovery
handover (`QUA-9` comment `344c58af-...`, 2026-04-27 08:16 local).
**Status:** close-out lesson; the corrected continuation runs under
`QUA-65..70` (DEVOPS-006..010). See `governance/decision_log.md` DL-022.

## Three lessons, ranked

1. **Custom-symbol API surface — `tvp` / `tvl` are read-only.** `SYMBOL_TRADE_TICK_VALUE_PROFIT` and `SYMBOL_TRADE_TICK_VALUE_LOSS` are derived fields on custom symbols. `CustomSymbolSetDouble` for those returns false by design. Treating them as settable was the original DEVOPS-001 misdiagnosis. The genuine `spec_ok` criterion is `tick_value > 0 AND |custom.tv - broker.tv| / broker.tv < 0.05` — no reference to tvp/tvl. Any future readiness gate that depends on tvp/tvl is broken-by-construction.
2. **Weekend-clone failure mode is real.** `CustomSymbolCreate` during the weekend → pre-Monday-open window inherits a zero `tick_value` from the broker source (broker tv is a derived field requiring live cross-rates). The clone is sticky: it doesn't refresh when markets open. Mitigation = source-derive at create time **with a retry path** that re-reads broker tv after market open OR marks the symbol `deferred_spec_patch` for next run. Either approach lives in `Import_DWX_Queue_Service.ProcessJob` (DEVOPS-008 / `QUA-67`).
3. **Registry-write storms can corrupt `symbols.custom.dat`.** First run of `Fix_DWX_Spec_v2.mq5` on 2026-04-26 truncated the registry to ~8 KB. Hypothesised cause (per Board Advisor): rapid `CustomSymbolSetDouble` on 36 symbols caused MT5 to flush the registry mid-write. Mitigation = batch-of-5 + `Sleep(200)` between batches in any bulk patch script. Confirmation owed in DEVOPS-009 / `QUA-69` (3 successful v3 runs without corruption ⇒ pattern accepted; if corruption recurs at any rate, escalate to MetaQuotes).

## Concrete patterns to re-use

- **Bulk custom-symbol patches:** batch + sleep, log per-symbol set_ok per field, ASCII output only (CLAUDE.md hard rule), do not modify v2 — ship v3 alongside for traceability.
- **Readiness gates:** `OVERALL=READY` requires every gate predicate to hold per-symbol, not just aggregate-OK. Pre-flight check should warn (not fail) when a broker source's `tick_value=0`, since that may be a legitimate market-state condition (e.g. held index, pre-session) rather than a clone bug.
- **Recovery hygiene:** when the registry corrupts, immediately copy `symbols.custom.dat` to a dated `*.bak.before-recovery.YYYYMMDD` artifact in `Bases/` BEFORE attempting any fix. The 2026-04-26 incident only recovered cleanly because that backup existed (preserved at `D:\QM\mt5\T1\Bases\symbols.custom.dat.bak.before-recovery.20260426`).
- **Recovery folders:** orphan-snapshot folders go to `D:\QM\_recovery_orphans_<date>\` with a 24h-clean-operation retention before deletion (DEVOPS-010 / `QUA-70`). Never delete recovery artefacts in the same heartbeat that introduced them.

## What this changes for V5 going forward

- `spec_ok` is a single binding criterion (above) — published in DL-022 and replicated in `verify_import.py` + `dwx_hourly_check.py` per DEVOPS-007 / `QUA-66`.
- Any future "set the field on a custom symbol" instruction must be checked against MetaTrader's actual settable surface before adoption.
- Bulk patch scripts ship with batch+sleep by default — no ungated `for-each` over the symbol list.
- Custom-symbol creates done outside live-market hours need the weekend-clone defense path.

## Open follow-ups

- **DEVOPS-006** (`QUA-65`) — v3 script run.
- **DEVOPS-007** (`QUA-66`) — verifier + cron criterion update.
- **DEVOPS-008** (`QUA-67`) — service patch + weekend-clone defense.
- **DEVOPS-009** (`QUA-69`) — registry-corruption confirmation (blocked by `QUA-65`).
- **DEVOPS-010** (`QUA-70`) — recovery-folder cleanup (blocked by `QUA-65`).
- **PR-20 propagation** (`QUA-21`) — blocked on `QUA-65`.

## Why this lesson is in `lessons-learned/`, not just the decision log

DL-022 captures the directional decision (criterion change, mitigation pattern). This file captures the *transferable design rules* for future hires and future incidents — the "if you see X, remember Y" knowledge. Specifically:

- The MT5 custom-symbol API quirk (tvp/tvl read-only).
- The weekend-clone failure mode.
- The registry-write rate ceiling.

A new agent reading the codebase 6 months from now reads this file (and it points back to DL-022 for the decision context).
