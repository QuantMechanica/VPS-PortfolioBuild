# FTMO alt-roster — deployable² — roster **D2g** (2026-09-18)

Successor study to `FTMO_ALT_ROSTER_DEPLOYABLE_2026-09-18.md`. D2f cannot be deployed:
`docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/PACKAGE.md` §4-§5 shows that **21505 XAGUSD**
and **13054 XTIUSD** ship binaries built before `strategy_host_symbol` existed — they still carry an
exact `.DWX` symbol gate — and their Q10 seals pin the *pre-`9359ecaf2b`* setfile bytes, so
`trial_setpath --roster` refuses with `sealed_source_hash_drift`. The other six derive cleanly.

This study rebuilds the book from the six clean sleeves and tests whether adding up to two
class-A replacements is worth their risk.

- Evidence root: `D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\deployable2\`
- Engine: `tools/strategy_farm/ftmo/first_passage.py build`, seed **20260915**, **10 000** paths,
  block **10**, horizon 1008, funded 120, 20 batches, engine cost grid — identical to the
  2026-09-18 primary run. Runner `deployable2/run_d2g_chain.py`, log `run_d2g_chain.log`.
- Financing: `swap/financing_lib.py` primary rate table, variant `fin`, finance-then-truncate
  ordering (identical to `swap/run_chain.py`).
- Windows: **full sample** and **2023-01-01+ holdout** (fully-contained-trade truncation of the
  frozen W38 snapshot; the engine re-verifies every stream sha at load).

Role: **DECISION_SUPPORT_EVIDENCE.** Nothing was installed, attached, compiled or toggled. All DB
reads `?mode=ro`. No repo file was modified except this document and `roster_D2g.json`.

---

## 1. Admission gate for replacement candidates

Every candidate had to clear all five tests. `deployable2/verify_identity.py` →
`deployable2/identity_gate.json`.

**(a) Binary identity — repo `.ex5` == Q10 seal `identities.ex5_sha256` == ex5 sha of the Q08 work
item that produced the frozen stream.** The Q08 row is matched by
`aggregate.json → portfolio_stream.content_sha256 == snapshot record sha256`, so the binary tied to
the *measured* stream is the one being checked, not merely the latest build.

**(b) No exact `.DWX` symbol literal gating trade logic, and sealed setfile bytes == seal baseline.**
Source read at repo HEAD; setfile hashed raw-byte, the same comparison `sealed_source_raw()` makes.

**(c)** not 10145 / 11660 (financing-negative). **(d)** financed contribution positive per
`…/swap/`. **(e)** symbol ≤2 / family ≤3 recorded as warnings, not exclusions (OWNER-DEC-CBE-20260915
made the old portfolio caps advisory).

### Result

| key | (a) ex5 triple | (b) setfile bytes | symbol literal gate (file:line) | (d) financed net USD, full sample | verdict |
|---|---|---|---|---|---|
| 13213 USDJPY | MATCH `8c99dea1…` | MATCH | none — `…balke-gmt3-range-breakout.mq5:256-263` returns false | +102 838.40 (financing 0.0 %) | **in (incumbent)** |
| 10706 GBPUSD | MATCH `eaffda6f…` | MATCH | none — `…tv-mon-ls.mq5:106-109` returns false | +62 697.53 (−9.3 %) | **in** |
| 10700 XAUUSD | MATCH `5fbf2ba0…` | MATCH | none — `…tv-liq-break.mq5:294-307` TF+spread only | +36 100.58 (−41.5 %) | **in** |
| 11422 USDCAD | MATCH `2b98e9e9…` | MATCH | none — `…williams-18ma-outside-bar-entry-d1.mq5:90-96` TF only | +14 632.92 (−20.1 %) | **in** |
| 10403 XAUUSD | MATCH `f927f07f…` | MATCH | none — `…et-turtle20x.mq5:252-263` weekday+spread only | +2 432.70 (−82.0 %) | **in** |
| 41219 XAUUSD | MATCH `e9670141…` | MATCH | none — `…cum-rsi2-commodity-requal8.mq5:53-66` TF+spread only | +1 676.79 (−67.4 %) | **in** |
| **11708 EURUSD** | MATCH `baff181f…` | MATCH | **none — zero symbol literals; `…anon-market-squeeze-d1.mq5:59-62` returns false** | **+2 640.50 (financing +1.3 %, a carry *earner*)** | **replacement 1** |
| **11910 NZDUSD** | MATCH `e18d477e…` | MATCH | **none — zero symbol literals; `…larry-williams-18ma-2outside-bars-d1.mq5:72-75` returns false** | **+1 856.57 (−23.5 %)** | **replacement 2** |
| 10513 XAUUSD | MATCH `3c7f46a1…` | MATCH | none — `…mql5-ichimoku.mq5:170-190` spread+session only | (train-window +836.71) | rejected — 4th XAUUSD sleeve, weakest financed drift of the qualifiers |
| 11421 EURUSD | MATCH `9dd7facd…` | MATCH | none — the three `.DWX` hits at `:39`, `:89`, `:303` are comment text | +2 769.04 (−33.5 %) | rejected — financed **train** drift −0.0837 USD/bd |
| 1537 XAGUSD | MATCH `142a019e…` | MATCH | canonical compare only | **−1 773.84** | rejected — (d) financing-negative; also needs a `strategy_calendar_symbol` preset or it is silently dark |
| 21505 XAGUSD | MATCH `395c4747…` | **DRIFT** `a345970c…` vs `fd653cf2…` | `_Symbol == "XAGUSD.DWX"` in the as-compiled source | +1 022.60 | **blocked (D2f blocker)** |
| 13054 XTIUSD | MATCH `2e65488f…` | **DRIFT** `d834b193…` vs `9388a6e8…` | `_Symbol == "XTIUSD.DWX"` in the as-compiled source | +4 465.44 | **blocked (D2f blocker)** |

The gate reproduces the two known D2f blockers exactly and clears nothing that PACKAGE.md flagged —
that is the control that the method is the same one `trial_setpath` applies.

**Replacement ranking rule** (unchanged from the financing-aware arm, `deployable/finaware_selection.json`):
top-N by **financed** drift USD/bd at 0.3125 %, fitted on the **train** window (…2022-12-31) so the
2023+ panel stays a genuine holdout. Among the four qualifiers: 11708 **0.3227**, 11910 **0.1898**,
10513 0.0148, 11421 −0.0837. Top two → **11708 EURUSD, 11910 NZDUSD**.

**Venue symbols.** EURUSD and NZDUSD are both present in the FTMO-Demo terminal's own
`bases\FTMO-Demo\ticks` *and* `…\history`
(`docs/ops/evidence/2026-09-15_ftmo_demo_v2_census/ftmo_symbol_probe.json`, account 1514536732) —
**VERIFIED**, same standard D2f applied.

**Magic registry — 8/8 PASS** (`deployable2/magic_registry_check.json`): every magic exists with
`status=active`, matching `ea_id`, matching `symbol_slot`, `symbol == <dxz>.DWX`, and
`magic == ea_id*10000 + slot`. Registry sha256 `6671944eb975e09b303fb4afd1cb40dc6e6b50d8111af48fbced020050851381`.

---

## 2. Arms

| arm | sleeves | book risk | note |
|---|---|---|---|
| `demo_8` | the 8 incumbent demo sleeves | 2.500 % | control |
| `D2f` | the 8 D2f sleeves | 2.34375 % | reference — **not derivable** |
| `D2g6` | the six clean sleeves | **1.71875 %** | 13213 @ 0.15625 %, five @ 0.3125 % |
| `D2g6r` | the same six, uniformly rescaled | 2.34375 % | isolates "same six, full risk budget" |
| `D2g` | six + 11708 EURUSD + 11910 NZDUSD | 2.34375 % | 13213 @ 0.15625 %, seven @ 0.3125 % |

---

## 3. Results — financed panels (primary)

LCB = `P_FIRST_NET_FTMO_PAYOUT_LCB`; E2E = `P_END_TO_END_FIRST_PAYOUT`; p50 bd = end-to-end median
business days; P1 max-loss = phase-1 max-loss breach probability; cost-stressed E2E = the
`x1.5 + 2.0 USD/lot` sensitivity cell; ENB = USD effective number of bets; max\|r\| = largest
absolute pairwise daily-P/L correlation.

| panel | arm | risk % | LCB | E2E | p50 bd | P1 max-loss | cost-str. E2E | USD-ENB | max\|r\| | caps | beats demo_8 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| fin full | demo_8 | 2.500 | 0.5287 | 0.5614 | 815 | 0.0491 | 0.4927 | 3.43 | 0.134 | none (XAGUSD ×2, XTIUSD ×2 at cap) | — |
| fin full | D2f | 2.344 | 0.8808 | 0.8921 | 492 | 0.0191 | 0.8302 | 4.81 | 0.114 | XAUUSD ×3 | yes |
| fin full | **D2g6** | **1.719** | **0.8839** | **0.9034** | 487 | **0.0152** | **0.8494** | 4.11 | 0.091 | XAUUSD ×3 | **yes** |
| fin full | D2g6r | 2.344 | 0.8496 | 0.8711 | **341** | 0.0471 | 0.8128 | 4.11 | 0.091 | XAUUSD ×3 | yes |
| fin full | D2g | 2.344 | 0.8556 | 0.8766 | 501 | 0.0221 | 0.8042 | **4.68** | **0.089** | XAUUSD ×3 | yes |
| fin 2023+ | demo_8 | 2.500 | 0.3239 | 0.3695 | 857 | 0.0923 | 0.3015 | 3.57 | 0.202 | none (XAGUSD ×2, XTIUSD ×2 at cap) | — |
| fin 2023+ | D2f | 2.344 | 0.9779 | 0.9839 | 369 | 0.0003 | 0.9746 | 4.98 | 0.180 | XAUUSD ×3 | yes |
| fin 2023+ | **D2g6** | **1.719** | 0.9759 | 0.9851 | 339 | 0.0003 | 0.9794 | 4.09 | **0.106** | XAUUSD ×3 | **yes** |
| fin 2023+ | D2g6r | 2.344 | 0.9698 | 0.9801 | **253** | 0.0029 | 0.9706 | 4.09 | 0.106 | XAUUSD ×3 | yes |
| fin 2023+ | D2g | 2.344 | **0.9779** | **0.9867** | 336 | 0.0007 | **0.9803** | **4.96** | 0.229 | XAUUSD ×3 | yes |

### Nofin panels (the same arms, financing switched off)

| panel | demo_8 | D2f | D2g6 | D2g6r | D2g |
|---|---|---|---|---|---|
| nofin full — LCB / p50 | 0.6571 / 746 | 0.9397 / 410 | **0.9419** / 412 | 0.9156 / **298** | 0.9300 / 426 |
| nofin 2023+ — LCB / p50 | 0.4480 / 828 | 0.9839 / 320 | 0.9838 / 304 | 0.9799 / **228** | **0.9859** / 299 |

`demo_8` and `D2f` reproduce `deployable/comparison_financing.json` to the last digit in all four
panels — the determinism check on the re-run.

**Verdict rule** (unchanged): beat `demo_8` on **both** axes (LCB and end-to-end median) at ≤2.5 %
book risk, **with financing**, in **both** windows. `D2g6`, `D2g6r` and `D2g` all **PASS** all four
panels. `demo_8` is the control and, as before, is beaten decisively — its financed 2023+ LCB is
0.3239 against 0.97+ for every candidate.

---

## 4. Which arm wins, and why it is the six

All three candidates clear the rule, so the decision is made on the doctrine's own priority ordering
(OWNER-DEC-CBE-20260915: *probability of success over speed*).

1. **`D2g6` has the highest financed full-sample LCB of every deployable arm — 0.8839 — while using
   27 % less capital at risk** (1.71875 % vs 2.34375 %). It beats even the undeployable D2f reference
   (0.8808) and has the lowest phase-1 max-loss breach probability in every panel (0.0152 / 0.0003)
   and the lowest max\|r\| (0.091 / 0.106).
2. **The two replacements do not pay for their own risk on the full sample.** D2g adds 11708 and
   11910 at +0.625 % book risk and the financed full-sample LCB *falls* 0.8839 → 0.8556 while P1
   max-loss rises 0.0152 → 0.0221. Their financed train drifts (0.32 and 0.19 USD/bd) are simply too
   small next to 13213's 17.67 to carry the extra drawdown exposure they fund.
3. **At a fixed 2.34375 % budget the replacements *are* the right call** — D2g beats D2g6r on LCB
   (0.8556 vs 0.8496), on P1 max-loss (0.0221 vs 0.0471, less than half) and on ENB (4.68 vs 4.11).
   So the two sleeves are genuine diversification; it is the *extra risk*, not the sleeves, that is
   not worth buying. If the OWNER wants the full 2.34 % deployed, take **D2g, never D2g6r**.
4. **D2g's holdout edge is measured on a thinner base.** Its 2023+ common window is **484 business
   days** against D2g6's **730** (11708 and 11910 stop trading earlier), so the 0.9779 vs 0.9759 LCB
   gap is inside the noise of a 34 % shorter panel and should not carry the decision.
5. **D2g6r is rejected outright.** It buys median speed (341 vs 487 bd) by tripling the phase-1 breach
   probability (0.0471 vs 0.0152) and giving up 0.034 of LCB — the exact trade the FTMO doctrine
   ranks last.

**Winner: `D2g6` — the six identity-clean sleeves at 1.71875 % book risk.**
`D2g` (8 sleeves @ 2.34375 %) is fully qualified and kept as the ready alternative
(`deployable2/roster_D2g_candidate.json`, derivation already proven — see §5).

### Residual risks / gaps

- **XAUUSD ×3 of 6 sleeves** (10700, 10403, 41219) — half the book on one metal. This is the one
  advisory cap breached, and it is the strongest argument for the 8-sleeve D2g, which dilutes it to
  3 of 8. Measured dependence stays low (max\|r\| 0.091 full / 0.106 holdout; 10403~41219 is
  *negative*, −0.085), so the label overstates the economic dependence — but a common XAUUSD gap
  event is not in the correlation estimate.
- **Friday-flat vs the measured streams.** The derived presets set
  `qm_friday_close_enabled=true / qm_friday_close_hour_broker=21` (FTMO **Standard**, not Swing),
  while three sleeves hold over weekends in the backtest streams — 10403 weekend share 0.77,
  41219 0.53, 11422 0.47, and (in D2g) 11910 0.60. Live behaviour will differ from the stream for those sleeves.
  This is inherited from D2f, not introduced here, and it is a measured **GAP**, not a modelled cost.
- **11422 and 11910 are the same mechanism** (Larry Williams 18MA + outside bars, D1) on different
  symbols; the `family` labels "williams" and "larry" hide that. Their measured daily correlation is
  only 0.089-0.093, which is why D2g still improves ENB — but the family cap would not have caught it.
- The two blocked sleeves stay blocked. 21505 and 13054 need a **recompile** and, per the
  rebuilt-EX5-is-a-new-identity rule, a **fresh seal from Q02** before they can run on a venue name.
  Nothing in this study changes that.

---

## 5. Derivation proof — `trial_setpath` dry-run on the winning roster

    cd C:/QM/repo
    python -m tools.strategy_farm.ftmo.trial_setpath \
      --roster docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/roster_D2g.json \
      --run-name probe_d2g --dry-run

**Result — SUCCESS, 6/6, no refusal:**

    {"directory": "D:\\QM\\strategy_farm\\artifacts\\ftmo_trial_sets_review\\probe_d2g",
     "sets": 6, "schema": "qm.ftmo-trial-setpath/v2", "status": "INERT_REVIEW_ONLY"}

`book_risk_percent = 1.71875`, `risk_percent = [0.15625, 0.3125]`, roster sha256 `53a1387081ab6b62…`.
Manifest copy: `deployable2/probe_d2g_manifest.json`.

| ea_id | derived preset | sha256 (first 16) | Q10 seal work item | risk % |
|---|---|---|---|---|
| 13213 | `QM5_13213_USDJPY_H1_live_trial.set` | `19c771ff8224dcff` | `6771f953…` | 0.15625 |
| 10706 | `QM5_10706_GBPUSD_H1_live_trial.set` | `31c37ec30421a51d` | `9c7db9b2…` | 0.3125 |
| 10700 | `QM5_10700_XAUUSD_H1_live_trial.set` | `6e319d98e5ea7b67` | `4066a5fb…` | 0.3125 |
| 11422 | `QM5_11422_USDCAD_D1_live_trial.set` | `215615b5da7ae2f4` | `74fec478…` | 0.3125 |
| 10403 | `QM5_10403_XAUUSD_D1_live_trial.set` | `9d8414ce65912a6b` | `77482986…` | 0.3125 |
| 41219 | `QM5_41219_XAUUSD_D1_live_trial.set` | `ba8ffd63db87de12` | `80107fb5…` | 0.3125 |

All six output shas are **byte-identical** to the `probe_six_sleeves/` diagnostic in the D2f package —
the derivation path is reproducible across runs and across roster files.

`symbol_slot_changes == {}` for all six: none of these EAs has a symbol-slot input, so venue binding
is **the chart symbol**. `CHART_PLAN.md` in the D2f package therefore remains load-bearing for this
roster too.

**The 8-sleeve alternative derives cleanly as well** — the same code path run against
`deployable2/roster_D2g_candidate.json` (redirected into
`deployable2/probe_d2g_local/`, zero footprint outside the evidence tree) produced 8/8 presets, the
six above unchanged plus `QM5_11708_EURUSD_D1_live_trial.set` (`d6bd8dc8da628f4a`) and
`QM5_11910_NZDUSD_D1_live_trial.set` (`1223b91258540527`).

---

## 6. Authority boundary

This document and `roster_D2g.json` are review artifacts. Installation, chart attachment,
AutoTrading, any FTMO purchase, gate thresholds and book construction remain **OWNER-only (ROT)**.
`trial_setpath` was run `--dry-run`; its output is marked `INERT_REVIEW_ONLY / installable: false`.
No MT5 process, chart profile or set file outside the review tree was touched.

### Evidence index

| artifact | path |
|---|---|
| chain results + KPI rows | `D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\deployable2\results_d2g.json` |
| runner / log | `…\deployable2\run_d2g_chain.py`, `…\run_d2g_chain.log` |
| identity + setfile gate | `…\deployable2\identity_gate.json`, `…\deployable2\verify_identity.py` |
| magic registry check | `…\deployable2\magic_registry_check.json` |
| per-arm engine outputs | `…\deployable2\{nofin,fin}{full,dtest}_<arm>.json` (+ `_manifest.json`) |
| financed stream indexes | `…\deployable2\streams_fin_{full,dtest}_index.json` |
| derivation probe | `D:\QM\strategy_farm\artifacts\ftmo_trial_sets_review\probe_d2g\manifest.json` |
| winning roster | `C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2f\roster_D2g.json` |
| 8-sleeve alternative | `…\deployable2\roster_D2g_candidate.json` |
