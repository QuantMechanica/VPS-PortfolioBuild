# DXZ Book v2 — Selective Union Search (2026-09-13)

**Status:** ANALYSIS EVIDENCE — `DRY_RUN`, `deployment_action=NONE`, `autotrading_action=NONE`.
Nothing here mints a book, changes a live weight, touches `C:\QM\mt5\T_Live`, or starts MT5.
Application of any book remains an OWNER ceremony.

**Question.** Today's full-union book (41 sleeves, 9.75 %) FAILS the ratified not-worse gate on
return/maxDD and maxDD. Is there a *subset* of the union that passes the gate **by construction**,
and which subset is best?

**Answer.** Yes. A 30-sleeve book — the live 24 plus six new sleeves — passes all three checks
with return/maxDD 5.57 vs the incumbent 3.71 and maxDD 1.68 % vs 2.43 %. Verified with the shipped
builder: `status = APPLY_RECOMMENDED`.

---

## 1. Method

| Item | Value |
| --- | --- |
| Metric functions | `book_builder_common.matrix_on_grid / capped_inverse_vol / portfolio_daily / book_metrics`; gate `build_book_dxz._gate`; concentration `concentration_tail.evaluate` |
| Grid | ONE shared day grid: union of the trading days of all **41** union keys inside the common window |
| Window | 2019-08-02 … 2024-12-06, **1374** days |
| Risk budget | total 9.75 %, sleeve cap 1.0 %, capped inverse vol on daily PnL |
| Starting capital | 100 000 |
| Gate reference | the **deployed 24** (`portfolio_manifest_live_24sleeve_20260724.json`) with its deployed `risk_percent` (sum 9.7499) — *always*, for every variant |
| Gate rule | ALL of: return/maxDD ≥ incumbent; worst-day ≥ incumbent; maxDD ≤ incumbent |
| Stream roots | ordered, as `build_book_dxz._load_daily_sources`: v2b bundle for the 23 proposal keys, `dxz_final_20260719` for the 18 incumbent-only keys |
| Excluded | `41221:EURUSD.DWX` (clone of live `11421`, OWNER decision) |

**Grid invariance.** `annual_return_pct` scales with `1/n_days`, identically for proposal and
incumbent, so `return/maxDD` is a ratio of two equally scaled quantities; `max_drawdown_pct` and
`worst_day_pct` are unaffected by zero-filled days. **The gate verdict is therefore invariant to the
grid choice** — only the absolute `ann` / `ret-DD` figures rescale. This is confirmed numerically in
§6 (builder grid 1351 days vs analysis grid 1374 days; factor 1.01702 on both sides).

---

## 2. Baselines

Gate reference for both rows is the deployed 24.

| # | Book | n | Weights | ann % | maxDD % | ret/DD | worst day % | Sharpe | Gate |
| --- | --- | --: | --- | --: | --: | --: | --: | --: | --- |
| ref | live 24 **as deployed** | 24 | deployed `risk_percent` | 9.0024 | 2.4255 | **3.7115** | **-0.8577** | 2.3192 | (reference) |
| i | live 24, re-weighted | 24 | capped inv-vol 9.75/1.0 | 9.0688 | 2.4700 | 3.6717 | -0.8367 | 2.3435 | FAIL (ret/DD, maxDD) |
| ii | live 24 **minus 3 dead** | 21 | capped inv-vol 9.75/1.0 | 9.2034 | 3.2667 | 2.8174 | -1.3912 | 1.9984 | FAIL (all three) |

**Finding B1 — removing the dead sleeves makes the book worse, not better.** Dropping
`12778:AUDUSD`, `13117:EURGBP`, `12969:USDJPY` redistributes 1.42 pp of risk onto 21 remaining
sleeves: maxDD 2.43 → 3.27 %, worst day -0.86 → -1.39 %, Sharpe 2.32 → 2.00. In the sealed backtest
those three sleeves are genuine diversifiers; in production they contribute nothing
(`docs/ops/evidence/2026-09-02_dark_live_sleeves_disposition.md`, and 0 closes each in
`live_attribution/20260913/sunday_live_attribution.json`). See §7.

