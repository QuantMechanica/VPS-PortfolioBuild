# FTMO Portfolio Gap — current recomputation (2026-09-18)

**Role:** DECISION_SUPPORT_EVIDENCE. Author: research analyst seat (read-only), commissioned by Fable under directive §30.
**Nothing here constructs a book, sets a weight, changes a gate or authorises a purchase** — all ROT / OWNER-only.
**KPI frame:** `docs/ftmo/FTMO_KPI_CONTRACT.md` v1 · **rules:** `docs/ftmo/FTMO_RULES_SNAPSHOT_2026-09-18.md`
(rulepack `FTMO_2S_100K_STANDARD_V2`, sha `857e2d4b…dcda5`).
**`FTMO_NET_CASH_REALIZED` = 0 USD** (ledger empty, no paid Challenge — KPI contract §1).

## 0. Headline numbers (all from the frozen v2 preview)

Source: `D:/QM/reports/state/ftmo_first_passage_v2_preview.json` (schema `qm.ftmo-first-passage/v2`, engine 2.0.0,
generated 2026-09-18T00:33:13Z, seed 20260915, 10,000 paths, block 10 bd, input manifest sha `721a1428…3a0a`).

| Quantity | Value | Path/key |
|---|---|---|
| P_CHALLENGE_PASS | 0.8163 | `.chain.probabilities.P_CHALLENGE_PASS` |
| P_VERIFICATION_PASS \| CHALLENGE | 0.9395 | same block |
| P_FUNDED_SURVIVAL_TO_FIRST_REWARD | 0.9119 | same block |
| **P_END_TO_END_FIRST_PAYOUT** | **0.6993** | same block |
| **P_FIRST_NET_FTMO_PAYOUT_LCB** | **0.6571** | `.chain.probabilities` (90% CI p05, 20 batches × 500) |
| **End-to-end median** | **746 business days** (p10 392 / p90 1205) | `.chain.time_business_days.end_to_end` |
| Phase-1 median | 439 bd (p10 184 / p90 818) | `.chain.time_business_days.phase1_target` |
| P(pass ≤60 cal-days) | 0.0004 | `.headline.pass_within_calendar_days.60` |
| P(daily-loss breach) | **0.0** in every stage and every cost scenario | `.chain.stages.*.p_daily_loss_breach` |
| P(max-loss breach), Phase 1 | 0.0244 · censored 0.1593 | `.headline` |
| Median net cash at first payout | 521.80 USD (p10 62.8 / p90 1594.8) | `.chain.net_condition.net_cash_usd` |
| Cost stress (×1.5 + 2 USD/lot) | LCB 0.6571 → 0.6059 | `.chain.sensitivity[4]` |

**Readiness verdict is NOT_READY** — `docs/ops/FTMO_CHALLENGE_READINESS.md` (2026-09-18T00:37:02Z): a demo cycle
realized **−10.26% max-DD vs the 10% limit**; FTMO fitness NOT_FIT, best FUND_SCORE 0.4076 vs floor 1.0; the current
cycle is 2.434 of the required 14 validation days (`D:/QM/reports/state/ftmo_demo_cycle.json`).

**The gap in one line:** the roster is not breach-prone, it is **slow**. Book drift is **16.02 USD/business day**
(= 0.016% of 100k/bd) — computed from the eight manifest streams over the engine window 2018-11-02..2024-12-06
(1,591 bd), 836 trades, mean +0.0976R/trade at 0.3125% risk. Median ≤90 bd needs ≈75–110 USD/bd, a **5–7× drift gap**.

---

## 1. Behaviour-coverage matrix

Measured columns computed by this analysis directly from the manifest streams
(`D:/QM/reports/book_evolution/2026-W38/ftmo/snapshot_r2/streams/QM/q08_trades/*.jsonl`, hashes in
`ftmo_first_passage_manifest.json`). `1R = 1,000 USD` at the streams' source risk of 1.0%.

### 1a. The 8 current demo sleeves (measured)

