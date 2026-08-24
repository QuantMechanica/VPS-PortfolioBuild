# Codex revalidation — recycled Gemini EA reviews, batch 6

- Reviewed at: `2026-08-24T15:49Z`
- Router task: `4550f45e-827d-4cb4-96f8-f25eaef2a30a`
- EA: `QM5_12944_sperandeo-trend-fault-line-h4`
- Source agent: Gemini/agy
- Disposition: **REVIEW / FAIL (binary binding only)**

## Current identity

- MQ5 SHA-256: `c57e003643bc0fbc727c25c2119b54457ff78ceb532ad9ee92f55f2b3498ce4a`
- Source commit: `f75e984cf326e1f0516d22de37df584fac1c71c3`
  (`rework(12944): restore card-faithful fault-line mechanics`, 2026-08-24)
- EX5 SHA-256: `e19a9d287c247aaec8f074ff0469aeb977f0fc03b349a95617aa02a347c2d711`
- Binary commit: `941b08d863176d923894b741bbfa86a3f7e3ee6d`
  (`build(ea): implement QM5_12944...`, 2026-08-21)

The tracked EX5 predates the reviewed rework by three days and is unchanged. The repository build
artifact names older MQ5 hash `a83623b3...`; the runtime artifact names still older hash
`18ece113...`. Both point to the same old EX5 and neither binds the reviewed MQ5.

## Independent source review

The latest rework resolves the previously named source defects:

- Risk defaults are mutually exclusive (`RISK_PERCENT=0`, `RISK_FIXED=1000`) and all 13 backtest
  setfiles preserve fixed risk greater than zero with percentage risk zero.
- The approved card's entry-only high-impact news window is implemented literally as
  `QM_NewsInWindow(..., 15, 15, "high")` at MQ5 line 395.
- `strategy_min_pivots` is live in both regression paths (lines 129 and 195) and validated at line
  488.
- Current semantic hardening reports zero failures/warnings. Current build guardrails report PASS,
  zero findings, and the news stale ceiling remains 336 hours.
- Focused command `pytest -q tools/strategy_farm/tests/test_qm5_12944_rework.py` reports
  `6 passed`.

## Verdict

**FAIL (binary binding only).** The repaired source is review-clean, but no compile receipt or EX5
exists for its exact hash. A governed compiler must rebuild this source and regenerate binding
evidence before Q02. This Gemini-origin task remains in REVIEW; no PIPELINE acceptance is implied.

No EA, setfile, registry, resolver, compiler queue, backtest queue, terminal, factory,
AutoTrading, or `T_Live` state was modified during this review.
