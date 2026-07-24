# Harvest ledger bulk duplicate audit (2026-07-24, marathon run)

## Trigger

STR-042 (PB dual stochastic) reached its build tranche with
eligibility=ELIGIBLE/status=NEW although its own [DEDUP 2026-07-24] note
said "Already built ff-pb-dual-stoch (thread 297661), FAILED Q04" — and
QM5_9999's SPEC is rule-identical to both blind specs produced in the
tranche. The Option-A re-grade had corrected eligibility semantics but not
reconciled the already-built dedup notes with eligibility for this class.

## Audit

All 27 then-remaining ELIGIBLE+NEW rows were scanned for
"[DEDUP] Already built" notes (16 hits) and each named prior EA's SPEC
strategy-logic paragraph compared against the row concept.

- RESOLVED-DUPLICATE (9, no rebuild): STR-049→QM5_10000, STR-051→QM5_10043,
  STR-066→QM5_9702, STR-069→QM5_10049, STR-071→QM5_9703, STR-075→QM5_9958,
  STR-079→QM5_9989, STR-087→QM5_10039, STR-088→QM5_10038. Plus the trigger
  case STR-042→QM5_9999 (reserved ea_id 20115 retired unused).
- REBUILD JUSTIFIED (1): STR-044 — QM5_9701 added an unsourced spread
  filter (spread < 20% ATR) and a session gate (broker 08:00-18:00) absent
  from the OP baseline; the faithful build (QM5_20116) proceeds with the
  deviation documented.
- DUPLICATE-SUSPECT (6, deep-check gate added): STR-058, STR-067, STR-072,
  STR-073, STR-082, STR-085 — prior-SPEC evidence incomplete in the quick
  scan (truncated paragraphs or plausible invented-filter deviations);
  each requires an explicit rule-identity verdict before any build.

## Honesty note

QM5_20108 (STR-024, tranche 4) may be near-identical to QM5_9944 — the
tranche-4 differentiation check recorded the prior build's STATUS but not
concrete rule deltas. Both are in the pipeline; Q04+ correlation/admission
gates (DL-083) will catch identical twins; flagged here for the record.

## Effect

ELIGIBLE+NEW backlog: 27 → 17 (1 built this tranche + 9 duplicates
resolved). Build throughput is preserved for genuinely distinct or
faithfully-corrective candidates only.
