# QUA-420 FIX-LIST Closeout (QM5_SRC04_S03)

## Scope
CTO FIX-LIST remediation for `QM5_SRC04_S03_lien_fade_double_zeros` (child of QUA-417) completed in commit `83c1e4c`.

## Commit
- `83c1e4c` — `fix(src04_s03): apply QUA-420 fix-list risk mode + warning cleanup`

## FIX-LIST Mapping
1. Compile warnings must be zero
- EA warning resolved: unchecked `OrderSend` in `CancelOurPendingOrders()` now checks send result + retcode and logs warning events.
- Include-chain warnings resolved in active branch:
  - `QM_RiskSizer.mqh`: `ACCOUNT_FREEMARGIN` -> `ACCOUNT_MARGIN_FREE`
  - `QM_ChartUI.mqh`: removed deprecated `POSITION_COMMISSION` open-position accessor

2. Explicit risk-mode enum input + dual-mode wiring
- Added EA input enum `QM5_RiskModeInput` with values `AUTO`, `FIXED`, `PERCENT`.
- Kept both framework inputs present: `RISK_FIXED` and `RISK_PERCENT`.
- `AUTO` wiring is ENV-consistent:
  - tester (`MQL_TESTER != 0`) -> `FIXED`
  - live (`MQL_TESTER == 0`) -> `PERCENT`
- Defaults now satisfy contract:
  - backtest fixed-risk default: `RISK_FIXED=1000.0`
  - live percent-risk default: `RISK_PERCENT=1.0`

3. Card fidelity + hard rules preservation
- Entry/exit/filter trading logic unchanged (only warning/risk wiring edits).
- Friday Close remains default-enabled.
- Magic remains framework path via `QM_Magic(qm_ea_id, qm_magic_slot_offset)`.
- No hardcoded symbol, no ML imports, no external API.

## Compile Evidence
Strict single-EA compile command:
- `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.mq5 -Strict`

Evidence log:
- `framework/build/compile/20260428_115145/QM5_SRC04_S03_lien_fade_double_zeros.compile.log`
- Result line: `0 errors, 0 warnings`

Note:
- Wrapper reports known `METAEDITOR_NONZERO_EXIT` anomaly despite clean compile log; compile log is authoritative for warning gate.

## CTO Next Action
- Run CTO EA-vs-card re-review on commit `83c1e4c`.
- If accepted, allow Pipeline-Operator progression to next phase gate.
