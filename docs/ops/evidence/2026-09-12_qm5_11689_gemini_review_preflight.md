# QM5_11689 Gemini review rework — deterministic preflight stop

Date: 2026-09-12
Router task: `b36ca851-5323-405b-9a22-f9c5a7c596ae`
Source task: `bf461f09-93ea-4eaa-9419-86d3f058b22d`
EA: `QM5_11689_strat-bb-mr`
Disposition: REVIEW — blocked before source mutation or compile

## Reproduced findings

The prior review finding reproduces in the MQ5: `Strategy_EntrySignal` calls raw `iClose` for shift 1 and `Strategy_ExitSignal` calls raw `iClose` for shifts 1 and 2. Those accesses must be replaced by checked `QM_ReadBar` calls before a build can be accepted.

The identity defect is upstream of the EA source. The OWNER-approved card declares `target_symbols: [EURUSD.DWX, XAUUSD.DWX, GER40.DWX]`, and magic row `11689/slot 2` is allocated to `GER40.DWX`. The canonical symbol matrix and execution alias registry instead identify the Darwinex DAX symbol as `GDAXI.DWX` (`framework/registry/dwx_symbol_matrix.csv` and `execution_symbol_aliases_v1.json`, where raw `GER40.cash` maps to logical `GDAXI.DWX`). No active `11689/GDAXI.DWX` row exists.

## Why no repair was applied

The `qm-build-ea-from-card` preflight requires the approved card and already-allocated magic rows to cover every symbol used. Its boundary expressly does not allocate or rewrite magic rows. Changing only the setfile or only the registry would make the package disagree with its approved card; changing the approved card is an OWNER decision. Therefore preflight fails before build work is authorized.

Required unblock sequence:

1. OWNER amends/re-approves the QM5_11689 card universe from `GER40.DWX` to canonical `GDAXI.DWX`.
2. The governed registry-writer lane migrates or replaces slot 2 while preserving magic identity `116890002`, regenerates `QM_MagicResolver.mqh`, and proves the row survives regeneration.
3. Requeue Codex review to replace the three raw `iClose` calls with checked `QM_ReadBar`, rename the setfile symbol segment, add the canonical SPEC/tests, and request COMPILE_EA under an exact-source authority.

No MQ5, setfile, approved card, registry, resolver, EX5, pipeline verdict, or historical result was mutated. No compile or backtest was started.

RESULT: BLOCKED_APPROVED_CARD_AND_MAGIC_ROW_USE_NONCANONICAL_GER40_OWNER_AND_REGISTRY_WRITER_REQUIRED
