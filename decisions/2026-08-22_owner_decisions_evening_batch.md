# OWNER decisions — 2026-08-22 evening batch (eight items)

Date: 2026-08-22

Authority: OWNER, written in-line on the canonical decision surface
`G:\My Drive\QuantMechanica - Company Reference\12 ToDo\AI ToDos\OWNER.md`
(file mtime 2026-08-22 20:52 local). Each item below quotes OWNER's own
words verbatim. Recorded by Claude (Orchestrator) the same evening.

This record is the repo-side, immutable counterpart of the Vault decision
surface. Mission Control remains canonical for decision *status*; where an
item has no Mission-Control `decision_id` yet, that is stated.

---

## 1. `OWNER-DEC-BACKUP-KEY` — Backup key custody — **DEFERRED**

> OWNER: vertagt

Consequence: SP-D3 (encrypted backups, router task `74a78403`) stays parked.
Codex had already refused correctly with
`DEFER: ROT-4 key-custody/recovery contract unavailable; no encryption or
retention mutation` — evidence
`docs/ops/evidence/2026-08-22_sp_d3_encrypted_backup_dependency_gate.md`.

**Documented actual state, deliberately accepted:** backups remain
unencrypted in the cloud until OWNER settles key custody. This is not an open
work item; it is a stated risk position. No AI seat may enable backup
encryption without a recovery contract — enabling it without one risks
locking the company out of its own backups.

## 2. `OWNER-DEC-MQ5-PROMOTION-BAN` — direct promotion of raw MQ5 from `G:` — **RATIFIED**

> Owner: folge der Empfehlung

Ratified as a permanent rule: **no `.mq5` file taken from `G:` (or any
external source) is ever promoted directly into the pipeline.** Adoption runs
only through a Strategy Card, a V5 re-implementation, and the full gate chain
Q00–Q13.

This closes ROT-3, which task `aa6510fb` explicitly left open as an OWNER
ratification while it shut the technical door. The technical quarantine is
already live and verified (3/3 web-MQ5 marked `RAW_UNTRUSTED` +
`DO_NOT_DEPLOY` in the source ledger; compile/REVIEW/Q02 promotion from `G:`
refused in code; 46 tests) — evidence
`docs/ops/evidence/2026-08-22_raw_mq5_quarantine.md`.

Rule text lands in the Vault under `01 Identity/Hard Rules`.

## 3. `OWNER-DEC-G-RETENTION` — `G:` archive retention — **MANIFEST-FIRST**

> OWNER: Manifest-first

The two audits disagreed; OWNER chose the conservative reading. **No deletion
on `G:` before a content-addressed corpus manifest and a dependency dry-run
exist.** Raw sources are reproducibility evidence; a purge can always follow
later, but it cannot be undone.

Order of operations: corpus manifest (`0fb2edcb`) → dependency/retention
dry-run (`2f36c28c`) → only then any retention proposal. The radical
immediate purge recommended by the G-Drive audit is **rejected**.

Execution note: both tasks are blocked for an infrastructure reason, not a
policy one — `G:` (DriveFS) is mounted in interactive session 1 and is *not*
visible to headless Codex. Evidence
`docs/ops/evidence/2026-08-22_sp_d1_corpus_manifest_access_gate.md`. The
manifest is therefore produced from the Orchestrator's interactive slot.

## 4. `OWNER-DEC-OPSEC-BUNDLE` — three OPSEC steps — **APPROVED**

> OWNER: genehmigt

Approved in order a → b → c, all three OWNER-executed:
(a) server topology into an encrypted record / password manager, Vault keeps
only redacted IDs; (b) review Google-Drive ACL / sharing / MFA / version
history on both folders; (c) RDP / admin / KVM rotation per risk assessment.

Urgency MEDIUM, not panic: no reusable credential is demonstrably leaked.

AI-side companion work: the Vault redaction pass (`3aa38252`) is Claude work
(it needs `G:`, which headless Codex does not have — evidence
`docs/ops/evidence/2026-08-22_sp_d8_vault_redaction_role_gate.md`). It runs
from the Orchestrator slot and does not wait on (a): redaction removes detail
from the Vault regardless of where the unredacted record ends up living.

