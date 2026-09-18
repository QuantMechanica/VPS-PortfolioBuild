# FTMO alt-roster overnight-financing (swap) study — 2026-09-18

**Role:** DECISION_SUPPORT_EVIDENCE. Author: quantitative-engineer seat. Read-only on
`C:/QM/repo`, the farm DB, MT5 and the FTMO demo terminal; writes only under
`D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\swap\` and this
file. No git, no DB write, no terminal control, no AutoTrading, no gate change, no book
construction, no roster selection — all ROT / OWNER-only.

**Question.** The first-passage chain for `R2_capped_13213half` models swap = 0, because
the `.DWX` factory streams carry `"swap":0.00` on every row (custom symbols are
financing-free in the tester). Finding **3** of the adversarial cross-vendor critique
(`D:\QM\reports\ai_exchange\20260918_alt_roster_critique_agy\agy_critique.md`) says that
invalidates the comparison, because four sleeves hold gold and oil overnight. This study
quantifies the financing on the FTMO venue and re-runs the chain with it.

**Answer up front.** Financing is large — it removes **28.3 %** of `R2_capped_13213half`'s
gross net and **21.5 %** of demo_8's — and it does **not** change the recomposition
decision. R2 still beats demo_8 on both control axes in every financed arm, by 29.7 LCB
points on the full sample and 64.8 on the 2023+ holdout.

---

## 1. Rates — what is actually on disk

The task's premise ("share and median holding from `stream_stats.json`") does not hold:
`stream_stats.json` has no overnight fields. They are computed here from the streams'
`entry_time` / `time` / `side` / `volume`, which do exist.

Venue data **was** found on disk; no WebFetch of ftmo.com was needed and none was made.
Two independent on-disk sources:

**(A) Native symbol spec** — read-only MT5 IPC capture of the FTMO-Demo terminal
(login 1514536732, server FTMO-Demo, build 6182), `checked_at_utc 2026-09-06T17:28:43Z`:
`docs/ops/evidence/2026-09-06_ftmo_demo_install/terminal_snapshot.json`
(sha256 recorded in `swap_rates_derivation.json`). Covers 8 symbols with
`swap_long` / `swap_short` / `swap_triple_day` / `contract_size` / `digits` /
`currency_profit`. The MT5 **swap mode is not in the capture**; the values are read as
`SYMBOL_SWAP_MODE_POINTS` — the same reading the repo's own v2 cost snapshot uses
(`docs/ops/evidence/2026-09-14_ftmo_book_v2/ftmo_book_symbol_cost_snapshot_v2.json`,
fields named `swap_long_points` / `swap_short_points`):

```
money per lot per night (profit ccy) = points × 10^-digits × contract_size
```

**(B) Realised native swap** — the FTMO demo account's own deal journal,
`<FTMO demo terminal>/MQL5/Files/QM/journal/live_deals_normalized.csv`, 138 deal rows,
**22 closed positions that actually paid or received swap** across `US100.cash`,
`USDJPY`, `XAUUSD`, `USOIL.cash`, `GBPUSD`, `EURUSD`, `GER40.cash` (2026-07-06 …
2026-09-04). This is money the venue actually charged. It is the authority where it
exists, and the cross-check everywhere else. `docs/ops/FTMO_CHALLENGE_READINESS.md`'s
one-line "Swap: −14.73 USD" is an aggregate, not a rate table, and is not used.

### 1.1 The charged-night rule, verified rather than assumed

Rollover at 00:00 FTMO server time (EET/EEST — the journal's `time_broker` column runs
UTC+3 in the sampled summer window). **Saturday and Sunday rollovers are not charged**;
instead the symbol's `swap_triple_day` weekday carries 3×, booked at the rollover
*following* that weekday. A Mon…Mon hold therefore costs exactly 7 units on any setting.

This was derived from the fills, not assumed:

| position | symbol | rollovers into | actual swap / lot | units under the rule | implied rate |
|---|---|---|---|---|---|
| 07-13→07-14 | GBPUSD sell | Tue | −4.971 | 1 | −4.97 |
| 08-12→08-14 | GBPUSD sell | Thu, Fri | −21.083 | 3+1 = 4 | **−5.27** |
| 08-25→08-28 | GBPUSD sell | Wed, Thu, Fri | −27.913 | 1+3+1 = 5 | **−5.58** |
| 07-22→07-23 | XAUUSD buy | Thu | −191.50 | 3 | **−63.83** |
| 07-14→07-16 | XAUUSD buy | Wed, Thu | −252.20 | 1+3 = 4 | **−63.05** |

GBPUSD's native `swap_triple_day = 3` (Wednesday) reproduces the charged amounts only if
the 3× lands on the **rollover into Thursday**, and it then reconciles −5.27 / −5.58
against a spec of −5.20. The same holds for gold. Rule confirmed.

### 1.2 Rate table used (per FTMO lot per charged unit)

| .DWX symbol | FTMO symbol | long | short | profit ccy | triple (MT5 dow) | source |
|---|---|---|---|---|---|---|
| XAUUSD.DWX | XAUUSD | −93.00 | −10.40 | USD | 3 (Wed) | native spec |
| GBPUSD.DWX | GBPUSD | −6.70 | −5.20 | USD | 3 | native spec |
| USDCAD.DWX | USDCAD | +0.71 | −12.00 | **CAD** | 3 | native spec |
| XTIUSD.DWX | USOIL.cash | +0.583 | −3.511 | USD | 5 (Fri) | native spec |
| NDX.DWX | US100.cash | **−6.2705** | **+0.2692** | USD | 5 *(assumed)* | **realised fills, n = 7 / 2** |
| USDJPY.DWX | USDJPY | **+204.1 JPY** | **−1978 JPY** | **JPY** | 3 *(assumed)* | long realised (n = 4), short v1 projection |
| EURUSD.DWX | EURUSD | −13.29 | +0.17 | USD | 3 | native spec |
| NZDUSD.DWX | NZDUSD | −4.82 | −1.36 | USD | 3 | native spec |
| XAGUSD.DWX | XAGUSD | −115.25 | +1.60 | USD | 3 | native spec |

A second **conservative** set (`fincons`) takes the worse debit per side across all
available sources and clamps every credit to 0 (XAUUSD short −23.538, GBPUSD short
−5.583, USOIL short −3.887, US100 long −6.497, all credits → 0).

### 1.3 Model-vs-venue residual

Predicting every predictable demo position from the primary table:
**actual −185.33 USD vs predicted −223.62 USD — the model is 20.7 % more expensive than
the venue actually charged.** The error is dominated by gold (the 2026-09-06 spec −93.00
against a July realised −63.83; gold swaps moved between the two dates). The financing
model therefore errs *against* the rosters, which is the right direction for a decision.

### 1.4 Lot mapping (derived, not assumed)

Financing is a notional cost, so `ftmo_lots = dwx_volume × dwx_contract / ftmo_contract`.
`.DWX` contract sizes come from each stream's own `notional / volume / exit_price`;
FTMO's from the native spec, except `US100.cash` (absent from the capture) whose
contract size **1.0** is derived from realised `profit / (Δprice × lots)`.

| symbol | .DWX contract | FTMO contract | ratio |
|---|---|---|---|
| XAUUSD | 100 | 100 | 1 |
| GBPUSD / USDJPY / USDCAD | 100 000 | 100 000 | 1 |
| XTIUSD → USOIL.cash | 1 000 | 100 | **×10** |
| NDX → US100.cash | 10 | 1 | **×10** |

Missing this on the two ×10 symbols would have understated their financing by an order
of magnitude.

---

## 2. Financing-adjusted streams

`swap/financing_lib.py` rewrites each stream row: `swap` ← modelled financing,
`net` ← `net + financing`, `mae_acct` ← `mae + min(financing, 0)` (the whole charge is
pushed into the intraday trough; a credit never improves the trough). Every written file
carries its own `sha256` plus the `source_sha256` of the frozen W38 line it came from, in
`streams_<variant>_<window>_index.json` and in each derived
`qm.recompose-frozen-inputs/v1` manifest — the engine re-verifies every sha at load, so
the pin still binds.

Streams are at source risk 1.0 % (1R = 1000 USD, `RISK_FIXED`). The engine scales a
sleeve's `net`/`low`/`lots` by `risk_pct / 1.0`, and financing is linear in lots, so
injecting it at source risk scales correctly — including 13213's 0.15625 % half-weight.

### 2.1 Where the drag actually sits (primary rates, at book weights)

| sleeve | trades | overnight % | median hold h | financing USD | sleeve net USD | financing / net |
|---|---|---|---|---|---|---|
| 13213 USDJPY @0.15625 % | 1 596 | **0.0** | 7.2 | **0** | 32 137 | **0.0 %** |
| 10706 GBPUSD | 360 | 45.3 | 7.7 | −2 001 | 21 594 | −9.3 % |
| 10700 XAUUSD | 373 | 55.5 | 19.7 | −7 992 | 19 273 | −41.5 % |
| **11660 NDX** | 1 410 | 41.0 | 12.0 | **−9 333** | 9 537 | **−97.9 %** |
| 11422 USDCAD | 195 | 79.5 | 41.0 | −1 149 | 5 722 | −20.1 % |
| **10145 XAUUSD** | 306 | 91.8 | 115.1 | −6 382 | 5 549 | **−115.0 %** |
| 20266 XTIUSD | 432 | 89.3 | 64.4 | −931 | 2 735 | −34.0 % |
| 12710 XTIUSD | 82 | 87.8 | 116.0 | −236 | 2 369 | −10.0 % |
| **R2_capped_13213half** | 4 754 | — | — | **−28 024** | 98 916 | **−28.3 %** |
| **R0_demo8** | 1 063 | — | — | **−7 462** | 34 646 | **−21.5 %** |

Three findings the critique did not have:

1. **13213 USDJPY is 100 % intraday** — zero overnight, zero financing. The de-concentration
   half-weight costs nothing in financing terms, and USDJPY's missing native swap spec is
   therefore *irrelevant to this roster* (it matters only for a hypothetical variant).
2. **The worst sleeve is 11660 NDX, which the critique did not name.** Financing consumes
   97.9 % of its gross contribution: on the FTMO venue this sleeve is approximately
   financing-neutral. **10145 XAUUSD is worse than neutral** at −115 % — financing turns it
   net-negative.
3. R2 is *relatively* more financing-exposed than demo_8 (−28.3 % vs −21.5 %) — it simply
   starts from 2.9× the gross edge.

---

## 3. Chain re-runs

`tools/strategy_farm/ftmo/first_passage.py build`, schema `qm.ftmo-first-passage/v2`,
engine `2.0.0`, rulepack `FTMO_2S_100K_STANDARD_V2`. Parameters byte-identical to the
primary and holdout runs: seed **20260915**, **10 000** paths, block **10** bd, horizon
1 008 bd, funded horizon 120 bd, 20 CI batches, the same five-cell cost grid. `low_power`
is `false` ("adequate") for every run below.

`nofin` is a **pipeline-transparency control**: the streams go through the identical
rewrite/manifest path with every rate set to zero. It reproduces the published numbers
exactly — demo_8 full-sample LCB **0.6571** and 2023+ test LCB **0.4480**, matching
`FTMO_ALT_ROSTER_HOLDOUT_2026-09-18.md` — so any difference below is financing, not
plumbing.

### 3.1 Full sample

| variant | roster | E2E | **LCB** | **p50 bd** | P1 max-loss | P1 daily | cost ×1.5+2 LCB |
|---|---|---|---|---|---|---|---|
| no financing | R2_capped_13213half | 0.9531 | **0.9293** | **344** | 0.0086 | 0.0 | 0.9059 |
| **financing** | R2_capped_13213half | 0.8536 | **0.8259** | **439** | 0.0437 | 0.0 | 0.7554 |
| financing (conservative) | R2_capped_13213half | 0.8447 | **0.8198** | **446** | 0.0470 | 0.0 | 0.7436 |
| no financing | R0_demo8 | 0.6993 | **0.6571** | **746** | 0.0244 | 0.0 | 0.6059 |
| **financing** | R0_demo8 | 0.5614 | **0.5287** | **815** | 0.0491 | 0.0 | 0.4599 |
| financing (conservative) | R0_demo8 | 0.5555 | **0.5211** | **817** | 0.0501 | 0.0 | 0.4540 |

### 3.2 2023+ holdout window (fully-contained truncation, `holdout_lib` rule)

| variant | roster | E2E | **LCB** | **p50 bd** | P1 max-loss | engine window |
|---|---|---|---|---|---|---|
| no financing | R2_capped_13213half | 0.9907 | **0.9840** | **256** | 0.0006 | 2023-01-27..2025-12-05 (746 bd) |
| **financing** | R2_capped_13213half | 0.9785 | **0.9718** | **301** | 0.0020 | same |
| financing (conservative) | R2_capped_13213half | 0.9774 | **0.9660** | **304** | 0.0020 | same |
| no financing | R0_demo8 | 0.4972 | **0.4480** | **828** | 0.0505 | 2023-07-31..2024-12-06 (355 bd) |
| **financing** | R0_demo8 | 0.3695 | **0.3239** | **857** | 0.0923 | same |
| financing (conservative) | R0_demo8 | 0.3641 | **0.3218** | **857** | 0.0950 | same |

demo_8's shorter engine window is the pre-existing `11910 NZDUSD` artefact documented in
the holdout study, not a truncation effect of this one.

### 3.3 What financing costs each roster

| | R2_capped_13213half | R0_demo8 | gap after financing |
|---|---|---|---|
| full sample, ΔLCB | −0.1034 | −0.1284 | R2 ahead by **+0.2972** |
| full sample, Δp50 | +95 bd | +69 bd | R2 faster by **376 bd** |
| 2023+ test, ΔLCB | −0.0122 | −0.1241 | R2 ahead by **+0.6479** |
| 2023+ test, Δp50 | +45 bd | +29 bd | R2 faster by **556 bd** |
| P1 max-loss, full | 0.0086 → 0.0437 | 0.0244 → 0.0491 | R2 now **lower** |

Financing roughly **5×** R2's Phase-1 max-loss probability on the full sample
(0.0086 → 0.0437) and nearly doubles demo_8's (0.0244 → 0.0491) — but R2 ends up the
*safer* of the two on that axis, reversing the common-window finding of the holdout study.

---

## 4. Weekend rule — funded stage only

`docs/ftmo/FTMO_RULES_SNAPSHOT_2026-09-18.md`: *"no restriction during evaluation; funded
Standard: manage intra-week, close before weekend"*, provenance **CARRIED_OVER** (it was
not re-verified against an official page in this study). Challenge and Verification are
therefore unaffected; only the funded stage is.

**The forced-close P/L itself is UNMEASURED and is not estimated here.** The frozen Q08
streams carry `mae_acct` (whole-life worst excursion) but **no MFE and no intra-trade
equity path**, so the P/L a position would have shown at the cut cannot be read off disk —
only its lower bound. Inventing it would breach the evidence rule.

What *is* measurable, at the two candidate cut definitions:

| cut | roster | trades | net at cut-risk | share of roster net | MAE floor | financing not paid |
|---|---|---|---|---|---|---|
| Friday **21:00** server (the task's literal cut) | R2_capped_13213half | 1 015 / 4 754 | 68 838 USD | **83.1 %** | −104 586 USD | 10 455 USD |
| Friday **21:00** server | R0_demo8 | 452 / 1 063 | 32 565 USD | **94.0 %** | −49 812 USD | 4 051 USD |
| open at **Sat 00:00** (true weekend hold) | R2_capped_13213half | 96 / 4 754 | 7 906 USD | **9.5 %** | −10 876 USD | — |
| open at **Sat 00:00** | R0_demo8 | 99 / 1 063 | 1 906 USD | **5.5 %** | −9 218 USD | — |

The two definitions differ by a factor of nine because ~900 of R2's positions close
between Friday 21:00 and the Friday session end — several of these EAs already flatten
before the weekend on their own. **A 21:00 cut would be destructive to both rosters; the
rule as written ("close before the weekend") touches only 5.5–9.5 % of either roster's
edge.** This gap is the single largest unresolved item in this study: the funded-stage
answer depends on which cut FTMO actually enforces, and that is not on disk.

**Scenario (not a bound).** Removing every strictly weekend-spanning trade outright,
financing otherwise applied, full sample:

| roster | E2E | LCB | p50 bd | P1 max-loss |
|---|---|---|---|---|
| R2_capped_13213half | 0.8130 | **0.7910** | 470 | 0.0586 |
| R0_demo8 | 0.5375 | **0.5054** | 829 | 0.0482 |

This discards the P/L those trades had accrued by Friday, so it is harsher than a true
truncation; it is reported as the pessimistic corner. The ordering is unchanged
(+0.2856 LCB, −359 bd in R2's favour).

---

## 5. Verdict

**Financing does not change the recomposition decision.** Under the decision rule in
force — the challenger must still beat demo_8 on **both** control axes with financing
applied — `R2_capped_13213half` beats `R0_demo8` in **every** financed arm: full sample
LCB 0.8259 vs 0.5287 and median 439 vs 815 bd; 2023+ holdout 0.9718 vs 0.3239 and 301 vs
857 bd; conservative rates 0.8198 vs 0.5211; worst cost stress (×1.5 + 2 USD/lot) 0.7554
vs 0.4599; weekend-flat scenario 0.7910 vs 0.5054. Financing costs R2 10.3 LCB points on
the full sample but only 1.2 on the 2023+ holdout, while it costs demo_8 12.8 and 12.4 —
the incumbent is hurt *more*, in both windows, by the correction its own advocate asked
for. Finding 3 is a **material haircut, not a refutation**, exactly as finding 6 was.

**What the study does change.** Two sleeve-level facts now belong in any Q15/Q16
conversation: `11660 NDX` gives up 97.9 % of its gross contribution to US100.cash
financing and `10145 XAUUSD` gives up 115 % — on the FTMO venue that sleeve is
net-negative once financed. Neither was visible before, neither is one of the four
sleeves the task named, and both are candidates for replacement in any future
recomposition. Against that, `13213 USDJPY` — the concentration the half-weight was meant
to defuse — is 100 % intraday and pays nothing.

---

## 6. Assumptions and unverifiable items

1. **MT5 swap mode is not captured.** Rates are read as `SYMBOL_SWAP_MODE_POINTS`. The
   reading is validated against realised fills for GBPUSD, GER40.cash, USOIL.cash, EURUSD
   and XAUUSD; it is *not* independently validated for XAGUSD, NZDUSD or USDCAD.
2. **`US100.cash` has no native spec on disk.** Its rates (−6.2705 / +0.2692) and contract
   size (1.0) come from 9 realised demo positions in July 2026. Its triple day is
   **assumed = 5 (Friday)**: a Wednesday triple is positively *excluded* by the fills
   (a rollover into Thursday was charged 1×), and 5 matches `GER40.cash`, the only index
   in the native capture. No weekend-spanning US100 position exists to confirm it.
3. **`USDJPY` has no native spec on disk.** Long = realised median (n = 4, spread 84 % of
   median — USDJPY swap moved materially inside July); short = the v1 ftmo.com projection
   (−19.78 points), never observed on a fill. Its triple day is **assumed = 3**, matching
   all six natively-captured FX symbols. **This sleeve is 100 % intraday, so none of it
   affects the result.**
4. **JPY/CAD conversion** uses the trade's own `exit_price` (the quote *is* the profit-ccy
   price of one USD). The USDJPY long rate is stored as 204.1 JPY = the realised
   +1.3608 USD × 150; at other price levels it drifts by a few percent.
5. **Rates are a single dated snapshot** (2026-09-06 spec / July–Sept 2026 fills) applied
   to streams spanning 2017-10 … 2025-12. Real swaps track policy rates, which were near
   zero for much of that window — so the model is almost certainly *too expensive* in
   2017–2021 and about right in 2023–2025. It is applied uniformly because no dated swap
   history exists on disk. Direction of the error: against the rosters.
6. **Model-vs-venue residual −20.7 %** (see §1.3): the table charges more than the venue
   actually charged on the sampled fills.
7. **MAE treatment.** The full financing charge is pushed into the trade's intraday trough
   (`mae_acct`), which is conservative — in reality it accrues at rollover.
8. **The engine's slippage grid uses `.DWX` lots**, not FTMO-normalised lots, for the
   `+1 / +2 USD/lot` cost cells. That is pre-existing behaviour, unchanged here, and it
   understates the slippage cells for XTIUSD and NDX by the same ×10 factor §1.4 corrects
   for financing. Flagged, not fixed — fixing it is a change to the cost model (ROT-adjacent).
9. **Forced-Friday-close P/L: UNMEASURED.** No MFE, no intra-trade path on the streams.
   Only the exposure and the MAE floor are reported.
10. **Which weekend cut FTMO enforces on a funded Standard account is unverified**
    (rules-snapshot provenance CARRIED_OVER). The 21:00 and Sat-00:00 readings differ by
    9× in exposure (§4).
11. **No XAGUSD fill exists** to cross-check the −115.25 USD/lot/night silver long rate,
    which is the largest single rate in the table. It affects demo_8 only (sleeves 1537
    and 21505), i.e. it hurts the *incumbent*; if it is overstated, demo_8's financed
    numbers are pessimistic.
12. **Commission is unchanged.** This study models financing only; the commission/slippage
    grid is the one the primary run used.

---

## 7. Evidence

`D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\swap\`

| file | what |
|---|---|
| `derive_swap_rates.py` → `swap_rates_derivation.json` | both venue sources, per-position realised swaps, implied contract sizes, source sha256s |
| `validate_rates.py` → `swap_rate_validation.json` | charged-night rule verification, per-symbol implied rates, model-vs-actual residuals |
| `financing_lib.py` | rate table with per-value provenance, night/triple-day logic, weekend predicates, stream rewriter |
| `run_chain.py` → `chain_results.json` | 12 chain runs (3 variants × 2 windows × 2 rosters) + per-sleeve financing summary |
| `weekend_exposure.py` → `weekend_exposure.json` | §4 exposure at both cut definitions |
| `run_weekend_scenario.py` → `weekend_scenario_results.json` | the weekend-flat scenario |
| `streams_<variant>_<window>/` + `_index.json` | financing-adjusted streams, each with `sha256` + `source_sha256` |
| `manifest_<variant>_<window>.json` | derived `qm.recompose-frozen-inputs/v1` manifests |
| `chain_<variant>_<window>_<roster>.json` + `_manifest.json` | raw engine output per run |

Inputs (read-only): `D:\QM\reports\book_evolution\2026-W38\ftmo\snapshot_r2\`,
`docs/ops/evidence/2026-09-06_ftmo_demo_install/terminal_snapshot.json`,
`docs/ops/evidence/2026-09-14_ftmo_book_v2/ftmo_book_symbol_cost_snapshot_v2.json`,
`docs/ops/evidence/2026-09-12_ftmo_native_cost_receipts/`,
`<FTMO demo terminal>\MQL5\Files\QM\journal\live_deals_normalized.csv`,
`docs/ftmo/FTMO_RULES_SNAPSHOT_2026-09-18.md`,
`docs/ftmo/FTMO_ALT_ROSTER_HOLDOUT_2026-09-18.md`.

The live read-models were not written: `D:\QM\reports\state\ftmo_first_passage*.json`
are untouched by this study.
