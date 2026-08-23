# QM5_37003 card-remediation build evidence

- Task: `6b9b31bd-8511-4f7b-8400-9e42162b0bd1`
- EA: `QM5_37003_hurst-exponent-dynamic-regime-switch`
- Source commit: `fe2d54b5d`
- Source SHA-256: `846b72f2273b32da2974088246c89c7373582bd74de3dc19dc37c1db54d9ae66`
- Disposition: prior review findings remediated; compilation remains held, so no build or pipeline verdict is claimed.

## Remediation and checks

- Added a history-derived 2.0% account realized-loss entry halt and configured the restart-safe framework kill switch for 2.5% daily equity, the 5.0% account-level total-DD signal threshold, and a 0.5% per-trade cap.
- Mean-reversion entries now reject an invalid Bollinger-midline target instead of substituting the unauthorized 1.5R target.
- Open-position Bollinger-midline management runs before all entry-only filters; state refresh and entries remain H1 new-bar gated.
- The rollover window is derived from `QM_BrokerToUTC(TimeCurrent())`; the unapproved absolute point-spread cap was removed, leaving the card's ATR-relative spread rule.
- Three H1 presets bind to the current source hash and use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Removed stale EX5 `f73bf23358e95c26bc37bafac1fed908a7ea636b6ba4aa0fa69cb860ee9acff5`.
- PASS: SPEC validation, build guardrails at 336 hours, build-gate hardening (zero failures), symbol scope, preset identity/risk audit, and `git diff --check`.

## Compile hold

Strict build preflight refused ad-hoc compilation with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` while factory terminals are alive. The governed enqueue then refused `BOUND_SETFILE_HASH_EXISTS` because this existing EA lacks OWNER force-rebuild authorization. No terminal or guard was altered; no current EX5 or compile PASS exists.
