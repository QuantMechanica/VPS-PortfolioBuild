# QM5_41185 Calendar Hardening And Governed Compile Handoff

- Router task: `9ec2e69a-1163-4e64-9566-1646154bafd6` (`build_ea`, priority 1000, assigned to Codex)
- Canonical build task: `4e9284dd-56e0-4618-9166-2d51f8caa320`
- EA: `QM5_41185_xauxag-fracd-rv`
- Branch: `agents/board-advisor`
- Approved card: `strategy-seeds/cards/approved/QM5_41185_xauxag-fracd-rv_card.md`
- Source SHA-256: `F72BAFE2028CA8020E4837B4F12719FCC84F64379007827FFA1217197129E605`
- Outcome: `SOURCE_READY_GOVERNED_COMPILE_PENDING`

## Governed pre-flight

- The approved card has `g0_status: APPROVED`, `execution_contract_status: APPROVED`, EA ID `QM5_41185`, and slug `xauxag-fracd-rv`.
- `framework/registry/ea_id_registry.csv` contains active EA ID 41185 with the same slug.
- `framework/registry/magic_numbers.csv` contains the two required active rows:
  - slot 0: `XAUUSD.DWX`, magic `411850000`
  - slot 1: `XAGUSD.DWX`, magic `411850001`
- The three presets are backtest-only and retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- News staleness remains capped at 336 hours. No `T_Live`, AutoTrading, live setfile, deploy manifest, or portfolio-gate change was introduced.

## Implementation review

The EA's current/completed broker-month classification now uses the framework-owned `QM_CalendarPeriodKey(PERIOD_MN1, ..., shift)` helper. Direct per-EA `iTime` and local month-key arithmetic were removed from the EA. Restart priming, the one-consumed-attempt-per-month latch, next-month package exit, exact D1 synchronization, and the approved fractional-difference signal remain intact.

The approved strategy mapping remains:

- No-trade: exact ID/symbol/timeframe, fixed-risk/news/Friday contract, and locked parameter validation.
- Entry: one monthly consumed attempt; exact 316-pair join; fixed `d=0.40`, 64-weight recurrence; held-out 252-sample z-score; inclusive `abs(z)>=0.50`; contrarian atomic pair.
- Management: malformed-package repair, later-broker-month exit, and 40-day stale repair.
- Close: framework close helper, broker hard stops, and kill switch.

## Focused verification

- `python -m unittest framework/EAs/QM5_41185_xauxag-fracd-rv/docs/test_fractional_difference_reference.py -v`: PASS, 8/8.
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41185_xauxag-fracd-rv`: PASS, 1/1.
- `python tools/strategy_farm/build_gate_hardening.py --repo-root C:/QM/repo --ea-label QM5_41185_xauxag-fracd-rv`: PASS, zero failures and zero warnings.
- `python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_41185_xauxag-fracd-rv --fail-on-leak`: `BASKET_OK`, zero violations.
- `python tools/strategy_farm/validate_build_guardrails.py --max-news-stale-hours 336 framework/EAs/QM5_41185_xauxag-fracd-rv`: PASS, four files checked, zero findings.

## Compile boundary and handoff

`python tools/strategy_farm/compile_ea.py --ea-id 41185 --force --json --fail-on-error` stopped before MetaEditor compilation with `INCLUDE_MIRROR_REFUSED`. A static `build_check.ps1 -SkipCompile` invocation also stopped at `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. Active T1-T10 factory terminals were not interrupted, stopped, or restarted.

The governed compile queue already contains pending work item `527e07ee-51ee-404d-acdc-76a01bbd4f51` for this exact EA, created at `2026-08-31T05:46:06Z`. No duplicate compile item was enqueued. Its completion is the authoritative compile gate; this artifact does not claim an EX5, Q02 result, pipeline PASS, promotion, or live authorization.

The required router transition to `REVIEW` was attempted and deterministically
refused with `D6_BUILD_IDENTITY_MISSING` /
`build_identity_json_missing_review_dispatch_refused`. D6 requires committed,
hash-bound MQ5, EX5, and setfile bytes plus strict-build PASS. Because the
governed work item remained pending through the scheduler window, those facts
do not yet exist and no build identity was fabricated. The truthful interim
router disposition is `BLOCKED` on work item
`527e07ee-51ee-404d-acdc-76a01bbd4f51`; a later orchestration cycle may resume
only from the compiler's durable result.

Short verdict: `SOURCE_READY_GOVERNED_COMPILE_PENDING: card-faithful calendar hardening and static gates PASS; existing governed compile work item remains pending because active factory terminals correctly refused ad-hoc include mirroring.`

## Governed compile-fail repair checkpoint

Recorded: `2026-08-31T07:12Z`

The first governed compile row
`527e07ee-51ee-404d-acdc-76a01bbd4f51` subsequently completed with zero
compiler errors and zero compiler warnings, but the strict build gate correctly
returned `COMPILE_FAIL / EA_ML_FORBIDDEN`. Its conservative scanner matched the
local deterministic fractional-difference array name `weights[]`; there is no
ML, fitting, adaptation, or learned state in this EA.

Commit `8588356b30` applies an identifier-only repair: `weights[]` became
`frac_coefficients[]` with every recurrence and convolution use preserved. The
same commit binds retry authority to the exact failed predecessor, rejected
source SHA-256, repaired source SHA-256, verdict class, and successful compiler
receipt. The focused authority test rejects a changed EA label, authority,
source hash, or predecessor verdict.

Repaired source SHA-256:
`371a4e20dfaf6aefb1e9b5e976b5087f28d528538d60e972b176df1847f65eab`.

Focused revalidation against the repaired source:

- fractional-difference reference suite: 8/8 PASS;
- `validate_spec_doc.py`: 1/1 PASS;
- `build_gate_hardening.py`: zero failures and zero warnings;
- `validate_symbol_scope.py --fail-on-leak`: `BASKET_OK`, zero violations;
- `validate_build_guardrails.py --max-news-stale-hours 336`: PASS, four files and zero findings;
- `pytest test_compile_work_items.py -k qm5_41185`: 1 PASS.

The append-only replacement compile row is
`a99d0b17-f974-4f32-bf4c-e7b66a8c3ce5`. At this checkpoint it remains
`pending`, unclaimed, with no verdict or evidence path. The EX5 emitted by the
failed predecessor is staged in the shared checkout but is stale against the
repaired source; it was not accepted, committed, or used to construct a build
identity. Only a `COMPILE_OK` receipt for the replacement row may satisfy D6.

No Q02 row, pipeline verdict, live artifact, terminal interruption, or manual
terminal launch was created by this checkpoint. Short verdict:
`REPAIRED_SOURCE_STATIC_PASS_GOVERNED_RECOMPILE_PENDING`.
