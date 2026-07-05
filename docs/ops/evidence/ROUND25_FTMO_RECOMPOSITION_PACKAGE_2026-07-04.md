# Round25 — FTMO 2-Step Recomposition Package (2026-07-04, late night)

**Status: CANDIDATE COMPOSITION — full-fidelity confirmed; OWNER decision pending (Q12-class).**

## Headline

A from-scratch greedy recomposition over all 49 validated candidate reports beats the
Round24 champion decisively at identical simulation fidelity (5000 runs × 5 seeds,
FTMO_2STEP preset, block_days 5, 60-day phase horizon, 100k account):

| Metric | Round24 (13 legs @ 5.9) | **Round25 seed_ii (12 legs @ 9.0)** | Delta |
|---|---|---|---|
| min robust pass probability | 57.04% | **67.72%** | **+10.68pp** |
| mean robust pass probability | 57.78% | **68.19%** | +10.41pp |
| max max-loss breach prob | 4.96% | **4.24%** | −0.72pp |
| max daily-loss breach prob | 0.00% | **0.00%** | = |
| mean target-not-reached prob | 38.04% | **28.00%** | −10.04pp |

Round24 was guard-saturated (4.96/5.00) — the 2026-07-04 interim sweep proved lead+1
additions structurally cannot admit (31 screens: 0 ADMIT). Round25 spreads risk across
more-orthogonal legs at a higher total scale: better coverage AND more guard headroom.

## The composition (seed_ii final lead, risk scale 9.0)

| Leg | Weight | Source basis |
|---|---|---|
| QM5_10911:GDAXI.DWX H1 grimes-complex-pb | 0.1396 | round31 fresh (141 tr, PF 1.41, DD 4.4%) |
| QM5_12958:XAUUSD.DWX D1 nnfx-hma-wae-swing | 0.1396 | round31 fresh (72 tr, PF 2.05) |
| QM5_10848:XAUUSD.DWX | 0.0931 | Round24 member report |
| QM5_10692:NDX.DWX H1 tv-ls-ms | 0.1241 | validation_round10 |
| QM5_10847:GBPUSD.DWX | 0.0432 | Round24 member report |
| QM5_10163:NDX.DWX | 0.0469 | Round24 member report |
| QM5_10440:NDX.DWX H1 mql5-ohlc-mtf | 0.0510 | validation_round12 |
| QM5_11476:USDJPY.DWX H1 | 0.1594 | validation_round6 (775 tr q08-basis) |
| QM5_10700:XAUUSD.DWX | 0.0693 | Round24 member report |
| QM5_12475:NDX.DWX | 0.0361 | Round24 member report |
| QM5_10286:XTIUSD.DWX D1 | 0.0576 | Round24 member report |
| QM5_12990:GBPUSD.DWX H4 grimes-context-pb-v2 | 0.0400 | round31 fresh (exit-surgery v2) |

New vs Round24: GDAXI enters the book (10911), plus 12958, 10692, 10440, 11476, 12990.
Dropped vs Round24: 10951, 10375, 10702, 10988, 10194, 9936, 10113/10712-class legs.
Overlap with the live DXZ S3 book: 10911, 10692, 10440 (FTMO = separate account; overlap
is capital-efficiency, not correlation risk between accounts).

## Method + evidence chain (all tool-conformant)

- Simulation exclusively via `prop_challenge_optimizer.py --screen-candidate` (report.htm
  basis; the 2026-06-30 basis lesson honored — zero reimplemented sim math).
- Greedy driver (3 independent seed restarts; scratchpad `round25_greedy_driver.py`)
  synthesized lead artifacts per round; adaptive weight menus; scales 5.0–9.0 (extended
  after the first run stalled at the 6.5 ceiling with unconverted guard headroom).
- Convergence cross-check: seed_iii (11 legs, triage 71%) independently selected nearly
  the same core (10911, 12958, 10848, 10692, 10847, 12475 + 12989/10700/10467/10132) —
  the composition is not a seed artifact.
