# FTMO Fitness Candidates — runtime audit (2026-09-15, READ-ONLY)

Task: directive §5, §16–§19, §47, §57, §68F. Source of truth =
`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md`.
All facts below carry a verifiable path/query. This is an audit; nothing was mutated.

## Headline (3 lines)

1. **No candidate has FTMO fitness today.** The Q10 FTMO Recommendation gate admits **0 of 42**
   evaluated pairs, and the FUND_SCORE cache scores **every** sleeve far below the 1.0 admission
   floor (best = 0.41). The strict FTMO book is not reachable this week from any pool.
2. **The only real FTMO evidence is a losing demo.** The FTMO demo account (1514536732) ran two
   cycles: cycle-1 (Jun 29–Jul 24) lost **−9,952.88 USD (−9.95 %)** with a **−10.26 % realized
   max drawdown that breaches the FTMO 10 % total-loss limit**; cycle-2 (Aug 2–Sep 4) was near-dormant
   (9 trades, −0.15 %). "FTMO book v2" per the sprint is a **DEMO burn-in** re-using the DXZ v2
   swing roster on FTMO symbol names — **no FTMO qualification is claimed** (F3 decision).
3. **The economic gap is structural:** the entire proven inventory is D1/H1/H4 swing with low
   trade density, high per-trade daily-loss footprint and swap burden — the opposite of the
   FTMO-fit profile (§17–§19). Low-timeframe/scalping/trailing candidates exist in the universe
   but none has cleared validation into book eligibility. That gap is the correct first Kimi mission.

---

## Findings

### F1 — The Q10 FTMO Recommendation gate admits 0 of 42 pairs
The gate = `tools/strategy_farm/q09_ftmo_recommendation.py` (read-only projection) delegating to
`tools/strategy_farm/portfolio/ftmo_q09_admission.py::evaluate_ftmo_q09_admission`. Despite the
`q09`/`Q09_NEWS` storage names, this is the operator-facing **Q10 FTMO Recommendation** gate
(gate_manifest v4). Running `collect()` read-only against the live DB
(`file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`) returns:

```
available True  total 42  suitable_yes 0  suitable_no 42
reason_counts: {FTMO_Q09_EVIDENCE_MISSING: 34, FTMO_Q09_NOT_CONFIG_LOCKED: 3, FTMO_Q09_SCOPE_NOT_FTMO: 5}
```

Admission requires a `CONFIG_LOCKED` Q09_NEWS row whose locked matrix targets FTMO (7x1 FTMO) or
whose 7x4 matrix carries a viable FTMO configuration (trades≥20, PF>1, DD≤25 %, seed stability). The
34 "evidence missing" pairs have no locked NEWS evidence; the 5 "scope not FTMO" pairs are locked to
DXZ, not FTMO. **Zero pairs carry a positive FTMO recommendation.** (Evidence: the module source +
the read-only `collect()` run above.)

### F2 — FUND_SCORE: every sleeve is far below the FTMO admission floor of 1.0
Authoritative cache `D:/QM/strategy_farm/artifacts/portfolio/fund_scores.json` (134 sleeves,
`screening_only=true`, `gate_override_allowed=false`). Formula
(`tools/strategy_farm/portfolio/fund_score.py:103`):
`fund_score = med60_1x / max(2.0, 2.0·|worst_day_1x|, wdd_p90_1x)`. Floor for strict FTMO admission
is **1.0** (`docs/ops/BOOK_SPRINT_2026-09-20.md:54`). Top of the ranking:

| rank | sleeve | FUND_SCORE | med60_1x | worst_day | wdd_p90 | active_days/60d |
|---|---|---|---|---|---|---|
| 1 | 12989:XAUUSD | 0.408 | 0.818 | 1.004 | 1.275 | 0.0 |
| 2 | 10939 / 41220:GBPUSD | 0.391 | 0.833 | 1.064 | 1.914 | 0.0 |
| 3 | 9936:USDJPY | 0.378 | 3.102 | 1.925 | 8.205 | 19.0 |
| 4 | 13301:GDAXI | 0.344 | 1.770 | 1.853 | 5.144 | 9.0 |
| 5 | 12823:USDJPY | 0.343 | 1.983 | 2.443 | 5.790 | 13.0 |