| Sleeve | trades/bd | E[R]/trade | med hold | overnight | swap/trade | worst MAE | top-5 win share | +yrs |
|---|---|---|---|---|---|---|---|---|
| 10706 GBPUSD | 0.168 | +0.192 | 7.4 h | 46% | 0.00 | −2.44R | 16.4% | 8/9 |
| 11421 EURUSD | 0.046 | +0.046 | 24.9 h | 74% | −8.63 | −1.13R | 14.8% | 6/8 |
| 11422 USDCAD | 0.096 | +0.094 | 41.0 h | 79% | 0.00 | −1.23R | 10.9% | 6/8 |
| 11910 NZDUSD | 0.034 | +0.039 | 116.9 h | 84% | −4.00 | −1.03R | 45.0% | 5/8 |
| 13054 XTIUSD | 0.040 | +0.059 | 70.0 h | 87% | 0.00 | −0.97R | 29.8% | 4/8 |
| 20048 XTIUSD | 0.030 | +0.019 | 72.0 h | 100% | 0.00 | −0.79R | 33.1% | 6/8 |
| 1537 XAGUSD | 0.060 | +0.038 | 48.0 h | 83% | 0.00 | −0.94R | 38.9% | 5/7 |
| 21505 XAGUSD | 0.062 | +0.062 | 116.0 h | 100% | 0.00 | −1.00R | 20.3% | 5/8 |

### 1b. Property coverage

| FTMO-useful property | Covered by (evidence) | Not covered / UNMEASURED |
|---|---|---|
| **Session-flat** | **None of the 8.** Overnight share 46–100%; the roster is an all-swing book. Measured above. | Claimed by 41475/41476/41477/41480 (SPEC §"Overnight exposure: None — mandatory flat 20:00 UTC / 16:30 UTC") — **UNMEASURED**, 0 work items (`farm_state.sqlite work_items` empty for 41475/41476/41477/41479/41480). |
| **Trade density** | Book 0.526 trades/bd. Best sleeve 10706 @0.168. Non-roster measured streams reach 0.744 (13213 USDJPY) and 0.727 (11660 NDX). | 41477 claims 55–85/mo ≈ 2.6–4.0/bd; 41475 55–65/mo ≈ 2.7–3.1/bd; 41476 6–15/mo ≈ 0.3–0.7/bd; 41480 12–20/mo ≈ 0.6–1.0/bd (cards §"Expected frequency") — all **UNMEASURED**. Second-chance 11211/11855/11373/11563: **never built, card-only** (`SECOND_CHANCE_SHORTLIST_2026-09-16.md` §2; `second_chance_funnel.json` furthest stage = `new-lineage-card` for all four). |
| **Short holding** | 10706 (7.4 h) only. Non-roster 13213 USDJPY 7.2 h, 13013 NDX 2.6 h. | 41477 M15 intraday, 41475/41476 H1 session — UNMEASURED. |
| **Low overnight** | 10706 46%; non-roster 13213 **0%**, 13013 15.7%, 11660 40%. | Six of eight sleeves ≥74%; 20048 and 21505 are 100% overnight. |
| **Low swap** | 6 of 8 sleeves: swap exactly 0.00 in stream (`swap` field). 11421 −8.63/trade, 11910 −4.00/trade. | **Swap = 0.00 is a modelling artefact for most sleeves, not a measurement** — the demo journal shows only −14.73 USD over 8 entry days (`FTMO_CHALLENGE_READINESS.md`). Real live swap on the FTMO venue is UNMEASURED. |
| **Bounded intraday loss** | P(daily-loss breach) = **0.0** in all 5 cost scenarios, all 3 chain stages (`.chain.stages.*`). Worst simulated book day −763 USD = −0.76% vs the 5% limit. | MAE proxy is per-trade, not tick-exact (`.label`, `.method`). True intraday path UNMEASURED. |
| **Predictable exits** | Time-stop clustering visible (21505 p50 = p90 = 116 h; 11910 116.9 h; 20048 72 h) → deterministic time exits. | Per-sleeve exit-reason breakdown is not in the streams — **UNMEASURED**. |
| **Recovery after loss** | Max consecutive losers: 20048 3, 11421 4, 13054 4, 11910/21505 5, 1537 6, 11422 8, 10706 9. Demo journal max losing streak 3. | Recovery *time* distribution UNMEASURED. |
| **Stable positive drift** | Positive-year share: 10706 8/9; 11421, 11422, 20048 6/8; 11910, 1537, 21505 5/7–5/8; **13054 only 4/8**. | 13054 and 20048 contribute +4.83R and +1.16R total over ~8 years — economically near-null. |
| **Low dependence on rare winners** | 10706 top-5 wins = 16.4% of gross wins; 11422 10.9%; book-wide fine. | **11910 45.0%, 1537 38.9%, 20048 33.1%, 13054 29.8%** — four sleeves are rare-winner dependent. |
| **Low tail dependence** | **Strong.** All 28 roster pairs: max \|r\| = 0.143 (1537~21505); every other pair \|r\| ≤ 0.08. Zero roster pairs exceed 2× the independence baseline in lower-decile-day overlap. Corroborated by `evidence.md` ENB 7.52 of 8. | Tail overlap vs *candidates*: 1537~21507 tailX 4.11, 21505~10145 tailX 4.69, 11421~10700 tailX 5.56 — adding XAU/XAG streams imports tail overlap. |
| **Realistic execution** | Cost sensitivity measured: LCB 0.6571 → 0.6059 at cost ×1.5 + 2 USD/lot (`.chain.sensitivity`). Commission present in 10706 (−29.28/trade), 13213 (−26.31), 11422 (−9.07). | **Spread is zero on `.DWX`** — critiques M4/M-SPREAD (`critique_41477…md`). Live slippage on the FTMO venue UNMEASURED. 41477 round-trip cost ≈0.85 pip vs ≈8.75 pip TP ≈ 0.12R/trade (RECEIPT.md §"Cost fragility"). |