- Full-fidelity confirm artifact:
  `D:\QM\strategy_farm\artifacts\portfolio\round25_recompose_20260704\fullfidelity_confirm_seed_ii_12leg.json`
  (lead = `seed_ii_gdaxi10911\round_14\lead.json` + 12990 @ 0.04, scales 8.5/9.0/9.5,
  runs 5000, seeds 0–4; selected summary quoted above).
- All per-round screen artifacts + progress.jsonl under
  `D:\QM\strategy_farm\artifacts\portfolio\round25_recompose_20260704\`.

## Caveats (honest list)

1. **Same-data optimization:** legs and weights were selected on the same 2023–2025
   report set the confirm runs on. The +10.7pp is in-sample composition edge; per-leg
   edges themselves carry independent pipeline evidence (Q02–Q08), but the WEIGHTS are
   fitted. Mitigation options: seed-holdout confirm (different seeds — done, 5 seeds),
   block-bootstrap already randomizes sequencing; a stricter OOS split (compose on
   2023–2024, confirm on 2025) is possible follow-up work.
2. **Scale 9.0 semantics:** risk scale multiplies the validation-run sizing; translation
   into per-EA RISK_FIXED for a real 100k FTMO account needs the deployment math from
   the scale8_equiv convention (PROP_CHALLENGE_MT5_VALIDATION doc) before any live use.
3. 12990 is an exit-surgery v2 with only 34 trades (2023–2025) on its fresh report —
   smallest evidence base in the book; its weight is correspondingly small (0.04).
4. Q04-class cost realism: validation reports run the canonical backtest sets (real
   Darwinex commission schedule); no additional cost stress applied at composition level.

## Deployment math — per-leg RISK_FIXED translation (caveat 2 resolved)

Sim semantics (verified in `_evaluate_weighted_case`, optimizer line ~722): combined
daily PnL = Σ wᵢ × PnLᵢ(report) × risk_scale. Source reports ran the canonical backtest
sets at RISK_FIXED = $1,000/trade (HR4 convention). Therefore on a 100k FTMO account:

**RISK_FIXED_live(leg i) = 1000 × 9.0 × wᵢ**

| Leg | Weight | RISK_FIXED (USD/trade) | % of 100k |
|---|---|---|---|
| QM5_11476:USDJPY | 0.1594 | 1,435 | 1.43% |
| QM5_10911:GDAXI | 0.1396 | 1,256 | 1.26% |
| QM5_12958:XAUUSD | 0.1396 | 1,256 | 1.26% |
| QM5_10692:NDX | 0.1241 | 1,117 | 1.12% |
| QM5_10848:XAUUSD | 0.0931 | 838 | 0.84% |
| QM5_10700:XAUUSD | 0.0693 | 624 | 0.62% |
| QM5_10286:XTIUSD | 0.0576 | 518 | 0.52% |
| QM5_10440:NDX | 0.0510 | 459 | 0.46% |
| QM5_10163:NDX | 0.0469 | 422 | 0.42% |
| QM5_10847:GBPUSD | 0.0432 | 389 | 0.39% |
| QM5_12990:GBPUSD | 0.0400 | 360 | 0.36% |
| QM5_12475:NDX | 0.0361 | 325 | 0.33% |
| **Σ (all legs simultaneously at full SL)** | 1.0000 | **9,000** | **9.0%** |

Pre-deploy verification — **DONE 2026-07-05 morning: all 12 source reports parsed,
12/12 confirm RISK_FIXED=1000.** The translation table above is exact as printed.
Note: worst-case 9.0% simultaneous full-loss < FTMO 10% max-loss limit even before
correlation effects; the sim puts the realistic breach probability at 4.24%.

## Window-split stability check (caveat 1 addressed; 5000×5 per window)

Input-window filter added to the screen CLI (`--pnl-from-date/--pnl-to-date`, commit
`9f2792c5c`, SELF_REVIEW-flagged for codex spot-check). Same 12-leg composition:

| Window | min_robust | max-loss breach | target-miss | confirm scale |
|---|---|---|---|---|
| Full 2023–2025 | 67.72% | 4.24% | 28.0% | ~9.0 |
| 2023–2024 | 68.70% | 4.10% | 27.5% | 9.5 (auto-selected) |
| 2025 only | 65.34% | 5.16% | 29.3% | 9.5 (auto-selected) |

Reading: the edge is not concentrated in any year — the weakest slice (2025) still sits
**8.3pp above the Round24 bar**. Mild ~3.4pp shrinkage vs the stronger years = normal
fit-shrinkage. The single guard breach (5.16% on 2025) occurred at the AUTO-SELECTED
scale 9.5, not the canonical 9.0; pinned-scale confirms (9.0 both windows + 8.5 margin
variant for 2025) are running and will be appended before the OWNER decision. If 2025 @
9.0 still grazes the guard, the conservative deployment is scale 8.5 (RISK_FIXED factors
scale down proportionally: Σ = $8,500 = 8.5% worst-case simultaneous).

Honesty note: this is a stability/shrinkage check, not true OOS — leg selection saw the
full window. True OOS (re-select on 2023–24 only, confirm on 2025) is possible with the
same tooling (driver + date filter) if OWNER wants the gold-standard number before
committing challenge capital.

## True-OOS protocol + fair baseline (2026-07-05 early AM — the decision-grade section)

**True OOS (select on 2023–24 only, confirm on untouched 2025, 5000×5):** the greedy
selector overfits substantially — train 78% → holdout **42%** with 16% daily-breach
(seed_iii collapse); train 74% → holdout **59.5%** at 9.4% max-loss (seed_ii, heavy
shrink but still above the 57.04 bar). Conclusion: greedy scores are selection-inflated
by ~15–35pp; scale 9 is too hot out-of-sample; single greedy compositions are
high-variance. The headline 67.72% must NOT be read as a forward pass probability.

**Consensus-10 equal-weight experiment (anti-overfit attempt): FAILED.** Legs chosen in
≥3/4 independent runs, equal weights: 30% (2025) / 57% (2023–24). The greedy WEIGHTS
carry real information; discarding them costs more than the overfit they embody.

**Fair baseline — Round24 evaluated identically (5000×5, per window):**

| Window | Round24 @ 5.9 | Round25 12-leg @ 9.0 |
|---|---|---|
| 2023–2024 | 56.1%, breach **6.0% ❌** | **66.5%, 3.3% ✓** |
| 2025 | 60.1%, 3.2% ✓ | **62.9%, 4.3% ✓** |

The incumbent Round24 itself breaches the max-loss guard on 2023–24 — its published
57.04 hides window fragility. On equal footing the Round25 12-leg composition beats it
in BOTH windows with clean guards. Both compositions were built with in-sample
processes, so the RELATIVE superiority is the robust statement; the absolute forward
pass probability is realistically ~55–65%, not 67.7.

## Final recommendation (Claude)

Deploy candidate = **the Round25 12-leg composition at scale 8.5–9.0** (8.5 for guard
margin: 59.8% on 2025 at 3.3% breach; 9.0 for yield: 62.9% at 4.3%). It dominates the
incumbent in every window at clean guards, contains the freshest evidence legs
(12958/12989/12990/10911), and its RISK_FIXED translation is documented above (scale
8.5 ⇒ Σ $8,500 = 8.5% worst-case simultaneous). Expect a real-world pass probability
in the high-50s to low-60s — materially better than the incumbent, not the in-sample 68.
Decision remains OWNER's (challenge fee = money decision); no urgency.

## Recommended next steps

1. OWNER reviews this package (after the Sunday chart session — no rush, challenge
   start is a money decision).
2. Optional hardening before decision: OOS-split confirm (compose 2023–24 / confirm 25)
   + per-leg RISK_FIXED translation table for a real FTMO 100k.
3. Prop-slate EAs (12985/12986/12988, Q02 in flight) and future exit-surgery v2s get
   screened against THIS bar (67.72) going forward, not Round24.

## Horizon appendix (2026-07-05) — FTMO time-unbound + OWNER Two-Speed decision

FTMO removed the phase time limits; everything above simulates a 60-day phase
horizon, where ~28–33% of all sim-fails were pure "target not reached in 60d"
timeouts. Time-unbound, those convert almost entirely into passes. Re-evaluated
with the SAME CLI chain (`--phase-horizon-days`, h=365 as unbounded proxy) plus a
module-level grid calling the optimizer's own library functions (cross-validation
cell reproduces the CLI confirm EXACTLY: 95.70 / 4.30 @ 8.5, h365, full window).

### Time-unbound (h365, 5000 runs; 8.5 = 5 seeds, others seed-0 / harness 5-seed)

| Scale | Pass full | Pass 2025 | Max-loss breach | Median days (both phases) |
|---|---|---|---|---|
| 6.0 | 98.90% | 98.66% | 1.08–1.32% | 98–102 |
| 7.0 | 97.80% | 97.38% | 2.20–2.62% | 84–86 |
| **8.5** | **95.70%** | **95.04%** | **4.30–4.94% ✓ guard-clean** | **~69** |
| 9.0 | 94.78% | 93.88% | 5.22–6.12% (grazes guard) | — |

Timeout probability ≈ 0 in every cell; the ONLY remaining fail mode is the
max-loss breach. Daily-loss breach = 0.00% everywhere.

### P(Phase 1 ≤ 30 days) ladder (h=30, 5000×5, conservative min-over-seeds/methods)

| Scale | Phase 1 ≤ 30d (full / 2025) | Breach within 30d |
|---|---|---|
| 8.0 | 27.6% / 26.5% | 0.7–1.0% |
| 8.5 | 31.2% / 30.2% | 1.1–1.3% |
| 9.0 | 35.0% / 33.9% | 1.5–1.8% |
| 9.5 | 38.1% / 37.6% | 2.0–2.2% |
| 10.0 | 41.3% / 40.5% | 2.5–3.0% |

Reading: a 30-day Phase 1 is a ~⅓ chance, not a plan basis — the book is
velocity-bound (+10% takes a median ~5–7 weeks), not risk-bound; each extra
scale step buys only ~3–4pp of 30d-probability. Time-unbound this goal is a
free roll: missing 30 days is not a fail, the phase simply continues.

### OWNER decision (2026-07-05, chat): TWO-SPEED RATIFIED

- **Phase 1 @ scale 9.0** — chases the 30d goal (~⅓ chance), median Phase 1
  ~5–6 weeks. RISK_FIXED(leg i) = 1000 × 9.0 × wᵢ, Σ = $9,000.
- **Phase 2 @ scale 6.0–7.0** (redeploy set files between phases) — 5% target
  without hurry, breach risk ~1–2.6%. RISK_FIXED Σ = $6,000–7,000; final pick
  at deployment.
- Execution deferred to challenge start (OWNER: "später umsetzen"); expected
  realistic totals after the overfit haircut: **~85–90% overall pass,
  ~25–30% Phase-1-in-30d**.

Artifacts: `D:\QM\strategy_farm\artifacts\portfolio\round25_horizon_20260705\`
(eval_full_h365_*.json = CLI full-fidelity; phase1_grid_progress.log +
round25_horizon_20260705_progress.log = grids incl. cross-validation).

## Sign-off

- Composition + evidence: Claude, 2026-07-04 (token-burn wave, OWNER-directed)
- Decision: composition/scale plan **Two-Speed ratified 2026-07-05** (see horizon
  appendix); challenge start (money) remains _pending OWNER_
