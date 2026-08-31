# QM5_41185 R3 Schema Normalization Amendment

Date: 2026-08-31

Decision: `APPROVED_EDITORIAL_NORMALIZATION_NO_MECHANIC_CHANGE`.

The OWNER-authorized source approval and G0 decision remain:

- `decisions/2026-08-27_xauxag_fractional_difference_reversion_source_approval.md`; and
- `decisions/2026-08-27_qm5_41185_xauxag_fractional_difference_reversion_g0.md`.

The current OWNER commodity/energy portfolio mission authorizes completing one
new structural commodity build and its paced Q02 handoff. The deterministic
`farmctl build-ea` intake requires the strict R2-R4 frontmatter fields to contain
the literal token `PASS`. The approved card predated that serializer contract
and stored `r3_data_available` as
`PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`, although the G0 decision and
card both concluded that registered native XAU/XAG D1 data supplies every
runtime input.

## Bound Card

- card: `strategy-seeds/cards/approved/QM5_41185_xauxag-fracd-rv_card.md`
- prior approved-card SHA-256:
  `47074A6FBB214B0707F6C418AEC969C4E118265EAA2890C55A72FB6303488685`
- normalized approved-card SHA-256:
  `E6735BCAFA7FC8A401C1E9038E502BB964FA43316903350FD4721010B4978ADE`

The normalization changes only the flat frontmatter value to
`r3_data_available: PASS` and advances `last_updated` to 2026-08-31. The
existing `r3_reasoning`, body R3 table, source packet, and G0 decision retain
the synchronization and continuous-CFD basis risks explicitly.

No symbol, sample count, timestamp join, fractional order, recurrence length,
baseline, threshold, side, clock, attempt state, position sizing, stop,
spread cap, lifecycle, risk mode, or pipeline criterion changes.

## Validation Boundary

The canonical and EA-local card copies are byte-identical after normalization.
The card schema lint, G0 lint, build-skill guard, specification validator,
build guardrails, basket symbol-scope validator, raw-MQ5 quarantine check, and
eight independent fixed-filter reference tests must all remain PASS before a
governed compile item is created.

This amendment authorizes no manual backtest, live/demo/shadow/stress or
optimization preset, `T_Live`, AutoTrading, deploy or live manifest,
portfolio-gate change, portfolio admission, correlation waiver, or
decorrelation claim.
