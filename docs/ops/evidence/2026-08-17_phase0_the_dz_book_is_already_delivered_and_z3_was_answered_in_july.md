# Phase 0 — The DZ book is already delivered, and Z3's search was run and answered on 2026-07-11

## What I was asked to do

Z3 was framed as *"das Einzige auf der gesamten Liste, das kurzfristig ein lieferbares Buch ergeben
kann"* — a bounded offline weighting search over the 24 sleeves to shed 0.0316 pp of MaxDD while
holding a +0.0315 Sharpe and +0.085 pp return gain, with a pre-registered search space and a time-split
holdout.

I applied **Bestandsaufnahme vor Neubau** before writing any search. It paid off twice, and the second
time changed what Phase 0 is.

## Finding 1 — the machine exists, with the holdout already built in

`tools/strategy_farm/portfolio/dxz_weight_oos_validation.py`. Its own contract:

- constraints `0 ≤ w_i ≤ CAP (1.0%)`, `sum(w) = TOTAL_RISK (9.75%)` — **exactly** the DXZ builder's
- optimiser: capped projected hill-climb with random restarts
- **fit on 60 % of months, score on the held-out 40 %, then the reverse fold**
- three candidates: A inverse-vol (current), B max-Sharpe tangency, C direct VaR95-Darwin
- *"The honest DXZ optimum is the weighting that wins OUT-OF-SAMPLE."*

Writing a new search would have created a second truth next to this — the exact failure the inventory
rule exists to prevent.

## Finding 2 — it was already run, and the answer was "the current weighting is already optimal"

`docs/ops/evidence/dxz_weighting_oos_validation_2026-07-11.csv`, committed as *"evidence: DXZ weighting
is already optimal (OOS-validated)"*:

| Slice | A inverse-vol (current) | B max-Sharpe | C direct-VaR95 |
|---|---:|---:|---:|
| full sample **(in-sample)** | eff 9.28 · Sharpe 2.233 | 7.909 · 2.49 | **12.744** · 2.149 |
| IS 60 % → **OOS last 40 %** | **15.345** · **3.365** | 6.123 · 2.094 | 7.707 · 2.009 |
| IS 60 % → **OOS first 40 %** | **5.471** · **1.555** | 2.229 · 0.779 | 1.187 · 0.426 |

**The current weighting wins out-of-sample in both folds by roughly 2.5×.** And note C: it wins
*in-sample* (12.744 vs A's 9.28) and then collapses to 1.187 on the reverse fold. That is the overfit
signature, and the holdout caught it.

### Why this matters specifically for Z3's objective

Z3's target is a **0.0316 pp reduction in a realised MaxDD over one 1349-day path.** MaxDD is a
single-path percentile statistic — structurally the same family as objective C, which maximised a
single percentile (VaR95) and was the worst out-of-sample performer of the three.

So Z3 as specified is at high risk of producing an in-sample win that fails forward, and the study that
would catch it already exists and already caught the analogous case. **My recommendation is not to run
it**, and that recommendation rests on measured evidence rather than caution.

## Finding 3 — and this is the one that reframes the goal: the DZ book is already delivered

`portfolio_manifest_live_24sleeve_20260724.json`:

```
status                LIVE
approved_by           OWNER (Fabian) 2026-07-24 — countersigned via chat
book                  DXZ_4000090541
n_sleeves             24
total_risk_pct        9.7499
weight_method         as-deployed (recorded from T_Live deployed presets, not a proposal)
```

Verified against the terminal rather than trusted:

- `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\QM\` holds **24 `QM5_*.ex5`**
- `…\MQL5\Presets\` holds **24 presets numbered `01_`–`24_`**
- set comparison of manifest pairs against parsed preset pairs: **exact match, 0 missing either way**

**So the incumbent is not a reference point — it is the deployed book.**

### What `NOT_WORSE_BAR_NOT_MET` therefore means

The builder is not failing to produce a book. It is being asked whether to **change** a live,
OWNER-countersigned book, and it declines because the proposed reweighting is 0.0316 pp worse on MaxDD
while better on Sharpe, return and worst-day. That is the ratchet **protecting a deployed book** — the
correct outcome, not a blocked delivery.

And the "proposal" is not a candidate improvement: both sides carry the same 24 sleeves over the same
1349 days, and the proposal is `CAPPED_INVERSE_VOL_DAILY_PNL` **recomputed on current data** against
weights frozen on 07-24. It is a routine refresh that comes out marginally worse on one leg.

## Consequence for the delivery definition

Section 2 defines DZ-done as *"Der Builder gibt eine Anwendungsempfehlung ab, nicht `BAR_NOT_MET`."*
Read against the above, that criterion asks the builder to recommend **replacing a live book that is
already good**. A builder that says "do not change it" satisfies the intent while failing the letter.

**This is a question for OWNER, not something to reinterpret unilaterally.** Two readings:

1. **DZ is delivered.** The remaining DZ work is re-sync discipline (Phase 4.3): after each Q10
   addition, check whether a new survivor belongs in the book. The 0.0316 pp gap is then not a gap at
   all.
2. **DZ is not delivered because the live book was assembled by reweighting rather than by
   construction from the full pool** — in which case the missing piece is BUILD-4's construction mode,
   not a weighting search, and the target is a *better roster*, not better weights on this one.

Reading 2 is the substantive one and it matches the stated thesis that value comes from combination.
But it makes the DZ half a Phase-3 problem, not a Phase-0 one — and it means **nothing on the current
list yields a deliverable DZ book short-term**, because the one candidate for that was Z3.

## One correction of my own, caught before reporting

My first check of T_Live returned **0** `.ex5` files and briefly looked like the manifest's `status: LIVE`
was false. That was my path error — the real root is `T_Live\MT5_Base\...`, not `T_Live\MQL5\...`. A
wrong claim that a book marked LIVE is not deployed would have been a serious error, and it was avoided
only by checking the directory instead of reporting the count.

## Evidence

- `tools/strategy_farm/portfolio/dxz_weight_oos_validation.py` — the existing search with its holdout
- `docs/ops/evidence/dxz_weighting_oos_validation_2026-07-11.csv` — both folds, all three weightings
- `2a7e08245` (2026-07-11) — *"DXZ weighting is already optimal (OOS-validated)"*
- `D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json` — `status: LIVE`, 24 sleeves
- `C:\QM\mt5\T_Live\MT5_Base\MQL5\{Experts\QM,Presets}` — 24 `.ex5`, 24 numbered presets, exact match
- DXZ dry-run manifest: `weighting.method CAPPED_INVERSE_VOL_DAILY_PNL`, identical roster both sides

**Not asserted:** whether AutoTrading is currently enabled on T_Live. The manifest records
`autotrading_action: NONE` and that flag is OWNER + Claude authority; I read the deployment, I did not
touch or verify the trading state.
