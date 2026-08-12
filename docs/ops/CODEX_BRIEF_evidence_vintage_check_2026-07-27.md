# Codex brief — is today's 9936 still the 9936 our numbers were measured on?

Date: 2026-07-27
Priority: highest. This questions the foundation of every figure produced today.

## Why this matters more than any single EA

Every FTMO number this week rests on Q08 trade streams under
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/` — FUND_SCORE 0.41 and then 0.641,
the 35 Q09-passing runner+satellite sets, the 35.7% single-account pass rate, the whole
sleeve ranking. Those streams were produced by binaries of a particular vintage.

The adversarial review of the multi-symbol effort raised this as a HIGH confirmed finding:
the Step-1 fidelity gate validates **today's** 9936, not the 9936 the book was measured
on. Separately, the fidelity diagnosis established that the gated 9936 reference binary is
from **2026-07-14** (`.ex5` SHA `a1de7a7b…`) while a 2026-07-27 compile produced
`c29da61f…` (`docs/ops/evidence/2026-07-27_joint_ea_fidelity_diagnosis.md`).

The framework has changed since July 14 — including a prop-firm phase section added today
(`framework/include/QM/QM_PropFirm.mqh`) whose author asserts default behaviour is
unchanged for EAs that do not opt in. **That assertion has never been tested against a
real strategy's trade stream.** This task tests it.

## The question, stated precisely

Does the CURRENT source tree, compiled today, produce a **functionally identical** trade
stream to the archived one, for the same EA, set file, symbol, window and tick model?

Byte-identical `.ex5` files are not the test — compiler output can differ harmlessly.
**Functional equivalence of the trade stream is the test.**

## Method

1. Pick QM5_9936 / USDJPY.DWX as the primary subject: it is the runner, it carries the
   book's entire drift, and its archived stream is the most load-bearing artifact we have.
2. Establish the archived stream's provenance: which work item produced
   `9936_USDJPY_DWX.jsonl`, which set file, which window, which tick model, which `.ex5`.
   If any of that cannot be established, say so — an unreproducible provenance is itself
   the finding.
3. Compile QM5_9936 from the current tree and re-run it on **exactly** that set file,
   window and tick model.
4. Diff the new trade stream against the archived one, trade by trade. Report:
   - the match rate;
   - the mismatch decomposition (same entry / same volume / shifted exit, versus different
     entry, versus extra or missing);
   - and the deltas that actually matter: total net P&L, trade count, `med60`, `|wDay|`,
     `wDD_p90` and **FUND_SCORE**.
5. If they diverge, **bisect to the cause.** The framework's git history since 2026-07-14
   is the search space. Name the commit and the mechanism. Do not stop at "something
   changed".
6. Then answer the general question: **are the archived streams still a valid basis for
   the book's numbers, or must they be regenerated?** If regeneration is needed, estimate
   the tester cost for the 15 gate-clean sleeves.

## What this is not

- Not a defect hunt in QM5_9936. A divergence is expected to come from the framework, not
  the strategy.
- Not a licence to change anything. This is a measurement. If the current tree behaves
  differently, that is reported, not fixed here.
- Do not "correct" the archived stream. It is evidence.

## Constraints

- Reserve a terminal (`farmctl.py reserve-terminal <T> --by codex --minutes <n> --reason
  "evidence vintage check"`) and release it when done. **Never T5**, never
  `C:/QM/mt5/T_Live`. ~2,000 items are queued; do not squat.
- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`. Do NOT re-import `.DWX` history.
- Do NOT modify the gated EA, its set files, or any archived stream.
- Do not invent commission, swap or DST values — match the archived run's cost model
  exactly and prove you did.
- Commit with explicit pathspecs.

## Deliverable

`docs/ops/evidence/2026-07-27_evidence_vintage_check.md`: the archived stream's
provenance, both `.ex5` SHA256 values, the trade-level diff, the metric deltas including
FUND_SCORE, the bisected cause if they differ, and a plain verdict on whether the book's
numbers still stand.
