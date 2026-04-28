# QUA-420 CTO Review Packet (Ready-to-Review)

Date: 2026-04-28
Issue: QUA-420 (child of QUA-417)

## Review target commits
1. `83c1e4c` - code remediation
2. `3b6bbee` - FIX-LIST closeout handoff doc

## Evidence snapshot
- Compile log: `framework/build/compile/20260428_115145/QM5_SRC04_S03_lien_fade_double_zeros.compile.log`
- Final compile line: `Result: 0 errors, 0 warnings, 1956 ms elapsed, cpu='X64 Regular'`

## Line-anchored checks for CTO

### A) Explicit risk-mode enum + dual-risk contract
- EA input enum present: `QM5_RiskModeInput` at line 13
- Input selector present: `qm_risk_mode` at line 19
- Percent input present: `RISK_PERCENT=1.0` at line 20 (live default)
- Fixed input present: `RISK_FIXED=1000.0` at line 21 (backtest default)
- AUTO wiring: line 321 onward (`MQL_TESTER != 0` -> fixed, else percent)
- Framework call receives resolved risk pair: lines 332-336

### B) EA warning fix (unchecked OrderSend)
- Function: `CancelOurPendingOrders()` line 119
- `OrderSend` return checked and logged:
  - send-fail log key `PENDING_CANCEL_SEND_FAIL` at line 147
  - non-DONE retcode log key `PENDING_CANCEL_RETCODE` at line 154

### C) Framework include-chain warning cleanup
- `QM_RiskSizer.mqh` line 163 uses `ACCOUNT_MARGIN_FREE` (deprecated constant removed)
- `QM_ChartUI.mqh` open PnL aggregation no longer reads deprecated `POSITION_COMMISSION`

### D) Hard-rule preservation spot checks
- Friday close default-enabled input remains true: line 28
- Magic path preserved via `QM_Magic(qm_ea_id, qm_magic_slot_offset)`: line 45
- Entry/exit wiring unchanged; `CancelOurPendingOrders()` still invoked from `OnStrategyBar()` line 298

## CTO action
- Review commit `83c1e4c` against card and FIX-LIST using this packet + `QUA-420_FIXLIST_CLOSEOUT_2026-04-28.md`.
