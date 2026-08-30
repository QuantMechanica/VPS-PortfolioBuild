# Q02 evidence-loss 34-pair execution authority conflict

Date: 2026-08-30

Router task: `026de980-3788-40b3-ac27-521100428b7a`

OWNER decision: `OWNER-DEC-Q02-EVIDENCELOSS-34-20260829` (`YES`)

## Outcome

No farm-state or repository control artifact was mutated. Execution stopped
fail-closed because the task requires the 14/20 split to be byte-identical to
commit `b82d814a9a58bb8a12e5fa1a4783b4c9b61738ac`, but that commit records the
opposite cause-group cardinality from the execution authority:

- the committed recovery narrative states that **20 pairs** belong to the
  runtime/transient cause groups `ACTIVE_TIMEOUT`,
  `TIMEOUT_METATESTER_HUNG`, and `NO_HISTORY_TRANSIENT`;
- the same committed classifier leaves **14 pairs** in the other cause groups
  (`SETFILE_MISSING`, `ONINIT_FAILED`,
  `SUMMARY_MISSING_NO_ROW_BOUND_AGGREGATE`, and `LOG_BOMB`);
- the routed task and OWNER execution ledger instead authorize **14 transient
  restarts and 20 structural retirements** and prohibit reclassification;
- neither the decision ledger nor the routed payload contains an exact
  per-pair 14/20 manifest that can resolve which six of the committed 20
  runtime/transient pairs moved to the structural class.

Applying either interpretation would violate one binding clause: following the
commit would produce a 20/14 disposition, while following the numeric 14/20
instruction would require an undocumented six-pair reclassification.

## Reproduction

The committed CSV has 34 distinct `(ea_id, symbol)` rows. Its primary-cause
counts are:

| Cause | Pair count | Commit narrative class |
|---|---:|---|
| `ACTIVE_TIMEOUT` | 16 | runtime/transient |
| `TIMEOUT_METATESTER_HUNG` | 2 | runtime/transient |
| `NO_HISTORY_TRANSIENT` | 2 | runtime/transient |
| `SETFILE_MISSING` | 6 | not runtime/transient |
| `ONINIT_FAILED` | 4 | not runtime/transient |
| `SUMMARY_MISSING_NO_ROW_BOUND_AGGREGATE` | 3 | not runtime/transient |
| `LOG_BOMB` | 1 | not runtime/transient |

The committed Markdown explicitly says: "all 20 pairs across the three cause
groups the classifier marks as runtime/transient". It also records that none
of those 20 retained source evidence or logs and that the canonical append-only
rerun path refused the sampled row with
`q02_rerun_source_evidence_missing`. The new OWNER decision grants a bounded
exception in principle, but does not define the missing exact 14-pair subset.

## Bound evidence

| Artifact | SHA-256 |
|---|---|
| `docs/ops/evidence/2026-08-29_q02_stranded_pairs_classification.csv` | `ca1fe0da1f7ccb7560bcd641776a7e6bbe1090685933cbd825abed4ecadbe84e` |
| `docs/ops/evidence/2026-08-29_q02_stranded_pairs_classification.json` | `ce28b95d50f5d558bf2acb42fdef94f0fe1eef16b0892bc9b485960fafaE3f76` |
| `docs/ops/evidence/2026-08-29_q02_stranded_pairs_staged_recovery_attempt.md` | `e4299501cf6819a85c024819f84f30e2c59409b9e4ebd683df851373428bc414` |
| `tools/strategy_farm/config/owner_decision_execution.v1.json` | `d1a2b045437b8017523ce7e8e1cdd3c76fbea0ec43b618a996ebeb22d73af4e0` |
| `D:/QM/reports/state/owner_decisions.json` | `0ca7c97d8275107b06a18a3d73ed3d0215f93a7122107f259660fd8b243f77fe` |

## Required correction

Publish a decision-bound manifest listing all 34 exact `(ea_id, symbol)` pairs
with one immutable action per row, exactly 14 `RESTART` and 20 `RETIRE`, plus
its SHA-256. That is a clarification of scope, not authority for this agent to
choose or infer the six disputed rows.

Verdict: `REVIEW_REQUIRED_AUTHORITY_CONFLICT`; zero restarts, zero retire
dispositions, and zero historical verdict/evidence mutations.