**Finding B2 — re-weighting alone is not free.** Even the *same 24 sleeves* fail the gate when
re-solved by capped inverse vol (row i): the deployed weights are marginally better on this history
than the rule that would produce them today. The gate is therefore not a formality.

---

## 3. Greedy forward selection

Rule: at each step add the candidate that most improves return/maxDD (tie-break: lower maxDD, then
higher Sharpe) **while all three gate checks stay PASS vs the deployed 24**; stop when no candidate
improves. Candidate set = the 23 v2b pairs (24 minus `41221:EURUSD`). Six of them
(`10403:XAUUSD`, `10513:XAUUSD`, `10706:GBPUSD`, `11421:EURUSD`, `11708:EURUSD`, `13213:USDJPY`)
are already live and are therefore already in every seed — 17 are genuinely addable.

### 3a. From variant (i) — the live 24 — **this is the winning route**

| Step | Added | n | ann % | maxDD % | ret/DD | worst % | Sharpe | Gate |
| --: | --- | --: | --: | --: | --: | --: | --: | --- |
| 0 | (seed, re-weighted 24) | 24 | 9.0688 | 2.4700 | 3.6717 | -0.8367 | 2.3435 | FAIL |
| 1 | `9641:WS30.DWX` | 25 | 8.9577 | 2.0089 | 4.4591 | -0.8018 | 2.3430 | **PASS** |
| 2 | `10700:XAUUSD.DWX` | 26 | 9.5557 | 1.9459 | 4.9107 | -0.8272 | 2.4608 | PASS |
| 3 | `13054:XTIUSD.DWX` | 27 | 9.5144 | 1.8459 | 5.1543 | -0.7846 | 2.5407 | PASS |
| 4 | `21505:XAGUSD.DWX` | 28 | 9.4943 | 1.7894 | 5.3059 | -0.7288 | 2.5739 | PASS |
| 5 | `13013:NDX.DWX` | 29 | 9.5386 | 1.7527 | 5.4421 | -0.7045 | 2.6249 | PASS |
| 6 | `1537:XAGUSD.DWX` | 30 | **9.3816** | **1.6839** | **5.5712** | **-0.6766** | **2.5940** | **PASS** |
| 7 | — STOP — | | | | | | | |

A single addition (`9641:WS30`) is already enough to clear the bar: it cuts maxDD by 0.46 pp.

**Rejected at the stop (all 11 remaining candidates):**

| Candidate | Broke | ret/DD | maxDD % | worst % |
| --- | --- | --: | --: | --: |
| `41219:XAUUSD.DWX` | **worst_day_not_worse** | 5.6088 | 1.6053 | **-0.9183** |
| `12710:XTIUSD.DWX` | no ret/DD improvement | 5.3571 | 1.7497 | -0.6479 |
| `12849:XTIUSD.DWX` | no ret/DD improvement | 5.3353 | 1.7492 | -0.6481 |
| `11422:USDCAD.DWX` | no ret/DD improvement | 5.1304 | 1.8337 | -0.7062 |
| `11660:NDX.DWX` | no ret/DD improvement | 4.9900 | 1.9573 | -0.6831 |
| `11910:NZDUSD.DWX` | no ret/DD improvement | 4.7945 | 1.9134 | -0.7528 |
| `12855:XTIUSD.DWX` | no ret/DD improvement | 4.6720 | 1.9296 | -0.6907 |
| `10145:XAUUSD.DWX` | no ret/DD improvement | 4.6511 | 2.0389 | -0.7564 |
| `20048:XTIUSD.DWX` | no ret/DD improvement | 4.5257 | 1.9058 | -0.6072 |
| `21501:USDJPY.DWX` | no ret/DD improvement | 4.2792 | 2.2023 | -0.6825 |
| `11881:GBPUSD.DWX` | no ret/DD improvement | 3.7970 | 2.4030 | -0.6543 |

`41219:XAUUSD` is the only candidate that would raise return/maxDD further (5.609) — and it is the
only one that breaks a gate check: its worst day of -0.918 % is worse than the incumbent's -0.858 %.
The gate does real work at exactly the right place.

