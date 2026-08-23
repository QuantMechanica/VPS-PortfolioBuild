# QM5_36006 card-remediation build evidence

- Task: `0d34c3bd-8853-499b-b357-aa59d82fb534`
- EA: `QM5_36006_nnfx-halftrend-jurik-coppock-engine`
- Lane: `codex`
- Source commit: `6093799cc`
- Source SHA-256: `016d8b5ba15352b04c9e81190724ef120aa0e2e764b7a128407de394c09189a8`
- Disposition: prior review findings are remediated in source and fixed-risk presets; governed compilation is blocked, so no build or pipeline verdict is claimed.

## Durable changes

- Replaced the custom high/low hysteresis and erroneous `ATR/100` deviation with the card's closed-bar `EMA(close,2) +/- 2.0 * ATR(100)` HalfTrend mapping.
- Replaced the TEMA surrogate with the standard open Jurik recurrence at conventional fixed defaults phase 0 (`phaseRatio=1.5`) and power 2; Jurik Velocity is the shift-1 minus shift-2 JMA value.
- Routed all raw history access through `QM_ReadBar`; HalfTrend/Jurik/Coppock/CMF and runner-exit evaluation now run only after the D1 new-bar gate.
- Replaced the full-volume +1 ATR broker TP with a one-time 50% partial close, then entry +/- 1 pip runner protection. The runner exits only on the HalfTrend direction flip.
- Added the history-derived 2.0% account realized-loss entry halt, UTC rollover conversion, restart-safe 2.5% daily framework hard stop, 5.0% account-level total-DD signal threshold, and 0.5% per-trade cap.
- Preserved open-position management before all entry-only filters and removed the unapproved 10-pip minimum from the exact one-ATR stop.
- All three D1 presets bind to the current source hash and retain `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Removed the stale tracked EX5 (`287e1a11af8421bd061d6090abf2c3bac090c7d1bf364804c9106f68c9f47583`) because it predates this source identity.

## Focused verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py` over MQ5 and three presets: PASS; news staleness ceiling remains 336 hours.
- `build_gate_hardening.py`: zero failures, including loss rails, UTC conversion, management reachability, request initialization, authorized symbols, and registry checks.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`.
- Raw-series scan: zero direct `iClose`, `iHigh`, `iLow`, `iTickVolume`, `CopyRates`, `CopyBuffer`, or `BarsCalculated` sites in the EA.
- Preset audit: three current-source hash matches and three fixed-risk presets.
- `git diff --check`: PASS.

## Compile hold

The strict build preflight, including a `-SkipCompile` attempt, correctly refused execution with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` while factory terminals are alive. No terminal was stopped or started and no guard was bypassed.

The sanctioned enqueue request refused with `BOUND_SETFILE_HASH_EXISTS`; this existing EA is not on the OWNER-authorized force-rebuild allowlist. Consequently there is no current strict compile PASS or current EX5. A governed rebuild authorization is required outside this build lane.
