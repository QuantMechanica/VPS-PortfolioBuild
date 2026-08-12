# DL-084 — Optimization Track Q14–Q16 + Dual-Venue Book Construction

Date: 2026-08-12
Status: ACCEPTED per OWNER directive (interactive, 2026-08-12: "erst EAs ab einem
gewissen Gate in die Optimierung … Gates wie OOS erneut absolvieren nach Optimierung
(… noch mehr Q Gates). Wenn dann alle EAs da durch sind wird ein neues Buch gebaut für
Darwinex Zero als auch für FTMO."). Gate numbering and contracts below are Claude's
concretization under the CEO mandate; OWNER may amend before the manifest v2 ships.
Author: Claude. Basis: `docs/research/SURVIVOR_OPTIMIZATION_PROGRAM_2026-08-12.md`
v1.1 + `SURVIVOR_OPTIMIZATION_DUAL_FORENSICS_RECONCILIATION_2026-08-12.md`.

## Decision

Extend the canonical pipeline (gate manifest v2) by an **optimization track** and
**venue-split book construction**:

```
                        (normal flow, unchanged)
 Q10 ──────────────────────────────────────────────► Q11 ─► Q12 ─► Q13
   │                                                  ▲
   │  (optimization fork, this DL)                    │
   └─► Q14 OPT ADMISSION ─► Q15 CHALLENGER BUILD ─►  Q16 HEAD-TO-HEAD ──┘
         (deterministic)      & FREEZE                 (sealed requal)
                                │
                                └─► spawns a NEW EA identity that runs the
                                    UNCHANGED standard cascade Q02→Q10
```

1. **Q14 Optimization Admission** (PIPELINE, automated). Source population: distinct
   `(ea_id,symbol)` with **Q10 PASS** — the admission gate OWNER asked for. Nothing
   below Q10 enters optimization (Q07/Q08 near-misses are handled by the separate
   WS-1 recertification/recycle path, which feeds Q10 first). Deterministic
   eligibility per lever (e.g. thinning filters require full-history trades ≥150 AND
   maxDD ≥12%). Output: an **opt-card** — the pre-registration artifact (hypothesis,
   lever, exact parameter surface, frozen comparison windows, opened trial ledger).
   Verdicts: `OPT_ELIGIBLE` / `OPT_REJECTED`.
2. **Q15 Challenger Build & Freeze** (DEVELOPMENT, routed). Builds the challenger as
   a **new EA identity** (registry + magic + setfiles; parent binary/inputs
   hash-bound in the opt-card). Bounded pre-registered sweep on the **DEV/IS window
   only** (reuses the Q03 runner under the optimization contract), then parameters
   are **FROZEN**. Ships with a default-OFF equivalence proof (lever disabled ⇒
   parent behavior) and the review_ea unwired-input grep. Exit spawns the standard
   **Q02→Q10 cascade for the challenger — no gate in the standard chain is modified
   or skipped**. Verdicts: `CHALLENGER_SPAWNED` / `FAIL`.
3. **Q16 Head-to-Head Requalification** (PIPELINE, automated). Runs only when the
   challenger holds its own Q10 PASS. Sealed comparison against the **frozen
   incumbent** on the pre-registered common OOS windows (anchored Q04 folds +
   post-DEV holdout), real venue costs, plus the **mandatory no-change control** and
   the book-level marginal evaluation (DL-082/DL-083: regime-split corr, ΔSharpe eps
   0.020 never sole driver, ΔMaxDD, Δworst-day, min-contribution). This is the "OOS
   erneut absolvieren" gate. Verdicts: `PROMOTE_CHALLENGER` / `KEEP_INCUMBENT` /
   `ADMIT_BOTH` (only if corr < DL-083 admit and both contribute) / `FAIL`.
4. **Q11 venue lanes** (OWNER authority, analytic runners): storage lanes
   `Q11_DXZ` and `Q11_FTMO` (same pattern as Q09_NEWS/Q09_PORTFOLIO — no new
   top-level gate). When the frozen optimization cohort is fully terminal at Q16 (or
   the declared cutoff passes), both book builders run:
   - **Q11_DXZ**: capped inverse-vol (INVVOL stage machinery) + WS-2 evidence-based
     cluster overlay + "apply only if not worse" incumbent gate vs the current live
     book. Output: hash-bound DXZ book manifest.
   - **Q11_FTMO**: FUND_SCORE = med60/max(2; 2·|wDay|; wDD_p90) ≥ 1.0 per sleeve,
     bootstrap LB P(P1) ≥ 0.80 at book level, density constraints, live = 1
     EA/symbol, FTMO swap/cost model. Output: hash-bound FTMO book manifest. **No
     challenge account before the bar is met** (unchanged doctrine) — the manifest is
     built and parked fail-closed either way.
5. **Application stays OWNER ceremony.** Book manifests are evidence artifacts; any
   T_Live / FTMO application requires the written OWNER approval + Claude
   verification chain (Hard Rules unchanged). The 16.08 book ceremony for the
   CURRENT live book (weighting evolution, Task #19) proceeds unchanged; the dual
   books built here are the successor generation with their own ceremony.

## Binding constraints carried over (anti-overfit charter v1.1, in force at every new gate)

Trial ledger: every mask/threshold/carrier/profile evaluated anywhere in Q14–Q16
enters the challenger's Q07 DSR / Q08 PBO/FDR deflation. Thresholds frozen on IS
before OOS. Frequency floor checked before any PF/DD comparison. Survivor-port purity
(Rule 6). Builder ≠ approver. One EA at a time in build. RISK_FIXED $1000 for all
backtests. Never auto-swap a live sleeve — `PROMOTE_CHALLENGER` feeds the book
builder, not the live terminal.

## Why admission at Q10 (and not earlier)

Optimization consumes family-wise trial budget; spending it on sleeves that have not
proven locked-configuration full-history reproducibility invites noise-fitting
(funnel evidence: most clean Q08 passers die on portfolio contribution, not
robustness — the scarce resource is orthogonal book value, not raw candidates). WS-1
requalification (infra recycle, Q07 second-axis recerts, current-contract Q09/Q10
requal) grows the Q10-PASS population in parallel and thereby feeds Q14.

## Cohort freeze & cutoff

The optimization cohort v1 freezes at the first Q14 admission run (Q10-PASS set as of
that date, plus explicitly listed WS-1 requalifications landing before freeze).
Book construction triggers when **all cohort Q16 verdicts are terminal OR the cutoff
date passes** — cutoff = 14 calendar days after the last Q15 challenger spawns, so
stragglers cannot block the books indefinitely. Late finishers enter the next book
generation.

## Rollout

Implementation on `agents/board-advisor` + Codex lane tickets (see
`docs/ops/FACTORY_ADAPTATION_OPTIMIZATION_TRACK_2026-08-12.md`). Gate manifest v2
ships **read-inert** (new phases defined, zero work items created) until the
components pass review; the first Q14 run is the activation act. Any change touching
resident-worker claim paths ships through a standard OFF/ON activation window
(standing unlimited prep, mint per ceremony). T_Live / FTMO terminals untouched
throughout.
