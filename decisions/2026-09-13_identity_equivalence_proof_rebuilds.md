# Decision: Identity-Equivalence Proof for Symbol-Literal EA Rebuilds

- **Date:** 2026-09-13
- **Status:** RATIFIED / IDENTITY_EQUIVALENCE_RULE=ACTIVE (OWNER receipt 2026-09-14)
- **OWNER receipt:** decision_id `OWNER-DEC-IDENTITY-EQUIVALENCE-20260913`, receipt_id
  `099bebe6-1db6-4174-82be-4287639f49ff`, receipt sha256
  `0dcb95b9393dfd6ad6bcd953f7dc2b9318185cce75ddc9e0574f033b5cd26a0f`, decided_at_utc
  2026-09-14T13:45:21Z ("Los gehts, alles freigegeben und gemaess Vorschlag entschieden!
  Ausser RAM Zukauf" — Mission Control receipt, choice YES). Execution record:
  `docs/ops/evidence/2026-09-14_identity-equivalence-20260913_099bebe6_execution.md`.
- **Author:** Claude (Orchestrator)
- **Zone:** ROT-adjacent (touches what may stand in a deploy manifest / book-level
  evidence) — therefore proposed, not self-executed.
- **Evidence:** `docs/ops/evidence/2026-09-13_identity_equivalence/README.md`
- **Tool:** `tools/strategy_farm/identity_equivalence_proof.py`
  (tests: `tools/strategy_farm/tests/test_identity_equivalence_proof.py`)

## Context

Hard Rule: a rebuilt `.ex5` is a NEW identity and re-enters the pipeline at Q02
("rebuilt EX5 = new identity from Q02"). It never inherits gate *verdict rows*.

On 2026-09-13 five EAs were patched **only** to replace hard-coded `".DWX"`
symbol literals by inputs (Hard Rule "symbols are inputs") and re-registered as
new ids (QM5_41470/41471/41472/41473/41474). These rebuilds are intended to be
behaviourally identical to their originals. OWNER 2026-09-13 ("Alle Punkte ...
umsetzen") ordered a mechanism to let such a rebuild inherit the original's
*deployability* for the book on proof of equivalence, WITHOUT manufacturing any
gate verdict rows.

A byte-exact proof is impossible for some symbols: `RISK_FIXED` lot sizing uses
the symbol tick value, which for JPY pairs moves with the USDJPY quote between
runs. The proof is therefore **lot-normalised** (see evidence README).

## Rule (ratified, active)

A rebuilt identity R that carries an **`EQUIVALENT_EXACT` or
`EQUIVALENT_LOT_NORMALISED`** proof (schema `qm.identity-equivalence-proof/v1`)
against a **qualified original** O (O holds a genuine PASS gate history) MAY:

- **(a) Manifest substitution.** R may be listed in a deploy manifest in place of
  O, provided the manifest cites the proof path and its `proof.sha256`. The
  substitution is only for the *artifact identity that trades*; it does not copy
  O's verdicts onto R.
- **(b) Book-level evidence inheritance.** R inherits O's book-level evidence for
  Q11 (portfolio) analysis: O's live/backtest streams are treated as R's streams
  for correlation, weighting and portfolio admission, because R is proven to make
  the same decisions.

While simultaneously:

- **(c) R's own Q02..Q10 chain continues normally.** Inheritance changes nothing
  about R's per-gate pipeline; its own gates keep running and are the real judge.
- **(d) No verdict row is ever created from a proof.** A proof produces no
  `work_items`/`agent_tasks` verdict, no census change, no pool-definition change.
  It is evidence, never a gate result.

On **`NOT_EQUIVALENT`**, nothing is inherited: R is an ordinary new identity and
must earn its own full Q02..Q10 evidence. (Example this cohort: QM5_21505 →
QM5_41474 on XAGUSD diverged — 159 vs 151 deals, 132 differing deals — and
inherits nothing. Once their own Q02 rows existed, the two basket/cointegration
rebuilds proved the same way: QM5_12778 → QM5_41471 diverged 389 vs 261 deals,
and QM5_13117 → QM5_41472 diverged on 112/225 compared deals — see
`docs/ops/evidence/2026-09-13_identity_equivalence/README.md`, both
`NOT_EQUIVALENT`, 2026-09-14. Only QM5_12969 → QM5_41470 and QM5_13054 →
QM5_41473 qualify for inheritance from this cohort.)

## Ratified constants

The proof tolerances are OWNER-ratified constants, fixed in `PROOF_TOLERANCES`
and printed into every proof:

- `volume_ratio_abs_tol = 0.02`
- `volume_max_step_lots = 0.01`
- `pnl_per_lot_rel_tol = 0.005`
- `net_ratio_abs_tol = 0.05` (recorded, informational)

Changing a tolerance is a gate-criterion change (ROT) and requires a new OWNER
decision.

## Scope limits (unchanged authorizations)

This rule does not touch, and does not authorize: T_Live, the AutoTrading
toggle, live deployment, gate thresholds, candidate-pool / card-universe
definitions, or construction of a new book. Each remains separately authorized.
"Qualified original" means an original that itself already passed the gates; a
proof cannot upgrade an unqualified original.

## Rollback

- To roll back: remove every proof citation from deploy
  manifests (substitution reverts to the original identity or R runs on its own
  gates only) and mark this decision superseded. No pipeline state was ever
  created from a proof, so nothing else needs unwinding.

## Verification

`identity_equivalence_proof.py verify --proof <path>` re-hashes the proof's
inputs and confirms it still binds. Any manifest citing a proof should be
re-verified before deployment. All three proofs in this cohort currently verify
`ok=True`.
