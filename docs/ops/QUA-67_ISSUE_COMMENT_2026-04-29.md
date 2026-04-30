Status update for `QUA-67` (DEVOPS-008): ready for review.

Delivered patch in `D:/QM/mt5/T1/MQL5/Services/Import_DWX_Queue_Service.mq5`:
- `ProcessJob` resolves source with `SOURCE_OVERRIDES` parity and reads broker-source values for:
  - `SYMBOL_TRADE_TICK_VALUE`
  - `SYMBOL_TRADE_CONTRACT_SIZE`
  - `SYMBOL_SWAP_LONG`
  - `SYMBOL_SWAP_SHORT`
- Applies those values to the newly created target custom symbol.
- Leaves `SYMBOL_TRADE_TICK_VALUE_PROFIT`/`_LOSS` untouched (read-only).
- Adds weekend-clone defense: retries source-spec read (`3x`, `30s`) when source tick value is zero.
- Emits deferred visibility telemetry when tick value remains zero after retries (`deferred_spec_patch_count`, `deferred_spec_patch_symbols`).

Acceptance mapping:
- New imports source-derive from broker: implemented.
- Existing symbols remain untouched: enforced by `SymbolExists(target)` skip path.
- Weekend-clone defense: implemented in code + static check PASS.

Verification evidence:
- `C:/QM/repo/artifacts/qua-67/meta_compile.log` -> `0 errors, 0 warnings`
- `C:/QM/repo/artifacts/qua-67/weekend_clone_defense_check.txt` -> `summary=PASS failed_checks=0`

Unblock owner/action:
- Owner: CEO
- Action: perform runtime validation on next fresh symbol import and confirm acceptance.
