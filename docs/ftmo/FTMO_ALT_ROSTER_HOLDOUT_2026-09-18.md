# FTMO alt-roster holdout, common-window, LOO and concentration study (2026-09-18)

**Role:** DECISION_SUPPORT_EVIDENCE. Author: quantitative-engineer seat (read-only on repo, farm DB
and MT5). **Nothing here constructs a book, sets a weight, changes a gate, selects a Demo roster or
authorises a purchase** — all ROT / OWNER-only. No git write, no farm-DB write, no MT5, no
AutoTrading, no change to any live read-model.

**Purpose.** Resolve, with deterministic evidence rather than opinion, the statistical objections in
the adversarial cross-vendor critique `D:\QM\reports\ai_exchange\20260918_alt_roster_critique_agy\agy_critique.md`
against `docs/ftmo/FTMO_ALT_ROSTER_CHAIN_2026-09-18.md`:
finding **1** (selection bias / winner's curse, no holdout), **6** (window asymmetry: demo_8's pool
ends 2024-12-06 while the alternatives run to 2025-12, never chain-evaluated on a common window),
**4** (breach monoculture on 13213 USDJPY), **5** (2.0 % as the rational risk under
probability-over-speed). Findings **2** (venue mapping, setfiles, magics, news filter) and **3**
(swap / financing drag on overnight gold and oil) are **operational, not statistical — this study
does not address them and they are restated as standing blockers in §7.**

**Engine (unchanged).** `tools/strategy_farm/ftmo/first_passage.py build`, schema
`qm.ftmo-first-passage/v2`, engine `2.0.0`, KPI contract `v1`, all three chain stages
(Challenge → Verification → funded → first net payout), pathwise. Rulepack
`FTMO_2S_100K_STANDARD_V2` as_of 2026-09-15. **Identical parameters to the primary run:** seed
`20260915`, 10,000 paths, block 10 bd, horizon 1,008 bd, funded horizon 120 bd, 20 CI batches, the
same five cost scenarios `(×1.0, +0/+1/+2 USD/lot)`, `(×1.5, +0/+2)`.

**Windowing method.** The engine takes no window argument (verified against its `build` parser), so a
window is realised by writing **truncated copies** of the frozen W38 streams plus a derived
`qm.recompose-frozen-inputs/v1` manifest carrying the sha256 of each truncated file — the engine
re-verifies every sha at load, so the pin still binds. Truncation keeps a `TRADE_CLOSED` row iff it is
**fully contained** in the window (close-day in `[start, end]` **and** entry-day ≥ `start`, both in
Europe/Prague, the day mapping `sleeve_daily` uses). Full containment is required because
`sleeve_daily` marks the **entry** day as an opening day; a close-time-only filter would leak opening
days before the window start and drag the engine's intersection window backwards. Lines are copied
byte-verbatim, never rewritten. 0 sleeves dropped, 0 sha mismatches in every run.

