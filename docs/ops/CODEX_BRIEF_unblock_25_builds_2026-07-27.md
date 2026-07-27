# Codex brief — unblock the 25 EA builds that failed preflight

Date: 2026-07-27
Priority: high. This is 25 potential sleeves, and sleeve supply is the binding constraint.

## Where these came from

`tools/strategy_farm/batch_coder.py` used to insert `agent_tasks` directly at
`state='REVIEW'` with a hardcoded verdict — "PASS: Auto-generated structural MQL5
skeleton for <ea>. Inputs mapped from YAML. Core entry logic pending." — under a comment
that said "Insert task into DB to satisfy the router cockpit". On 2026-07-25T23:30:29 it
seeded 25 such rows in one second, for files that existed nowhere in the tree, on HEAD,
or on `origin/main`.

That generator was fixed on 2026-07-27 (commit `d5d0879a5`): it now inserts at
`BACKLOG` with a NULL verdict. The 25 rows were requeued so they would be genuinely
built. You then correctly refused all 25 at preflight:

> `BLOCKED_PREFLIGHT`: zero governed magic rows; card body incomplete

That refusal was right and is why this brief exists — the work is real, it just has
unmet upstream requirements. The tasks are now in `BLOCKED` state carrying that verdict.

## What blocks them

Two distinct upstream gaps, in this order:

1. **Incomplete strategy card bodies.** Cards are the governed source of an EA's
   strategy. A card whose body does not carry the required content cannot produce a
   faithful EA. Note the known validator traps: the body scan requires a *literal*
   timeframe token (frontmatter does not count), and `approve-card` requires the year
   and DOI in the flowing text.
2. **No governed magic rows.** Magic numbers follow `ea_id*10000+slot` and must be
   registered through the governed path in strict order: **directories first, then CSV,
   then regenerate, then verify, then compile.** Builds must be **serial** — the magic
   resolver has a known race, and duplicate build dispatch has previously produced magic
   collisions. When checking whether an id exists, grep anchored on `^<bare_id>,` — an
   unanchored grep matches substrings and has caused false negatives before.

## What to do

1. **Triage first, do not bulk-fix.** For each of the 25, establish which of the two
   gaps applies and whether the card is salvageable at all. Some may be duplicates of
   existing EAs, or ideas that never had a real source. Report a table: ea_id, slug,
   card path, what is missing, and a disposition of FIXABLE / NEEDS-SOURCE / RETIRE.
2. **Fix what is genuinely fixable** through the governed paths only. Never edit an
   approved card in place to make a validator pass — that is the failure mode that got
   QM5_20160 recycled today.
3. **Register magic rows** for the fixable set, in the documented order, serially.
4. **Do NOT build them all.** Once unblocked, hand them back to the normal build lane.
   Bulk-building 25 EAs would flood a queue already holding ~2073 pending work items.
5. Where a card cannot be completed from its recorded source, mark it RETIRE with the
   reason. An EA with an invented strategy is worse than no EA.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- Do NOT touch T5 (under repair) or T9 (reserved for a joint backtest), and never
  `C:/QM/mt5/T_Live`.
- Builds serial, never parallel.
- Commit with explicit pathspecs. Evidence over claims.

## Deliverable

`docs/ops/evidence/2026-07-27_unblock_25_builds.md` with the triage table, what was
fixed, what was retired and why, and the magic rows registered.
