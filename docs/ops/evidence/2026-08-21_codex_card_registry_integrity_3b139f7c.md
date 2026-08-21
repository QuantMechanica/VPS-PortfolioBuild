# Card / registry identity integrity repair — 3b139f7c

Date: 2026-08-21  
Branch: `agents/board-advisor`  
Task: `3b139f7c-a114-4e3d-a9e1-7bc64d5c6b47`

## Outcome

The two disagreement classes are now fail-loud in farm health. The initial
production check reproduced all 268 defects: three cards in
`cards_rejected` with `g0_status: DRAFT`, and 265 active registry rows whose
slug embeds a second `QM5_<id>_` identity.

The three card records were mechanically normalized to `REJECTED` through
`farmctl reject-card`; their existing leading rejection comments, rejected-pool
placement, and prohibited mechanics all agreed. No strategy meaning changed.

Nine materialized registry rows were mechanically normalized through the new
lock-protected, atomic `farmctl normalize-ea-id-slugs` command. Each was changed
only after the numeric registry ID, exact `QM5_<ea_id>_<slug>` directory, and
every active magic row agreed on the prefix-free slug. A second `--apply` run
was an idempotent no-op.

The other 256 embedded-slug rows have no EA directory or magic rows and are all
marked `RETIRE` by the independent D1 disposition. They were deliberately not
reinterpreted here. The separately routed `retire-ea-ids` task owns that status
transition.

## Authorities

- Card decision: the Strategy Card's `g0_status` is the authoritative G0 field.
  For the three corrections, a pre-frontmatter rejection audit comment and the
  `cards_rejected` pool supplied corroborating durable evidence.
- Registry numeric identity: `framework/registry/ea_id_registry.csv:ea_id`.
- Materialized slug: the exact EA directory plus every active
  `magic_numbers.csv:ea_slug` row for that numeric ID.
- Unmaterialized-row disposition:
  `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.

## Complete affected-row inventory

The machine receipt lists every one of the 265 initially affected registry
rows (row number, numeric ID, old slug, embedded ID, normalized slug, status,
and D1 disposition) and all three affected cards:

`artifacts/reviews/3b139f7c-a114-4e3d-a9e1-7bc64d5c6b47.json`

Receipt SHA-256:
`e3f32729b44efebc42d95c597d6619393cb79e7db34aa3c5aa4004799c8fe064`.

Initial registry classification: 256 `RETIRE`, nine `NOT_IN_DECISION` but
fully materialized and three-way corroborated. Post-repair residue: exactly
256, all `RETIRE`.

## Guard and verification

- `card_registry_identity_integrity` is registered in `health.ALL_CHECKS` and
  returns structured, complete affected-row lists.
- The frontmatter parser/updater now preserves UTF-8 BOMs and leading HTML
  rejection comments, so the legacy card format cannot evade the check.
- `reject-card` now accepts an already-in-place rejected-pool card idempotently
  and refuses a different-file collision before mutation.
- `normalize-ea-id-slugs` is dry-run by default, requires evidence, validates
  the entire batch before mutation, uses the registry lock and atomic writer,
  refuses identity disagreement or active-slug collision, and is idempotent.
- Focused tests: `15 passed` across card frontmatter/rejection, slug
  normalization, and registry health fixtures.
- Code guard commit: `96ee7ecab`.

The production integrity check is intentionally still `FAIL` with 256 rows
until the decision-backed retirement task completes; hiding that residue would
defeat the new guard.