### 3b. From variant (ii) — the live 21 — **fails at step 1**

The strict rule stops immediately: **all 17 addable candidates break all three checks**. The best of
them, `9641:WS30`, still lands at maxDD 2.58 % / worst -1.30 % against a bar of 2.4255 % / -0.8577 %.
Result: 21 sleeves, ret/DD 2.8174, gate FAIL.

**Relaxed cross-check** (identical improvement rule, gate scored only as a property of each state, so
a myopic first step cannot hide a later pass):

| Step | Added | n | ann % | maxDD % | ret/DD | worst % | Gate |
| --: | --- | --: | --: | --: | --: | --: | --- |
| 0 | (seed 21) | 21 | 9.2034 | 3.2667 | 2.8174 | -1.3912 | FAIL |
| 1 | `9641:WS30.DWX` | 22 | 9.0040 | 2.5804 | 3.4894 | -1.3002 | FAIL |
| 2 | `10700:XAUUSD.DWX` | 23 | 9.7112 | 2.4903 | 3.8996 | -1.2803 | FAIL |
| 3 | `21505:XAGUSD.DWX` | 24 | 9.6284 | 2.3743 | 4.0553 | -1.2180 | FAIL |
| 4 | `1537:XAGUSD.DWX` | 25 | 9.3604 | 2.2335 | 4.1908 | -1.1423 | FAIL |
| 5 | `13013:NDX.DWX` | 26 | 9.4030 | 2.2383 | 4.2010 | -1.0931 | FAIL |

**No state on the relaxed path ever passes** — `worst_day_not_worse` stays broken at every step
(best -1.0931 % vs bar -0.8577 %). The 21-sleeve seed is not repairable from the v2b candidate pool.

---

## 4. Greedy backward pruning (cross-check)

Start from the full union (41), remove the sleeve whose removal most improves return/maxDD, until
the gate passes.

| Step | Removed | n | ann % | maxDD % | ret/DD | worst % | Sharpe | Gate |
| --: | --- | --: | --: | --: | --: | --: | --: | --- |
| 0 | (full union) | 41 | 8.2034 | 3.1959 | 2.5669 | -0.7016 | 2.5600 | FAIL |
| 1 | `11881:GBPUSD.DWX` | 40 | — | 2.7056 | 3.0913 | -0.7763 | — | FAIL |
| 2 | `11165:AUDCAD.DWX` | 39 | — | 2.3728 | 3.6493 | -0.8007 | — | FAIL |
| 3 | `13213:USDJPY.DWX` | 38 | 8.6256 | 1.9884 | **4.3380** | -0.8175 | 2.6192 | **PASS** |

**Removed set: `{11881:GBPUSD.DWX, 11165:AUDCAD.DWX, 13213:USDJPY.DWX}`** — 38 sleeves, ret/DD 4.338.
It passes, but it is **worse than the forward route on every gate dimension** (ret/DD 4.34 vs 5.57,
maxDD 1.99 vs 1.68, worst -0.818 vs -0.677) and it retires two live sleeves. The forward route is
selected.

**Why the full union fails at all:** it is not a bad-sleeve problem but a dilution problem. Spreading
a fixed 9.75 % over 41 sleeves cuts each incumbent weight by ~40 %, and the high-conviction incumbent
sleeves lose more return than the 17 thin newcomers add — annual return falls 9.00 → 8.20 % while
maxDD rises. Adding only the six sleeves that actually cut portfolio variance keeps the return and
buys the drawdown reduction.

---

## 5. The selected book — 30 sleeves

Route `greedy_forward_from_variant_i`. **No live sleeve is dropped**; this is a pure-addition
proposal of six sleeves.

| | Selected 30 | Deployed 24 (bar) | Δ |
| --- | --: | --: | --- |
| annual return % | 9.3816 | 9.0024 | +0.38 pp |
| max drawdown % | **1.6839** | 2.4255 | **-0.74 pp** |
| return / maxDD | **5.5712** | 3.7115 | **+1.86** |
| worst day % | **-0.6766** | -0.8577 | **+0.18 pp** |
| Sharpe | 2.5940 | 2.3192 | +0.27 |
| gate | `return_to_maxdd` PASS · `maxdd` PASS · `worst_day` PASS | | **PASS** |

