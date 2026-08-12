# Survivor Optimization — Dual-Forensics Reconciliation (Claude × Codex) — 2026-08-12

OWNER directive: run Codex independently on the same four analysis briefs (funnel
forensics, survivor census, Unger reference, lever critique), compare, update the plan.
Independence held: Codex payloads contained only the raw questions + primary-source
paths, with an explicit ban on reading the Claude program doc or sibling artifacts;
Codex confirmed the boundary in each report.

Inputs: Claude pass = 12-agent workflow + funnel re-verification (evidence in
`SURVIVOR_OPTIMIZATION_PROGRAM_2026-08-12.md` v1.0). Codex pass = router tickets
`d37bb33e` / `c2b505e6` / `b4c56952` / `3e187d36` (all reviewed, APPROVED), artifacts
`CODEX_FUNNEL_FORENSICS_`, `CODEX_SURVIVOR_CENSUS_`, `CODEX_UNGER_REFERENCE_PORTABILITY_`,
`CODEX_SURVIVOR_LEVER_CRITIQUE_2026-08-12.md`. Load-bearing Codex claims were
independently re-verified by Claude before acceptance (marked ✔ below).

## 1. Convergent (both passes, independent methods)

- OWNER's dashboard numbers 255/179/19/34 reproduce exactly as distinct
  (ea_id,symbol) PASS pairs per gate; **Q08=19 is not a bug**.
- **No queue starvation Q06→Q08**: every Q06-passer reached Q07, every Q07-passer
  reached Q08 (NO_ROW = 0 in both analyses). The contraction is merit selection.
- Q07 kill mechanism = per-seed PF floor (dominant), plus seed trade floor; Q07
  infra-only residue = 41 pairs (identical count both passes; recyclable, not merit).
- Q08 FAIL_SOFT routes onward to the Q09 portfolio track (`aggregate.py`), FAIL_HARD
  is terminal; the strict-PASS chip therefore understates the admitted cohort.
- Survivor cohort = 34 distinct (ea,symbol) from 40 Q10 PASS rows; XAUUSD 9/34,
  EURUSD 4, GDAXI 4; 22 of 24 live roster sleeves inside the 34; live anomalies
  10440/NDX (Q10 FAIL) + 12567/XNGUSD (Q08 FAIL_HARD).
- Top optimization targets by DD×sample: 13213/USDJPY, 10706/GBPUSD, 13301/GDAXI;
  protect-don't-optimize: 10919/XTIUSD, 13128/NDX and the event/RV corner.
- Unger reference: gate = daily direction-aware permission (whitelist/blacklist over
  D1 patterns); **bar[0] forming-candle evaluation repaints → inadmissible**; HMM =
  ML-doctrine breach (and unwired in source); the 10-slot×~100-pattern sweep is an
  overfitting engine — port the mechanism, never the methodology.
- Levers: FVG/confluence combos REJECT; DOW masks REJECT/deprioritize; SL-tightening
  dead (Tier-B MAE); TP re-opt deprioritized; time-exit surgery = the one validated
  exit class; portfolio-level levers = highest value per unit risk.

## 2. Codex findings adopted (Claude pass missed or under-measured)

