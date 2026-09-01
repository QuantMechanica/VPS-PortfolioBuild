# Q09 REQUAL-8 Pair 5 Build Recorded — Review Pending

- Orchestration task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER hold: `7bbeef66-becf-4bd3-aa5c-1d00bde262d8` (remains active)
- Pair: 5 of 8
- EA: `QM5_41219_cum-rsi2-commodity-requal8`
- Parent: `QM5_12567_cum-rsi2-commodity`
- Build task: `da8e6083-8e62-43a7-85f4-68d009383e96`
- Authority manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Recovery card SHA-256: `af36edefbf33f5269da134ebd3c31de238fc0e928a67dbc26ed3ab0a2d126aba`
- Canonical branch: `agents/board-advisor`
- Build commit: `a9767089d9`
- Checkpoint: build recorded; Codex review and Q02 remain pending

## Outcome

Pair 5 was implemented as a faithful identity-preserving port of the approved cumulative-RSI commodity strategy for `XAUUSD.DWX` on `D1`. The source, specification, governed backtest set, EX5, and compile-release receipt were committed with explicit pathspecs on `agents/board-advisor` in commit `a9767089d9`.

The build was compiled only by the governed `COMPILE_EA` queue. The resident worker completed work item `ed5f9b8f-8804-4678-8908-621aa97aa985` with `COMPILE_OK`, zero compiler errors, zero compiler warnings, and a passing build check. The build result was recorded against build task `da8e6083-8e62-43a7-85f4-68d009383e96`; its status is `done`. Automatic Q02 creation remained suppressed by the required Codex review gate (`q09_requal8_review_required_before_q02`). No review task or pipeline work was created manually in this cycle; the scheduled controller/router owns that transition.

Pairs 6 through 8 were not touched. The OWNER hold remains active. No pipeline verdict is asserted by this checkpoint.

## Artifact hashes

- MQ5: `CD2A0AC6E3F4A677CBB30197E23EAEB8338F06F69D66341EEEDFC45CB68746B3`
- EX5: `E9670141E89249AFF7DF44A10A2402E2103AA4CECF8D0A35A8CD6D6BABEDF108`
- SPEC: `15BA5E9758AF5EF557C1877DFAC8A91441D7C7E44E1655C0956807E12B2F8EDA`
- Backtest set: `297081B5B1E8AA70E76246B1CDAAFDD38807305C5E8D05DB59E5D63998FA180A`
- Recorded build result: `1356FB70738F0F66B98BFE44436FE5B19CBD968C597F2F8F5A3F3C1D9A2FFB52`
- Compile evidence: `56766E753BA816B58A54E657FA602A3AD0AF30BD7EC69890FAB1A0B4B637D626`

Compile evidence:
`D:\QM\reports\work_items\ed5f9b8f-8804-4678-8908-621aa97aa985\QM5_41219\COMPILE_EA\compile_evidence.json`

## Focused verification

- `validate_spec_doc.py`: PASS (`1` checked, `0` failed)
- `validate_build_guardrails.py` on source and set: PASS, zero findings
- `build_gate_hardening.py`: zero failures; only the expected recovery-card location warnings were emitted because the card remains in the governed runtime `cards_review` directory
- Compile: PASS, zero errors, zero warnings
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- News-calendar fail-closed ceiling: `qm_news_stale_max_hours=336`

Exactly one governed smoke attempt was made after checking MT5 slots. It stopped before launch with `status=no_capacity` at `2026-09-01T02:01:38Z`: seven `terminal64` processes were present, tester-owned activity was active on T1, T2, T7, T8, and T9, and terminal workers were alive on T1–T10. No Pair 5 terminal was launched and no active test was interrupted. Smoke therefore remains deferred to Q02; this is not a pipeline verdict.

## Guardrail attestation

- No `terminal64.exe` process was started manually.
- Neither AutoTrading nor `T_Live` was enabled.
- No active T1–T10 backtest was interrupted.
- Operator-facing phase names remain Q-only.
- The protected `QM5_41162` line was not modified.
- The canonical `main` branch and `C:/QM/worktrees/cto_main` were not advanced.

The Company Reference drive `G:` was unavailable in this headless session. The durable task payload, local charter, profitability-track contract, approved/recovery cards, registries, and canonical evidence were used; no missing reference was guessed or weakened.
