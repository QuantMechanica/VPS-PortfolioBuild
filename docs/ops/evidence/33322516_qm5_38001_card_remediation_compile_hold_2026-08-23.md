# QM5_38001 card remediation and governed compile hold

- Router task: `33322516-1797-4d97-8a74-eb4fd7385953`
- EA: `QM5_38001_codetrading-vwap-bollinger-rsi-scalper`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38001_codetrading-vwap-bollinger-rsi-scalper.md`
- Prior mandatory review: `docs/ops/evidence/ce1b2ad8_qm5_38001_codex_review_2026-08-18.md`
- Source commit: `fb225460d`
- Remediated MQ5 SHA-256: `b7b2b565c0d297a64416bc3b51e25413329b857fc2d55a0c11076cb6eb3b3699`
- Verdict: **SOURCE_STATIC_PASS / COMPILE_HELD — no binary or pipeline handoff**

## Remediation

The build now:

- reconstructs the current closed-bar session VWAP from UTC midnight at
  initialization, UTC-day rollover, or a detected M5 gap, then advances it once
  per contiguous bar; restart time can no longer truncate the session input;
- refreshes VWAP, Bollinger, RSI, and ATR state before entry admission on the
  new M5 bar, and keeps open-position management reachable on every tick before
  all entry-only filters;
- derives the +1R break-even trigger from the position's original broker-side
  stop distance and moves the stop to exact normalized entry, rather than
  recomputing R from the latest ATR or adding an unapproved two-point buffer;
- targets favorable Session VWAP directly and uses 1.8R only when VWAP is not a
  valid favorable target, removing the unapproved 0.5R minimum-distance rule;
- implements the 2.0% account realized-loss entry halt and framework kill
  switch at 2.5% daily, 5.0% total, and 0.5% per-trade risk;
- evaluates the 23:55-00:05 window in registry-converted UTC and enforces the
  card's three-tick order-deviation ceiling; and
- enforces M5 and card-required break-even configuration at initialization.

`SPEC.md` and all three M5 presets were updated. Every preset remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and is bound to the
remediated MQ5 hash above. The stale EX5
`7dc80f0769ff5658aabd2ba710c2d10efe78e878f177065a34121ddd9b744013`
was removed after the source changed; it remains recoverable from git but is not
a valid binary for this source.

## Focused verification

Executed from `C:/QM/repo` on 2026-08-23:

| Check | Result |
|---|---|
| `build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_38001_codetrading-vwap-bollinger-rsi-scalper` | **PASS**, zero failures/warnings |
| `validate_build_guardrails.py` on MQ5 and all three sets | **PASS** at the mandatory 336-hour news ceiling |
| `validate_spec_doc.py` on the EA directory | **PASS** |
| Preset identity/risk inspection | three hash matches; fixed risk 1000; percent risk 0 |
| `build_check.ps1 -Strict` | correctly refused: `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` |
| `farmctl.py enqueue-compile QM5_38001_codetrading-vwap-bollinger-rsi-scalper` | correctly refused: `BOUND_SETFILE_HASH_EXISTS`, `force_rebuild_authorized=false` |

No retry bypass, terminal start/stop, backtest, AutoTrading, `T_Live`, or Q phase
was attempted. The existing OWNER force-rebuild authorization path is required
before a governed worker can emit the source-hash-bound EX5 and strict build
report. Static checks do not imply a pipeline verdict.