---

## 2. Why the roster is slow — speed decomposition

`time_to_target ≈ 10,000 USD / (density × E[R]/trade × risk_per_trade × 100,000)`.

Measured now: **0.526 trades/bd × +0.0976R × 0.3125%** → **16.02 USD/bd** → naive 624 bd; the engine's median is 439 bd
because first passage is inverse-Gaussian-shaped (median ≈ 0.70 × mean).

**Model validation.** An independent resampler built for this document (Poisson arrivals, empirical per-trade R shape
sd 1.374R, FTMO stops applied) reproduces the engine at the roster's own parameters: median **449.5 bd** vs engine 439,
P(target) **0.8156** vs 0.8163, P(max-loss) **0.0157** vs 0.0244. A calendar-block bootstrap over the actual combined
daily series reproduces it even more closely: **440 bd / 0.820 / 0.021**. Both agree, so the frontier below is sound.

**Frontier to a median ≤90 business days, FTMO stops enforced (target +10k, max loss −10k, daily −5k):**

| risk/trade | density/bd | E[R]/trade | R/bd | USD/bd | median bd | P(target) | P(max-loss) | worst day p95 |
|---|---|---|---|---|---|---|---|---|
| 0.50% | 1.5 | +0.10 | 0.150 | 75 | 98 | 0.909 | **0.068** | −2,057 |
| 0.50% | 1.0 | +0.15 | 0.150 | 75 | 113 | 0.958 | 0.015 | −1,686 |
| **0.50%** | **1.0** | **+0.20** | **0.200** | **100** | **93** | **0.993** | **0.002** | **−1,575** |
| 0.50% | 1.0 | +0.25 | 0.250 | 125 | 77 | 0.999 | 0.000 | −1,397 |
| **0.25%** | **2.0** | **+0.20** | **0.400** | **100** | **97** | **1.000** | **0.000** | **−1,001** |
| 0.25% | 3.0 | +0.10 | 0.300 | 75 | 114 | 0.976 | 0.004 | −1,370 |

