# Session-tick variants — 25-card implementation record

- Router task: `ec024dae-2078-4df9-8ec1-e1e1f8464610`
- OWNER authority: `docs/ops/evidence/2026-08-16_owner_decisions.md`, item 2
- Proposal: `docs/ops/evidence/2026-08-16_session_offset_grace_batch_proposal_25_cards.md`
- Date: 2026-08-16
- Disposition: **card layer complete; source rebuild requires a follow-up batch**

## Canonical card mutation

The exact 25 `confirmed_affected` cards in
`strategy-seeds/cards/approved/` were amended. Each amendment:

- anchors entry at `D1_bar_open + strategy_session_offset_min`;
- fixes `strategy_session_offset_min` at `61.6` minutes;
- fixes `strategy_entry_grace_minutes` at `10`;
- adds `strategy_min_stub_ticks = 20`;
- adds `strategy_min_attach_ticks = 20` within five minutes;
- explicitly supersedes only the old raw-D1-label/five-minute clock;
- preserves the card's existing consumed-attempt and advance/never-shift
  semantics; and
- changes no formation, signal, direction, exit, sizing, or risk rule.

All ten cards that mention `XNGUSD.DWX` (the seven XNG-only cards and three
XTI/XNG baskets) visibly state that `61.6` is an **UNVERIFIED XNG estimate
inferred from XTI**, not an XNG measurement. Independent XNG tick measurement
remains recommended.

## Focused verification

- Exact scoped-card count: `25`.
- Cards carrying the OWNER amendment: `25/25`.
- XNG-bearing cards with an explicit `UNVERIFIED` marker: `10/10`.
- Canonical card diff: `git diff --check` PASS.
- Existing affected EA directories: `25/25`.
- Runtime reservoir cards were not mutated, so queued work cannot silently pair
  an amended runtime card with an old binary.
- No terminal, AutoTrading, `T_Live`, backtest, pipeline verdict, or registry
  mutation occurred.

## Why source rebuild was not bulk-applied

The current EAs do not expose one mechanically interchangeable clock helper.
Several consume their period attempt or evaluate entry only on the first
new-D1-bar edge. The approved attach floor can only be known after observing up
to five minutes of ticks. A simple source substitution would therefore either:

1. consume the attempt before 20 ticks can accrue and force zero trades; or
2. defer consumption in a way that weakens the existing restart-safe contract.

That is a source-level state-machine change needing per-idiom implementation
and tests, not a safe 25-file constant replacement. The build guardrail is not
at fault and was not weakened.

## Required follow-up

Requeue Development in implementation batches grouped by clock idiom. Each
batch must add an explicit pre-entry attach state that preserves the card's
original attempt-consumption point, copy the amended card into the EA docs and
runtime reservoir only with the matching source, regenerate setfiles with
`RISK_FIXED > 0` and `RISK_PERCENT = 0`, then pass strict compile, build_check,
SPEC, unwired-input audit, and `validate_build_guardrails.py` before its Q02
work item is requalified. XNG remains unverified until the recommended tick
measurement is completed; that label must survive every copy.
