# QM5_12580 FX Magic Resolver Rebuild And Q02 Requeue

Date: 2026-06-27
Agent: codex-board-advisor
Branch: agents/board-advisor

## Scope

- EA: `QM5_12580_fx-usd-exhaustion-reversal`
- Instrument focus: seven-symbol D1 FX basket (`EURUSD.DWX`, `GBPUSD.DWX`,
  `AUDUSD.DWX`, `NZDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`)
- Farm DB task: `f118eb4a-65c0-42a1-8f0a-d63441f70238`
- Constraint boundary: no portfolio gate change, no `T_Live`, no AutoTrading

## Action

The farm task was blocked by an older Codex review finding that
`HasOpenUsdDirection` used a hardcoded magic range. The current repo source is
already resolver-based:

```mql5
const int slot = SymbolSlot(symbol);
const int expected_magic = QM_Magic(qm_ea_id, slot);
```

This wake rebuilt the EA from that resolver-based source, refreshed all seven
backtest setfile build hashes, recorded the build through `farmctl
record-build`, and staged a new Q02 wave.

## Validation

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12580_fx-usd-exhaustion-reversal`
  - Result: `PASS`
- `pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_12580_fx-usd-exhaustion-reversal`
  - Result: `PASS`
  - Failures: `0`
  - Warnings: `16` existing shared-framework DWX advisories
  - Report: `D:/QM/reports/framework/21/build_check_20260627_134748.json`
- `pwsh -NoProfile -File framework/scripts/compile_one.ps1 -EALabel QM5_12580_fx-usd-exhaustion-reversal -Strict`
  - Result: `PASS`
  - Errors: `0`
  - Warnings: `0`
  - Compile log: `framework/build/compile/20260627_134811/QM5_12580_fx-usd-exhaustion-reversal.compile.log`

Compiled artifact SHA256:

```text
E314A20A11E902B7B58526F70D76B521EE67C52F58A79945F657FD27AC6E9295
```

## Queue Action

Database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Claimed the blocked build task, recorded
`D:/QM/strategy_farm/artifacts/builds/f118eb4a-65c0-42a1-8f0a-d63441f70238.json`,
cleared the stale `blocked_reason`, and marked the task `done`.

`record-build` inserted these non-active Q02 stage-one rows:

| Symbol | Work item |
|---|---|
| `EURUSD.DWX` | `37cdb882-7500-466f-b45a-5e648b0cfe3d` |
| `GBPUSD.DWX` | `9a3889e1-0c64-48e8-a062-dc44361bbc6a` |
| `AUDUSD.DWX` | `c5049294-2374-4981-a27c-e999e3b820af` |

The other four symbols were recorded by the farm's normal staged deferral path:
`NZDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`.

## CPU Ceiling

No manual MT5 backtest was launched. Q02 execution is delegated to the paced
worker fleet.