**Reading.** The requirement is ≈**100 USD/bd of drift** (0.10%/bd), i.e. **6.2× the current book**. It can be bought
with density *or* edge, but **not with density at low edge**: at E[R] ≤ +0.10R the same speed costs 4–7% max-loss
breach probability. The clean corners are **1 trade/bd at +0.20R at 0.5% risk** or **2 trades/bd at +0.20R at 0.25%**.

**Daily-Loss headroom is not the constraint.** P(daily-loss breach) = 0.0 everywhere, including the frontier configs:
worst-day p95 −1,000 to −2,100 USD = **1.0–2.1% against a 5.0% limit → 2.9–4.0 pp headroom**; worst simulated single
day −3,500 USD (3.5%). **Max Loss (10% static) is the only binding rule** — 244/244 Phase-1 breaches and 175/175
Verification breaches are `max_loss`, zero `daily_loss` (`.chain.stages.*.conditional_failure_modes.by_type`).
Breach concentration: **GBPUSD/10706 46.7%**, USDCAD/11422 20.9%, EURUSD/11421 13.9%; **Friday 42.2%** of breaches.
So the fastest sleeve is also the dominant breach carrier.

---

## 3. Independence

**The current 8 are genuinely independent, and that is not the problem.** Measured pairwise daily-P/L correlation over
the common span: maximum \|r\| = **0.143** (1537 XAGUSD ~ 21505 XAGUSD, same symbol), every other pair \|r\| ≤ 0.08;
lower-decile-day co-occurrence never reaches 2× the independence baseline for any roster pair. `evidence.md` reports
**ENB 7.52 of 8 sleeves** and 28 dependence-panel entries with 0 advisory cap warnings.

**Where redundancy would be imported:**
- **1537 ~ 21507 XAUUSD** r=0.301 tailX 4.11; **1537 ~ 10145** r=0.292 tailX 2.22; **21505 ~ 10145** tailX 4.69;
  **21507 ~ 10145** r=0.609 tailX 5.36. Adding a second XAU stream to a book already carrying two XAG sleeves buys
  little and imports tail overlap.
- **Exact duplicate streams in the snapshot:** `13213_USDJPY ≡ 21501_USDJPY` and `11421_EURUSD ≡ 41221_EURUSD`
  (byte-identical P/L sequences). Treating either pair as two sleeves would be a fictitious diversification claim.
- **H-CW (41475) vs H-MR (41476):** RECEIPT.md records ~80% shared strategy-module code, disjoint triggers
  (close-outside vs pierce-and-close-inside cannot co-fire on the same bar) but **the same symbols (NDX/GDAXI/SP500),
  the same UTC session window, the same shock/spread/news filters and the same flatten hour**. Their losing days are
  structurally likely to coincide; RECEIPT.md itself defers this to "must be correlation-measured at Q08". **UNMEASURED.**
- **H-PY2L (41480) vs H-CW (41475):** the card states H-PY2L *reuses the H-CW session-flat envelope* — same entry
  shell plus a pyramid leg. This is a **leveraged variant, not an independent sleeve**; its own card §"Refuted if"
  forbids a book claim before the joint-tail protocol passes against H-CW/H-MR.
- **H-FXMR (41477)** is the only new candidate on a different asset class (EURUSD/GBPUSD/USDJPY M15) and different
  timeframe from the index trio — the strongest independence prior, still UNMEASURED.
- **Second-chance 11211 (M15 BB-MR, 4 symbols), 11855 (M5 EURUSD scalp), 11373 (USDJPY daily-range bracket),
  11563 (Connors RSI2 D1):** never built; independence UNMEASURED. 11563 is a D1 mean-reversion — the same
  low-density swing class the roster already has too much of.

---

## 4. Gap classification

