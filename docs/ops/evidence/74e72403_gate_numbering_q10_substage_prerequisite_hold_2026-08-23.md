# Gate Numbering Q10.1–Q10.3 — Prerequisite Hold

- Router task: `74e72403-399b-41c9-8627-0fdaa0bc8e08`
- ToDo: `QM-TODO-20260823-502`
- Assigned implementation lane: Codex steps 3-5, after Claude steps 1-2
- Outcome: `BLOCKED_PREREQUISITE_DECISION_AND_MANIFEST`

## Finding

The OWNER instruction carried by the router selects the optimization fork
tokens `Q10.1` (Pattern Filter), `Q10.2` (Parameter Optimization & Freeze), and
`Q10.3` (Best-Settings Head-to-Head), returning to the unchanged Q11-Q13
ordinary chain. The task contract explicitly requires a new immutable decision
record and a reviewed/activated manifest v4 before Codex performs data and
documentation migration.

Neither prerequisite exists in the canonical checkout:

- The only related dated decision is
  `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`. It ratifies the
  incompatible full-linear Q00-Q17 scheme (including moving current Q11-Q13 to
  Q15-Q17). Dated decisions are immutable, so it cannot be repurposed for the
  later sub-stage choice.
- `tools/strategy_farm/config/gate_manifest.v4.json` is absent.
- `tools/strategy_farm/config/gate_manifest.v4.draft.json` is the incompatible
  full-linear proposal and remains `DRAFT_PROPOSAL_NOT_ACTIVATED` / READ_INERT.
- `tools/strategy_farm/gate_manifest.py` still binds `DEFAULT_MANIFEST` to
  `gate_manifest.v3.json`, whose canonical token contract does not write
  `Q10.1`-`Q10.3`.

Therefore steps 3-5 cannot safely begin. Migrating database rows before the new
contract is active would write tokens that current factory readers do not own;
rewriting documentation first would make operator surfaces disagree with the
runtime. Editing the existing dated decision would violate the explicit
immutability rule.

## Read-only census

The live database was opened in SQLite read-only mode. Current optimization
rows remain exactly:

- `Q14`: 14 work items
- `Q15`: 1 work item
- `Q16`: 0 work items
- `Q10.1` / `Q10.2` / `Q10.3`: 0 work items

Agent-task payloads contain 21 rows mentioning Q14, 11 mentioning Q15, and 16
mentioning Q16 (mentions can overlap). The only payload mentioning any new
sub-stage is this commission itself. No row, task payload, manifest, default,
factory process, terminal, or documentation token was mutated.

## Required unblock sequence

1. Claude/OWNER creates a new dated DL decision that explicitly supersedes the
   full-linear proposal for future writes and records the Q14→Q10.1,
   Q15→Q10.2, Q16→Q10.3 alias table without editing prior decisions.
2. Claude prepares and reviews a sub-stage `gate_manifest.v4.json` as READ_INERT,
   then activates it through the existing OWNER activation guard.
3. Re-route Codex steps 3-5 against that exact active manifest: transactional
   append-preserving migration, mechanical non-decision documentation sweep,
   alias round-trip and ambiguity tests, and strictly ascending ordinary-chain
   tests.

Short verdict: `BLOCKED_PREREQUISITE: immutable sub-stage decision and matching active manifest v4 are absent; no migration attempted.`
