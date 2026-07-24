# Needs OWNER (Fabian)

_As of 2026-07-24. Anything in the source-harvest finalization that is unreadable, was not fully processed, or raises a question only OWNER can settle._

## Bottom line

**Nothing blocking.** All 127 harvested PDFs are classified into 143 ledger rows (cross-checked: 127 inventory PDFs = 127 distinct `source_file` values = 127 `ledger_parts` working notes; zero missing classifications, no agent left a gap). Dedup (5 clusters) and eligibility are deterministic per Q00 R1–R4. The items below are informational / optional future harvest, not gates.

## Capture-quality flags (both mitigated)

- **STR-005 · ff_110278.pdf** — captured with **0 posts** (empty ForexFactory thread). No entry/exit content; correctly REJECTED. The thread URL (110278) may be dead/expired. Re-capture only if OWNER knows the thread is worthwhile — otherwise drop; low value.
- **STR-093 · forex-sma-20151009.html.pdf** — capture returned a **Cloudflare block page** instead of the article; correctly REJECTED. **Mitigated:** the same BabyPips 'art-of-automation' SMA-crossover-pullback post was captured cleanly as `www.babypips.com_blogs_art-of-automation_forex-sma-20151009.html.pdf` (STR-142, ELIGIBLE) and folded into dedup **CL-04**. No information lost.

## Referenced-but-not-captured companion sources (optional future harvest)

These threads point at material outside the captured PDFs. None is required to finalize the ledger; harvest only if the parent candidate is later prioritized for a build.

- **STR-031 (AshFX V2)** — full AO/AC/Stochastic entry confluence lives in companion thread **156889**, not in the captured PDF; only exit/MM params were captured.
- **STR-007 (Sonic R)** — PVSRA and 'Scout' trade detail exist only in externally-linked PDFs, not the thread capture.
- **STR-015 / STR-039 / STR-099 (meta threads)** — repeatedly reference the 'Trading Made Simple' (TMS) 7000+-page thread and other external systems that were not part of this harvest scope.

## Open questions

- None require an OWNER decision. Whether to build any of the un-built ELIGIBLE candidates (`overlaps_existing = none`) is a routine capability-router / pipeline call, not a money-gate or hard-rule question.
- One HIGH-priority row (**STR-086, DIBS**) is already built (ff-dibs-breakout, FAILED Q04); flagged 'no rebuild'. Confirming that is a pipeline judgment, not an OWNER gate.