**Evidence folder (new, created by this study):**
`D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\holdout\`
— `holdout_lib.py`, `step_a_holdout.py`, `step_bcd.py`, `step_e_risk.py` (the scripts),
`a_selection_train.json`, `a_drift_shrinkage.json`, `a_results.json`, `bcd_results.json`,
`e_risk_results.json`, `holdout_summary.json`, per-run `<label>.json` + `<label>_manifest.json`,
the truncated stream sets `streams_{train,test,testcommon,testall,common}/` with their
`streams_*_index.json`, and the derived manifests `manifest_{test,testcommon,common,loo,half13213}*.json`
(the train window needs no manifest — it is used only to re-derive the selection, never simulated).
Inputs: the frozen W38 snapshot `snapshot_r2` and the existing
`roster_definitions.json` / `stream_stats.json` / `comparison.json` of the primary run. Every run used
`--out` / `--manifest-out` into the holdout folder; the live read-models were **not** written —
`D:\QM\reports\state\ftmo_first_passage.json` and `…_manifest.json` still carry mtime 2026-09-15 20:00,
`…_v2_preview.json` mtime 2026-09-18 02:33 (both predate this study).

---

## A. Temporal holdout — does the R2 selection rule survive out-of-sample?

**Train** = each stream's own start … **2022-12-31**. The R2 rule is re-applied *verbatim* on train
data only: rank by own-span drift USD/bd at 0.3125 %, take the top 8 subject to symbol ≤2, family ≤3,
duplicates (`21501:USDJPY`, `41221:EURUSD`) excluded. **Test** = 2023-01-01 … stream end. The train
selection never sees a single test-window trade.

**R2_train** = `13213 USDJPY, 10706 GBPUSD, 10700 XAUUSD, 11660 NDX, 11422 USDCAD, 10145 XAUUSD,
12710 XTIUSD, 12849 XTIUSD` — **7 of 8 identical to R2_capped**; the one difference is
`12849 XTIUSD` (family `brent`) where the full-sample rule takes `20266 XTIUSD` (family `collins`).
The rule is therefore **stable in time**, not a full-sample artefact (`a_selection_train.json`).

Because demo_8's sleeve `1537 XAGUSD` still ends 2024-12-06, the plain test window remains
asymmetric; a second, **common test window** `2023-01-01..2024-12-06` is therefore reported as well.

| Window | Roster | risk | E2E | **LCB** | p10/**p50**/p90 bd | P(daily) | P(maxloss) P1 | cost ×1.5+2 E2E | engine window (bd) |
|---|---|---|---|---|---|---|---|---|---|
| TEST 2023-01-01..end | **R2_train** (OOS) | 2.50 | 0.9800 | **0.9716** | 132/**234**/418 | 0.0 | 0.0031 | 0.9690 | 2023-01-27..2025-12-05 (746) |
| TEST | R0_demo8 | 2.50 | 0.4972 | **0.4480** | 416/**828**/1305 | 0.0 | 0.0505 | 0.4214 | 2023-07-31..2024-12-06 (355) |
| TEST | R2_capped (in-sample ref) | 2.50 | 0.9812 | **0.9739** | 131/**233**/411 | 0.0 | 0.0028 | 0.9694 | 2023-01-27..2025-12-05 (746) |
| TESTCOMMON 2023-01-01..2024-12-06 | **R2_train** (OOS) | 2.50 | 0.9476 | **0.9320** | 147/**276**/513 | 0.0 | 0.0140 | 0.9162 | 2023-01-27..2024-11-15 (471) |
| TESTCOMMON | R0_demo8 | 2.50 | 0.4092 | **0.3852** | 409/**826.5**/1312 | 0.0 | 0.0780 | 0.3389 | 2023-07-31..2024-11-06 (333) |
| TESTCOMMON | R2_capped (in-sample ref) | 2.50 | 0.9621 | **0.9519** | 146/**268**/496 | 0.0 | 0.0071 | 0.9368 | 2023-01-27..2024-11-15 (471) |

`low_power` is `false` ("adequate") for **every** run above.
demo_8's shorter engine window is not a truncation artefact of this study — its sleeve
`11910 NZDUSD` places its first post-2023 trade on 2023-07-31 (26 trades in three years), and the
engine intersects on all-active spans.

**Answer to the task question: yes — R2_train beats demo_8 out-of-sample on BOTH axes, in both test
windows, by very wide margins** (LCB 0.9716 vs 0.4480 and 0.9320 vs 0.3852; median 234 vs 828 and
276 vs 826.5 business days).

**Bounding the winner's curse directly.** Two independent measurements:

1. **Honest-selection penalty.** On the same test window, the honestly-selected R2_train scores
   LCB 0.9716 against the full-sample (contaminated) R2_capped's 0.9739 — a penalty of **0.0023 LCB
   and +1 bd of median**. On TESTCOMMON the penalty is **0.0199 LCB and +8 bd**. The optimism the
   critique demands be bounded is therefore **0–2 LCB points**, against a demo_8 gap of **52–57 LCB
   points**.
2. **Drift shrinkage across the 24-stream universe** (`a_drift_shrinkage.json`): Spearman rank
   correlation train→test **0.4374** (Pearson 0.5445) — persistent but genuinely noisy, as the
   critique asserts. The selected eight earn **2.58×** the universe mean drift in train and still
   **2.07×** out-of-sample (premium shrinkage ≈ 20 %); demo_8's eight earn 0.89× in train and 0.82×
   in test. **No** selected sleeve has non-positive test-window drift. The order statistics do decay,
   but nowhere near enough to close the gap.

**The critique's own worry cuts the other way.** demo_8 was itself a selected roster, and it decays
hardest: LCB 0.6571 on its full sample → **0.4480** on 2023+ data it did not select on. The current
Demo roster is the strongest in-sample-optimism case in the comparison.

## B. Common window — is the gap regime or composition?

Largest window common to **all** streams of demo_8 ∪ R2_capped: **2018-11-02 .. 2024-12-06**, binding
at both ends by `1537 XAGUSD`. Both rosters truncated to it and run through the **full chain**
(the primary run's §4 only compared deterministic sample moments on this window; this is the
pathwise chain evaluation the critique asked for).

| Roster @2.5 % | E2E | **LCB** | **p50 bd** | P(daily) | P(maxloss) P1 / Ver | cost ×1.5+2 E2E | engine window (bd) |
|---|---|---|---|---|---|---|---|
| R0_demo8 | 0.6667 | **0.6458** | **752.0** | 0.0 | 0.0219 / 0.0216 | 0.6085 | 2018-11-29..2024-11-06 (1,550) |
| R2_capped | 0.8790 | **0.8634** | **322.5** | 0.0 | 0.0441 / 0.0407 | 0.8016 | 2018-12-03..2024-11-15 (1,555) |

**The critique is partly right and the verdict is unchanged.** Removing the 2025 tail costs R2_capped
**0.0425 of LCB** (0.9059 → 0.8634) and **nearly doubles its Phase-1 max-loss probability**
(0.0256 → 0.0441, now *twice* demo_8's 0.0219), while demo_8 barely moves (0.6571 → 0.6458). So a
real part of R2's headline safety margin is 2025 regime, and R2 is **not** the calmer book on equal
days — it is the faster one. But on identical days R2 still beats demo_8 on both control axes
(LCB +0.2176, median −429.5 bd) and under the worst cost stress (0.8016 vs 0.6085). Finding 6 is a
**valid haircut, not a refutation**.

## C. Leave-one-out robustness of R2_capped

Each sleeve removed in turn; the remaining 7 carry 0.3125 % each → book risk **2.1875 %** (per the
task specification; the lower book risk is itself worth ~2–3 LCB points, so these are not directly
comparable to the 2.5 % rows). Full untruncated snapshot streams. Verdict test = beats demo_8
full-sample on **both** LCB > 0.6571 and median < 746 bd.

| Removed sleeve | E2E | **LCB** | **p50 bd** | P(maxloss) P1 | verdict preserved |
|---|---|---|---|---|---|
| 13213 USDJPY | 0.9461 | 0.9255 | 402.0 | 0.0076 | **yes** |
| 10706 GBPUSD | 0.9314 | 0.9160 | 373.0 | 0.0166 | **yes** |
| 20266 XTIUSD | 0.9244 | 0.9097 | 294.0 | 0.0241 | **yes** |
| 11660 NDX | 0.9237 | 0.9078 | 325.0 | 0.0224 | **yes** |
| 11422 USDCAD | 0.9194 | 0.9076 | 300.0 | 0.0272 | **yes** |
| 10145 XAUUSD | 0.9137 | 0.8960 | 303.0 | 0.0297 | **yes** |
| 12710 XTIUSD | 0.9079 | 0.8928 | 308.0 | 0.0297 | **yes** |
| 10700 XAUUSD | 0.8972 | 0.8739 | 351.0 | 0.0339 | **yes** |

**No sleeve is load-bearing for the verdict — all 8 variants preserve it**, with LCB spanning only
0.8739–0.9255 and median 294–402 bd. The result does not rest on any single stream, which is the
structural form of the concern in finding 1. Note the sign: dropping **13213 USDJPY** *raises* LCB
(0.9255, the best LOO) and cuts Phase-1 max-loss to 0.0076 while costing 114 bd of median — the
speed/breach trade-off is concentrated exactly where the critique said it was.

## D. Concentration — breach share vs drift share

Breach shares are Phase-1 dominant-sleeve attributions from the engine; drift share is each sleeve's
own-span drift USD/bd at 0.3125 % as a fraction of the roster total (47.098). A ratio > 1 means the
sleeve buys more breach than it pays for in drift.

| Sleeve | breach share @2.5 % | breach share @2.0 % | drift share | breach/drift @2.5 % |
|---|---|---|---|---|
| **13213 USDJPY** | **0.5352** | **0.5978** | 0.3178 | **1.68** |
| 11660 NDX | 0.1406 | 0.1304 | 0.1043 | 1.35 |
| 10706 GBPUSD | 0.1328 | 0.1196 | 0.2137 | 0.62 |
| 10700 XAUUSD | 0.1055 | 0.1413 | 0.1920 | 0.55 |
| 11422 USDCAD | 0.0273 | 0.0000 | 0.0594 | 0.46 |
| 10145 XAUUSD | 0.0273 | 0.0109 | 0.0576 | 0.47 |
| 20266 XTIUSD | 0.0273 | 0.0000 | 0.0284 | 0.96 |
| 12710 XTIUSD | 0.0039 | 0.0000 | 0.0268 | 0.15 |

(256 Phase-1 breaches at 2.5 %, 92 at 2.0 %.) **Finding 4 is confirmed and it gets worse, not better,
when the book is de-risked uniformly:** cutting book risk 2.5 → 2.0 % removes 64 % of breaches but
*raises* 13213's share of the survivors to 59.8 %. Uniform de-risking is the wrong instrument for a
concentration defect.

**Variant: 13213 USDJPY risk halved to 0.15625 %, the other seven unchanged at 0.3125 %**
(book risk 2.34375 %), full untruncated streams, same engine parameters:

| Variant | book risk | E2E | **LCB** | **p50 bd** | P(maxloss) P1/Ver/Fund | 13213 breach share | cost ×1.5+2 E2E / LCB |
|---|---|---|---|---|---|---|---|
| R2_capped | 2.500 % | 0.9223 | 0.9059 | 288.0 | 0.0256/0.0213/0.0035 | **0.5352** | 0.8772 / — |
| R2_capped @2.0 % | 2.000 % | 0.9489 | **0.9337** | 367.0 | 0.0092/0.0078/0.0011 | **0.5978** | 0.9115 / — |
| **R2_capped, 13213 halved** | 2.344 % | 0.9531 | **0.9293** | **344.0** | 0.0086/0.0076/0.0009 | **0.1163** | 0.9293 / 0.9059 |

Breach attribution in the halved variant spreads to 10700 XAUUSD 0.244, 10706 GBPUSD 0.233,
11660 NDX 0.209, 11422 USDCAD 0.128, 13213 USDJPY 0.116 — **the monoculture is dissolved** (86 total
Phase-1 breaches vs 256). It delivers essentially the LCB of the 2.0 % book (−0.0044) with a **23 bd
faster median**, a *lower* Phase-1 max-loss than the 2.0 % book (0.0086 vs 0.0092), and it survives
the worst cost stress better (E2E 0.9293 vs 0.9115).

**Out-of-sample confirmation of the same lever** on the honestly-selected R2_train (same test windows
as §A, `e_risk_results.json`):

| Window | Variant | book risk | E2E | **LCB** | **p50 bd** | P(maxloss) P1 |
|---|---|---|---|---|---|---|
| TEST | R2_train @2.0 % | 2.000 % | 0.9845 | 0.9777 | 291.0 | 0.0012 |
| TEST | **R2_train, 13213 halved** | 2.344 % | 0.9899 | **0.9839** | **259.0** | 0.0006 |
| TESTCOMMON | R2_train @2.0 % | 2.000 % | 0.9650 | 0.9579 | 344.0 | 0.0037 |
| TESTCOMMON | **R2_train, 13213 halved** | 2.344 % | 0.9835 | **0.9759** | **283.0** | 0.0005 |

The halved-13213 variant **dominates the uniform 2.0 % book on both control axes out-of-sample, in
both test windows** — it is not a full-sample artefact.

---

## E. Verdict table

| # | Question | Evidence | Result |
|---|---|---|---|
| 1 | Does the R2 rule survive a temporal holdout? | §A, `a_results.json` | **YES** — R2_train (fit ≤2022-12-31) LCB 0.9716 / p50 234 bd vs demo_8 0.4480 / 828 bd on 2023+ |
| 2 | Same on a common test window (no window asymmetry)? | §A TESTCOMMON | **YES** — 0.9320 / 276 bd vs 0.3852 / 826.5 bd |
| 3 | Falsification rule (beat demo_8 on **both** LCB and median, OOS)? | §A | **NOT FALSIFIED** — passed in both test windows |
| 4 | How large is the winner's curse? | §A, `a_drift_shrinkage.json` | **0.002–0.020 LCB** (honest vs contaminated selection); drift premium 2.58× → 2.07×; Spearman 0.437 |
| 5 | Is the gap window/regime rather than composition? | §B | **PARTLY** — common window costs R2 0.0425 LCB and doubles P1 breach to 0.0441, but R2 still wins both axes (+0.2176 LCB, −429.5 bd) |
| 6 | Does the verdict depend on any single sleeve? | §C | **NO** — all 8 LOO books beat demo_8 on both axes; LCB 0.874–0.926 |
| 7 | Is 13213 USDJPY a breach monoculture? | §D | **YES** — 53.5 % of P1 breaches on 31.8 % of drift (ratio 1.68); uniform de-risking *raises* it to 59.8 % |
| 8 | Is uniform 2.0 % the rational risk (critique 5)? | §D | **NO — dominated.** 13213-halved @2.344 % gives LCB 0.9293 at 344 bd and P1 breach 0.0086 vs 2.0 %'s 0.9337 / 367 bd / 0.0092, with the concentration removed |
| 9 | Does that lever hold out-of-sample? | §D OOS table | **YES** — halved variant beats uniform 2.0 % on both axes in both test windows |
| 10 | Is deployment therefore safe? | §7 | **NO** — critique findings 2 (venue/symbol/magic/setfile/news filter) and 3 (swap & weekend financing on 4 overnight gold/oil sleeves) are untouched by this study and remain blocking |

## Resolution

The critique's statistical objections do not survive measurement, but its risk-policy conclusion is
improved on rather than upheld. Re-deriving the R2 rule on data ending 2022-12-31 reproduces seven of
its eight sleeves, and that honestly-selected roster beats demo_8 out-of-sample on **both** control
axes — LCB 0.9716 vs 0.4480 and median 234 vs 828 business days on 2023+, and 0.9320 vs 0.3852 /
276 vs 826.5 on the common test window that removes the window asymmetry entirely. The winner's curse
is real but small where it matters: the honest-selection penalty is 0.002–0.020 LCB against a 52–57
point gap, the selected sleeves' drift premium decays only from 2.58× to 2.07× of the universe mean,
no selected sleeve turns negative out-of-sample, and all eight leave-one-out books still clear the
falsification rule — while demo_8, itself a selected roster, decays hardest of all (0.6571 → 0.4480).
Finding 6 earns a genuine haircut: on the common 2018-11..2024-11 window R2_capped loses 0.0425 of
LCB and its Phase-1 max-loss probability doubles to 0.0441, *above* demo_8's 0.0219 — R2 is the
faster book, not the calmer one, and the 2025 tail flatters it. Finding 4 is confirmed outright and,
critically, **uniform de-risking to 2.0 % makes it worse** (13213's breach share rises 53.5 → 59.8 %),
so 2.0 % is not the rational answer the critique claims: halving 13213 USDJPY to 0.15625 % at an
otherwise unchanged 2.34 % book buys the same LCB as the 2.0 % book (0.9293 vs 0.9337), a lower
Phase-1 breach probability (0.0086 vs 0.0092), a 23 bd faster median, better cost-stressed E2E
(0.9293 vs 0.9115) and a breach distribution with no sleeve above 25 % — and that lever reproduces
out-of-sample on the honestly-selected roster in both test windows. **The holdout evidence therefore
supports RECOMPOSE, at neither of the two risks put to the vote: the measured frontier point is
R2_capped with 13213 USDJPY risk-halved (≈2.34 % book), with uniform 2.0 % as the conservative
fallback and 2.5 % rejected as buying speed with an unnecessary 3× breach rate.** This conclusion is
**statistical only**. Critique findings 2 and 3 are untouched by this study, are not refuted by it,
and remain blocking for any actual Demo deployment; roster selection, book construction, purchase and
AutoTrading remain OWNER-only (ROT).

## 7. Assumptions, limits and what is NOT verified

Inherited unchanged from `FTMO_ALT_ROSTER_CHAIN_2026-09-18.md` §7 (all 17): 1R = 1,000 USD / source
risk 1.0 %; equal risk per sleeve except where a variant states otherwise; family = EA-directory slug
stem; advisory caps; MAE intraday proxy with all sleeves troughing simultaneously (conservative);
zero spread on `.DWX`; **swap ≈ 0.00 in most streams — a modelling artefact, not a measurement**;
fee 540 USD / 80 % split / 100 % refund from the rulepack, not the live order page; funded-stage
eligibility mapping; duplicate policy; per-roster windows are sleeve-span intersections. New to this
study:

1. **Window truncation is by fully-contained trade** (close-day in window **and** entry-day ≥ start).
   Trades straddling the boundary are dropped, not clipped: `a_*`/`b_*` index files record the exact
   counts per stream (`dropped_close_outside`, `dropped_entry_before_start`).
2. **Truncated streams carry new sha256.** The manifests pin the truncated files; provenance back to
   the frozen snapshot sha is recorded per stream as `source_sha256` in each `streams_*_index.json`.
3. **The test windows are short by construction** (333–746 business days vs 1,591–1,875 in the primary
   run). The engine's own `low_power` flag reports `false` ("adequate") for every run here, but a
   block bootstrap over ~1.5 years of pool cannot see a regime absent from that pool. The TEST/
   TESTCOMMON absolute probabilities are **not** comparable to the primary run's full-sample figures;
   only the within-window comparisons are.
4. **demo_8's engine window starts later than requested in both test windows** (2023-07-31) because
   `11910 NZDUSD` is very low frequency. This shortens demo_8's bootstrap pool relative to R2's;
   it disadvantages demo_8 in pool richness but the direction of the result is far larger than that
   effect and is reproduced on the common window.
5. **The LOO books in §C carry 2.1875 % book risk, not 2.5 %** (task specification: 7 × 0.3125 %).
   Lower book risk mechanically improves LCB, so LOO rows must be compared with each other, not with
   the 2.5 % table.
6. **The 13213-halved variant is not risk-parity or any optimised weighting** — it is a single,
   pre-specified, auditable intervention on the sleeve the breach attribution names. No search over
   weights was performed; doing so would reintroduce exactly the selection problem this study bounds.
7. **UNVERIFIED / out of scope (critique findings 2 and 3, restated as blockers):** FTMO-venue
   tradability and symbol mapping for `NDX`, `XTIUSD`, `USDJPY`, `XAUUSD` on the live venue;
   `ftmo_symbol` and `magic` are still report-only placeholders; no chart profiles, templates or
   setfiles exist for the non-demo sleeves; live news-filter capability under funded Standard rules;
   realised overnight financing / swap and weekend-flat restrictions for the four overnight gold and
   oil sleeves; live slippage and spread; per-sleeve exit-reason and recovery-time distributions; the
   realized −10.26 % demo max-DD provenance; whether every alternative sleeve holds a current Q08 PASS.
   **None of these is addressed, improved or refuted by this study.**

---

*Generated 2026-09-18 by the quantitative-engineer seat. Read-only on the repo, the farm DB and MT5;
the only files created are this document and the contents of
`D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\holdout\`.*