The best sleeve scores **0.41 (59 % below the floor)**; 29 sleeves are UNSCORABLE. Corroborated by the
sprint (F2/F3): FTMO builder dry-run **BAR_NOT_MET, 0 of 16 pairs, fund scores 0.05–0.09 vs floor 1.0**
under FTMO cost-adjusted streams (`docs/ops/BOOK_SPRINT_2026-09-20.md:54,55,79`). Both sources agree:
no pair clears the bar. (Note: raw-stream cache = 0.05–0.41; FTMO-cost-adjusted = 0.05–0.09 — cost
adjustment lowers scores further.)

### F3 — The FTMO demo history is a losing, drawdown-breaching record
Deterministic parse of the FTMO demo terminal journal
`C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850/MQL5/Files/QM/journal/live_deals_normalized.csv`
(138 rows; two `BALANCE` deposits of 100,000 → the account was **reset on 2026-08-02**, so there are
two cycles). Rules bound from `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json`:
profit target 10 % (P1) / 5 % (P2), **max daily loss 5 %, max total loss 10 %**, min 4 trading days.

| cycle | span | closed trades | open-days | net USD (%) | worst day | realized max-DD | verdict vs FTMO |
|---|---|---|---|---|---|---|---|
| 1 | 2026-06-29 → 07-24 | 59 | 16 | **−9,952.88 (−9.95 %)** | −2,338.91 (−2.34 %) | **−10,264.90 (−10.26 %)** | **BREACH max-loss 10 %** |
| 2 | 2026-08-02 → 09-04 | 9 | 8 | −146.43 (−0.15 %) | −180.84 | −285.61 | near-dormant, no progress to target |

Realized per-symbol P&L (cycle-combined, OUT legs): GER40.cash −4,063.68, XAUUSD −2,435.21,
GBPUSD −2,276.80, US100.cash −1,996.45; EURUSD +36.29, USDJPY +107.20, USOIL.cash +529.34. The demo
**has never approached a pass**: cycle-1 would have failed on the total-loss limit; cycle-2 never
generated enough activity. `account_snapshot.json` (2026-09-06) shows equity/balance flat at 100,000
with 0 open positions — the book is effectively idle. (Evidence: the CSV parse above; snapshot at the
same journal dir.)

### F4 — "FTMO book v2" is a demo burn-in of the DXZ swing roster, not a qualified FTMO book
Sprint decision **F3** (`docs/ops/BOOK_SPRINT_2026-09-20.md:55`): *FTMO demo book v2 = the DXZ v2
roster (28 sleeves) on FTMO broker symbol names, same sha-bound binaries, deployed on the FTMO demo
terminal under governor M13 as a burn-in/observation book; NO FTMO qualification is claimed for any
pair; the strict Q11_FTMO bar and its verdicts stay untouched.* The admission census (task **42a437a4**,
`assigned_agent=claude`, state IN_PROGRESS) resolved **24 ADMIT / 4 EXCLUDE**
(`docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/README.md`). ADMIT/EXCLUDE here is purely
**operational** (symbol name resolvable, magic non-colliding, no rebuild needed) — it is explicitly
**not** an economic FTMO-fitness verdict. All 28 roster sleeves are D1/H1/H4 swing (per the roster
table); the census EXCLUDEs are 11132/SP500, 12567/XNGUSD, 13117/EURGBP (unverified symbol name) and
12778 (D7 dark no-op).