| # | Finding | Verification | Plan impact |
|---|---|---|---|
| C1 | Dashboard chips come from `render_cockpit.py` `_pass_pairs` — **lifetime distinct-PASS, cumulative across gate-regime eras** (own footnote :2529-2534); the two "34"s (Q09 union chip vs Q10) **overlap only 17** | footnote grep ✔; SQL-3 logic reviewed | §1 rewrite: chips are independent lifetime populations, not one funnel |
| C2 | **Zero of 41 Q10 rows carry the current paired-Q09 dependency binding; only 1 pair holds CONFIG_LOCKED + PASS_PORTFOLIO** — all 34 survivors are historical-visible passes; current code refuses new Q10 without both authenticated arms (`farmctl.py:5922-5929`, `:15200-15218`) | re-ran both queries against backup: 41/0 and 1/1 ✔ | New WS-1 primary objective: current-contract requalification; Q09_NEWS CONFIG_LOCKED is the real frontier (ties into Task #20 news program) |
| C3 | **Realized daily-return correlations refute mechanism-based redundancy**: max pair 0.295 (10403/10513); Balke variants 0.008, cum-RSI2 cousins 0.053, Grimes cousins 0.077; only XAU bloc 10403/10513/1556 exceeds the 0.15 admit reference; nothing reaches 0.40 | recomputed 10403/10513 = 0.294803 and 13213/13301 = 0.008319, n=2348 ✔ | WS-2 reframed measure-then-decide; no mechanism-based retirement |
| C4 | Q08 PASS cohort (19) fate: portfolio arm 5 PASS / 12 FAIL_PORTFOLIO / 2 NEED_MORE_DATA — **most clean Q08 passers die on portfolio contribution**, and 18 of 34 Q10 passes hold no Q08 strict PASS (soft-track/legacy promotions) | SQL-5/SQL-3 logic reviewed | Confirms portfolio-first: optimizing standalone PF attacks the wrong constraint |
| C5 | Q07 **rule-era mixing**: 11 stored variance-fails predate the ratified second axis (var 20–40% + worst-seed ≥1.10 now passes) and lack its marker | SQL-6 taxonomy reviewed | WS-1 gains a recertification candidate class: re-run legacy variance-fails under the current ratified rule |
| C6 | Q05 `FAIL_DD_PORTFOLIO_REVIEW` = park for portfolio review (per `q05_stress_medium.py:574-595`), not a merit kill — first pass lumped it into genuine-fail | source cited | Funnel table corrected; parked sleeves are WS-1 inventory |
| C7 | PatternFilter reference is **fail-open** on insufficient history (returns default-allow while debug text claims block) | verified at source :250-259 ✔ | V5 port contract: `valid=false` ⇒ both directions blocked |
| C8 | Reference NewsFilter fail-open + disabled during optimization (train/runtime skew); OnTester composite has no IS/OOS separation and pass-CSV logs only slot 1 of 5 per direction | source citations reviewed | Reference results are inadmissible as evidence; only mechanism ports |
| C9 | Filter-layer design upgrade: **compiled card-declared predicate profiles** (`qm_pattern_profile=<NAME>`) instead of free slots; cache keyed by (symbol, tf, closed-bar-time, profile); challenger = new EA identity | design reviewed | §5 adopts profile API on top of Option A |
| C10 | MTF entry refinement is salvageable under a strict contract: parent signal frozen at closed bar, ONE pre-registered tuple, opportunity-level conversion reporting (so "better entries" can't silently delete parent losses), timestamp look-ahead audit | protocol reviewed | Verdict upgraded DEPRIORITIZE → PURSUE_CONDITIONAL (backlog behind WS-3/WS-4) |
| C11 | Port protocol hardening: pre-registered carrier LIST, publish failures, every carrier counts in family-wise DSR/PBO/FDR | protocol reviewed | WS-6 adopts; ranking rises (see §4) |
| C12 | Doc drift: `phase_ids.py` says 10 Davey sub-gates, executable defines 11 (incl. 8.11 MC shuffled DD); SPEC.md missing for QM5_1567 + QM5_13301; cockpit chips deserve a `LIFETIME (MIXED ERAS)` label + a contract-versioned cohort panel | file checks ✔ | Follow-up ops ticket |

## 3. Claude findings Codex did not surface (retained)

- The **~60 infra-stuck sleeve inventory across Q06–Q09_NEWS** as an explicit harvest
  list (Codex counted the same Q07 41 but did not aggregate the cross-gate residue as
  a workstream).
- The Q02 frequency-floor arithmetic pre-filter for any thinning filter (≥150 trades
  AND ≥12% DD eligibility list) — Codex's critique agrees directionally but did not
  compute the eligible set.
- The concrete two-week sequencing with lane assignments and the WS-5 MC tail-sizing
  lever (live layer only).
- House-evidence specifics: QM5_13204 FVG-as-filter falsification numbers, Gold-Reaper
  vol-gate open thesis, INVVOL incumbent head-to-head status.

## 4. Divergences and how they were resolved

| Topic | Claude v1.0 | Codex | Resolution (v1.1) |
|---|---|---|---|
| WS-2 near-duplicate retirement | Retire one leg of 10142+11132, 13036+13301 on mechanism grounds | Realized corr shows mechanism ≠ redundancy; those pairs are unrostered/untested | **Measure first**: fixed-risk return series + leave-one-out/regime-split for the untested pairs; only the evidenced XAU bloc (10403/10513/1556) is a selection candidate today |
| Symbol ports ranking | WS-6, parked (Codex quota assumed dead until 18.08) | #1 lever ("port first") | Quota reset verified (used 1%) → WS-6 **unblocked now**, promoted to co-priority with WS-1/WS-2; still gated on host-gate genericization (ticket 9ad6d9c0) and carrier-list pre-registration |
| MTF entry | DEPRIORITIZE | PURSUE_CONDITIONAL with survival contract | Upgraded to PURSUE_CONDITIONAL, backlog behind WS-3/WS-4, Codex contract binding |
| Day-filter surviving slice | PURSUE_CONDITIONAL (vol-regime gate, WS-4) | DEPRIORITIZE (allow one source-derived pre-registered calendar mechanism) | Kept as WS-4 but demoted below WS-6; both passes agree on the protocol shape (one pre-registered predicate, frequency gate first, DD-shaped success metric); Codex's stricter "source-derived thesis" wording adopted |
| Admitted post-Q08 cohort | 92 (any-row PASS∪FAIL_SOFT) | 81 exclusive-precedence (19 PASS + 62 SOFT after HARD dominates) | Precedence view adopted as primary (a pair that ever recorded FAIL_HARD is terminal); 92 kept as the loose upper bound |
| Q09_NEWS "cleared" | 18 (REVIEW_REQUIRED as advance token) | 1 (CONFIG_LOCKED is the current-contract success; REVIEW_REQUIRED = awaiting OWNER A/B decision) | Codex reading adopted — matches the OWNER Q09-news semantics (A/B → recommendations; activation needs an OWNER window) |
| WS-4 variant identity | Lane-1 ablation (same ea_id) or Lane-2 v2 | New EA identity from the start (no inherited PASS, clean lineage) | Ablation stays the *measurement* instrument; any *promotion* candidate gets a new EA identity |

## 5. Verdict on the dual-forensics exercise

Codex corroborated every load-bearing v1.0 number it re-derived (255/179/19/34, the 41
Q07 infra pairs, the 34-sleeve census, the XAU 26% concentration) and falsified two
v1.0 interpretive claims (mechanism-redundancy; REVIEW_REQUIRED-as-pass). Claude's
pass caught the recyclable cross-gate infra inventory and the frequency-floor
arithmetic that Codex's lever critique only reasoned about. Net: the plan survives
with its workstream set intact, but its ordering, its WS-2 method, and its §1 funnel
narrative changed materially. Plan updated to v1.1 in
`SURVIVOR_OPTIMIZATION_PROGRAM_2026-08-12.md` (changelog at top).