**Six new sleeves:** `1537:XAGUSD.DWX`, `9641:WS30.DWX`, `10700:XAUUSD.DWX`, `13013:NDX.DWX`,
`13054:XTIUSD.DWX`, `21505:XAGUSD.DWX`.

**Six live/v2b overlaps** (already in the book; sourced from the v2b bundle, proposal row wins):
`10403:XAUUSD.DWX`, `10513:XAUUSD.DWX`, `10706:GBPUSD.DWX`, `11421:EURUSD.DWX`,
`11708:EURUSD.DWX`, `13213:USDJPY.DWX`.

### 5a. Per-sleeve weights (RISK_PERCENT, sum = 9.750000, cap 1.0 % — nothing capped)

| EA | Symbol | Src | weight % | live % now | EA label |
| --: | --- | --- | --: | --: | --- |
| 13128 | NDX.DWX | LIVE | 0.9087 | 1.0000 | pre-fomc-drift-ndx |
| 12567 | XNGUSD.DWX | LIVE | 0.7892 | 0.9797 | cum-rsi2-commodity |
| 10919 | XTIUSD.DWX | LIVE | 0.7068 | 0.9181 | grimes-overshoot |
| 12567 | XAUUSD.DWX | LIVE | 0.6467 | 0.7465 | cum-rsi2-commodity |
| 12969 | USDJPY.DWX | LIVE † | 0.4865 | 0.5100 | usdjpy-gotobi-nakane-fix |
| 11708 | EURUSD.DWX | LIVE | 0.4490 | 0.5080 | anon-market-squeeze-d1 |
| 1556 | XAUUSD.DWX | LIVE | 0.4456 | 0.6017 | aa-zak-mom12 |
| 11165 | AUDCAD.DWX | LIVE | 0.4188 | 0.5230 | weiss-rsi-ma |
| 13054 | XTIUSD.DWX | **NEW** | 0.4053 | — | brent-tom-mom |
| 1537 | XAGUSD.DWX | **NEW** | 0.3860 | — | aa-vol-sma10 |
| 12778 | AUDUSD.DWX | LIVE † | 0.3620 | 0.4905 | edgelab-audusd-eurjpy-cointegration |
| 11132 | SP500.DWX | LIVE | 0.3520 | 0.4562 | tm-cum-rsi2 |
| 13117 | EURGBP.DWX | LIVE † | 0.3378 | 0.4199 | eurgbp-audjpy |
| 11165 | EURUSD.DWX | LIVE | 0.3376 | 0.4127 | weiss-rsi-ma |
| 13013 | NDX.DWX | **NEW** | 0.3120 | — | grimes-trendday-v2 |
| 9641 | WS30.DWX | **NEW** | 0.3078 | — | QM5_9641 |
| 21505 | XAGUSD.DWX | **NEW** | 0.2804 | — | xag-weekly-lowvol-momentum |
| 11421 | EURUSD.DWX | LIVE | 0.2676 | 0.3364 | ohlc-daily-squeeze-reversal-d1 |
| 11421 | AUDUSD.DWX | LIVE | 0.2648 | 0.3614 | ohlc-daily-squeeze-reversal-d1 |
| 10513 | XAUUSD.DWX | LIVE | 0.2462 | 0.3050 | QM5_10513 |
| 12989 | XAUUSD.DWX | LIVE | 0.1874 | 0.2420 | grimes-nested-pb-v2 |
| 10403 | XAUUSD.DWX | LIVE | 0.1796 | 0.2204 | QM5_10403 |
| 10939 | GBPUSD.DWX | LIVE | 0.1613 | 0.1887 | grimes-context-pb |
| 1567 | EURUSD.DWX | LIVE | 0.1523 | 0.1791 | demark-td-reverse-sequential-h4 |
| 10911 | GDAXI.DWX | LIVE | 0.1038 | 0.1276 | grimes-complex-pb |
| 10700 | XAUUSD.DWX | **NEW** | 0.0733 | — | tv-liq-break |
| 13301 | GDAXI.DWX | LIVE | 0.0534 | 0.0692 | balke-minute-range-breakout |
| 10440 | NDX.DWX | LIVE | 0.0482 | 0.0577 | mql5-ohlc-mtf |
| 10706 | GBPUSD.DWX | LIVE | 0.0434 | 0.0530 | tv-mon-ls |
| 13213 | USDJPY.DWX | LIVE | 0.0365 | 0.0431 | balke-gmt3-range-breakout |