### F5 — Scalping / low-timeframe / trailing inventory exists but none has cleared validation
Setfile-timeframe census across `framework/EAs` (4,125 EA dirs): D1 12,854 · H1 8,180 · H4 6,170 ·
M15 2,622 · M5 1,835 · M30 1,178 · M1 544 · W1 304 setfiles. Many EA names encode intraday/scalp/
session/trailing intent (e.g. `tv-ma-scalper-relief`, `tv-vwap-rsi-scalp`, `tv-london-session-break`,
`tv-ema10-20-rsi-trail`, `tv-ma922-trail`, `gh-asian-sweep`). Pipeline reach of low-TF (M1/M5/M15)
work_items (live DB): 250 distinct low-TF EAs reached Q08+, incl. **53 Q14 items across 34 EAs**
(terminal gate) and 1 Q15 item. **However:** none appears in the FUND_SCORE cache above the floor, and
none is in the current demo book — the demo book is entirely D1/H1/H4 swing (roster table + v1 attach
map). One low-TF sleeve did reach the **v1** demo (10715 `tv-asian-box`, USDJPY M15, magic 107150004 —
`ftmo_demo_attach_map.json`), but it is not carried into v2 and produced no cited economic evidence.
The scalping/trailing directions §18–§19 now explicitly allow are **present in the idea universe but
absent from any validated FTMO-relevant book.**

### F6 — The FTMO rules snapshot binding the numbers is 11 days old
`FTMO_2S_100K_STANDARD_V2.json` official-rules snapshot `retrieved_at_utc = 2026-09-04T02:10:47Z`
(`docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json`, sha256 `c199b8f5…`), status
`RESEARCH_CONTRACT_ONLY`. GO criteria in the same file: P(pass) point-estimate ≥ 80 %, lower-95 % ≥ 70 %,
joint two-phase ≥ 65 %, phase-2 conditional ≥ 85 %, evidence max age 7 days. Directive §63 requires
current rules be re-verified before any paid recommendation — this snapshot is past the 7-day evidence
window it itself sets.

---

## FTMO-fit table (per candidate → decision)

Because Q10 admits 0 pairs (F1) and FUND_SCORE clears 0 pairs (F2), **every candidate's FTMO verdict
today is NOT-FIT.** The table shows the strongest-scoring pairs with the property that fails each.

| pair | FUND_SCORE | first-passage / P(pass) | daily-loss survival | density (active-days/60d) | holding | swap burden | verdict |
|---|---|---|---|---|---|---|---|
| 12989:XAUUSD | 0.41 (floor 1.0) | none (no CONFIG_LOCKED FTMO NEWS) | med60 0.82 vs worst-day 1.00 → thin | 0.0 | D1 swing | gold, overnight | **NOT FIT** (below floor, no density) |
| 10939:GBPUSD | 0.39 | none | worst-day 1.06 | 0.0 | H4 | FX overnight | **NOT FIT** |
| 9936:USDJPY | 0.38 | none | worst-day 1.93, wdd_p90 8.2 | 19.0 | swing | JPY carry | **NOT FIT** (tail too deep) |
| 13301:GDAXI | 0.34 | none | worst-day 1.85 | 9.0 | H1/H4 | index overnight | **NOT FIT** |
| 12823:USDJPY | 0.34 | none | worst-day 2.44 | 13.0 | swing | JPY | **NOT FIT** |

**Strongest current FTMO demo roster justifiable from evidence:** only the operational demo burn-in
roster of F4 (24 ADMIT swing sleeves on FTMO symbol names), and it must ship **labelled DEMO-BURN-IN
with no qualification claim** — its predecessor lost 9.95 % and breached the 10 % total-loss limit
(F3). There is **no evidence-justified paid-challenge roster today.**

---

## What is missing

**Economically missing (the property NO current candidate has):** a positive-drift, higher-density,
short-holding, low-tail, low-swap intraday profile. Concretely: (a) no pair clears FUND_SCORE ≥ 1.0
(F2); (b) no pair carries first-passage P(pass) evidence — the authoritative engine
`ftmo_timebox_eval.py` has no current per-pair FTMO output because no pair is CONFIG_LOCKED to FTMO
(F1); (c) the demo roster's realized daily-loss and drawdown footprint is too large relative to its
median 60-day gain (worst-day and wdd_p90 exceed med60 for every top sleeve — F2); (d) trade density
is near zero for the top scorers (0 active-days/60d).

