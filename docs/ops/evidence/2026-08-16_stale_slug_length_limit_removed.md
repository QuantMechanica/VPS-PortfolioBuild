# Stale slug/folder length limit removed from the build contract (2026-08-16)

## What the contract said

`qm-build-ea-from-card` (SKILL.md, section 2) required:

> Slug is lowercase kebab-case, ≤ 16 chars. Compiled MT5 EA name (folder name)
> must be ≤ 32 chars.

## Why it is false

Measured against the actual fleet on 2026-08-16:

- **948 existing EA folders exceed 32 characters**; the longest is 64.
- `QM5_32003_cl-pit-open-volatility-breakout` has a 31-character slug and a
  41-character folder name. It was built, deployed to terminals, ran real-tick
  Model-4 backtests, passed Q02 and produced an economic Q04 verdict. Nothing
  in the report parsing, tester ini, logger path or evidence stream failed.

A limit that the entire fleet violates, while the pipeline runs on it daily, is
not a constraint — it is a stale line in a document.

## What it cost

The limit produced at least two false build blocks:

1. `9e872ce2_turn_of_month_index_build_preflight_2026-07-17.md` — one of four
   FAIL rows was "Slug is 24 characters (limit 16)".
2. `1cfde12d_century_batch1_build_preflight_2026-08-16.md` — batch 1 of the
   Century Suite build programme aborted with all five identities failing both
   limits. Measured afterwards: **all 77 clean Century EAs violate it**, so the
   entire programme was unbuildable on a rule the fleet already ignores.

The blocking agent was right to stop: its contract said so, and silently
shortening a slug would break the required card/registry/folder slug equality.
The defect was in the contract, not in the refusal.

## Change made

The two limits were replaced with guidance rather than a gate:

> Slug is lowercase kebab-case and descriptive. NOTE 2026-08-16: the former
> ≤16-char slug / ≤32-char folder limits were REMOVED as empirically false …
> Keep slugs reasonably short for readability, but do not reject a build on
> length alone.

File: `C:\Users\Administrator\.codex\skills\qm\qm-build-ea-from-card\SKILL.md`
(agent skill home, not repo-tracked).

## What was NOT changed

- Card / registry / folder **slug equality** remains mandatory. A slug may be
  long, but it must be identical in the approved card, `ea_id_registry.csv`,
  the folder name and the `.mq5` filename.
- No card, registry row, EA source or work item was mutated by this correction.

## Follow-up

Century Suite batch 1 is re-filed. If a genuine length constraint is ever
discovered (for example in a report-path or tester-ini field), it must be
re-introduced **with the failing evidence attached**, not as an unsourced
number.
