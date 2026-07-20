# Level-Up Campaign — Strategy Fidelity & Uplift (2026-07-20)

**Authority:** OWNER order 2026-07-20 ("Heben wir das ganze wieder auf den nächst
höheren Level!") — generalize the Balke lesson: strategies that needed faithful
re-implementation before their real edge showed. **Method:** 4-lens parallel analysis
(coverage / fidelity / uplift / misdraft) over the ea_metrics archive, cards, and
research docs. Working files: session scratchpad `levelup/*.md`. Dead lists respected
throughout (Wyckoff/SMC, ICT, harmonics, icy-tea); no post-hoc concentration filters.

## Headline finding — the biggest loss is pre-evaluation amputation, not no-edge

**~380 strategies died before their idea was ever tested:**
- **295 of the 298 RECYCLE-cohort EAs are auto-generated skeletons** whose
  `Strategy_EntrySignal()` literally `return false` — compiled, advanced, recycled,
  never implemented. An unimplemented-idea reservoir mislabeled as failures.
- **85 real-logic EAs fired ZERO trades on every symbol at Q02** — entry-gating /
  setfile-param defects (includes the whole NFP/CPI reaction-drift family), retired as
  honest FAILs when they were draft defects.
- **1392 of 2992 approved cards (46.5%) still lack `target_symbols`** (down from ~72%,
  still feeding the dispatcher silent fallbacks).

## Campaign structure — evidence-first cohorts (not by symbol, not purely by style)

### Cohort 0 — systemic fixes (stop the bleeding; Codex lane, S-M effort)
1. **Build-gate: reject skeleton EAs** (`Strategy_EntrySignal` returning constant
   false) — one guard would have stopped 295 phantom builds.
2. **Q02 verdict `DRAFT_DEFECT`:** zero trades on ALL symbols routes back to re-draft,
   never to FAIL-retire.
3. **Card validator: require `target_symbols` + literal TF token.**

### Cohort 1 — tooling-lost merit re-runs (cheapest EV; requeued 2026-07-20)
- **13012** grimes-complex-pb-v2 — v2 of the LIVE sleeve 10911/GDAXI (+45pp win-rate
  potential per exit-surgery scan); 3× Q02 INFRA, never judged. Batch
  `LEVELUP_EXITSURGERY_V2_20260720`.
- **13015** (Q04 INFRA), **13016** (Q05 INFRA; 288 Q02 trades) — same wave.
- 13013 (grimes-trendday-v2): Q08+Q10 PASS already; portfolio re-eval under DL-083
  thresholds rides the 26.07 admission round (FTMO-admissible independently).

### Cohort 2 — fidelity rebuilds (the Balke pattern; M effort each)
Ranked by "does the amputated ingredient target the exact death mode":
1. **1567 DeMark Reverse-Sequential (EURUSD H4, Q08 FAIL_SOFT PF 1.63):** card
   self-admits the fitted 1.5×ATR take-profit is a proxy for Perl's parameter-free
   structural target (Setup-9 bar open). A tuned scalar failing the parameter-
   neighborhood gate is the textbook symptom; the structural target is inherently
   neighborhood-robust. *Rebuild v2 with the structural exit.*
2. **10403 Turtle 20/10 (XAUUSD D1, Q08 FAIL_SOFT PF 1.34/218tr):** pyramiding AND the
   System-1 last-trade filter (the Turtles' own false-breakout defense) were
   deliberately amputated. *Rebuild faithful System-1/2.*
3. **11196 Heracles (XAUUSD H4, Q05 FAIL on 21.6% DD, PF 1.29/656tr):** crypto ROI
   percentages (59.8%…) inert on gold → runs with no working profit exit. *Re-draft
   the exit for the asset; also the deferred revival-wave candidate.*
4. **NFP/CPI post-release REACTION drift (10019/10643, 0 trades everywhere):**
   news-time gating never fired (known symbol_slot/news-index defect class). The
   event-reaction style is genuinely diversifying and never got tested. *Fix gating,
   re-run.*

### Cohort 3 — uplift of survivors/near-survivors (portfolio-first)
- **13301 TT-DAX (GDAXI, 742 trades, DD-ratio 0.24, Q09 PF 1.26):** high-frequency
  low-DD diversifier — param-type-aware Q08 re-adjudication per the 07-17 doctrine
  (subsumes task #20). Both-books candidate (density!).
- **10123/XAUUSD (one of only two explicit Q08 PASSes, Q09 fail amid 9+ gold
  sleeves):** decorrelation/marginal-contribution review under DL-083, not a filter.
- 13014 diagnostic (bounded): why the highest-confidence exit mechanism (10494's
  0→68% WR gradient) produced a fair Q04 FAIL in v2.
- Exit-surgery Tier B stays CLOSED (rejected with real MAE data — do not reopen).

### Cohort 4 — depth mining & genuinely new (L effort, steady drip)
1. **Kathy Lien book: full faithful mine** — sits in Drive, never brief-mined; the
   shallow skim's cards died 0-trade. Session-range tables / carry timing / leading
   indicators → low-freq FX structure sleeves.
2. **Currency-strength G8 rotation basket** — three prior cards never fairly tested
   (INVALID / under-fired / degenerate). Cross-sectional style absent from the book.
3. **Vol-regime-conditional switching** (trend in high-vol, MR in low-vol) — style
   absent; must raise per-trade expectancy, not reallocate (icy-tea discipline).
4. **Skeleton re-draft wave (~11 aligned ideas):** TSMOM/calendar cluster from the
   295 skeletons (tsmom-12m-vol-scaled-ndx, aa-tsmom-1-3-12, aa-overnight-mom,
   january-barometer, first-half-month, pre-election-sp500, cot-spec-momo) — matches
   the surviving structural-edge doctrine and the live TOM family.
   **33 dead-aligned skeletons (harmonics/Wyckoff/chart patterns) stay dead.**
5. Covered-by-exclusion (do not re-propose): GARCH/implied-vol (data-thin on .DWX),
   order-flow/L2 (feed lacks depth), meta-labeling (ML ban).
6. **SSRN standing source (OWNER 2026-07-20):** deep mine executed same day — 30 papers,
   9 verified card candidates + published spec-feeds for the items 1-4 skeletons above
   (MOP TSMOM constants, Fan COT speculative pressure, Menkhoff/AMP for G8 rotation).
   Shortlist, verification deltas, and sequencing: `docs/research/SSRN_MINING_2026-07-20.md`.
   Also settles item-4 scope: `aa-overnight-mom` is decay-confirmed by its own authors
   (2021-2025 ≈ 0%) — condition it or shelve it, do not naively re-draft.

## Cadence

Cohort 0 fixes land via Codex this week; Cohort 1 requeues drain through the factory
now; Cohort 2 rebuilds are card-work (2 per week sustainable, 1567 first); Cohort 3
rides the 26.07 admission machinery; Cohort 4 is the standing research drip replacing
the closed Wyckoff campaign. Admission remains OWNER-gated throughout.

Evidence bundle: 4 lens reports in session scratchpad `levelup/`; every claim above
carries an ea_metrics query or file path in those reports.
