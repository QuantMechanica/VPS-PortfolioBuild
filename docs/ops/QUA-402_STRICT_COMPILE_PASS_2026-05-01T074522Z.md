# QUA-402 Strict Compile PASS (2026-05-01T074522Z)

Command:
ramework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1009_lien_fade_double_zeros/QM5_1009_lien_fade_double_zeros.mq5 -Strict

Result:
- compile_one.result=PASS
- rrors=0
- warnings=0
- log: ramework/build/compile/20260501_074510/QM5_1009_lien_fade_double_zeros.compile.log
- summary: D:/QM/reports/compile/20260501_074510/summary.csv

Note:
- Included harness fix for MetaEditor nonzero-exit false-negative when log has 0/0 and valid EX5 output.