† sleeve is dark in production — see §7.

### 5b. Robustness

| Metric | Value |
| --- | --- |
| Effective number of bets (ENB, weighted, Meucci-style) | **21.92** of 30 sleeves |
| Max pairwise \|r\| (daily PnL, shared grid) | **0.2937** |
| Pairs flagged \|r\| ≥ 0.5 | **none (0)** |
| Sum of RISK_PERCENT | 9.750000 |
| Sleeves at the 1.0 % cap | 0 |

**Concentration policy** (`tools/strategy_farm/config/concentration_tail_limits.v1.json`, 9.75 %
scale, `concentration_tail.evaluate`): `status = PASS`, `builder_eligible = true`,
`policy_status = OWNER_RATIFIED`, `concentration_reject = []`.

| Dimension | Status | Worst bucket | Used | Cap |
| --- | --- | --- | --: | --: |
| asset_class | PASS | fx | 34.03 % | 69.0 % |
| family | PASS | grimes | 15.09 % | 57.5 % |
| session | PASS | ASIA | 51.36 % | 80.5 % |
| symbol | PASS | XAUUSD.DWX | 18.24 % | 46.0 % |
| joint tail (k=10) | PASS | worst joint day | 0.6623 % | 4.0 % |

Highlights: metals+energy 44.58 % of book risk (4.35 % stop risk), XAUUSD 18.24 % (1.78 % stop risk).

### 5c. Burn-in variant

New sleeves at min-lot (median trade on 0.01 lots), the live 24 at their v2 target weight
(`burnin.py`; streams are `RISK_FIXED` $1000 on 100 k = 1.0 %/trade, lots scale linearly).

| Sleeve | Burn-in % | v2 target % | Basis |
| --- | --: | --: | --- |
| `1537:XAGUSD.DWX` | 0.0769 | 0.3860 | MIN_LOT_MEDIAN_TRADE |
| `21505:XAGUSD.DWX` | 0.0714 | 0.2804 | MIN_LOT_MEDIAN_TRADE |
| `13054:XTIUSD.DWX` | 0.0488 | 0.4053 | MIN_LOT_MEDIAN_TRADE |
| `10700:XAUUSD.DWX` | 0.0130 | 0.0733 | MIN_LOT_MEDIAN_TRADE |
| `13013:NDX.DWX` | 0.0105 | 0.3120 | MIN_LOT_MEDIAN_TRADE |
| `9641:WS30.DWX` | 0.0104 | 0.3078 | MIN_LOT_MEDIAN_TRADE |
| 24 live sleeves | 7.9852 | 7.9852 | V2_TARGET_WEIGHT |
| **Sum** | **8.2162** | 9.7500 | |

All-trades-min-lot basis (every trade ≥ 0.01 lots): **8.0728 %**. Burn-in therefore runs the book at
~84 % of the target budget; the six new sleeves carry 0.231 % of risk in total while they prove
themselves live.

---

## 6. Builder verification

```
python -X utf8 tools/strategy_farm/portfolio/build_book_dxz.py \
  --roster D:/QM/reports/portfolio/dxz_v2_20260913/selective/roster_selected.json \
  --stream-root D:/QM/reports/portfolio/dxz_v2_20260913/streams_v2b \
  --incumbent-stream-root D:/QM/reports/portfolio/dxz_final_20260719 \
  --union --analysis-only --as-of 2026-09-13
```

**Result: `status = APPLY_RECOMMENDED`, 30 sleeves, gate PASS on all three checks,
`concentration.builder_eligible = true`, `concentration_reject = []`,
`deployment_action = NONE`, `autotrading_action = NONE`.**

