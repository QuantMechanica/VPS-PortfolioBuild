# Provider Rulepack Review SLA — Darwinex Zero + FTMO

Date: 2026-08-23

Router task: `65bb719f-75d5-4e73-a21b-69daeaaf8976` (`SP-E3`, priority 46,
zone GRUEN)

## Purpose

QM designs strategies and cost/risk models against two external venues'
published rules: the Darwinex Zero DARWIN Risk Engine (VaR targeting,
D-Leverage caps) and FTMO's Challenge/Verification/Funded rules (daily/total
loss limits, fees, trading-conduct restrictions). Both providers change these
rules unilaterally and without notice to QM. This document is the durable
policy for keeping QM's copy of those rules versioned, sourced, and checked
on a cadence — not a one-time snapshot that silently goes stale.

## Current rulepacks

| Rulepack | Path | Schema | Retrieved | Freshness ceiling |
|---|---|---|---|---|
| FTMO official rules | `docs/ops/evidence/2026-08-23_ftmo_official_rules_snapshot.json` | `qm.ftmo-official-rules-snapshot/v2` | 2026-08-23T07:46:57Z | 7 days |
| Darwinex Zero Risk Engine | `docs/ops/evidence/2026-08-23_darwinex_zero_risk_engine_snapshot.json` | `qm.darwinex-zero-risk-engine-snapshot/v1` | 2026-08-23T07:47:00Z | 7 days |

The FTMO rulepack supersedes `docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json`
(schema v1), which had gone 25 days past its own 7-day freshness ceiling
before this refresh — the concrete gap this SLA exists to close. The
Darwinex Zero rulepack is new; no prior version existed in the repo.

## Sources (primary, official origin only — no third-party summary sites)

FTMO (7 URLs, all `ftmo.com`): trading objectives, 2-step challenge, news
policy, weekend/overnight policy, EA policy, forbidden trading practices,
fee/refund policy. Darwinex Zero (2 URLs): `help.darwinex.com/risk-manager`
(primary, raw-capturable) and `darwinexzero.document360.io/docs/risk-engine`
(secondary — see the rulepack's own `capture_note`: this CDN loops direct
`curl` in a redirect cycle, likely a JS/cookie challenge; only the WebFetch
tool's rendered pass could read it, which cannot produce byte/hash evidence
the way a raw GET can). This asymmetry is recorded in the rulepack itself
(`evidentiary_tier` per source), not hidden.

## Freshness ceiling and what breaches it

**7 days**, matching the ceiling FTMO's own v1 snapshot already established
(2026-07-29) — kept unchanged rather than inventing a new number. A rulepack
older than 7 days is stale for any *new* purchase, live-capital, or
leverage decision; it remains usable for retrospective research or
already-committed positions.

## Review process (what "regularly checked" means operationally)

1. Before any of the following actions, first check both rulepacks'
   `retrieved_at_utc` against the 7-day ceiling: (a) a paid FTMO Challenge
   purchase decision, (b) a change to the FTMO cost/risk model referenced by
   `reference_venue_cost_model`, (c) a change to any DXZ book's leverage or
   position-duration assumptions, (d) any OWNER decision that cites either
   provider's numeric rules as justification.
2. If stale, refresh by repeating this task's method: raw HTTPS GET (curl)
   against every URL for byte-length/sha256/status/Last-Modified capture,
   cross-checked with a rendered-content pass (WebFetch) for the exact
   normalized claims, written as a new dated snapshot file (never overwrite
   the prior file — supersession is recorded in the new file's own header,
   append-only per the repo's evidence convention).
3. If a provider changes a numeric rule between two snapshots, that is a
   finding for OWNER, not something to silently absorb into downstream cost
   models — cite both the old and new snapshot paths in whatever change
   record touches the affected model.
4. This SLA document itself should be re-dated (a new
   `RULEPACK_REVIEW_SLA_YYYY-MM-DD.md`) only if the *process* changes (new
   source added/removed, freshness ceiling changed, retrieval method
   changed) — routine refreshes only need a new dated rulepack snapshot, not
   a new SLA document.

## Known open item from this refresh

The exact FTMO Challenge fee amount per account-size tier ($10k/$25k/$50k/
$100k/$200k) is rendered through a JS-driven pricing widget that neither the
raw `curl` capture nor the WebFetch rendered pass could read from the pages
checked this session. Recorded as `null` in the FTMO rulepack's
`normalized_claims.fee_exact_amount_by_account_size_tier` rather than
invented, per this task's own hard_constraint ("Quelle+Abrufdatum
dokumentiert, keine erfundenen Werte"). If the exact fee table becomes
load-bearing for a cost decision, it needs either a JS-rendering fetch tool
or a manual OWNER check against the live pricing page.

The Darwinex Zero D-Leverage short-hold bucket boundary (16.25x cap) is
disputed between the two official sources themselves (`<15 minutes` vs
`<30 minutes`) — recorded verbatim in the rulepack rather than silently
picked. Does not block current usage since QM's own operating figure
(9.75x, >60-minute bucket) is unaffected and both sources agree on it.

## Evidence

- `docs/ops/evidence/2026-08-23_ftmo_official_rules_snapshot.json`
- `docs/ops/evidence/2026-08-23_darwinex_zero_risk_engine_snapshot.json`
- `docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json` (superseded v1)
