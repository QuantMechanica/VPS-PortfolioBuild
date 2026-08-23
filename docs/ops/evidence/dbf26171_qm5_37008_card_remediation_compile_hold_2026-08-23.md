# QM5_37008 card remediation and governed compile hold

- Router task: `dbf26171-4fbc-4ac0-bdf8-c76c761e4974`
- EA: `QM5_37008_garch-volatility-forecast-breakout`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_37008_garch-volatility-forecast-breakout.md`
- Prior mandatory review: `docs/ops/evidence/fe559a03_qm5_37008_codex_review_2026-08-18.md`
- Source commit: `fcaea554a`
- Remediated MQ5 SHA-256: `94e0f1ea793c88c63d276f143d292f170a5f4892398c548210d68ad17e624d1b`
- Verdict: **SOURCE_STATIC_PASS / COMPILE_HELD — no binary or pipeline handoff**

## Remediation

The build now:

- ratchets an open position's stop only tighter along the card's closed-D1
  one-sigma cone (`Open[1] - sigma` for a long and `Open[1] + sigma` for a
  short), while retaining the card's initial one-sigma stop and 2R target;
- refreshes D1 GARCH, SMA, and ATR state before evaluating entry admission on
  the new bar, while keeping open-position management reachable before every
  entry-only filter;
- removes the unapproved absolute 100-point spread cap and retains only the
  card's `spread > 1.8 * ATR(14,D1)[1]` rejection;
- implements the 2.0% account realized-loss entry halt and configures the
  framework kill switch at 2.5% daily, 5.0% total, and 0.5% per-trade risk;
- converts the 23:55-00:05 window from broker time through the registry-backed
  UTC helper;
- enforces the card's maximum three-tick order deviation through the framework
  entry configuration;
- validates GARCH stationarity and all risk parameters at initialization; and
- adds an explicit dynamic-array bound proof required by current build
  hardening.

`SPEC.md` and all three D1 presets were updated. Every preset remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and is bound to the
remediated MQ5 hash above. The old EX5
`6e0a49f705731644585f0397f22c5a793f8d4d78849471867ac06d009c5e47ba`
was removed after the source changed; it is recoverable from git but is not a
valid binary for this source.

## Focused verification

Executed from `C:/QM/repo` on 2026-08-23:

| Check | Result |
|---|---|
| `build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_37008_garch-volatility-forecast-breakout` | **PASS**, zero failures/warnings |
| `validate_build_guardrails.py` on MQ5 and all three sets | **PASS** at the mandatory 336-hour news ceiling |
| `validate_spec_doc.py` on the EA directory | **PASS** |
| Preset identity/risk inspection | three hash matches; fixed risk 1000; percent risk 0 |
| `build_check.ps1 -Strict` | correctly refused: `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` |
| `farmctl.py enqueue-compile QM5_37008_garch-volatility-forecast-breakout` | correctly refused: `BOUND_SETFILE_HASH_EXISTS`, `force_rebuild_authorized=false` |

No retry bypass, terminal start/stop, backtest, AutoTrading, `T_Live`, or Q phase
was attempted. A governed compile needs the existing OWNER force-rebuild
allowlist path; only then can a source-hash-bound EX5 and strict build report be
produced. No pipeline verdict is inferred from static evidence.
