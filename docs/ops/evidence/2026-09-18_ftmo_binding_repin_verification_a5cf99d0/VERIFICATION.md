# Router ticket a5cf99d0 — independent verification (session-race convergence)

Session: `agents/claude-orchestration-1`, single-pass cycle, 2026-09-18.

## Finding: the fix already exists, is tested, and is merged

While investigating `tools/strategy_farm/ftmo/trial_setpath.py:load_binding()`
(the payload's cited `policy_config.py` does not define `load_binding` — the
function lives in `trial_setpath.py`), I found that a parallel session had
already router-ticketed the same defect (`a5cf99d0`), implemented, tested and
committed the fix on branch `agents/fable-ftmo-binding-20260918`
(commit `a2b5e47d87`), and that commit is **already merged into
`agents/board-advisor`** (merge commit `4f92aedd40`, present in this
canonical checkout `C:/QM/repo` at cycle start). This is another instance of
the known duplicate-session-routing defect (see prior memory entries on
router-ticket collisions) — two sessions received the same ticket.

No fix was duplicated here. This artifact is an independent readback/re-run
of the existing fix and receipt, not a new patch.

## What the existing fix does (verified by reading + re-running, not by trust)

- Root cause: `load_binding()` pinned `sha256` of several bound files
  (account-terms evidence, the Standard rulepack, two QM5_13206 governor
  presets) over **raw on-disk bytes**. `core.autocrlf` smudges those bytes
  differently per working tree/clone, and the pins were not even internally
  consistent about which byte-stream (LF vs CRLF) they described — so the
  binding could refuse in every checkout simultaneously
  (`account_terms_evidence_hash_drift`, `rulepack_file_hash_drift`).
- Fix: `tools/strategy_farm/ftmo/binding_hash.py` — one shared
  `content_sha256()` that normalizes CRLF/CR → LF before hashing (except
  UTF-16 payloads, hashed verbatim to avoid corrupting `CR NUL LF NUL`).
  `trial_setpath.py`, `governor_rebind`, and
  `ftmo_book3_standalone_evaluator.py` now share this one definition instead
  of each hashing raw bytes independently.
- Defense in depth: `.gitattributes` gained `-text` for the three previously
  unprotected files (account-terms evidence, both governor presets); the
  rulepack and the binding file itself already carried `text eol=lf`.
- Re-pin: only the two governor-preset pin *values* changed
  (`c189004f…`→`15c18dc4…`, `85373094…`→`f7345341…`); the receipt at
  `docs/ops/evidence/2026-09-18_ftmo_binding_repin/repin_proof.json` proves
  both new values are the sha256 of the exact same committed LF blob, i.e.
  line-ending-only changes, zero rule-content drift.
- Also fixed (not a line-ending issue): a stray `rulepack_file_sha256_note`
  key inside `binding.evaluator` (added by an unrelated commit) was breaking
  `load_binding()`'s exact 5-key dict-equality check; moved to a top-level
  `notes` list.

## Independent re-run of the evidence (this session)

1. `python -m pytest tools/strategy_farm/tests/test_ftmo_binding_pin_line_endings.py -q`
   run **in the originating worktree**
   (`C:/QM/worktrees/fable-ftmo-binding-20260918`, clean, HEAD = `a2b5e47d87`):
   **11 passed** — matches the commit message's claim exactly.
2. `python -m pytest tools/strategy_farm/tests/test_ftmo_trial_setpath.py -q`
   in the same worktree: **18 passed, 2 failed**. Both failures are the
   documented, deliberately-out-of-scope `wrong_rulepack` refusal
   (`binding.rulepack.as_of=2026-09-04` vs the rulepack's own
   `as_of=2026-09-15`; also hard-coded in
   `ftmo_book3_standalone_evaluator.py:840`). This is a gate/contract-criterion
   choice (**ROT** under the Stehende Vollmacht), not a hashing defect, and is
   correctly left to a separate OWNER decision.
3. Re-ran the same two suites **in this canonical checkout**
   (`C:/QM/repo`, branch `agents/board-advisor`, which already has the merge):
   the line-ending suite showed **5 of 11 failing**, all with
   `rulepack_file_hash_drift`/downstream refusals instead of the expected
   fixture refusals. Traced this to **pre-existing, unrelated, uncommitted
   local drift**: `git diff` on
   `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json`
   shows only `rebound_at_utc` bumped from `2026-09-15T14:00:00Z` to
   `2026-09-18T00:04:45Z` — a live write from the freshness-tracking process
   (`rules_snapshot.py`) that stamps this field, not a defect in the fix. The
   sibling session's own receipt (`RECEIPT.md`, "Existing working trees"
   section) explicitly calls this out and excludes it from the re-pin, i.e.
   this session's re-run reproduces exactly the caveat the original author
   already documented. This is real, legitimate content mutation in a
   different, unrelated process's write path — not something to revert here,
   and not evidence against the fix.

## Verdict

Ticket a5cf99d0's actual defect (hash pins not portable across
`core.autocrlf` checkouts) is **fixed, tested, and already merged** into
`agents/board-advisor` via commit `a2b5e47d87` / merge `4f92aedd40`. No
further code change is needed from this session. Two items remain, both
explicitly out of this ticket's scope and already flagged by the original
fix's own receipt:

- `wrong_rulepack` (binding `as_of` vs rulepack `as_of` disagreement) —
  ROT, needs an OWNER decision on which `as_of` is authoritative.
- The canonical checkout currently carries an unrelated uncommitted
  `rebound_at_utc` freshness-stamp write; whoever owns `rules_snapshot.py`'s
  write cadence should commit or reconcile it independently of this ticket.

Recommend closing this router ticket rather than routing it again.