Composition experiments run for this document (calendar-block bootstrap, block 10 bd, 10,000 paths, seed 20260915,
FTMO stops enforced, Phase-1 only; drawn **only from streams already present in the frozen snapshot**):

| Composition | book risk | drift USD/bd | median bd | P(target) | P(max-loss) |
|---|---|---|---|---|---|
| A — current `demo_8` @0.3125% | 2.50% | 16.0 | 440 | 0.820 | 0.021 |
| A3 — `demo_8` @1.0% | 8.00% | 51.3 | 91 | 0.758 | **0.242** |
| C — 8 highest-drift measured streams @0.3125% | 2.50% | 46.9 | **171** | **0.977** | **0.022** |
| C @0.4375% | 3.50% | 65.7 | 110 | 0.938 | 0.062 |
| all 23 measured streams @0.20% | 4.60% | 39.1 | 226 | 0.997 | 0.002 |
| all 23 @0.375% | 8.62% | 73.2 | **105** | 0.964 | **0.036** |

**Classification — the gap is in three parts, in this order of size:**

1. **~40% closable by composition, at zero new research cost.** At the *identical* 2.5% book risk, a different
   eight-sleeve selection from the same frozen snapshot (13213 USDJPY, 10700 XAUUSD, 10706 GBPUSD, 11422 USDCAD,
   11660 NDX, 21507 XAUUSD, 12855 XTIUSD, 13013 NDX) yields median **171 bd instead of 440**, P(target) **0.977
   instead of 0.820**, at **equal** breach probability (0.022 vs 0.021). The current roster is dominated on both axes.
   Most of the current roster's chain loss is **censoring (0.1593), not breaching** — 15.9% of paths simply never
   arrive. The single largest measured sleeve outside the roster, 13213 USDJPY, is 0.744 trades/bd at +0.064R with
   **0% overnight exposure and 7.2 h median hold** — the exact behaviour profile the three new candidates are being
   built to obtain, already measured and already in the snapshot.
2. **~30% only perceived, because evidence is missing.** Five FTMO-shaped candidates (41475, 41476, 41477, 41479,
   41480) have **zero work items** — no Q02 evidence exists. Four second-chance records are card-only. The
   `P_FIRST_NET_FTMO_PAYOUT_LCB` is computed on a roster that has not been re-selected since 2026-09-15
   (`ftmo_demo_cycle.json` roster_hash `6c5383d8…9bf2`, first seen 2026-09-15T14:12:11Z).
3. **~30% genuinely needs new strategy.** Even the best composition of *everything measured* reaches median 105 bd
   only at 8.6% book risk with P(max-loss) 3.6%. Nothing in the measured pool delivers **≥1 trade/bd at ≥+0.20R** —
   the only combination that reaches median ≤90 bd with breach probability ≈0. That cell is exactly what H-FXMR
   claims (2.6–4.0 trades/bd) and exactly what is unproven.

**Risk allocation alone does not close it.** Scaling the current roster to 8% book risk hits median 91 bd but takes
P(max-loss) to **24.2%** — the chain would fall far below today's 0.699.

---

## 5. Top-5 next actions for `FTMO_NET_CASH_REALIZED`

