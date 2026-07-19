# QM5_12784 registry collision re-key evidence — 2026-07-19

## Identity decision

`progo-xti` retains EA ID 12784. It owns the only current 12784 work item
(`e04d6c58-8b0d-461c-a0f3-22912b484695`, Q02/XTIUSD). The colliding
`intraday-config-engine` had no work items and was re-keyed.

ID 20006 was not available: a runtime review card already claims it. The
canonical `farmctl reserve-ea-ids` lock path atomically reserved ID 20007 with a
temporary hold slug; that row was then finalized as the active
`intraday-config-engine` identity.

## Applied changes

- The old 12784 intraday EA directory, including its compiled EX5, moved under
  `_obsolete_QM5_12784_intraday-config-engine_pre-rekey` as immutable historical
  evidence.
- A new `QM5_20007_intraday-config-engine` source/spec/setfile tree was created.
  It intentionally has no EX5 until the canonical build lane is unblocked.
- Registry row `12784,intraday-config-engine` and its four magic rows were
  retired. `progo-xti` and magic `127840000` remain active.
- New active slots are GDAXI=0, NDX=1, SP500=2, XAUUSD=3, yielding magics
  `200070000` through `200070003`.
- The approved runtime card was archived below
  `cards_approved/_obsolete_rekey_20260719/`; the top-level replacement is
  `QM5_20007_intraday-config-engine.md`. The archived card SHA-256 is
  `D03D8FDB6AB8034A4BF81CE341AA055FDE5461832DCC7C90B203CBF79EEA8CDD`.
- `QM_MagicResolver.mqh` was regenerated from the CSV. It retains progo magic
  `127840000`, excludes retired intraday magics `127840001..127840004`, and
  contains all four new 20007 magics. The registry SHA prefix is
  `CAE9686CD1BB1EA0`.

The regenerator also reported three pre-existing, unrelated active-magic rows
without EA directories (1001, 1015, 1016). They were not changed by this re-key.

## Health and build state

`ea_id_slug_uniqueness` is now a standard farm health check. It normalizes bare
and `QM5_`-prefixed IDs and requires both active magics and an exact EA directory
before escalating a duplicate to FAIL. After this re-key the live collision is
gone; the check returns WARN for eight pre-existing registry-only duplicates.

Canonical compilation is deliberately deferred because the shared checkout is
dirty with unrelated active work and the build guard is fail-closed. No old EX5
was copied or renamed into the 20007 identity. An isolated temporary-tree
MetaEditor validation nevertheless passed with 0 errors and 0 warnings, proving
the re-keyed source and regenerated resolver compile together without creating a
canonical 20007 EX5.