**Operationally missing:** (a) an FTMO demo terminal that is actually running a representative book —
the account is idle at flat equity since ~09-04 (F3), so the directive §12 two-week validation clock
has **not** started on any intended roster; (b) verified FTMO symbol names for 3 sleeves
(11132/SP500, 12567/XNGUSD, 13117/EURGBP) — though see Drift D1, the v1 attach map already resolves
two of them; (c) a current (≤7-day) official FTMO rules snapshot (F6); (d) the LIVE_RISK_FREEZE is
ACTIVE and blocks even minting an FTMO manifest until the OWNER's written lift + conditions
(`docs/ops/BOOK_SPRINT_2026-09-20.md:10-24`).

**Evidence missing:** (a) any completed representative two-week FTMO demo cycle on the intended roster
(§12); (b) first-passage / timebox simulations for any FTMO-scoped pair (the diagnostic engines
`ftmo_p1_mc.py` / `challenge_firstpassage.py` exist but have no FTMO-locked inputs to run on); (c)
cost-fidelity coverage — the v2 cost snapshot covers only 5/10 symbols
(`docs/ops/evidence/2026-09-14_ftmo_book_v2/README.md`, sprint F2).

---

## Top-3 research questions for the first Kimi FTMO-gap campaign (§47)

Each is a falsifiable hypothesis with the dataset that answers it. All research-only, mechanizable,
ML permitted offline (§41–§42), cross-vendor critic ≠ Kimi (§52).

1. **H1 — Intraday session-bounded mean-reversion beats swing on FTMO first-passage.**
   *Falsifiable claim:* a mechanical intraday strategy that opens and flattens within one session
   (no overnight hold) achieves higher simulated P(pass ≤60d) at ≤10 % max-DD than the best current
   swing sleeve, because it removes the overnight/swap tail that produced the −10.26 % demo breach.
   *Dataset:* the 68-deal demo stream (F3) partitioned by holding time + session; the D1/H1/H4
   sleeve_streams in `D:/QM/reports/portfolio/sleeve_streams`; `challenge_firstpassage.py` /
   `ftmo_timebox_eval.py` on resampled intraday-only vs swing streams. *Refuted if* intraday variants
   do not reduce worst-day/wdd_p90 relative to med60.

2. **H2 — Trade density, not per-trade edge, is the binding FTMO constraint.**
   *Falsifiable claim:* across the FUND_SCORE population, low active-days/60d (density) predicts FTMO
   failure more strongly than low med60 — i.e. the book fails the 4-trading-day + target-progression
   requirement before it fails on expectancy. *Dataset:* `fund_scores.json` (density vs med60 vs
   fund_score, 134 sleeves) + `sleeve_density.py` output + the demo cycle-2 near-dormant record.
   *Refuted if* density adds no incremental explanatory power over med60 for the observed pass/fail.

3. **H3 — Failure-mining the loser population reveals a recurring daily-loss-cluster condition (§45).**
   *Falsifiable claim:* the demo losers (GER40.cash, XAUUSD, GBPUSD, US100.cash — F3) and the
   below-floor swing population share a common regime/time-of-day condition under which they lose,
   whose mechanical exclusion (a no-trade filter) lifts simulated FTMO daily-loss survival without
   destroying expectancy. *Dataset:* all Q08 trade streams + economic FAILs (separated from INFRA/
   NO_REPORT per §44) keyed by symbol/session/day; ML clustering (allowed offline) on trade-level
   features; validated by re-simulating first-passage with the candidate filter applied. *Refuted if*
   no filter improves daily-loss survival at equal or better net expectancy out-of-sample.

---

## Drift table

