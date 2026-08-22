# News impact taxonomy — canonical source ratified

Date: 2026-08-22

Decision: **Option 1 — `forex_factory_calendar_clean.csv` is canonical.**

Authority: OWNER, in-line on the canonical decision surface
`G:\My Drive\QuantMechanica - Company Reference\12 ToDo\AI ToDos\OWNER.md`
under `OWNER-DEC-NEWS-MAPPING`: "OWNER: genehmigt", against a recommendation
that named the spec template's own proposal (Clean canonical, Original as
audit trail). Recorded per the instruction in
`docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md` §15 ("Once decided, record
under `decisions/YYYY-MM-DD_news_impact_taxonomy.md` citing this section").

Batch record: `decisions/2026-08-22_owner_decisions_evening_batch.md` §6.

## What was decided

For events present in both calendar files whose impact classification
disagrees, `forex_factory_calendar_clean.csv` carries the canonical impact
classification under `qm.news_impact_mapping.v1`.

`news_calendar_2015_2025.csv` is **retained as an audit trail**. It is not
deleted, not degraded, and stays available for provenance and historical
reconstruction — but it is not a gating source for impact-sensitive
decisions.

This satisfies §3's "exactly one source" rule for impact-sensitive gating.

## Scale of the divergence this settles

- 47,565 events common to both files
- 41.7 % disagree on impact classification
- 25.5 % are High / Not-High flips — i.e. they change whether an event gates
  at all

The size of that second number is the reason this could not be an
engineering call: a quarter of the common events flip the binary that the
news filter actually acts on.

## What this decision does NOT do

- It does **not** retroactively invalidate pipeline verdicts already
  rendered. Per §14 of the contract, V1-shaped evidence stays valid as a
  historical record; it merely may not be treated as equivalent to V2
  evidence in any *new* comparison or admission decision.
- It does **not** change Q09 adjudication states
  (`CONFIG_LOCKED` / `REVIEW_REQUIRED` / `INVALID_EVIDENCE`,
  `q09_news_contract.py`). This is a semantics-layer lock underneath that
  adjudication layer.
- It does **not** unblock implementation on its own. See below.

## Implementation gate — still closed

Router task `84c988e6` (SP-B2) is gated on **two** conditions, and OWNER's
ratification satisfies only the first:

1. `OWNER-DEC-NEWS-MAPPING` decided — **met, 2026-08-22**.
2. Q09 rerun complete — **not met**. The pilot is running
   (`ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2`, Q09_NEWS, QM5_11294/XAUUSD.DWX,
   claimed by T4) under the repaired runner.

Codex held this correctly and must continue to hold it. Unblocking on the
OWNER half alone would re-label news semantics underneath an in-flight
measurement — exactly the failure the double gate exists to prevent.

Codex's own hold verdict on `84c988e6`, quoted for the record:

> BLOCKED (korrektes Gate-Honoring): SP-B2 wartet auf OWNER-DEC-NEWS-MAPPING
> + Q09-Rerun-Abschluss; Vorarbeit committed (403be708f) ohne
> Shared-Data-Mutation.

## Classification

ROT — gate data semantics. This is why it was never decided autonomously and
why the implementation stays fail-closed behind the second gate.

## Evidence

- Spec and decision template: `docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md` §3, §4, §14, §15
- Consulting audit §6 F-03 / §14 S-05 / §15 (Google Drive fileId `1TlfBZ2FoYLgfxTjiNiGeGhIxQjV0xG54`)
- Pre-work already committed without shared-data mutation: `403be708f`
- Two-file pair with no precedence rule (the defect this closes):
  `tools/strategy_farm/news_calendar_gate.py:45-47`
- Current unversioned impact rank: `framework/scripts/p8_news_driver.py:254,275`
