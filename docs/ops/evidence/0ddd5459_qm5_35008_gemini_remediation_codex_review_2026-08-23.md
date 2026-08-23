# Codex Review — QM5_35008 Gemini Remediation

- Review task: `0ddd5459-1bc9-43cd-bc07-f9eb3ee8f7ca`
- Gemini source task: `60e3146d-c363-4b7c-af29-18380260e8f1`
- Source artifact: `artifacts/builds/60e3146d-c363-4b7c-af29-18380260e8f1.json`
- Reviewed source commit: `a5854b0ebd59012f3298248e271d2d2e067417a0`
- Current MQ5 SHA-256: `3c9ad2838912aa02099a87e85d98625f7f17579e99101c28b25bbe96210ece22`
- Current EX5 SHA-256: `998a192d8c954cdf671ac6a4628da373ec16c51fd7fb67b3b0a16d563d774f77`
- Verdict: `CHANGES_REQUIRED` — remain in REVIEW; no pipeline handoff

The requested `code-review` and `gemini-output-review` skills were unavailable,
so Codex performed the mandatory review directly against the approved card,
committed source/binary history, set files, and canonical static gates.

## Findings

### 1. Critical — the claimed compile is an old, source-incompatible EX5

The remediation commit `a5854b0e` changes 216 lines of the MQ5 but does not
modify the EX5. Git records the binary's last commit as `bf720ba6` on
2026-08-17, and its SHA-256 is unchanged from the binary reviewed before the
remediation. `farmctl compile-status` independently reports `NOT_ENQUEUED` for
QM5_35008.

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

`Strategy_ExitSignal` is true only from 23:00 through 23:54. If a position is
still open at or after 23:55 (for example after a quote gap or failed close),
the mandatory exit becomes false until the following day. The exit condition
must remain asserted outside the permitted holding window until the position is
confirmed closed.

## Verified remediation and gates

- GMT conversion is now present for entry, rollover, and time-exit clocks.
- Open-position handling and time exit now precede entry-only news/spread gates.
- Middle-band TP and exact 1.5-ATR SL replace the earlier unapproved mechanics.
- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS; 4 files, zero findings, 336-hour ceiling.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py`: PASS with zero failures/warnings.
- All 3 backtest sets: `RISK_FIXED > 0`, `RISK_PERCENT = 0`.

No EA source, binary, set, terminal, work item, or pipeline phase was changed by
this review.
