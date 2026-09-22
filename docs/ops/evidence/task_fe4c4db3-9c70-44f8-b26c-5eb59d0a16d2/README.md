# Futures prop research profiles — task fe4c4db3-9c70-44f8-b26c-5eb59d0a16d2

Verdict: **REVIEW — two source-bound profiles produced; both intentionally nondeployable.**

This task turns the 2026-09-22 official-source comparison into explicit phase contracts for:

- MyFundedFutures Rapid EOD 50k;
- Tradeify Select 50k default 40% evaluation to Select Flex.

Each JSON profile covers evaluation, initial simulated-funded state, payout account debit/loss-floor behavior, and live transition. News, inactivity, consistency/reset, day counts, scalping/holding, automation ownership, hosting, and phase-specific costs are represented explicitly. Unknown facts remain the literal value `UNKNOWN`; no absence was converted into permission or a zero-dollar cost.

## Bound inputs

- `D:/QM/reports/research/futures_pivot_20260922/prop_firms.json` — SHA-256 `a4116ec9f12a9d126c051f1fa7829829e051955eaef4a2d9a6b5164ac9179a0c`.
- `D:/QM/reports/research/futures_pivot_20260922/prop_firms.md` — SHA-256 `8d6c5fd9739ff261e08a540c4c0313d2a0213096107e94c33cb635c94535515b`.
- OWNER decision `decisions/2026-09-22_owner_futures_prop_research_and_preparation.md`.
- Isolated diagnostic dependency commit `4aef1793e5c0939513b507d674e40fc2b95b659c`.

Every profile carries the official URL, observed date, snapshot hash, and per-constraint source IDs. The validator rejects undeclared source IDs, duplicate JSON keys, null-substituted unknowns, missing phase/cost sections, incomplete blocker lists, and any attempt to mark these unresolved profiles deployable.

## Bounded diagnostic additions

`tools/futures_lab/prop_risk.py` now:

- models an explicitly sourced payout-time floor increase and refuses a floor decrease;
- reports effective post-debit room without treating cash split as the account debit;
- counts qualifying winning days from supplied completed-session net PnL only;
- continues to report provider payout eligibility as `NOT_EVALUATED`.

Adversarial tests bind only unambiguous semantics: exact 30% and 40% evaluation-consistency boundaries, Tradeify's inclusive USD 150 winning-day threshold, its immediate USD 50,100 first-request floor lock, and the conservative MFFU cashflow example without claiming that the unresolved first-request wording is satisfied.

## Deployment blockers retained

MFFU remains blocked on written Hetzner/IP permission, the exact execution route, exact Tier-1 blackout minutes, first-request buffer wording, and unbound reset/live/payout costs.

Tradeify remains blocked on the ordinary-login/VPS procedure, bot ownership/exclusivity eligibility, the NinjaTrader/execution-route conflict, news/inactivity rules, formal first-request buffer wording, and unbound Elite/payout costs.

No account was purchased or opened; no provider was contacted; no credentials, live connection, terminal, AutoTrading setting, order, CFD verdict, or pipeline state was changed.

## Verification

The task receipt is `profile_validation.json`. Focused test output is recorded in `verification.json`. A PASS confirms only structural/source binding and deterministic diagnostic behavior; it does not establish provider acceptance, strategy profitability, payout eligibility, or live readiness.
