# QM5_36002 card-hardening build evidence

- Task: `f7849572-7aad-4e79-ad7f-8c6d1fccf935`
- EA: `QM5_36002_nnfx-kijunsen-absolute-strength-damiani`
- Lane: `codex`
- Source commit: `890436241`
- Source SHA-256: `3cb46b43a01a9a578cceedc3b6fe6980bef4bf38a962a37772ca79780d414671`
- Disposition: source and fixed-risk presets are ready; governed compilation is blocked, so no build or pipeline verdict is claimed.

## Durable changes

- Added the card-declared 2.0% account realized-loss entry halt, 2.5% restart-safe daily equity hard stop, 5.0% account-level total-drawdown signal threshold, and 0.5% per-trade risk cap.
- Converted the 23:55-00:05 entry blackout from broker time to UTC with `QM_BrokerToUTC`.
- Replaced the full-position 1 ATR take-profit with the card's one-time 50% TP1 partial close; the runner moves to entry +/- 1 pip and exits on the Kijun re-cross.
- Kept management and strategy exits reachable before all entry-only blackout checks.
- Set source defaults and all four D1 presets to `RISK_FIXED=1000`, `RISK_PERCENT=0`; all presets carry the current source hash.
- Removed the stale tracked EX5 (`306f9836ee139e90cd52fa9c4294be9d5b18220d8aaff71cf3ce5492e77ed5ee`) because it was compiled from the pre-remediation source.

## Focused verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py` over MQ5 and four presets: PASS; `qm_news_stale_max_hours=336`.
- `build_gate_hardening.py`: zero failures, including loss-limit contract, UTC rollover, management reachability, request initialization, authorized symbol universe, and magic registry checks.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`.
- Preset identity/risk audit: four source-hash matches; four fixed-risk presets; no percent-risk preset.
- `git diff --check`: PASS.

## Compile hold

The strict build check correctly refused ad-hoc compilation with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory `terminal64` processes are alive. No terminal was stopped or started and no guard was bypassed.

The sanctioned enqueue request also refused with `BOUND_SETFILE_HASH_EXISTS`; the EA is an existing build and is not on the OWNER-authorized force-rebuild allowlist. There is therefore no current strict compile PASS and no current EX5. Resolving this requires an authorized governed rebuild window/allowlist entry, outside this build lane's authority.