| # | doc/vault says | runtime says | path |
|---|---|---|---|
| D1 | Census EXCLUDEs 11132/SP500 and 12567/XNGUSD as "no verified FTMO symbol name" (unverified) | The v1 FTMO demo attach map already resolves them: SP500→**US500.cash**, XNGUSD→**NATGAS.cash** | census `docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/README.md:98-116` vs `…/Terminal/81A933A9…/ftmo_demo_attach_map.json` |
| D2 | Sprint F3 cites authoritative dry-run at `D:/QM/reports/portfolio/book_ftmo_2026-09-14/` | That directory does not exist; only `book_ftmo_2026-08-12[_codex_dryrun]` are present under `D:/QM/reports/portfolio/` | `docs/ops/BOOK_SPRINT_2026-09-20.md:46` vs `find D:/QM/reports -iname book_ftmo*` |
| D3 | Sprint: "FUND_SCORE all 26 pairs 0.05–0.09 vs floor 1.0" | Authoritative cache spans 0.05–**0.41** on raw DXZ streams (FTMO-cost-adjusted values are the lower 0.05–0.09) | `docs/ops/BOOK_SPRINT_2026-09-20.md:54,79` vs `D:/QM/strategy_farm/artifacts/portfolio/fund_scores.json` |
| D4 | Census README top: 24 ADMIT / 4 EXCLUDE | Task 42a437a4 base slot-1 v2 was 1 ADMIT / 16 ADMIT_CONDITIONAL / 11 EXCLUDE; the 24/4 is the merged/corrected canonical (state still IN_PROGRESS, due 2026-09-16 18:00Z) | `docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/README.md:20-27` vs agent_tasks.verdict for 42a437a4 (live DB) |
| D5 | FTMO rules bound as current | Rules snapshot retrieved 2026-09-04, past the 7-day evidence window; §63 requires re-verify before a paid recommendation | `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json` (`retrieved_at_utc`, `go_criteria maximum_age_days=7`) |

---

## Open questions strictly requiring OWNER

None from this audit that are not already covered by the directive. The paid-challenge purchase and the
LIVE_RISK_FREEZE lift are OWNER-only by construction (§64, sprint §0) but are not "unresolved
questions" — they are known gates. The one decision worth surfacing (not blocking) belongs to the
implementing phase: whether to admit US500.cash / NATGAS.cash for the demo burn-in on the strength of
the v1 attach-map evidence (Drift D1) rather than re-capturing the names live.

---

## Recommended actions for implementing phases (concrete paths)

**Phase B (policy):** In the venue-fitness layer, record explicitly that FTMO_FITNESS is currently
**0 candidates** and is a distinct axis from DXZ_FITNESS (§5, §57). Do not let the DXZ v2 swing roster
imply FTMO fitness anywhere — update `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` and
`docs/ops/FTMO_CHALLENGE_READINESS.md` to carry the F1/F2/F3 verdicts.

**Phase D (Mission Control):** In the FTMO section (`tools/strategy_farm/mission_control_v2_data.py`,
`render_cockpit_v2.py`), surface: demo cycle span + reset, realized net/max-DD (F3), FUND_SCORE best
vs floor (F2), Q10-admitted-pairs = 0 (F1), and readiness recommendation **NOT READY**. Fix Drift D3
(cite the cache, distinguish raw vs cost-adjusted).

**Phase E (portfolio engine):** Point the FTMO branch of the continuous recomposition engine at
`fund_scores.json` + `ftmo_q09_admission` and have it emit the honest **empty roster / KEEP-observe**
outcome with the missing-property diagnostics of the "What is missing" section, so a small valid pool
(§4) is handled without a hard 25-count gate.

**Phase F (FTMO acceleration):** (1) Resolve Drift D1 — bind US500.cash/NATGAS.cash from the v1 attach
map to admit 2 of the 3 EXCLUDEd sleeves for the demo burn-in (task 42a437a4 corrections). (2) Re-verify
current FTMO rules and refresh the snapshot (Drift D5, §63) before any readiness call. (3) Start the
directive-§12 two-week demo clock on a *representative* intraday-leaning roster, not the idle swing book.
(4) Repair Drift D2 (missing dry-run artifact) so the authoritative FTMO builder output is on disk.

**Phase G (autonomous edge discovery):** Commission the first Kimi campaign on H1–H3 above
(`docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` + a preregistered experiment record); cross-vendor
critic must not be Kimi (§52); mechanization gate before any Q00 (§51).

**Phase H (weekly automation):** Include the FTMO demo-cycle metrics (F3 parse) and the FUND_SCORE-vs-
floor delta (F2) in the Friday evidence cut so the weekend recomposition can compute FTMO
incumbent-vs-challenger deterministically.
