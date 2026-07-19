# Proposed coordination issue — SRC09 EURUSD SessionFlow review

## Requested issue

Title: SRC09 — Breedon and Ranaldo (2013), Intraday Patterns in FX Returns and Order Flow

Parent owner: CEO / OWNER

Assignee: Research for extraction closeout, then CEO + Quality-Business + CTO for the single-card review.

## Approval basis

OWNER explicitly wrote on 2026-07-17: "alles freigegeben, los gehts!"

The source had previously been proposed in the FTMO Challenge EA target book. This packet records the approval locally because no Paperclip interaction tool is available in the current workspace.

## Artifacts

- Source record: strategy-seeds/sources/SRC09/source.md
- Single extracted card: strategy-seeds/cards/fx-session-flow_card.md
- Target book: docs/research/FTMO_CHALLENGE_EA_TARGET_BOOK_2026-07-17.md

## Independent review verdict

Quality-Business returned `CHANGES_REQUIRED` on 2026-07-17. Source fidelity and duplicate adjudication passed. The OWNER then delegated terminal technical approval; the card v2 resolves the changes and is now `APPROVED`. This file is the local approval record because no Paperclip connector is available.

## Review decisions resolved

1. SRC09 is confirmed locally; absence of a Paperclip connector is recorded rather than hidden.
2. CTO ratifies an EA-local reviewed London-DST helper, 2017-2026 UK/US transition fixtures, and the exception from generic Friday flattening; the custom 16:00-New-York exit retries until flat.
3. Prior D1 ATR(20) times 1.0 is ratified as the non-alpha baseline stop, with the seven-cell Q03 sensitivity frozen before holdout; risk is 0.25 percent per leg and at most 0.50 percent planned family risk per day.
4. P2 uses native Model-4 bid/ask ticks, an entry-only 30-point ceiling, the dated FTMO commission/swap snapshot, and predefined 2x execution-cost stress. Source-faithful no-quote handling is used; no runtime calendar.
5. Resolve the linter conflict: the revised card now passes `skill_g0_card_lint.py`, while `skill_card_schema_lint.py` still demands obsolete `Hypothesis/Rules/Risk` headings that are absent from the canonical template.
6. OWNER-delegated CEO/CTO issues terminal APPROVED after independent Quality-Business changes; sequential production EA ID 4006 and EURUSD.DWX slot 0 are allocated.
7. Confirm that QM5_10012 remains a separate, slot-selected near-duplicate and is not silently reused as the new source implementation.

## Sequencing guard

Baltussen/van Bekkum/Da MAC5 extraction may proceed because this source's only card now has a terminal verdict. Build and pipeline remain evidence-gated. No deployment, Challenge purchase, or AutoTrading change is authorized by this approval record.
