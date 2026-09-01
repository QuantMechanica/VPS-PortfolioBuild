# QM5_41272 compile-complete review handoff

Date: 2026-09-01  
Router task: `2e0bc944-0f47-47e2-b6c2-e7b83db89147`  
Build task: `28ba8397-3400-4f5b-a545-0d5ba7278200`  
Operator: Codex on `agents/board-advisor`

## Verdict

The append-only source-repair compile row for
`QM5_41272_turn-of-month-index-long-restart-r1` completed `COMPILE_OK` with
zero MetaEditor errors, zero warnings, and a passing Q01 build check. The
restart-safe recovery is ready for independent build review. It has not been
recorded through `farmctl record-build` and no Q02 row has been seeded, because
the generic recorder auto-seeds Q02 while this OWNER-bound recovery explicitly
requires independent review first.

## Exact build binding

| Item | Binding |
|---|---|
| Source | `framework/EAs/QM5_41272_turn-of-month-index-long-restart-r1/QM5_41272_turn-of-month-index-long-restart-r1.mq5` |
| Source SHA-256 | `47579844c327c1aee22986fef9c3170a1fcc973926c9908ec0c91d27b5d5d442` |
| Binary SHA-256 | `2845820d099232713c053266e0b6204ef904e872f5cd6fad2efbcc6441ef4fe9` |
| Setfile SHA-256 | `6474359fd97c4fb7625d159deaf6fcbd186c5bdf14f70fffcabad2d8e40b9e16` |
| Setfile build-hash header | `14dfa0c26b135c21b4a42c79b08fe2bb36c64cde7f37027dfb6c98e55ebedf10` |
| Compile work item | `85c6de75-0080-45dc-b128-6e6a3910f047` |
| Compile evidence | `D:/QM/reports/work_items/85c6de75-0080-45dc-b128-6e6a3910f047/QM5_41272/COMPILE_EA/compile_evidence.json` |
| Compile-evidence SHA-256 | `3210bc7225d8e1b1087418d3d7573014685e1b11fcf3de25f5d75052db6263e9` |
| Compile verdict | `COMPILE_OK`; `build_check_result=PASS`; errors `0`; warnings `0` |

The immutable failed predecessor remains work item
`8784ae52-96aa-4c03-97b5-424edc9ea3ad`. Its two Q01 findings are not
overwritten; the successful row is the sanctioned append-only repair bound to
the repaired source hash above.

## Focused verification

Fresh checks on the compiled source and generated setfile:

- `python -m pytest -q framework/EAs/QM5_41272_turn-of-month-index-long-restart-r1/tests/test_restart_rehydration.py`
  -> `4 passed`;
- `python -m pytest -q tools/strategy_farm/tests/test_compile_work_items.py`
  -> `60 passed`;
- `python tools/strategy_farm/validate_build_guardrails.py <mq5> <set>`
  -> both paths `PASS`, zero findings, news-staleness ceiling `336`;
- `git diff --check -- framework/EAs/QM5_41272_turn-of-month-index-long-restart-r1`
  -> clean;
- exact work-item query shows only the failed and successful `COMPILE_EA`
  rows for `QM5_41272`; Q02 row count remains zero.

The backtest set remains `RISK_FIXED=1000` and `RISK_PERCENT=0`. No census
program, active backtest, terminal process, T_Live configuration, or
AutoTrading state was touched.

## Review boundary

Independent review must bind the source, EX5, setfile, approved recovery card,
restart regression, and compile receipt above. Only after an approved review
may the governed build record and one fresh Q02 seed be created. The old
`QM5_20004` Q04-Q06 evidence remains historical and must never be rebound to
this new identity.
