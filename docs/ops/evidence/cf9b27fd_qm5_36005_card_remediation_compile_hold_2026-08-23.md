# QM5_36005 card-remediation build evidence

- Task: `cf9b27fd-11f6-465b-9731-8e551bb9c671`
- EA: `QM5_36005_nnfx-coral-trendlord-woodies-harvester`
- Lane: `codex`
- Source commit: `083ed39d3`
- Source SHA-256: `6c247a3802f6237c71c29770ebd172b95f55f715d587c1d43152a9eb60cc29a4`
- Disposition: card-conformant source and fixed-risk presets are ready; governed compilation is blocked, so no build or pipeline verdict is claimed.

## Durable changes

Codex reviewed and completed the pre-existing remediation in the shared checkout. The result resolves every finding in `ddb87b6b_qm5_36005_gemini_build_codex_review_2026-08-18.md`:

- Card-defined Coral is the 20-period SMMA rather than a six-stage T3.
- TP1 is a one-time 50% partial close at +1 ATR; the runner is protected at entry +/- 1 pip and has no full-volume broker TP.
- Trend Lord color reversal is the only strategy runner exit; Woodies CCI is entry confirmation only.
- The 23:55-00:05 rollover blackout uses `QM_BrokerToUTC`.
- The 2.0% entry halt is based on closed account PnL reconstructed from deal history, not floating equity or a restart-reset local baseline.
- The restart-safe framework kill switch is configured for the 2.5% daily hard stop, 5.0% account-level total-DD signal threshold, and 0.5% per-trade cap.
- Management and exits execute before entry-only filters.
- All three D1 presets contain only current inputs, bind to the current source hash, and retain `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- The stale tracked EX5 (`767293967529ab5d8ff4fd9efb586b4a750d8676d658275efb1ac2d0b8796d57`) was removed because it predates this source identity.

## Focused verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py` over MQ5 and three presets: PASS; news staleness ceiling remains 336 hours.
- `build_gate_hardening.py`: zero failures, including loss rails, UTC conversion, management reachability, request initialization, authorized symbols, and registry checks.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`.
- Preset audit: three current-source hash matches, three fixed-risk presets, zero stale input names.
- `git diff --check`: PASS.

## Compile hold

The strict build check correctly refused ad-hoc compilation with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` while factory terminals are alive. No terminal was stopped or started and no guard was bypassed.

The sanctioned enqueue request refused with `BOUND_SETFILE_HASH_EXISTS`; this existing EA is not on the OWNER-authorized force-rebuild allowlist. Consequently there is no current strict compile PASS or current EX5. A governed rebuild authorization is required outside this build lane.