`roster_selected.json` declares the **proposal side only** — the six new sleeves. `--union` re-adds
the incumbent 24 and de-duplicates, giving exactly the selected 30. (Declaring the incumbent-only
sleeves in the roster instead would make the builder source every sleeve from the v2b bundle, which
does not seal them, and the run would fail closed.) The file also carries the full 30-sleeve
`selected_book` with weights and `selected_book_roster_sha256` for identity.

Metric reconciliation — the builder's own grid is 1351 days (union of the selected 30 plus the
incumbent 24) vs the 1374-day analysis grid (union of all 41). Ratio 1374/1351 = 1.01702:

| | Analysis (1374 d) | Builder (1351 d) | Predicted |
| --- | --: | --: | --- |
| proposal ann % | 9.3816 | 9.5413 | 9.3816 × 1.01702 = 9.5413 ✓ |
| proposal ret/DD | 5.5712 | 5.6661 | 5.5712 × 1.01702 = 5.6661 ✓ |
| proposal maxDD % | 1.68394 | 1.68393 | identical ✓ |
| proposal worst % | -0.67664 | -0.67664 | identical ✓ |
| incumbent ann % | 9.0024 | 9.1557 | 9.0024 × 1.01702 = 9.1557 ✓ |
| incumbent ret/DD | 3.7115 | 3.7747 | 3.7115 × 1.01702 = 3.7747 ✓ |

Both sides rescale by the same factor; **every gate check and the PASS verdict are identical.**
The book reproduces.

---

## 7. Two things OWNER must weigh before this becomes a decision

**(1) Three of the 30 sleeves are dark in production.** `12778:AUDUSD`, `13117:EURGBP` (symbol-name
mismatch) and `12969:USDJPY` (dark 7 weeks) hold 1.186 % of the proposed budget and carry real
backtest PnL, but have **0 closes** since 2026-07-24
(`live_attribution/20260913/sunday_live_attribution.json`). The book above therefore books
diversification it will not actually receive. **Sensitivity — the same book with those three removed
(27 sleeves, re-solved at 9.75 %) still PASSES the gate:** ann 9.3687 %, maxDD 2.2929 %, ret/DD
4.0859, worst -0.8474 %, Sharpe 2.3262, concentration PASS. The margin is thinner (maxDD 2.29 vs the
2.4255 bar) but it holds. The 30-sleeve book is the correct answer to the question as posed; the
27-sleeve variant is the honest answer to "what will actually run". Their disposition is an open
OWNER item, not something this analysis settles.

**(2) A materially better book exists if live sleeves may be retired.** An informational backward
polish of the selected 30 (remove while the gate stays PASS and return/maxDD improves) drops
`10911:GDAXI`, `10513:XAUUSD`, `13213:USDJPY`, `12778:AUDUSD` and reaches **26 sleeves, ret/DD 7.019,
maxDD 1.351 %, ann 9.484 %, worst -0.724 %** — clearly better than 5.571 on this history. It is
deliberately **not** the selected roster: retiring four live sleeves on one in-sample pass is an
in-sample selection act, not a not-worse addition, and it belongs in a Q16 challenger/retire
discussion with out-of-sample evidence, not in a book-composition search. Recorded so it is not lost.

---

## 8. Conclusion

