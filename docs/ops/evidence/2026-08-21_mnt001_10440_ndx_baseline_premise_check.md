# MNT-001 — 10440/NDX KS baseline: premise check (no baseline generated)

**Date:** 2026-08-21
**Router task:** f421b62a-277b-421a-b638-33e6d8568bcd (priority 77, ops_issue)
**Authority cited on the ticket:** OWNER decision 2026-08-21, "wir folgen immer der Empfehlung" on MNT-001 — generate the baseline from Q10 evidence and stage it file-side.
**Recorder:** Claude (agents/board-advisor)

## Instructed work

Generate the KS dormancy baseline for EA 10440 / NDX from its canonical Q10
full-history evidence, stage it under `D:/QM/reports/state/q10_baselines_staging/`
with a deploy manifest carrying SHA256 of every file, and hand over for
verification (no self-certify, no live deploy, no AutoTrading touch).

## Finding: the premise is wrong — stopping per ticket constraint

> "if the premise turns out to be wrong, say so and stop -- do not invent work
> to fill the ticket"

10440/NDX has exactly **one** Q10 attempt on record, and it is a **FAIL**, not
a PASS:

- Run: `20260725_163009`, work item `bdfdd179-3801-492c-b3c0-2a5a163d16a4`,
  window 2017.01.01–2025.12.31 (full history, model 4/real-tick, H1), 490 trades.
- Report (would-be generator input): `D:\QM\reports\pipeline\QM5_10440\20260725_163009\raw\run_01\report.htm`
- Aggregate: `D:\QM\reports\pipeline\QM5_10440\Q10\NDX_DWX\aggregate.json`
- **Verdict: FAIL** — max drawdown 31.00579% exceeds the 25.0% Q10 gate
  (profit factor 1.07 does pass, drawdown does not).
- The Q10 EX5 hash (`efb71824...`) also differs from the last published live
  binary (`b71d3029...`) — an additional reason this isn't "the" canonical
  artifact even setting the verdict aside.
- This is consistent with the 2026-08-02 adjudication
  (`docs/ops/evidence/2026-08-02_ks_deploy_execution.md`,
  `decisions/2026-08-02_t_live_ks_recompile_deploy.md`), which left 10440 as
  the one baseline-uncovered sleeve **by design**, pending either a Q10 PASS
  or retirement — not an oversight to be silently closed.

A KS dormancy baseline exists to characterize the canonical *passing* trade
distribution so live drift can be measured against it. Generating one from a
failed Q10 run would stage a baseline that doesn't represent anything the
sleeve is entitled to trade against, and would make `chk_ks_baseline_dormancy`
read 24/24 by manufacturing coverage rather than by the sleeve actually
qualifying. That is the "economic verdict laundered into an infra green"
failure class this shop has been burned by before.

## What was and wasn't done

- No baseline file was generated or staged.
- No files were written to `D:/QM/reports/state/q10_baselines_staging/`.
- No live/Common baseline directory was touched.
- AutoTrading / T_Live: untouched, as required.
- Only this evidence doc was written.

## Recommendation (for OWNER decision, not self-executed)

Two legitimate paths, neither of which this ticket authorized me to pick:

1. **Retire 10440/NDX** from the 24-sleeve live book (update the signed
   manifest `portfolio_manifest_live_24sleeve_20260724.json` to 23 sleeves,
   with OWNER sign-off) — `chk_ks_baseline_dormancy` would then correctly read
   23/23 loaded_ok instead of a manufactured 24/24.
2. **Re-run Q10** for 10440/NDX (fresh full-history run against the current
   compiled binary) and, only if it PASSes the drawdown gate, generate the
   baseline from that passing run.

Recommend OWNER pick one of the two above; this ticket's "generate from Q10
evidence" instruction presumed a PASS existed, which it does not.

## Verification

- `docs/ops/evidence/2026-08-02_10440_q10_path.md` — Q10 evidence path record for 10440.
- `D:\QM\reports\pipeline\QM5_10440\Q10\NDX_DWX\aggregate.json` — verdict=FAIL, dd=31.00579%.
- `docs/ops/evidence/2026-08-02_ks_deploy_execution.md` — loaded_ok=23/24, missing=10440 by design.
