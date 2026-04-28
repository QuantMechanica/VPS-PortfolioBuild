QUA-420 development closeout (review-ready).

Primary remediation commit:
- `83c1e4c`

Support/handoff commits:
- `3b6bbee` closeout doc
- `3ca59bc` CTO review packet
- `4c36c0b` blocked-state record
- `dcd5847` patch bundle export
- `b256f32` execution ledger
- `9c4c02c`, `ccc5640`, `922a4c2`, `819fc07` transition diagnostics/repro

Verification:
- Compile log: `framework/build/compile/20260428_115145/QM5_SRC04_S03_lien_fade_double_zeros.compile.log`
- Result: `0 errors, 0 warnings`

Card/hard-rule checks:
- Entry/exit/filter logic preserved
- Friday Close default-enabled preserved
- Magic path remains `QM_Magic(...)`
- Dual risk contract explicit (`RISK_FIXED` + `RISK_PERCENT` with selector)

Status request:
- Keep `in_review` pending CTO verdict on FIX-LIST closure.
