# CODEX BRIEF 2026-08-02 — book-candidate admission repair programme (OWNER-directed)

**Scope widened by OWNER 2026-08-02 („geh den gesamten Reparaturaufwand an!"):**
this ticket covers the **entire shortlist**, not only 11422. Build the tooling
once, then deliver the ordered command list per candidate:

| Priority | Candidate | First required repair (per the adjudication) | Est. terminal cost |
|---|---|---|---|
| 1 | `11422/USDCAD` | append-only current-binary Q02, then Q03→Q10 | 2–4 h |
| 2 | `13013/NDX` | **already supported** — Q04 append-only rerun (Claude starts it now), then Q05→Q10 | 1.5–3 h |
| 3 | `13036/GDAXI` | candidate-specific Q03, then rebind Q04→Q10 | 2–4 h |
| 4 | `20048/XTIUSD` | reserve — full chain stale, Q04 only `PASS_SOFT`; sequence it last | 2–4 h |

Everything below was written for 11422 and applies unchanged to all four: the
tooling is shared, the honesty conditions are identical, and each chain stops at
its first non-pass. Report per candidate separately so one dead chain does not
obscure another's result.

---

## Original brief (11422 as the worked example)

**Author:** Claude. **Implementer:** Codex (Sol, effort max). **Reviewer:** Claude.
**Authority:** OWNER 2026-08-02 („passt, dann geh das in diese Richtung an!"),
following the approved adjudication
`docs/research/BOOK_EXPANSION_CANDIDATES_2026-08-02.md`, which ranked
`11422/USDCAD` first: the only candidate that opens a symbol the book does not
trade **and** improves it (ΔSharpe +0.0292, max regime correlation 0.0628,
+0.3156 %/yr, DD change inside the neutral band).

**Hard constraints:** factory keeps running; no T_Live contact; no manifest,
baseline or deploy change; no admission decision (that stays Claude review +
OWNER); explicit-pathspec commits. Enqueues: see the gating rule below.

## Why this needs tooling first

The adjudication established honestly that **no supported command repairs this
lineage today**: 11422's Q02–Q08 evidence predates the current binary, its
current `Q09_NEWS` row is a `PENDING_RUNNER` placeholder rather than an
evidence-bearing `CONFIG_LOCKED` predecessor, `--phase Q03` is rejected because
Q03 is not a cascade phase, and the append-only exact-row rerun helper accepts
only terminal `INFRA_FAIL` source rows — not stale `PASS` rows. Inventing a
broad-fanout substitute would burn machine time without proving this lineage.

## Build

1. **Append-only stale-evidence rerun path.** Extend the existing exact-row
   rerun mechanism so a *stale-but-terminal* source row (current-binary
   mismatch, verdict `PASS`) can seed an append-only rerun, under the same
   contract that governs the INFRA_FAIL path: historical row preserved
   untouched, payload stamped with `append_only_rerun_of_work_item`, an
   explicit `rerun_reason`, exact predecessor binding, and refusal when the
   predecessor identity does not match on ea/symbol/setfile. Add an explicit
   staleness proof requirement: the caller must supply the expected current EX5
   hash, and the tool must verify it against the repo binary before enqueueing.
2. **Candidate-specific Q03 (and any other non-cascade gate the chain needs).**
   Provide a supported way to enqueue exactly one identity's Q03 bound to the
   current binary, without a broad fan-out. If the cleanest shape is a flag on
   the existing enqueue path rather than a new command, argue for it.
3. **Q09 news-config predecessor.** Determine what turns a `PENDING_RUNNER`
   `Q09_NEWS` row into an evidence-bearing `CONFIG_LOCKED` one, and make that
   step invocable per identity. If it requires a runner that does not exist,
   say so instead of faking the state.
4. **Tests** for every refusal path: wrong EX5 hash, non-matching predecessor,
   non-terminal source row, broad-fanout attempt, and double-enqueue.

## Then, and only then

Produce the exact ordered command list for `11422/USDCAD` — Q02 (current
binary) → Q03 → Q04…Q08 → Q09 news config → hash-bound Q10 — with a machine-time
estimate per step and the explicit rule **stop at the first non-pass**. Do not
run them: Claude enqueues after reviewing the tooling, one gate at a time,
so a failing gate ends the effort instead of consuming the whole chain.

A `FAIL` at any gate is a complete and welcome answer — it means the candidate
does not deserve a book slot, which is worth knowing cheaply.

## Deliverable

`docs/ops/evidence/2026-08-02_11422_repair_tooling.md`: what was built, verbatim
test output, the ordered command list with estimates, and a plain statement of
anything that still cannot be done honestly. Router task → REVIEW.