| # | Action | Decision it changes | Factory hours | Falsification criterion |
|---|---|---|---|---|
| 1 | **Re-run the v2 chain engine on 3–5 alternative rosters drawn from the 23 already-measured snapshot streams** (incl. the top-drift 8 of §4), same seed/manifest discipline, all three stages. | Whether the Demo roster should be re-selected *before* any new EA lands — the largest measured lever, no backtests needed. | **0 factory hours** (engine-only, minutes of CPU). | Falsified if no alternative roster beats `demo_8` on **both** `P_FIRST_NET_FTMO_PAYOUT_LCB` and end-to-end median at ≤2.5% book risk. My Phase-1 bootstrap says one does; Verification+funded stages are **not** recomputed here. |
| 2 | **Q02 fan-out for 41477 H-FXMR on EURUSD/GBPUSD/USDJPY `.DWX` at `RISK_FIXED=250`** (live-equivalent 0.25%, per critique M1) rather than the default 1,000. | Whether the one candidate that can close the density gap is real, measured at the sizing its FTMO thesis rests on. | ~6–10 h (3 symbols × full history, M15). | Killed if realized density < 15 active days/month/symbol, or net expectancy < +0.10R after costs, or ±1-step neighbourhood majority-negative (card §"Falsification"). |
| 3 | **Measure the H-CW/H-MR/H-PY2L joint-tail panel before any of them is proposed as a second sleeve** — they share symbols, session window and filters. | Whether the index trio counts as one sleeve or three; prevents a fictitious ENB gain. | ~8–12 h (Q02 on 41475 + 41476, 3 symbols each; 41480 deferred behind them). | Falsified if pairwise daily-P/L \|r\| > 0.30 or lower-decile co-occurrence > 2× independence — then only one of the three may enter a book. |
| 4 | **Attack the breach concentration instead of the whole book:** 10706 GBPUSD causes 46.7% of Phase-1 and 43.4% of Verification breaches and 42.2% of breaches fall on Friday. Measure a Friday-flat / reduced-Friday-size variant and a per-sleeve risk re-allocation of 10706. | Whether the 5–7× speed target can be reached at higher per-sleeve risk without the max-loss cost — 10706 is also the highest-E[R] roster sleeve (+0.192R). | ~2–4 h (re-scored from existing streams; a Friday-flat variant needs one Q02 rerun). | Falsified if removing Friday entries reduces 10706's drift by more than it reduces book P(max-loss) — i.e. if the Friday concentration is drift, not tail. |
| 5 | **Close the two economic GAPs that bound the KPI itself:** the live 100k 2-Step **fee amount** (rules snapshot §Gaps 1 — currently the rulepack list 540 USD, `.economics.fee_source = RULEPACK_LIST_FEE`) and the **live FTMO-venue spread/swap** from the Demo terminal's Market Watch (§Gaps 3). | The net-positive condition and the cost scenario that the LCB is reported under; median net cash is only 521.80 USD, so a wrong fee is ~100% of the first payout. | 0 factory hours (order page + Demo Market Watch read). | Falsified if the observed order-page fee and the observed live spread both fall inside the modelled band (540 USD; cost ×1.0–×1.5) — then the current LCB stands unchanged. |

---

## 6. Assumptions and unverified numbers

1. **All per-sleeve statistics in §1a/§2/§3/§4 were computed by this analysis from the manifest streams**, not read
   from a read-model. They are reproducible from the eight `stream_sha256` values in
   `D:/QM/reports/state/ftmo_first_passage_manifest.json`. Assumption: `1R = 1,000 USD` (the manifest's
   `source_risk_pct: 1.0` against 100k) — consistent with the observed loss cluster at −0.99R to −1.05R.
2. **§2 frontier and §4 compositions are Phase-1 only.** Verification and funded-stage probabilities are **not**
   recomputed for any alternative composition. The end-to-end claim in §4 item 1 is therefore a Phase-1 claim; action 1
   exists precisely to close that.
3. **§4 compositions are diagnostics, not book proposals.** They ignore the advisory family/symbol caps, contain
   XAU concentration, and one candidate pair (13213/21501, 11421/41221) is a byte-identical duplicate that must never
   be double-counted. Book construction is OWNER-only (ROT).
4. **Overnight share** is computed as entry-date ≠ exit-date in UTC, not against broker rollover time. Sleeves with
   100% overnight (20048, 21505) are unambiguous; borderline sleeves may shift by a few percent.
5. **Swap = 0.00 in six of eight streams is a modelling artefact**, not evidence of a swap-free strategy. The only
   real swap observation is −14.73 USD over 8 demo entry days (`FTMO_CHALLENGE_READINESS.md`) — far too short to
   verify the cards' "realized swap < 10% of gross P&L" kill criterion. **UNMEASURED.**