**Deutsch.** Das volle Vereinigungsbuch (41 Sleeves) fällt durch das Nicht-schlechter-Tor, weil es
ein Verdünnungsproblem hat und kein Qualitätsproblem: dieselben 9,75 % Risiko auf 41 statt 24
Sleeves verteilt schneidet jedem starken Bestandssleeve rund 40 % Gewicht weg, und die 17 dünnen
Neuzugänge liefern weniger Ertrag zurück, als die Bestandssleeves verlieren. Nimmt man statt aller
Neuzugänge nur die sechs, die tatsächlich die Portfolio-Schwankung senken — `9641:WS30`,
`10700:XAUUSD`, `13054:XTIUSD`, `21505:XAGUSD`, `13013:NDX`, `1537:XAGUSD` —, entsteht ein Buch aus
30 Sleeves, das kein einziges Live-Sleeve abschaltet und alle drei Torprüfungen besteht: Ertrag pro
maximalem Rückschlag 5,57 statt 3,71, maximaler Rückschlag 1,68 % statt 2,43 %, schlechtester Tag
-0,68 % statt -0,86 %, bei leicht höherer Jahresrendite (9,38 % statt 9,00 %). Der Builder bestätigt
das eigenständig mit `APPLY_RECOMMENDED`. Zwei Vorbehalte gehören dazu: das Entfernen der drei toten
Live-Sleeves macht das Buch rechnerisch schlechter, nicht besser (sie sind im Backtest echte
Diversifizierer, im Livebetrieb aber stumm) — ohne sie bleibt das Buch mit 27 Sleeves trotzdem über
der Latte —, und wer bereit wäre, vier Live-Sleeves stillzulegen, käme rechnerisch auf 7,02 statt
5,57, was aber eine Auswahl im Rückspiegel wäre und in eine Q16-Diskussion gehört, nicht in diese.
Nichts davon schaltet irgendetwas scharf: Anwendung, Deployment und AutoTrading bleiben OWNER.

**English.** The full 41-sleeve union fails the not-worse gate for a dilution reason, not a quality
reason: spreading the same 9.75 % across 41 instead of 24 sleeves cuts roughly 40 % off every
high-conviction incumbent weight, and the 17 thin newcomers give back less return than the incumbents
lose. Adding only the six newcomers that actually reduce portfolio variance — `9641:WS30`,
`10700:XAUUSD`, `13054:XTIUSD`, `21505:XAGUSD`, `13013:NDX`, `1537:XAGUSD` — produces a 30-sleeve
book that retires no live sleeve and clears all three checks: return/maxDD 5.57 vs 3.71, maxDD 1.68 %
vs 2.43 %, worst day -0.68 % vs -0.86 %, at a slightly higher annual return (9.38 % vs 9.00 %). The
shipped builder confirms this independently with `APPLY_RECOMMENDED`. Two caveats travel with it:
removing the three dark live sleeves makes the arithmetic worse, not better (they are genuine
diversifiers in the sealed backtest and silent in production) — though the book still passes at 27
sleeves without them — and an operator willing to retire four live sleeves could reach 7.02 instead
of 5.57, which is an in-sample selection act belonging to a Q16 discussion rather than to this one.
None of it arms anything: application, deployment and AutoTrading remain OWNER-only.

---

## 9. Evidence files

| Path | Content |
| --- | --- |
| `C:\QM\repo\docs\ops\evidence\2026-09-13_dxz_book_v2\select_union.py` | the search driver (read-only except the two sanctioned output dirs) |
| `C:\QM\repo\docs\ops\evidence\2026-09-13_dxz_book_v2\SELECTIVE_UNION_REPORT.md` | this report |
| `D:\QM\reports\portfolio\dxz_v2_20260913\selective\selection_analysis.json` | full search record: baselines, both forward paths with every rejection, relaxed path, backward path, polish sensitivity, minus-dead sensitivity, correlation matrix, co-active days, full concentration evidence |
| `D:\QM\reports\portfolio\dxz_v2_20260913\selective\roster_selected.json` | selected roster in the builder roster schema (proposal side = 6 new sleeves; `selected_book` = all 30 with weights) |
| `D:\QM\reports\portfolio\dxz_v2_20260913\selective\analytic_preview_manifest_SELECTED.json` | per-sleeve weights, volumes, min-lot thresholds (burn-in input) |
| `D:\QM\reports\portfolio\dxz_v2_20260913\selective\burnin_variant.json` | burn-in variant, sum 8.2162 % |

Inputs: `D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json` (incumbent),
`D:\QM\reports\portfolio\dxz_final_20260719` (incumbent streams),
`D:\QM\reports\portfolio\dxz_v2_20260913\roster_v2b.json` +
`D:\QM\reports\portfolio\dxz_v2_20260913\streams_v2b` (candidates),
`tools\strategy_farm\config\concentration_tail_limits.v1.json` (policy, unmodified),
`docs\ops\evidence\2026-09-02_dark_live_sleeves_disposition.md`,
`D:\QM\reports\portfolio\live_attribution\20260913\sunday_live_attribution.json`.
