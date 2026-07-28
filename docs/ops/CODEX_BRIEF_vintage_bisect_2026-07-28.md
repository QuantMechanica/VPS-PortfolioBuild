# Codex brief — bisect the 9936 vintage drift: what did we change, and why does it move trades?

Date: 2026-07-28
Priority: highest. OWNER's decision rule: "wenn wir das Framework verändert (und
vermutlich verbessert) haben, dann sollten wir eher die Tests wiederholen. Finde
heraus, was wir verändert haben und warum es die Trades beeinflusst, dann entscheiden
wir weiter!"

## The fact to explain

Same EA, same set file, same window, same tick model, compiled 2026-07-27 vs the
archived stream produced by the 2026-07-14 vintage:

| comparison | exact | shifted exit | different entry | missing | match |
|---|---:|---:|---:|---:|---:|
| fresh 9936 vs archive (common window 2018-07-02..2025-12-31) | 1,046 | 72 | 25 | 109 | **0.835463** |

(`docs/ops/evidence/2026-07-27_multisym_step1_EXECUTED.md`.) The joint EA is exonerated:
it matches the fresh standalone at 1.000000. Something in the framework tree between
2026-07-14 and 2026-07-27 changed 9936's behaviour: ~9% of archived trades no longer
happen, 25 entries differ, 72 exits shift.

## Method — do it the cheap way

1. **Build the true suspect list by CONTENT, not by commit message.** The pump has
   demonstrably swept hand-authored framework source into `build: pump auto-commit`
   commits (the 383-line QM_PropFirm.mqh rewrite sits in `a35c08338`, not in its
   feature commit). So: `git log --since 2026-07-14 -- framework/include/QM/` and keep
   every commit whose DIFF touches `.mqh` content that 9936's compile actually
   includes (trace its include graph: QM_Common, QM_Entry, QM_RiskSizer, QM_News,
   QM_TradeManagement, QM_KillSwitch, QM_EquityStream, indicators, ...). EA-only
   commits (new QM5_201xx sleeves) cannot affect 9936 and drop out. Expect the real
   list to be ~10-15 commits, not 163.
2. **Read before running.** With the mismatch decomposition in hand (109 missing
   entries + 25 different entries + 72 shifted exits), the mechanism has a shape:
   something now SUPPRESSES ~9% of entries and shifts some exits. Read the suspect
   diffs with that shape in mind - news/calendar handling, session/bar gating, spread
   or freeze-level checks in the entry path, kill-switch, equity-stream hooks, the
   prop-firm section's default path (its author claims default-unchanged; that claim
   is now under direct test - 9936 does not opt in). If one diff plainly explains the
   signature, say so and verify with ONE run instead of a full bisect.
3. **Bisect with SHORT windows.** Full runs cost ~100 min; a bisect probe does not
   need the full window. From the comparator output identify the EARLIEST divergent
   trade in the common window, pick a 3-6 month window bracketing a dense cluster of
   divergences, and confirm the short window still reproduces a clean
   archive-vs-fresh mismatch on those dates. Then binary-search the suspect commits
   with short-window runs: ~log2(N) runs at 10-20 min each. Compile each probe from
   the checked-out historical tree in its own session; record every .ex5 SHA256.
4. **All runs through the governed queue** (the ad-hoc path has failed four times to
   worker reclaim; the progress-aware reaper is live so queue runs survive). Priority
   high; each probe is small.
5. **Name the commit and the mechanism.** "Something changed" is not an answer.
   State: the commit, the file:line, WHY it changes entries/exits, and whether the
   change was an intentional improvement (e.g. one of the audited framework fixes) or
   an accident.

## The decision this feeds

OWNER's rule: if the change is an intentional improvement, the TESTS get repeated
rather than the change reverted. So finish with:

- **Intentional or accident**, with the evidence.
- If intentional: the regeneration bill - which archived streams are invalidated (at
  minimum the 15 gate-clean sleeves), and the tester cost to regenerate them through
  the governed queue.
- If accident: the minimal revert and what it would restore.
- Either way: whether the archived streams' FUND_SCORE/composition conclusions
  (0.641, the 35 Q09 sets) are directionally robust to the drift or must be treated
  as void until regeneration. Check by computing FUND_SCORE components on the FRESH
  9936 stream and comparing against the archived one - that single comparison says
  whether the drift moves the metrics that matter.

## Constraints

- Do NOT run Factory_OFF/ON; never T5, never T_Live; no .DWX re-imports.
- All probes via the governed queue. Serial compiles, SHA256 recorded per probe.
- Do NOT revert anything in the working tree - historical probes are built from
  checkouts/worktrees, the current tree stays as it is until OWNER decides.
- Explicit pathspecs; evidence over claims; NOT ESTABLISHED over inference.

## Deliverable

`docs/ops/evidence/2026-07-28_vintage_bisect.md`: the content-filtered suspect list,
the identified commit + mechanism with file:line, intentional-vs-accident, the
FUND_SCORE drift check on the fresh stream, and the regeneration bill or revert
recommendation.
