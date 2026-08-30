# QM5_38006 Gemini rework — mandatory Codex review

- Review task: `6af79210-d7db-4712-94cf-4a40d626bb9d`
- Gemini source task: `8eb1627c-03bb-4f59-ab0a-b6c46c8a63ab`
- EA: `QM5_38006_codetrading-doji-hammer-pivot-rejection`
- Rework commit: `3e6cc85e523d9331489c5e2bb825f7b07910f8cc`
- Reviewed at: `2026-08-30T16:37:16Z`
- Disposition: **CHANGES_REQUIRED — remain in REVIEW**
- Pipeline verdict: **none** (this is code-review evidence, not pipeline evidence)

The task payload requested `code-review` and `gemini-output-review`. Neither
skill is installed in this Codex session, so the review was performed directly
against the approved card, the current source and binary, the durable build
identity, the governed compiler evidence, and the repository guardrails.

## Review outcome

The current MQ5 contains the two requested source repairs:

1. `StrategyTotalDrawdownHaltCheck` records initial equity, latches at the
   card-authorized 5.0% total-drawdown threshold, closes positions for the
   framework magic, and runs on the tester-active `OnTick` path.
2. `StrategyDailyRealizedLossHalt` fails closed when `HistorySelect` fails and
   emits `HISTORY_SELECT_FAILED` while retaining the separate 2.5% framework
   daily hard stop.

The compiled deliverable still predates those repairs. Therefore the Gemini
output is not accepted and must not be submitted to Q02.

## Blocking finding

### F1 — current MQ5 is not the source used to produce the current EX5

At review time the repository files were:

- current MQ5 SHA-256:
  `52edb8f216fb7f35df6e1298ef7fd2fb661e79ceb4ee156c952295c46d747dd2`
- current EX5 SHA-256:
  `dc90fac248aa873859bb374979d336c60e7c9474b99a3570ac3e3d7f6300624b`
- MQ5 last-write time: `2026-08-30T15:06:53Z`
- EX5 last-write time: `2026-08-30T05:05:29Z`

The only governed compile work item for this EA remains
`2e0c4df5-9c1c-4498-bdb5-b49d0b785c68`, completed at
`2026-08-30T05:05:40Z`. Its evidence records:

- compiled MQ5 SHA-256:
  `7031db1a2fef63e99394dc224e96c234676d33b8130f3cddcd1c79402b8d5831`
- produced EX5 SHA-256:
  `dc90fac248aa873859bb374979d336c60e7c9474b99a3570ac3e3d7f6300624b`

The current EX5 is consequently the output of the pre-rework MQ5. Editing
`docs/ops/evidence/8eb1627c_qm5_38006_build_identity.json` to name the current
MQ5 hash while retaining the old EX5 hash does not establish build provenance.
The compiled artifact does not contain the reviewed drawdown and history
failure repairs.

`python C:/QM/repo/tools/strategy_farm/farmctl.py work-items --ea QM5_38006`
also reports only that one completed compile work item; no post-rework governed
compile evidence exists.

## Focused verification

| Check | Result |
|---|---|
| `python -m pytest tools/strategy_farm/tests/test_qm5_38006_rework_static.py -q -p no:cacheprovider` | PASS — 11 passed |
| `python -m pytest tools/strategy_farm/tests/test_build_guardrails.py -q -p no:cacheprovider` | PASS — 22 passed |
| `validate_build_guardrails.py` over the MQ5 and all three backtest sets | PASS — no findings; `qm_news_stale_max_hours=336`, `RISK_FIXED=1000`, and `RISK_PERCENT=0` preserved |
| `build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_38006_codetrading-doji-hammer-pivot-rejection` | PASS — no failures or warnings |
| `skill_build_ea_guard.py --ea-id 38006 --ea-label QM5_38006_codetrading-doji-hammer-pivot-rejection` | PASS — registry, magic rows, and EA directory valid |
| `validate_spec_doc.py framework/EAs/QM5_38006_codetrading-doji-hammer-pivot-rejection` | PASS |
| Current identity versus governed compile evidence | **FAIL — current MQ5 hash differs from the compiled MQ5 hash; EX5 is unchanged** |

These source/configuration checks are not pipeline verdicts and cannot repair
the binary identity failure.

## Required rework before another review

1. Produce a governed compile work item for the current MQ5 without manually
   starting a terminal.
2. Require compiler evidence whose captured MQ5 SHA-256 is
   `52edb8f216fb7f35df6e1298ef7fd2fb661e79ceb4ee156c952295c46d747dd2`
   and whose EX5 is the output of that compile.
3. Regenerate/reseal the three backtest set identities and rebuild the durable
   identity artifact from the fresh compiler evidence; do not hand-edit hashes.
4. Rerun the focused guards and obtain another mandatory Codex review. Preserve
   the 336-hour news-staleness ceiling and the fixed-risk backtest contract.

No terminal, AutoTrading, live setting, or pipeline state was changed during
this review.
