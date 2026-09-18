# FTMO alternative-roster chain run — full v2 first-passage engine (2026-09-18)

**Role:** DECISION_SUPPORT_EVIDENCE. Author: quantitative-engineer seat (read-only), executing
`docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md` §5 **action 1**.
**Nothing here constructs a book, sets a weight, changes a gate, selects a Demo roster or authorises a
purchase** — all ROT / OWNER-only. No farm-DB write, no MT5, no AutoTrading, no git write.

**Engine:** `tools/strategy_farm/ftmo/first_passage.py build` — schema `qm.ftmo-first-passage/v2`,
engine `2.0.0`, KPI contract `v1`, all three chain stages (Challenge → Verification → funded → first
net payout), pathwise.
**Rulepack:** `FTMO_2S_100K_STANDARD_V2`, as_of 2026-09-15, sha `857e2d4b…dcda5`.
**Params (identical for every roster):** seed `20260915`, 10,000 paths, block 10 bd, horizon 1,008 bd,
funded horizon 120 bd, 20 CI batches, five cost scenarios `(×1.0, +0/+1/+2 USD/lot)`, `(×1.5, +0/+2)`.
**Inputs:** the frozen W38 snapshot `D:\QM\reports\book_evolution\2026-W38\ftmo\snapshot_r2`
(`qm.recompose-frozen-inputs/v1`, git `8a9e20d0…`, frozen 2026-09-15T15:33:21Z), stream sha256 records
copied verbatim; every stream sha re-verified at load (0 mismatches, 0 dropped sleeves).
**Evidence folder:** `D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\`
(per-roster `<label>.json` + `<label>_manifest.json`, `alt_roster_manifest.json`,
`roster_definitions.json`, `stream_stats.json`, `duplicate_probe.json`, `comparison.json`,
`window_confound_check.json`, and the three scripts that produced them).
**The live read-model `D:\QM\reports\state\ftmo_first_passage.json` was NOT touched** (mtime unchanged,
2026-09-15 20:00); every run used `--out` / `--manifest-out` into the evidence folder.

---

## 0. Control reproduction (R0)

`R0_demo8` reproduces the frozen v2 preview (`D:\QM\reports\state\ftmo_first_passage_v2_preview.json`)
**bit-identically**: a full recursive comparison of the `headline`, `chain`, `sensitivity`, `window` and
`compact_for_readiness` blocks returns **0 differences** — E2E `0.6993`, LCB `0.6571`, end-to-end median
**746 bd** (p10 392 / p90 1204.8), Phase-1 median 439 bd, P(daily) 0.0, P(max-loss) 0.0244, window
2018-11-02..2024-12-06 / 1,591 bd / 1,010 active book days. Only `input_manifest_sha256` differs
(`721a1428…` → `0a8633fb…`) because the roster is resolved from a *derived* experiment manifest rather
than the snapshot manifest; the roster, the streams, their sha256 and every parameter are the same.

## 1. Duplicate handling (rule a)

`duplicate_probe.json` hashed all 26 snapshot streams three ways — file bytes, canonical trade sequence
(close ts, entry ts, net, MAE, lots, commission) and the daily-net series:

| notion | duplicate groups found |
|---|---|
| **byte-identical file** | **none** |
| trade-sequence identical | `11421_EURUSD ≡ 41221_EURUSD`, `13213_USDJPY ≡ 21501_USDJPY` |
| daily-net identical | the same two groups |

**Correction to the gap doc §3:** the two pairs are *economically* identical, **not byte-identical** —
the files differ (sha256 differ), only the extracted P/L sequence is the same. The conclusion is
unchanged and the caution is right: counting both members would be a fictitious diversification claim.
`21501:USDJPY.DWX` and `41221:EURUSD.DWX` are **excluded from every roster**; `13213` / `11421` are the
retained representatives. No further duplicate group exists in the snapshot.

**Count correction:** the snapshot carries **26** stream records, all 26 measurable (≥60 trades each);
after duplicate removal there are **24 distinct P/L identities**, not the 23 stated in the gap doc.

## 2. Rosters (rule e)

Selection is computed in `build_rosters.py` from `stream_stats.json`, never hand-typed (except R1, which
is fixed verbatim by the gap doc). Ranking metric = **own-span drift USD/bd at 0.3125 %** =
(Σ net × 0.3125) / (business days in the stream's own span). Family = the EA-directory slug stem
(`framework/EAs/QM5_<id>_<family>-…`), the same fingerprint `portfolio/concentration_tail.py` uses.

| Roster | Composition (ea_id:symbol) | Rule |
|---|---|---|
| **R0_demo8** | 10706 GBPUSD, 11421 EURUSD, 11422 USDCAD, 11910 NZDUSD, 13054 XTIUSD, 20048 XTIUSD, 1537 XAGUSD, 21505 XAGUSD | control (current Demo) |
| **R1_docC** | 10706 GBPUSD, 13213 USDJPY, 11660 NDX, 21507 XAUUSD, 12855 XTIUSD, 13013 NDX, 10700 XAUUSD, 11422 USDCAD | gap doc §4 composition C, verbatim |
| **R2_capped** | 13213 USDJPY, 10706 GBPUSD, 10700 XAUUSD, 11660 NDX, 11422 USDCAD, 10145 XAUUSD, 20266 XTIUSD, 12710 XTIUSD | top-8 by drift s.t. symbol ≤2, family ≤3 |
| **R3_noGBP** | R2 − 10706 GBPUSD + **21505 XAGUSD** | breach-concentration test |
| **R4_ratio** | 13213 USDJPY, 10700 XAUUSD, 10706 GBPUSD, 10145 XAUUSD, 11660 NDX, 11422 USDCAD, 10403 XAUUSD, 21507 XAUUSD | top-8 by drift / \|worst day\| |

Each sleeve carries **0.3125 %** → book risk exactly **2.5 %** (rule b). The 2.0 % variants (0.25 % × 8)
were run for **both** front-runners, because R1 and R2 do not dominate one another at 2.5 %.

Note: the unconstrained top-8 by drift and the top-8 by drift/|worst day| are the **same eight streams**
— the two rankings agree, so R4 is also "top-8 by drift, caps ignored". It is kept because it is the one
roster that trips an advisory cap, which is exactly what rule (c) is meant to surface.

## 3. Results

All numbers from `<label>.json`; aggregated in `comparison.json`.

| Roster | risk | P_CHAL | P_VER\|C | P_FUND | **E2E** | **LCB** | p10/**p50**/p90 bd | P(daily) | P(maxloss) P1/Ver/Fund | dominant breach sleeve | cost ×1.5+2 E2E | max\|r\| | ENB | caps |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| R0_demo8 | 2.50 | 0.8163 | 0.9395 | 0.9119 | 0.6993 | **0.6571** | 392/**746**/1205 | 0.0 | 0.0244/0.0175/0.0 | 10706 GBPUSD 46.7 % | 0.6438 | 0.147 | 3.42 | none |
| R1_docC | 2.50 | 0.9715 | 0.9783 | 0.9715 | 0.9233 | **0.9133** | 154/**297**/572 | 0.0 | 0.0273/0.0222/0.0037 | 13213 USDJPY 56.4 % | 0.8728 | 0.093 | 5.05 | none |
| R2_capped | 2.50 | 0.9731 | 0.9784 | 0.9687 | 0.9223 | **0.9059** | 150/**288**/545 | 0.0 | 0.0256/0.0213/0.0035 | 13213 USDJPY 53.5 % | 0.8772 | 0.087 | 4.99 | none |
| R3_noGBP | 2.50 | 0.9775 | 0.9827 | 0.9674 | 0.9293 | **0.9079** | 198/**372**/684 | 0.0 | 0.0175/0.0172/0.0018 | 13213 USDJPY 53.7 % | 0.8793 | 0.157 | 4.63 | none |
| R4_ratio | 2.50 | 0.9723 | 0.9746 | 0.9689 | 0.9181 | **0.9016** | 149/**289**/545 | 0.0 | 0.0263/0.0253/0.0053 | 13213 USDJPY 44.5 % | 0.8672 | **0.622** | 5.11 | **4 warnings** |
| R1_docC @2.0 % | 2.00 | 0.9850 | 0.9888 | 0.9710 | 0.9458 | **0.9339** | 203/**379**/698 | 0.0 | 0.0111/0.0109/0.0008 | 13213 USDJPY 39.6 % | 0.9062 | 0.093 | 5.05 | none |
| R2_capped @2.0 % | 2.00 | 0.9875 | 0.9919 | 0.9688 | 0.9489 | **0.9337** | 198/**367**/676 | 0.0 | 0.0092/0.0078/0.0011 | 13213 USDJPY 59.8 % | 0.9115 | 0.087 | 4.99 | none |

`P_FIRST_NET_FTMO_PAYOUT` equals `P_END_TO_END_FIRST_PAYOUT` for every roster (with fee 540 USD,
80 % split and 100 % fee refund the net-positive threshold is 0 USD of funded profit, so every path that
reaches a payout is net-positive). Median net cash at first payout: R0 521.80, R1 686.00, R2 694.80,
R3 546.10, R4 704.60, R1@2.0 547.60, R2@2.0 553.80 USD.

**Advisory cap warnings (rule c — reported, never applied as filters):**
- **R4_ratio: XAUUSD ×4 vs advisory symbol cap 2**, plus three pairwise correlations above 0.30 —
  10145~21507 **0.622**, 10403~21507 **0.606**, 10145~10403 **0.561**. This is the gap doc §3 warning
  made concrete: stacking XAU streams imports real co-movement. R4's ENB is nominally the highest (5.11)
  yet it is the **worst** alternative on both LCB and cost-stressed E2E.
- R0, R1, R2, R3: **no** symbol, family or correlation warning. Max family count is 2 (`tv` in R1/R2/R4).
- Every roster: P(daily-loss breach) = **0.0** in all three stages and all five cost scenarios. Max Loss
  remains the only binding rule, exactly as in the gap doc.

**ENB discrepancy (new finding).** On the roster's actual USD daily P/L at equal 0.3125 % sizing,
demo_8's effective number of bets is **3.42**, not the **7.52** published in
`D:\QM\reports\book_evolution\2026-W38\ftmo\evidence.md`. The published figure is reproducible only if
each sleeve's daily series is first **volatility-normalised** (recomputed that way: **7.494** vs the
published 7.5208 — same construction, small grid difference). The cause is sleeve-vol heterogeneity:
10706 GBPUSD has a daily σ of **1,137 USD** against 41–394 USD for the other seven, so at equal nominal
risk the book is far more concentrated than the published diversification metric suggests. This is
consistent with 10706 carrying 46.7 % of R0's breaches. **The 7.52 figure should not be read as
"7.52 of 8 independent bets at the book's actual sizing."** Flagged for the weekly-recomposition surface;
not fixed here (read-only).

## 4. Window confound and its control

Each roster's simulation window is the intersection of **its own** sleeves' spans, so demo_8 is simulated
over 2018-11-02..2024-12-06 (1,591 bd; sleeve 1537 ends 2024-12-06) while the alternatives run to
late 2025 (1,825–1,936 bd). Part of the gap could therefore be regime rather than composition.
`window_confound_check.json` re-measures every roster's book on the **identical demo_8 window**:

| Roster @2.5 % | drift USD/bd | daily σ USD | drift/σ | worst close day | worst intraday proxy | naive bd to +10k |
|---|---|---|---|---|---|---|
| R0_demo8 | 16.02 | 313.9 | 0.0511 | −763 | −872 | 624 |
| R1_docC | 41.95 | 550.3 | 0.0762 | −1,278 | −1,408 | 238 |
| R2_capped | 41.66 | 550.3 | 0.0757 | −1,252 | −1,381 | 240 |
| R3_noGBP | 32.08 | 455.3 | 0.0705 | −1,252 | −1,381 | 312 |
| R4_ratio | 44.34 | 576.4 | 0.0769 | −1,390 | −1,506 | 226 |

On the *same* days, R1/R2 earn **2.6× the drift per business day** and **1.49× the drift per unit of
daily volatility**. The drift advantage on the common window (2.62×) is slightly *larger* than the
median-speed advantage the engine reports over the differing windows (746/297 = 2.51×), so the window
difference is not the source of the result — the composition is. Worst intraday proxy stays at 1.4–1.5 % of the
100k account against the 5 % daily-loss limit — consistent with P(daily) = 0.0 everywhere.

## 5. Falsification rule, applied explicitly

Gap doc §5 action 1: *"Falsified if no alternative roster beats `demo_8` on **both**
`P_FIRST_NET_FTMO_PAYOUT_LCB` and end-to-end median at ≤2.5 % book risk."*

| Roster | risk ≤2.5 % | LCB > 0.6571 | median < 746 bd | **rule passed** |
|---|---|---|---|---|
| R1_docC | yes | 0.9133 ✔ | 297 ✔ | **YES** |
| R2_capped | yes | 0.9059 ✔ | 288 ✔ | **YES** |
| R3_noGBP | yes | 0.9079 ✔ | 372 ✔ | **YES** |
| R4_ratio | yes | 0.9016 ✔ | 289 ✔ | **YES** |

**The falsification hypothesis is NOT falsified — it is refuted in the opposite direction.** All four
alternatives beat demo_8 on both axes at identical 2.5 % book risk, by wide margins (LCB +0.24 to +0.26
absolute; median −374 to −458 bd, i.e. 2.0–2.6× faster). The gap doc's §4 item-1 Phase-1-only claim now
holds through the **full chain**: the improvement is not a Phase-1 artefact, it carries into
Verification (0.9395 → 0.978–0.983) and the funded stage (0.9119 → 0.967–0.972).

Two secondary findings:
- **Breach concentration is transferable, not removable.** Replacing 10706 GBPUSD (R3) cuts Phase-1
  P(max-loss) from 0.0256 to 0.0175 and raises LCB slightly (0.9059 → 0.9079), but costs **84 bd of
  median** (288 → 372). In every alternative the dominant breach carrier becomes 13213 USDJPY at
  40–60 % — the fastest sleeve is always the dominant breach carrier, which is the same structural
  pattern the gap doc identified for 10706, not a defect of any particular sleeve.
- **De-risking to 2.0 % is the better lever than de-risking by composition.** R2 @2.0 % gives the best
  LCB of the whole set (0.9337) and the best cost-stressed E2E (0.9115), at the price of 79 bd of median
  (288 → 367). It still beats demo_8 @2.5 % on both axes by a large margin.

## 6. Recommendation

**RECOMPOSE — the evidence supports re-selecting the Demo roster now, and `R2_capped` is the roster to
put in front of OWNER.** At the identical 2.5 % book risk the current `demo_8` is dominated on every KPI
in the contract: end-to-end first-payout probability 0.6993 → 0.9223, the control value
`P_FIRST_NET_FTMO_PAYOUT_LCB` 0.6571 → 0.9059, end-to-end median 746 → 288 business days, at the same
breach profile (P(daily) 0.0 in both; P(max-loss) 0.0244 → 0.0256) and a *better* dependence panel
(max |r| 0.147 → 0.087) with **no** advisory cap breached, and it survives the cost stress far better
(×1.5 + 2 USD/lot: E2E 0.6438 → 0.8772). `R1_docC` is statistically indistinguishable from it
(LCB 0.9133 vs 0.9059, median 297 vs 288 — neither dominates); I prefer `R2_capped` because its
composition is reproduced by an explicit, auditable rule that respects the advisory caps rather than
being a published list, and because it degrades less under cost stress. `R4_ratio` should be rejected
despite the nominally best ENB — it stacks four XAUUSD streams with pairwise |r| up to 0.622 and comes
last on LCB and on cost-stressed E2E, which is precisely the fictitious-diversification failure mode.
If OWNER wants the *safest* version of the change rather than the fastest, `R2_capped @2.0 %` is the
single best point measured here (LCB 0.9337, cost-stressed E2E 0.9115, P(max-loss) 0.0092) at 367 bd —
still 379 bd faster than today's roster. **Caveats that bound this recommendation:** the comparison is
backtest-derived and spread-free; the alternatives are simulated over a longer, more recent window than
demo_8 (§4 controls for this: on the identical demo_8 window the drift advantage is 2.62×, slightly
*larger* than the 2.51× median-speed advantage the engine reports, so the window difference is not what
produces the result); 13213 USDJPY becomes the dominant breach carrier in every alternative; and none of this changes
the readiness verdict, which is `NOT_READY` for reasons (realized demo max-DD, 14-day validation) that
a recomposition does not by itself resolve. **Roster selection, book construction, any purchase and
AutoTrading remain OWNER-only (ROT); this document proposes nothing beyond the measurement.**

---

## 7. Assumptions — every one of them

1. **`1R = 1,000 USD`**; streams are `RISK_FIXED $1000` on 100k = `SOURCE_RISK_PCT 1.0` (engine constant,
   manifest `source_risk_pct: 1.0`). A sleeve at 0.3125 % scales its P/L by 0.3125.
2. **Equal risk per sleeve** in every roster (rule b): 0.3125 % × 8 = 2.5 %; the variants 0.25 % × 8 =
   2.0 %. No risk-parity, vol-targeting or per-sleeve optimisation was applied — that would be a
   different (and larger) experiment.
3. **Ranking metric = own-span drift USD/bd**, i.e. each stream measured over its *own* span, not a
   common window. Streams with different spans are therefore ranked on different day sets. The
   drift/|worst-day| ranking (R4) happens to select the same eight streams, which is weak evidence that
   the ranking is not fragile, but it is not a robustness proof.
4. **`family` = the first `-`-separated stem of the EA-directory slug** (`concentration_tail.py`
   convention). The snapshot itself carries **no** family field; a mis-slugged EA would mis-classify.
   No roster reaches the family cap, so the caps are not load-bearing for the ranking here.
5. **Caps are advisory** (rule c): symbol ≤2, family ≤3, pairwise |r| > 0.30 — all reported as warnings,
   none applied as a filter, except inside the *definition* of R2/R3 where the caps are the stated
   selection rule.
6. **Pairwise |r|** is the population Pearson correlation of daily closed P/L on the roster's business-day
   grid (zero-filled on inactive days). The union-of-active-days basis used by
   `recompose/metrics.py` gives the same values to ±0.001 (`comparison.json`, both reported).
7. **ENB** = the diversification-ratio ENB of `recompose/metrics.py`, computed with the **actual** risk
   weights on **actual USD** P/L. It is NOT comparable to the 7.52 in `evidence.md`, which is reproducible
   only on volatility-normalised sleeves (§3). Which basis the weekly surface *intends* is **UNVERIFIED**.
8. **Windows differ per roster** (engine behaviour: intersection of the roster's sleeve spans). §4 is the
   control for this; the residual regime confound is **not fully removed**.
9. **`ftmo_symbol` and `magic` for non-demo sleeves are report-only placeholders** (base symbol, `null`).
   The engine computes exclusively from the `.DWX` stream, so no result depends on them. The FTMO-venue
   tradability of each symbol is **NOT** checked here — a roster containing e.g. NDX or XTIUSD assumes the
   FTMO instrument exists and is mapped; that is a separate, unclosed check.
10. **Intraday equity is the engine's per-trade-MAE proxy**, not tick-exact mark-to-market; the book low
    sums all sleeve lows as if every sleeve troughed simultaneously (conservative, overstates breach).
11. **Spread is zero on `.DWX`**; all expectancies are commission-inclusive and spread-free. The
    ×1.5 + 2 USD/lot scenario is the only cost stress applied.
12. **Swap** is 0.00 in most streams — a modelling artefact, not a measurement (gap doc §6.5). Unchanged
    here; it biases every roster in the same direction but not by the same amount (R0 carries two
    negative-swap sleeves, 11421 and 11910; the alternatives carry none, so the alternatives' advantage
    is **slightly overstated** by an unmeasured amount).
13. **Fee 540 USD / 80 % split / 100 % refund** from the rulepack (`fee_source: RULEPACK_LIST_FEE`), not
    the live order page — still the documented GAP of the rules snapshot.
14. **Funded stage** assumes reward eligibility at 14 calendar days after the first placed trade
    (mapped 5/7 to 10 bd) plus 4 business days of processing, no breach in between — engine defaults,
    unchanged.
15. **Duplicate policy**: `21501:USDJPY` and `41221:EURUSD` excluded everywhere. If the *other* member of
    a pair were the true production sleeve the numbers are unchanged (the P/L is identical); only the
    label would move.
16. **No path-dependence between rosters:** each roster is an independent engine run with the same seed,
    so cross-roster differences are composition + window, never RNG.
17. **UNMEASURED / unchanged from the gap doc:** live FTMO-venue slippage and spread; per-sleeve exit-reason
    distributions; recovery-time distributions; any Q02+ evidence for 41475/41476/41477/41479/41480; the
    realized −10.26 % demo max-DD provenance.

---

*Generated 2026-09-18 by the quantitative-engineer seat. Read-only on the repo and the farm DB; the only
files created are this document and the contents of
`D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\`.*

---

## Addendum 2026-09-18 ~01:20Z — cross-vendor critique and Fable resolution (disagreement protocol, directive §25)

Antigravity (`agy -p`, read-only) reviewed this document and returned **REJECT** for an immediate demo recomposition:
`D:/QM/reports/ai_exchange/20260918_alt_roster_critique_agy/agy_critique.md`. Disputed propositions and Fable's disposition:

| # | Critic finding | Fable disposition |
|---|---|---|
| 1 | Selection bias / winner's curse — top-8-by-drift selected and evaluated on the same 24 streams; no holdout | **Accepted as unresolved.** Deterministic test commissioned: select on ≤2022-12-31, evaluate the full chain on 2023-01-01..end (`FTMO_ALT_ROSTER_HOLDOUT_2026-09-18.md`). No recomposition until it lands. |
| 2 | Operational infeasibility (venue symbols, magics, presets, news capability) | **Accepted.** Package preparation running under `docs/ops/evidence/2026-09-18_ftmo_demo_recompose_R2/`; venue gaps are blockers by construction. |
| 3 | Unmodelled financing drag — 4 of 8 sleeves are gold/oil held overnight, swap hard-coded 0 | **Accepted as a modelling gap.** Requires FTMO venue swap rates from the demo Market Watch; to be added as a cost scenario before any decision. |
| 4 | Breach monoculture moves to 13213 USDJPY (53–60 %) | **Partly accepted.** Concentration is transferred, not removed; the holdout run includes a 13213-half-risk variant and leave-one-out. |
| 5 | 2.0 % book risk is the rational choice under probability-over-speed | **Accepted in principle** (KPI contract §2, directive §56): if recomposition proceeds, the 2.0 % variant is the default candidate. |
| 6 | Window asymmetry (demo_8 streams end 2024-12, R2 through 2025-12); chain never evaluated on a common window | **Accepted.** Common-window chain evaluation is part of the holdout run. |
| 7 | ENB 7.52 was volatility-normalised; USD ENB (3.42 / 4.99) is the FTMO-relevant figure | **Accepted**; the USD-ENB figure is the one to carry forward. |

**Resolution:** the recommendation of this document is downgraded from RECOMPOSE to **RECOMPOSE-CANDIDATE PENDING HOLDOUT**.
The current demo cycle continues unchanged (KEEP is a legitimate weekly decision). Decision owner: Fable. Evidence pending:
holdout/common-window/leave-one-out run (deterministic, 0 factory hours), FTMO venue swap scenario, deployment package
feasibility.
