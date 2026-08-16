# Batch proposal: session-tick variants for the 25 XTI/XNG confirmed_affected cards

- Router task: `ee0922a7-ea31-48b4-862c-76b536f44978` (claude, priority 70)
- Status: **DRAFT, PENDING OWNER APPROVAL** — no card, source, or work item is
  mutated by this proposal. This is the single batch ask requested by the
  task payload ("present as one batch proposal with the offset evidence, not
  25 separate asks").
- Evidence chain: `fea371c2` (XTI tick-level offset measurement) →
  `6dfa3117` (23+4-row census) → discriminator doc
  `2026-08-16_entry_clock_discriminator_41015_41021_census_reclassification.md`
  (proved the defect is `declared_grace < offset`, corrected the gate design
  to a relationship test, reclassified the census to 25 confirmed / 2
  cleared) → this proposal.

## What is being asked

One OWNER decision, applied identically to all 25 rows below: replace each
card's D1-label-anchored entry clock (`"first observed tick within N minutes
of the D1 bar open"`, currently `N=5` on every row) with the session-tick
anchor already designed and drafted for the `QM5_41016`/`QM5_41017` template
(`docs/ops/evidence/2026-08-16_qm5_41016_41017_session_tick_variant_derivation.md`):

> Anchor the entry grace window to `D1_bar_open + strategy_session_offset_min`
> instead of the raw D1 label. `strategy_session_offset_min` = 61.6 min for
> `XTIUSD.DWX` (fea371c2 tick-measured maximum, used conservatively), and the
> same 61.6 min value carried as an *unverified* estimate for `XNGUSD.DWX`
> (same broker energy feed route, not independently tick-measured — flag
> this to OWNER explicitly per row 3 below). `strategy_entry_grace_minutes`
> stays tight (10 min) around that anchor, preserving the parent cards'
> falsifiable-attach philosophy instead of loosening it into a vague session
> window. Add a `strategy_min_stub_ticks` floor (default 20) to reject thin
> weekend/holiday D1 stubs, and a `strategy_min_attach_ticks` floor (default
> 20 ticks within 5 min of the qualifying tick) to distinguish a genuine
> session-open attach from a mid-session process restart.

This is a **mechanics change** (the entry-clock definition itself moves), so
per Specification Density Principle it needs OWNER approval per card family,
not self-authorization — hence one batch ask covering the mechanically
identical change across all 25.

## The 25 rows

| # | ea_id | symbol | current grace (min) | q02 status (as of 6dfa3117 census) | pipeline_phase |
|---|---|---|---:|---|---|
| 1 | QM5_41014 | XTI+XNG basket | 5 | PENDING | repo |
| 2 | QM5_41015 | XTI+XNG basket | 5 | PENDING | repo |
| 3 | QM5_41016 | XTIUSD.DWX | 5 | ENQUEUED (zero-trade, template variant already drafted) | repo |
| 4 | QM5_41017 | XTIUSD.DWX | 5 | ZERO_TRADES, BLOCKED_CARD_MECHANICS (template variant already drafted) | repo |
| 5 | QM5_41018 | XTI+XNG basket | 5 | PENDING | repo |
| 6 | QM5_41021 | XTI(+XNG?) | 5 | PENDING (upgraded from LIKELY_AFFECTED by the discriminator doc) | repo |
| 7 | QM5_20011 | XNGUSD.DWX | 5 | (upgraded from LIKELY_AFFECTED; raw non-modulo comparison confirmed at `:131-134`) | repo |
| 8 | QM5_20117 | XTIUSD.DWX | 5 | ENQUEUED | repo |
| 9 | QM5_20145 | XTIUSD.DWX | 5 | Q01 PASS / q02 PENDING | repo + D: (D: stale) |
| 10 | QM5_20149 | XTIUSD.DWX | 5 | PENDING_CPU_CEILING | repo |
| 11 | QM5_20153 | XTIUSD.DWX | 5 | ENQUEUED | repo |
| 12 | QM5_20154 | XTIUSD.DWX | 5 | ENQUEUED | repo |
| 13 | QM5_20155 | XTIUSD.DWX | 5 | ENQUEUED | repo + D: (identical) |
| 14 | QM5_20173 | XTIUSD.DWX | 5 | BLOCKED_FACTORY_OFF | repo |
| 15 | QM5_20174 | XTIUSD.DWX | 5 | ENQUEUED | repo |
| 16 | QM5_20215 | XTIUSD.DWX | 5 | NOT_STARTED | repo |
| 17 | QM5_20217 | XTIUSD.DWX | 5 | ENQUEUED | repo |
| 18 | QM5_20226 | XTIUSD.DWX | 5 | ENQUEUED | repo |
| 19 | QM5_20230 | XTIUSD.DWX | 5 | NOT_STARTED | repo |
| 20 | QM5_20159 | XNGUSD.DWX | 5 | ENQUEUED (repo; D: stale) | repo + D: |
| 21 | QM5_20158 | XNGUSD.DWX | 5 | NOT_STARTED | repo + D: |
| 22 | QM5_20156 | XNGUSD.DWX | 5 | NOT_STARTED (source lineage differs D: vs repo, defect line identical) | repo + D: |
| 23 | QM5_20163 | XNGUSD.DWX | 5 | NOT_STARTED | repo |
| 24 | QM5_20160 | XNGUSD.DWX | 5 | NOT_STARTED | repo |
| 25 | QM5_20198 | XNGUSD.DWX | 5 | NOT_STARTED | repo |

Source: `bar_open_clock_sweep_6dfa3117` census confirmed-affected table plus
the discriminator doc's two upgrades (`QM5_20011`, `QM5_41021`). `q02_status`
values are as last observed by that sweep (2026-08-16); several rows have
almost certainly advanced in the normal queue since — re-check `q02_status`
per row before drafting the actual variant cards, do not assume this table
is still current by the time OWNER reviews it.

## Recommended decision structure for OWNER

1. **One yes/no on the mechanics change** described above, applying to every
   row currently carrying `XTIUSD.DWX`/`XNGUSD.DWX`/XTI+XNG-basket carriers
   with the D1-label + tight-grace idiom (this table plus any future row the
   detector finds — the fix is carrier-level, not per-card).
2. **Explicit sub-decision on XNGUSD rows (7 of 25: #7, #20-25)**: their
   `strategy_session_offset_min` is an *inferred* value (XTI's measured 61.6
   min carried over on the "same broker energy feed" assumption), not an
   independently tick-measured one. OWNER can either (a) approve the
   inferred value now and flag it for later tick-confirmation, or (b) require
   a `fea371c2`-style tick replay on `XNGUSD.DWX` before touching those 7
   cards. This proposal does not pick for OWNER.
3. **Per-card "advance vs. never-shift" semantics still needs a card-by-card
   call** (item 4 of the original `6dfa3117` review handoff) — e.g.
   `QM5_41017`'s exact-date rule must keep consuming a non-tradable date
   flat rather than shifting it, matching its existing card intent; a
   monthly-boundary card like `QM5_41016` advances the whole window instead.
   The two already-drafted variants
   (`D:/QM/strategy_farm/artifacts/cards_review/PENDING_6DFA3117_wti-mclose-mom-session-tick.md`,
   `..._wti-dom-ctrreg-session-tick.md`) are the reusable template for
   whoever drafts the remaining 21+2 (23) variant cards once OWNER approves
   the batch — drafting all 23 remaining variant cards is follow-up work,
   not done by this proposal.

## What this proposal is not

- Not a build, compile, setfile regeneration, or work-item action.
- Not a claim that all 25 rows will pass Q02 once fixed — only that the
  current clock makes them structurally untestable; Q02-Q14 evidence remains
  the real judge per the pipeline's own rules.
- Not a decision on the `XAUUSD.DWX`/`XAGUSD.DWX` registry question raised in
  the companion evidence doc
  (`2026-08-16_session_offset_registry_measurement_and_xau_reconciliation.md`)
  — that is a forward-looking registry-correctness fix with zero current
  card exposure, deliberately kept out of this batch ask to avoid diluting
  the 25-card unblock with an unrelated decision.
