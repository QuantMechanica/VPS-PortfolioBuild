# Point 1.13 — `supersedes` is fragmented across five encodings, not missing; and the newest supersessions use none of them

v6 §6 1.13 states the supersession is *"heute **nur menschenlesbar**: kein Feld, keine Tabelle"*, and
makes it a precondition for 2.2: *"Das Screening in 2.2 kann abgelöste Zeilen nicht ausschließen,
wenn die Ablösung unsichtbar ist."*

**Inventory first: the premise is half wrong, and the real defect is worse than a missing field.**

## There is no table and no column — but there are 30,589 payloads mentioning it

| | |
|---|---:|
| tables named `*supersed*` | **0** |
| `work_items` columns named `*supersed*` | **0** |
| `work_items` rows whose payload mentions "supersed" | **30,589** |
| `events` rows mentioning it | 81 |

So the data exists. What is missing is a *canonical form*. Five incompatible encodings are in use:

| encoding | rows | carries |
|---|---:|---|
| `superseded_by_work_item_id` | 87 | a work_item UUID — the usable one |
| `superseded_by` | 29 | **an agent name** (`"codex-headless-board-advisor"`) |
| `superseded_at_utc` + `superseded_reason` + `superseded_scope` + `superseded_by_logical_symbol` + `prior_status_before_supersede` + `prior_verdict_before_supersede` | 21 each | the basket-consolidation family |
| `repair_history[].superseded_by_label` + `superseded_at` | 2 | a *label*, not an id |
| event `superseded` | 2 | — |

**`superseded_by` means two different things.** In one family it is a work_item id; in another it is
the agent that performed the supersession. A consumer joining on that field mixes rows and
identities silently — the same failure shape as a key-format mismatch, and just as invisible.

## Positive control: today's hedge supersessions are machine-invisible

The brief asks for a control on the hedge rows. It fires:

| row | EA / symbol | verdict | supersede marker |
|---|---|---|---|
| `ffcc2666` | QM5_21506 / XAUUSD | **PASS** | **none** |
| `9eda802e` | QM5_21507 / XAUUSD | **PASS** | **none** |
| `6d4af788` | QM5_21513 / NDX | **PASS** | **none** |

All three were produced by binaries rebuilt minutes later (19:26:34 / 19:27:04 / 19:27:32) to repair
the non-atomic reversal defect. The supersession is recorded in
`docs/ops/evidence/9ecec938_qm5_21506_21507_21513_atomic_reverse_repair_2026-08-17.md` and **nowhere
in the database**. An automated consumer sees three clean PASS rows.

So the newest supersessions use *none* of the five encodings — they are evidence-only. The trend is
away from machine-readability, not toward it.

## Stake in 2.2, measured

| | |
|---|---:|
| pool pairs (2.2 union) | 91 |
| **pool pairs carrying a supersede marker on some row** | **17** |
| hedge pairs in the pool | **0** |

The hedge case does not touch the current pool — that is luck, not design. But 17 of 91 pool pairs
have supersession history that 2.2 must interpret, and it cannot do so uniformly while one field
means two things and the newest cases are unmarked.

## What the fix has to be, given the inventory

Not "invent a mechanism". Three things:

1. **One canonical relation** — a `supersedes` table or a single reserved payload key whose value is
   always a work_item id, never an agent, never a label.
2. **A back-fill** mapping the five existing encodings onto it, with the ambiguous `superseded_by`
   disambiguated by value shape (UUID vs agent name) rather than by guessing.
3. **A write path**, so a supersession recorded in evidence also lands in the database. Without it
   the back-fill decays immediately — today's three hedge rows would already be missing from it.

The positive control for the fix is fixed in advance: after the back-fill, those three hedge rows
must be marked, and querying "superseded rows in the 2.2 pool" must return a number that a human can
reconcile against the evidence documents.

## Correction to my own earlier reporting

I wrote in several earlier rounds that supersession is *"machine-invisible — no field, no table"*.
That is right about the schema and wrong about the data: 87 rows carry a usable work_item pointer
today. The accurate statement is that there is no canonical form, one field is ambiguous, and the
most recent supersessions are unmarked.

## Evidence

- `work_items.payload_json` key census over 4,000 sampled matching rows
- `events` where `event LIKE '%supersed%' OR detail_json LIKE '%supersed%'`
- hedge rows `ffcc2666`, `9eda802e`, `6d4af788`; repair evidence `9ecec938`
- pool: `artifacts/pool_union_20260817.json`, 91 members