## 5. `OWNER-ACT-SIGN-POINTER` — sign the deploy pointer — **APPROVED**

> OWNER: genehmigt

This is the explicit, dated, written OWNER approval that
`docs/ops/evidence/2026-08-22_sp-a1_pointer_schema_and_signing.md` §4 requires
before Claude may run the signing step on OWNER's record ("or by Claude acting
on record of an explicit, dated, written OWNER approval — never inferred or
assumed").

**Prerequisite that still gates execution**, stated in the same §4: the
signing procedure forbids signing a pointer whose `manifest_path` targets a
manifest other than the one T_Live actually runs, and `farmctl health`
(`ks_baseline_dormancy`) flags four newer, unreconciled 2026-07-26 candidate
manifests. Manifest reconciliation is therefore performed and evidenced
*before* the signature — see
`docs/ops/evidence/2026-08-22_deploy_pointer_manifest_reconciliation.md`.

No AutoTrading toggle, no risk change, and no live mutation is part of this
step. Signing only marks the pointer authenticated so the bound consumers
(Pulse, burn-in, Sunday-compare, inventory — all `RequireSigned`) stop
reading UNKNOWN.

## 6. `OWNER-DEC-NEWS-MAPPING` — news impact taxonomy — **APPROVED (Option 1)**

> OWNER: genehmigt

The Vault item's recommendation was "the one in the spec template (Clean as
canonical, Original as audit trail)", i.e. **Option 1** of
`docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md` §15:
`forex_factory_calendar_clean.csv` is canonical for impact classification
under `qm.news_impact_mapping.v1`; `news_calendar_2015_2025.csv` is retained
as an audit trail, not as a gating source.

Scope of the disagreement this settles: 41.7 % impact divergence across
47,565 common events, 25.5 % High/Not-High flips.

**This is ROT — gate data semantics.** Implementation (`84c988e6`) stays
gated until *both* conditions hold: this decision (now met) **and**
completion of the Q09 rerun. Codex held correctly and must not unblock on the
OWNER half alone. Detailed record: `decisions/2026-08-22_news_impact_taxonomy.md`.

## 7. `OWNER-DEC-STAT-CONTRACT` (announcement) — **APPROVED**

> OWNER: genehmigt

Approved as announced: Claude drafts the statistical contract (nested
walk-forward / PBO / DSR / holdout); scaling 9.75 → 12+, FTMO book adoption
and any challenge purchase (ROT-10/11/12) stay **parked until the drain goal
is reached**. Approval covers the drafting and the parking, not the adoption
of any threshold — the contract itself returns as its own decision.

## 8. `OWNER-DEC-CALENDAR-REPIN` — permanently red calendar lint — **APPROVED (Option a)**

> Owner: genehmigt

Option (a) with a signed receipt chain: the daily refresh re-pins the
calendar dependency hash itself and records every pin change as an
individually auditable, chained receipt. Option (b) — weakening the test to
coverage-window/freshness instead of a byte hash — is **not** approved and
must not be substituted.

Rationale carried from the recommendation: the pin protects the provenance of
the calendar bytes; an automatic, signed continuation protects it just as
well, without manufacturing a false red every morning. A permanently red test
protects nothing, and this one masks regressions in exactly the class that
checks live execution contracts.

Commissioned: router task `689b3af1` (Codex, priority 86) with the five hard
requirements spelled out, including fail-closed refusal on an implausible
calendar file and a verifier that detects a broken receipt chain.
Diagnosis: `docs/ops/evidence/2026-08-22_two_permared_test_classes_diagnosis.md`.

---

## Still open after this batch

`OWNER-DEC-RISK-FREEZE` received no answer. Per the Stehende Vollmacht the
Auffangregel applies to it (reversible, Vorlage submitted with options,
recommendation, rollback and cost of waiting): **without an answer by
2026-08-23 ~12:00 the freeze is executed as a documented actual state** and
marked explicitly as an Auffangregel execution.

`OWNER-DEC-MQL5CAND` remains deliberately deferred (2026-08-21): the choice
is made later from the final candidate pool with optimization set-file (Q16
cohort), preferring EAs profitable on several symbols. Q16 has zero rows
ever, so there is nothing to choose from yet.
