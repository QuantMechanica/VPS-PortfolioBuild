# QM5_38006 governed compile recovery

- Router task: `81811459-7f67-4799-b906-a3448ec69652`
- EA: `QM5_38006_codetrading-doji-hammer-pivot-rejection`
- Completed: `2026-08-30T17:19:55Z`
- Branch: `agents/board-advisor`
- Disposition: **READY FOR CODEX RE-REVIEW**
- Pipeline verdict: **none** (COMPILE_EA is build evidence, not a trading gate)

## Outcome

The canonical queue appended source-repair successor
`09320649-3bcf-453b-9828-19a8db881efe`. The rollout hold was released only for
that exact row after the release dry-run proved that its expected MQ5 SHA-256
matched the canonical source. A resident worker claimed the row on T4; no
terminal was started manually and no live or AutoTrading setting was changed.

The governed receipt is `COMPILE_OK` with compiler result `PASS`, zero compiler
errors, and zero compiler warnings. Its build check also passed. Four
event-vocabulary advisories are preserved in the receipt; they are not compiler
warnings and did not produce a build failure.

## Build identity

| Field | Value |
|---|---|
| Current/receipt MQ5 SHA-256 | `52edb8f216fb7f35df6e1298ef7fd2fb661e79ceb4ee156c952295c46d747dd2` |
| Current/receipt EX5 SHA-256 | `e6a7905650cbd401095d3856afada8bbe5fb39fc0560b6629215f820bead39ff` |
| Receipt path | `D:/QM/reports/work_items/09320649-3bcf-453b-9828-19a8db881efe/QM5_38006/COMPILE_EA/compile_evidence.json` |
| Receipt SHA-256 | `0602c940626e7ec71ece564a8e3382e891e31a155e5385cc3f3d5b94d43b2f4e` |
| Compiler | `PASS`, 0 errors, 0 warnings |
| Build check | `PASS` |
| Setfile count | 3 |

The durable identity at
`docs/ops/evidence/8eb1627c_qm5_38006_build_identity.json` now binds these exact
receipt, source, and binary hashes. The three backtest setfiles retain
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and the 336-hour news-staleness ceiling.

## Focused verification

- `python -m pytest tools/strategy_farm/tests/test_compile_work_items.py -q -p no:cacheprovider`: 44 passed.
- `python -m pytest tools/strategy_farm/tests/test_qm5_38006_rework_static.py -q -p no:cacheprovider`: 11 passed.
- Governed receipt source hash equals the current MQ5 hash.
- Governed receipt binary hash equals the current EX5 hash.
- Compiler errors/warnings are exactly `0/0`.

This evidence authorizes only another mandatory Codex review. It does not
self-approve Gemini code, move the EA to PIPELINE, or assert any pipeline gate
verdict.
