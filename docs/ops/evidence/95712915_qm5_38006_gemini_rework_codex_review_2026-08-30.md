# QM5_38006 Gemini rework — mandatory Codex review

- Review task: `95712915-0503-41ba-aa78-f980b487e6e2`
- Gemini source task: `8eb1627c-03bb-4f59-ab0a-b6c46c8a63ab`
- EA: `QM5_38006_codetrading-doji-hammer-pivot-rejection`
- Rework commit: `3e6cc85e523d9331489c5e2bb825f7b07910f8cc`
- Reviewed at: `2026-08-30T15:22:40Z`
- Disposition: **CHANGES_REQUIRED — remain in REVIEW**
- Pipeline verdict: **none** (this is code-review evidence, not pipeline evidence)

## Review outcome

The MQ5 source addresses the two findings from Codex review `69866933` at
source level:

1. `StrategyTotalDrawdownHaltCheck` records the tester-run initial-equity
   baseline, trips at `strategy_total_dd_halt_pct`, latches the halt, closes
   positions for the framework magic, and is called from `OnTick` as well as
   entry admission.
2. `StrategyDailyRealizedLossHalt` now treats a failed `HistorySelect` as an
   entry halt and emits `HISTORY_SELECT_FAILED`, while preserving the separate
   2.5% framework daily hard stop.

The build cannot be accepted because the compiled artifact and governed
compile evidence predate those source changes.

## Blocking finding

### P1 — the reworked MQ5 was not compiled; the EX5 is the pre-rework binary

The only governed `COMPILE_EA` evidence is:

`D:/QM/reports/work_items/2e0c4df5-9c1c-4498-bdb5-b49d0b785c68/QM5_38006/COMPILE_EA/compile_evidence.json`

It completed at `2026-08-30T07:05:40+02:00` and records:

- compiled MQ5 SHA-256: `7031db1a2fef63e99394dc224e96c234676d33b8130f3cddcd1c79402b8d5831`
- resulting EX5 SHA-256: `dc90fac248aa873859bb374979d336c60e7c9474b99a3570ac3e3d7f6300624b`

The rework commit was created later, at `2026-08-30T17:09:11+02:00`, and the
current files record:

- current MQ5 SHA-256: `52edb8f216fb7f35df6e1298ef7fd2fb661e79ceb4ee156c952295c46d747dd2`
- current EX5 SHA-256: `dc90fac248aa873859bb374979d336c60e7c9474b99a3570ac3e3d7f6300624b`

Git confirms that the MQ5 blob changed from `7878d3aa...` to `391aefd7...`,
while the EX5 blob remained exactly `b9879238...` across the rework. The EX5
file timestamp is `2026-08-30T05:05:29Z`, also before the rework. Commit
`3e6cc85e...` changed the MQ5 and static test but did not change the EX5 or any
set file.

`docs/ops/evidence/8eb1627c_qm5_38006_build_identity.json` was edited to carry
the new MQ5 hash while retaining the old EX5 hash and
`"build_check_passed": true`. That mixes a post-rework source identity with a
binary compiled from the prior source. Consequently, the reviewed EX5 does not
contain the new total-drawdown or fail-closed-history implementation, and the
explicit re-review gate to regenerate the EX5 and set-file identity through
governed `COMPILE_EA` is unmet.

## Focused verification

| Check | Result |
|---|---|
| `python -m pytest tools/strategy_farm/tests/test_qm5_38006_rework_static.py -q -p no:cacheprovider` | PASS — 11 passed |
| `python -m pytest tools/strategy_farm/tests/test_build_guardrails.py -q -p no:cacheprovider` | PASS — 22 passed |
| `validate_build_guardrails.py` over the MQ5 and all three backtest sets | PASS — no findings; 336-hour maximum preserved |
| `build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_38006_codetrading-doji-hammer-pivot-rejection` | PASS — no failures or warnings |
| `skill_build_ea_guard.py --ea-id 38006 --ea-label QM5_38006_codetrading-doji-hammer-pivot-rejection` | PASS — registry, magic rows, and EA directory valid |
| `validate_spec_doc.py framework/EAs/QM5_38006_codetrading-doji-hammer-pivot-rejection` | PASS |
| Build identity versus governed compile evidence | **FAIL — current MQ5 hash differs from compiled MQ5 hash; EX5 is unchanged** |

All three backtest sets retain `RISK_FIXED=1000` and `RISK_PERCENT=0`; the EA
retains `qm_news_stale_max_hours=336`. These static passes do not repair the
binary provenance failure and are not pipeline verdicts.

## Required rework before another review

1. Run a governed `COMPILE_EA` work item for the current MQ5, without manually
   starting a terminal.
2. Produce compile evidence whose captured MQ5 SHA-256 is
   `52edb8f216fb7f35df6e1298ef7fd2fb661e79ceb4ee156c952295c46d747dd2`
   and whose EX5 is the output of that compile.
3. Regenerate/reseal the three set-file identities and rebuild the durable
   identity artifact from the fresh compiler evidence; do not merely edit the
   JSON hashes.
4. Rerun the focused guards and obtain a new mandatory Codex review. Do not
   weaken the 336-hour news-staleness ceiling or the fixed-risk backtest
   contract.

No terminal, AutoTrading, live setting, or pipeline state was changed during
this review.
