# QM5_20246 promotion-priority repair — 2026-08-11

## Outcome

Repaired the farm promotion contract so `priority_track` and its optional
`priority_reason` survive Q02-to-Q03/Q04 and later phase promotions. The defect
was directly starving `QM5_20246_usdjpy-eurgbp`, a Tier-A, D1 market-neutral FX
basket, behind non-priority work even after it passed Q02.

No backtest was launched and the two existing pending rows were not duplicated
or reprioritized in the runtime database because the host was at the explicit
backtest CPU ceiling (99.9% three-sample average; seven active work items).

## Selection and claim

- Farm claim: `6f387a9f-3a2e-457a-a01f-d468ef949837`
- Claim owner: `codex:agents/board-advisor`
- Pre-claim backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20246_priority_repair_20260811T073335Z.sqlite`
- Card: `strategy-seeds/cards/approved/QM5_20246_usdjpy-eurgbp_card.md`
- Source criterion: Ernest Chan, *Quantitative Trading* (Wiley, 2009),
  OWNER-ratified Tier-A extraction.
- Structure: frozen-beta USDJPY/EURGBP D1 residual reversion; deterministic,
  no ML, and one logical multi-leg basket.
- Risk contract: both canonical setfiles retain `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The approved build backlog contained no clean non-duplicate diverse build: its
remaining entries already had economic/downstream verdicts or explicit setup
blocks, while the fresh WTI build `QM5_20278` was visibly in progress in the
shared checkout. `QM5_20246` therefore supplied the highest-value distinct
funnel repair.

## Root cause

Q02 predecessor `d8619249-7764-4d80-a714-6b7922b73b4b` is `done/PASS` and its
payload carries `priority_track=true`. The canonical helper
`_promotion_payload_with_basket_context()` copied basket execution fields but
not queue-priority fields. Consequently:

- Q04 early probe `1a269ff4-cbef-429b-afa4-47a3cc692916` was pending at
  canonical claim position 126 with no `priority_track` key.
- Q03 sweep `46c97cb3-45f9-475d-8e6b-aa7bdd40df0e` was pending at canonical
  claim position 168 with no `priority_track` key.

This was a promotion-contract defect, not a strategy or build failure. Creating
new work items would have duplicated already-valid pending identities.

## Repair

`tools/strategy_farm/farmctl.py` now defines the queue context preserved by
every promotion and copies `priority_track` plus `priority_reason` unless the
caller explicitly overrides them. Regression coverage extends the existing
basket-promotion test to prove both fields survive alongside host, manifest,
risk, and conversion context.

The runtime continuation is intentionally deferred: after CPU headroom returns
and workers load this committed code, atomically add the inherited priority
fields to the two exact pending rows above only if both remain unclaimed and
pending. Do not create replacement Q03/Q04 rows.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_basket_work_items.py -q`:
  **15 passed**.
- `python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -q`:
  **23 passed, 4 subtests passed**.
- `python -m pytest tools/strategy_farm/tests/test_ultracode_wsa_claim.py tools/strategy_farm/tests/test_priority_track_new_q02.py -q`:
  **32 passed**.
- `framework/scripts/build_check.ps1 -EALabel QM5_20246_usdjpy-eurgbp
  -Strict -SkipCompile`: **PASS, 0 failures, 0 warnings**; report
  `D:\QM\reports\framework\21\build_check_20260811_073725.json`.
- Magic resolver dry-run: **15,869 rows kept, 0 dropped**, registry SHA prefix
  `7EB07E52C0E3FE44`.
- Existing MQ5 SHA-256:
  `4ee9db9b746599413e00af5f01583252bd8ec9b8440d0509ca25207ea483ec6a`.
- Existing Q02-authenticated EX5 SHA-256:
  `f2384173fdd41e914b48b3098467c9b02a7648494f937f5f027f4e8b45aa6eab`.

The existing EX5 was deliberately not recompiled against unrelated concurrent
registry/resolver edits. No smoke, Q03, Q04, T_Live, AutoTrading, portfolio-gate,
or deployment-manifest action was performed.
