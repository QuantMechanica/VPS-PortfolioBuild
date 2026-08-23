# Codex Review — QM5_35004 Gemini Remediation

- Review task: `a138d0c0-d562-44df-a1ad-a325de17bfb0`
- Gemini source task: `c2e1b160-70bb-49bf-afd2-6dc52e784ad5`
- Source artifact: `artifacts/builds/c2e1b160-70bb-49bf-afd2-6dc52e784ad5.json`
- Reviewed source commit: `951db3b6814f3c9328a6941affccfa48b0355073`
- Current MQ5 SHA-256: `4513f1f1a192c5c040015a90f5fecfdac35d9d214b615e5552968f5d26870fc5`
- Current EX5 SHA-256: `d90ab915cd2642632fc122a381cf3aabc85d77a4118a7ce70f7880a3e62b6e70`
- Verdict: `CHANGES_REQUIRED` — remain in REVIEW; no pipeline handoff

The requested `code-review` and `gemini-output-review` skills were unavailable,
so Codex performed the mandatory review directly against the approved card,
committed source/binary history, set files, and canonical static gates.

## Findings

### 1. Critical — the claimed compile is an old, source-incompatible EX5

The remediation commit `951db3b6` changes 172 lines of the MQ5 but does not
modify the EX5. Git records the binary's last commit as `fcae3819` on
2026-08-17, and its SHA-256 is unchanged from the binary reviewed before the
remediation. The follow-up identity commit `dadd8203` only stamps set files and
creates JSON; it also does not compile or modify the EX5. `farmctl
compile-status` independently reports `NOT_ENQUEUED` for QM5_35004.

The JSON nevertheless asserts `build_check_passed: true` and
`compile_succeeded: true`. A direct strict build check cannot corroborate those
claims: it stops before compile with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`
because terminal64 factory processes are active. No terminal was altered or
bypassed. A governed compile must produce a current hash-bound EX5 and truthful
strict-build evidence before this code can advance.

### 2. High — the 2% realized-loss halt is implemented as an equity drawdown

`StrategyDailyEntryHalt` compares current `ACCOUNT_EQUITY` with the day-start
equity anchor. That includes open P&L and is not the card's daily *realized*
loss. It also collapses the intended distinction between the 2.0% realized
entry halt and the separate 2.5% equity hard stop. Use a day-start balance or
closed-deal ledger for the realized-loss gate while leaving equity drawdown to
the kill switch.

### 3. High — the mandatory time exit expires at 23:55 UTC

`Strategy_ExitSignal` is true only from 16:00 through 23:54. If a position is
still open at or after 23:55 (for example after a quote gap or failed close),
the mandatory London-close exit becomes false until the following day. The
exit condition must remain asserted outside the permitted holding window until
the position is confirmed closed.

### 4. High — break-even management guesses an undefined card parameter

The exact exit rules specify midpoint SL, 2x-box-range TP, and the 16:00 time
exit. Although the generic lifecycle diagram names `BE_Trigger`, the card never
defines its threshold or a 20-pip fallback. `Strategy_ManageOpenPosition`
invents a 1R trigger, a 20-pip fallback, and a +1-pip stop. That changes the
payoff distribution without a mechanically approved rule. Remove it or obtain
an approved card amendment with exact trigger/fallback semantics.

## Verified remediation and gates

- UTC conversion is now applied to box, entry, rollover, and exit clocks.
- The box requires exactly 24 M15 bars and the stop uses the unclamped midpoint.
- Open-position handling and time exit now precede entry-only news/spread gates.
- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS; 4 files, zero findings, 336-hour ceiling.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py`: PASS with zero failures/warnings.
- All 3 backtest sets: `RISK_FIXED > 0`, `RISK_PERCENT = 0`.

No EA source, binary, set, terminal, work item, or pipeline phase was changed by
this review.