6. **Spread is zero on `.DWX`** — every expectancy figure here is commission-inclusive but spread-free.
7. **The −10.26% realized demo max-DD** that drives NOT_READY is reported as "worst across cycles"; the *current*
   cycle's realized max-DD is −0.2856%. Which prior cycle produced it, and under which roster, is **not** resolvable
   from `ftmo_demo_cycle.json` (its `roster_history` holds exactly one entry). **UNVERIFIED.**
8. **Candidate density/expectancy figures are card claims from in-sample, zero-cost, single-feed Dukascopy pilots**
   (41476: 2.9 trades/mo, PF(R) 1.12, +0.02R — *below* its own success bar; 41480: PF(R) 1.26, +0.12R/basket, level-3
   reach 0%). 41475 has **no pilot fire count at all** in its card. None has farm `.DWX` evidence.
9. **Critique B-WINDOW (RECEIPT.md) roughly halves 41476's real signal set** versus the pilot the card quotes — so
   even the 2.9/mo figure is optimistic for the as-built binary before the fix.
10. **Fee 540 USD and profit split 80% / 100% fee refund** come from the rulepack, not the live order page
    (`.economics.fee_source = RULEPACK_LIST_FEE`); a 20%-off promotion was visible on 2026-09-18.
11. **UNMEASURED throughout:** live slippage on the FTMO venue; per-sleeve exit-reason distributions; recovery-time
    distributions; any Q02+ evidence for 41475/41476/41477/41479/41480 (`work_items` returns zero rows for all five);
    any build for 11211/11855/11373/11563.

---

## 7. Adversarial read — the single strongest economic failure reason per new candidate

- **QM5_41475 H-CW** — *the session-flat envelope caps the edge below the level its density needs.* Fixed
  1.75× target_r on a 1.0×ATR stop, one entry/symbol/day, mandatory flat at 20:00 UTC and a time stop: the winners are
  truncated by the clock while the losers are full-R. Its own critique (M-DST) shows the "cash-open" anchor is
  **5–6 hours late for GDAXI** and drifts ~1 h against the US open across DST, so a third of the symbol set has no
  mechanism at all. At ≈3 trades/bd it must still clear +0.10R net to matter; a clock-truncated 1.75R breakout on
  three co-moving indices is the classic configuration that prints +0.02R after costs. **And the card carries no
  pilot fire count** — unlike its two siblings, its density claim (18–22/mo/symbol) is pure structural inference.
- **QM5_41476 H-MR** — *it is already known to be below its own kill floor.* The card's own pilot reports
  **PF(R) 1.12 at +0.02R/trade**, versus a preregistered kill bar of PF ≥ 1.20 and ≥ +0.10R; the critique's B-WINDOW
  finding then halves the signal set, taking 2.9 trades/mo/symbol toward ~1.5 — under the card's own "≥3 active
  days/month" criterion. A candidate that fails its kill criteria in-sample, zero-cost, on its author's own feed has
  essentially no path to passing Q08 after costs. It should be last in the Q02 queue, not third.
- **QM5_41477 H-FXMR** — *cost eats the target.* Round-trip ≈0.85 pip against an ≈8.75 pip TP is **≈0.12R per trade**
  (RECEIPT.md), so the thesis needs gross ≥ +0.22R merely to clear +0.10R net — on an M15 EMA-reclaim whose
  alternative trigger (run-of-closes) has **no magnitude floor** and will dominate signal count with noise
  (critique M2). Worse, the whole cost estimate is spread-free: `.DWX` models zero spread, and M15 FX mean reversion
  in the first minutes of London/NY is exactly where real spread widens. This is the candidate that *can* close the
  speed gap and the one whose economics are most likely to invert once a true spread is applied.

---

*Generated 2026-09-18 by the research-analyst seat. Read-only: no farm-DB write, no gate transition, no verdict,
no weight, no terminal start, no AutoTrading toggle. This document is the only file created.*
