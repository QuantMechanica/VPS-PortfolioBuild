# Disposition of the 963 active EA-IDs that never reached a gate

**Date:** 2026-08-21 · **Author:** Claude (Orchestrator) · **Programme:** drain (D1)
**Decision list:** `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv` (963 rows, one
`action` + `reason` per ID)
**Census this came from:** `docs/ops/evidence/2026-08-21_pipeline_drain_census_and_programme.md` §3.1

Drain condition **D1** requires that no active EA-ID exists without either a pipeline row or a
dated terminal disposition. 1 470 IDs failed it; 507 of those have build artifacts and are
handled by the compile/enqueue tasks. These 963 have **no EA directory at all** — an ID was
reserved and nothing followed. This document decides all 963.

## Result

| Action | IDs | Meaning |
|---|---:|---|
| **RETIRE** | **759** | terminal, with a reason; nothing is lost |
| **ADJUDICATE** | 191 | a real card is waiting for a G0 decision |
| **INVESTIGATE** | 8 | 7 slug variants + 1 safety override |
| **RECHECK** | 5 | blocked on R3 data; re-test against today's symbol matrix |

D1's unknown bucket therefore collapses from **963 to 204**, and every one of those 204 has a
named action rather than silence.

## The trap that would have made a bulk retire destructive

The obvious rule — *"the card was rejected, so retire the ID"* — is **wrong**, and the data
says so plainly.

`QM5_1136` is registered as `qp-option-exp-sp500`. The rejected-card pool holds
`QM5_1136_index-close-auction-intraday-momentum.md`. Same ID, two entirely different
strategies. The same pattern appears on 1137, 1138, 1139, 1140, 1151–1158 — and several of
them carry magic-number rows (1156 has 15).

That is not corruption. It is **ID re-purposing after rejection**: once a card is rejected its
reserved ID becomes free again, and `farmctl reidentify-recovery-card` exists precisely to
re-point it. The stale rejected-card file stays behind in the pool as debris under an ID that
now means something else entirely.

Retiring on "there is a rejected card with this ID" would therefore have retired **live,
re-purposed IDs** — some of them already built and carrying magic space. The magic formula is
`ea_id*10000+slot`, so a wrongly retired ID with magic rows reproduces the 2026-08-15
re-symbol collision class that blocked every reservoir prebuild for three days.

**The rule that survives contact with the data:** retire only when the **registry slug still
matches the rejected card's slug** — i.e. the ID was never re-pointed. Those re-purposed IDs
are not in this set at all: they have EA directories and work items, so the census excluded
them before the question arose.

## How each action was derived

### RETIRE — 439 rejected, slug still matching

Every one verified mechanically, not sampled:

- the card file in `cards_rejected/` carries `g0_status: REJECTED` **and** an explicit
  `g0_rejection_reason` — 443 of 446 (the other 3 carry `g0_status: DRAFT` while sitting in the
  rejected pool, an inconsistency reported below, and are not retired here);
- the registry slug equals the card slug (ignoring `_dup-*` suffixes) → never re-purposed;
- **zero** magic rows, no EA directory, no work items.

Rejection reasons cluster as expected for a G0 gate: R2 (not mechanical enough) 164, R3 (data
not available) 115, R2/R3 32, R1/R2 16, R1/R3 14, plus card-body-incomplete variants.

### RETIRE — 320 reserved before the current card process

321 IDs have **no card in any pool**. The provenance is unambiguous:

- **316 of 321 were registered in 2026-05**;
- **260 are owned by `DeepSeek`** — a provenance that no longer exists in the operation;
- 6 of them have since been re-carded under a *different* ID (e.g. `singh-trend-rider` is
  QM5_1034 in the registry but lives as QM5_12548 in `cards_review`), so the old reservation is
  a duplicate of a live card, not a lost strategy.

Retiring them loses nothing, because **no strategy was ever written**. One is excluded by the
safety override below, leaving 320.

### ADJUDICATE — 191 cards sitting in `cards_review`

These are the only ones representing real unfinished thinking: a card exists and was never
given a G0 decision. That is a card-universe judgement (ROT), so it is **not** a registry edit
and not something the drain tooling may resolve. It becomes its own reviewed workstream.

### INVESTIGATE — 8

- **7 slug variants**: the registry slug is a near-miss of the rejected card slug, e.g.
  `QM5_11456` registered as `davey-dueling-momentum-d1-alt-a` against a rejected
  `davey-dueling-momentum-d1`. Was the variant ever a separate strategy, or is this naming
  drift? Decided per ID, not by rule.
- **1 safety override — `QM5_20001` `master-xauusd`** (reserved by Codex 2026-07-13): it has
  **1 magic row** (`200010000`, XAUUSD.DWX) but no card and no EA directory. Something once
  claimed this ID's magic space. It is the only one of the 963 in that condition and it is not
  retired on a heuristic.

### RECHECK — 5

Cards blocked on `r3_data_available`. The DWX symbol matrix has changed since; re-test before
any terminal call.

## Two integrity findings reported, not fixed here

1. **3 cards with `g0_status: DRAFT` are sitting in `cards_rejected/`.** A card's pool and its
   own status disagree — the same defect class as the retired cards found in `cards_approved`
   earlier today (`8c685237`, where the pump's `_detect_unbuilt_cards` turned out never to
   check registry status and QM5_38007 was next in line to be claimed).
2. **Registry slugs contain embedded IDs.** Several rows carry slugs like
   `QM5_9221_mql5-...` and `QM5_1428_wyckoff-...`, i.e. the ID is duplicated inside the slug
   field. Cosmetic until something string-matches on slug — `farmctl` already compares registry
   slug against card slug (`ea_id_registry_slug_mismatch`), so it is a latent false-mismatch
   source.

## What blocks execution: there is no governed way to retire an EA-ID

`farmctl` has `reserve-ea-ids` (atomic, lock-protected) and `reject-card`, but **no
retire/status transition for a registry row**. The research-agent prompt states plainly:
*"never hand-edit or append `framework/registry/ea_id_registry.csv`"*. So 446 rejected cards
kept `status: active` simply because nobody had a legitimate way to say otherwise — and today's
mirror-image finding (`09291af2`: `reserve_ea_ids` only allocates NEW IDs, with no path to
backfill a legacy row) is the same gap seen from the other side.

I am therefore **not** editing the CSV by hand. The decision list above is the input; the
mechanism is commissioned as a governed CLI with the refusal conditions this analysis produced
(refuse if the ID has an EA directory, work items, or magic rows; require a reason and an
evidence pointer; idempotent; bounded waves with receipts).

## Reproduction

The three read-only probes that produced this (census by card pool, ID-reuse probe, disposition
with slug-match and magic guards) are deterministic against
`framework/registry/ea_id_registry.csv`, `framework/registry/magic_numbers.csv`,
`D:/QM/strategy_farm/artifacts/cards_*` and `work_items`. Key counts to re-derive:
963 never-gated IDs with no EA directory; 446 with a rejected card; 443 of those carrying an
explicit rejection reason; 439 with a still-matching registry slug; 321 with no card anywhere;
191 in `cards_review`; exactly 1 of the 963 carrying magic rows.
