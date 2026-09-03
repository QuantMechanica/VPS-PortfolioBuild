# Shadow book-evaluation — OWNER-DEC-Q12-ADMISSION cohort (evidence-only dossier)

- Router task: `08ba621a-0928-41d5-844b-62080da79401` (`ops_issue`, lane `claude`, scope `evidence_only`)
- Commissioned by: CEO 2026-09-03 against admission receipt `39b77657-66a6-4b2f-bb14-5a480c1fd4d7`
- Kind: **read-only dossier**. Builds no book, no weights, no deploy artifact, no live/queue/verdict/gate mutation.
- Allowed here: read-only among-cohort correlation + a book-composition dossier. Everything downstream stays OWNER-gated.

## Zusammenfassung für OWNER (DE)

1. Die 24er-Kohorte (16 auditierbar, 8 auf aktiven Tracks ausgeschlossen) ist **heute kein Buch-Baustein**: **0 der 24 Paare** stehen terminal auf Q14 — die Buch-Schwelle (`book_build_guard`) bleibt bei **5/25 qualifiziert, allowed=False**.
2. Die 3 Kohorten-Paare, die zu den 5 qualifizierten zählen (`10706/GBP`, `11421/EUR`, `11422/USDCAD`), sind genau die **ACTIVE_OPT_FORK-Ausschlüsse** — sie sind schon auf dem Weg, den alle anderen erst gehen müssen. Netto-Beitrag der Kohorte zur Schwelle: **0**.
3. Von den 16 auditierten müssen **11 komplett neu ab Q02** (neue Identität, EX5/Setfile driftete) und **5 ab Q09** (Hash-gebundenes Q08 wiederverwendbar) wieder in die Kette — dann bis Q14 hoch. Die 5 Q09-Paare sind der **billigste Pfad**.
4. Korrelation aus **vorhandenen** Trade-Streams: nur **9/16** haben überhaupt einen Q08-Stream, und **jedes Paar** unterschreitet die 60-Tage-Overlap-Schwelle des Tools → die gemessenen Werte (alle |r|<0,11) sind **nur ein Screening-Indiz, kein buchfähiger Beweis**. Zusätzlich binden nur **3 der 9** Streams an das aktuelle Binary; 6 stammen aus überholten Identitäten.
5. Struktur-Risiken: **Gold-Klumpen** (XAUUSD 6× in 24), **Selbe-EA-auf-zwei-Symbolen** (11165, 10815), **Familien-Cluster** (Grimes-Pullback, Connors-RSI2, Williams-18MA), **keine gebundene News-Evidenz** (für FTMO teuer).
6. Ein „Was-wäre-wenn"-Orthogonalset von **7 Kandidaten** liegt unten als Diskussionsbasis (ausdrücklich **keine Gewichte, kein Buch**).
7. OWNER muss entscheiden: (V1) Wiedereinstiegs-Reihenfolge, (V2) Gold-Cap, (V3) Venue DXZ vs FTMO, (V4) Korrelations-Beweisstandard, (V5) News-Bindung vor FTMO. Details als 1-Zeilen-Vorlagen unten.
8. Cost-of-Waiting heute: gering (unter 25 kein Buch möglich); höchster Hebel ist V1(b) — die **5 Q09-Paare** requalifizieren, um die Q14-Zählung zu wachsen. Diese Beauftragung ist **nicht** hier erfolgt.

---

## 1 · Cohort composition

The cohort is the 24 rows in `portfolio_candidates` with `state='Q12_REVIEW_READY'` (re-verified live at snapshot `2026-09-03T07:12:06Z`, count = 24; `RETIRED` = 6). 16 are audited (Q02_NEW_IDENTITY = 11, Q09 = 5); 8 are excluded on active tracks. Identity, anchor and hash-binding are transcribed from the admission record; EA slugs give the edge family.

### 1a · Audited members (16) — the candidate set

| # | ea_id / symbol | TF | anchor 09-03 | edge slug | edge family | asset class | Q08 stream | binding to current binary |
|---|---|---|---|---|---|---|---|---|
| 1 | QM5_1556 / XAUUSD | D1 | Q09 | aa-zak-mom12 | trend / 12m momentum | gold | yes | **representative** (EX5+set MATCH) |
| 2 | QM5_10403 / XAUUSD | D1 | Q09 | et-turtle20x | breakout (Turtle 20) | gold | no | — (no stream) |
| 3 | QM5_10700 / XAUUSD | H1 | Q02_NEW | tv-liq-break | liquidity breakout | gold | no | — (unbound legacy) |
| 4 | QM5_10815 / EURUSD | H1 | Q02_NEW | tv-post-vwap | VWAP mean-reversion | fx major | no | — (unbound legacy) |
| 5 | QM5_10911 / GDAXI | H1 | Q09 | grimes-complex-pb | pullback | eu index | no | — (no stream) |
| 6 | QM5_10940 / XAUUSD | H4 | Q02_NEW | grimes-nested-pb | pullback | gold | no | — (unbound legacy) |
| 7 | QM5_11132 / SP500 | D1 | Q02_NEW | tm-cum-rsi2 | Connors RSI2 mean-reversion | us index | yes | superseded (setfile MISMATCH) |
| 8 | QM5_11165 / AUDCAD | H1 | Q02_NEW | weiss-rsi-ma | RSI+MA mean-reversion | fx cross | yes | superseded (setfile MISMATCH) |
| 9 | QM5_11165 / EURUSD | H1 | Q02_NEW | weiss-rsi-ma | RSI+MA mean-reversion | fx major | yes | superseded (setfile MISMATCH) |
| 10 | QM5_11708 / EURUSD | D1 | Q09 | anon-market-squeeze-d1 | vol-squeeze breakout | fx major | yes | **representative** (EX5+set MATCH) |
| 11 | QM5_11910 / NZDUSD | D1 | Q02_NEW | larry-williams-18ma-2outside-bars | breakout (Williams 18MA) | fx major | yes | superseded (EX5+set MISMATCH) |
| 12 | QM5_12580 / AUDUSD | D1 | Q02_NEW | fx-usd-exhaustion-reversal | exhaustion mean-reversion | fx major | no | — (unbound legacy) |
| 13 | QM5_12710 / XTIUSD | D1 | Q02_NEW | commodity-tsmom-12m-atr | time-series momentum | oil | yes | superseded (UNBOUND) |
| 14 | QM5_12778 / AUDUSD·EURJPY basket | D1 | Q02_NEW | edgelab-cointegration | stat-arb cointegration | fx stat-arb | yes | superseded (UNBOUND) |
| 15 | QM5_12966 / GDAXI | D1 | Q02_NEW | gdaxi-weekly-oversold-swing | oversold mean-reversion | eu index | no | — (unbound legacy) |
| 16 | QM5_12969 / USDJPY | M30 | Q09 | usdjpy-gotobi-nakane | calendar / Gotobi day-of-month | fx major | yes | **representative** (EX5+set MATCH) |

### 1b · Excluded active-track members (8) — reported for coverage, not audited for anchor

`QM5_1567/EURUSD` (REQUAL8), `QM5_10513/XAUUSD` (ACTIVE_NEWS_MATRIX), `QM5_10706/GBPUSD` (ACTIVE_OPT_FORK), `QM5_10815/GDAXI` (REQUAL8), `QM5_10939/GBPUSD` (REQUAL8), `QM5_11421/EURUSD` (REQUAL8+ACTIVE_OPT_FORK), `QM5_11422/USDCAD` (ACTIVE_OPT_FORK), `QM5_12567/XAUUSD` (REQUAL8). The three ACTIVE_OPT_FORK names (`10706`, `11421`, `11422`) are the cohort members that already sit inside the real 5-pair Q14 census.

### 1c · Mix (audited 16)

- **Asset class:** forex 7 (EURUSD×3 counting the 11165/10815 duplicates, AUDCAD, NZDUSD, AUDUSD, USDJPY) · gold 4 (1556, 10403, 10700, 10940) · index 3 (GDAXI×2, SP500) · oil 1 (XTIUSD) · fx stat-arb basket 1 (12778).
- **Timeframe:** D1 = 9 · H1 = 5 · H4 = 1 · M30 = 1. The book skews slow/daily.
- **Edge family:** mean-reversion / pullback 8 (10815, 10911, 10940, 11132, 11165×2, 12580, 12966) · trend / breakout / momentum 5 (1556, 10403, 10700, 11910, 12710) · vol-squeeze breakout 1 (11708) · stat-arb 1 (12778) · calendar-seasonal 1 (12969).

### 1d · Venue suitability (per the worst-case cost model + Q15 dual-book design)

The cost model (`live_commission.json`, worst-case of {DXZ, FTMO}) is applied identically to both venues: `max(0.005%·notional, flat/lot)` with flat = $5 forex, $5.5 index, $0 commodity — and it is already subtracted inside every stream's `net` field. Venue fit therefore turns on **geometry and cadence**, not on a different fee:

- **DXZ (Buch 1, fund-motor, 5% daily / 20% total DD, uptime-scored):** the natural home for this cohort. Slow D1 sleeves with low drawdown (e.g. 12969/USDJPY ~2% DD/300 trades, 1556/XAU) fit an uptime book; DXZ historically runs **one EA per symbol** with capped inverse-vol + cluster overlay.
- **FTMO (Buch 2, cash-motor, 10% max / 5% daily, 60/30 sprint, FUND_SCORE≥1.0, P(Phase-1)≥0.80):** a poorer fit as-is. Most members trade ~7-11 entries/year (50-80 trades over 7 years), too slow to clear a 60-day sprint standalone; the FTMO blueprint's own thesis is that these need density *veredelung* (DL-089 pattern filter) and a 4-sleeve orthogonal combine, not solo deployment. FTMO allows multiple EAs per symbol (OWNER 2026-08-21) but the builder still enforces `ONE_EA_PER_SYMBOL` until `OWNER-DEC-FTMO-SYMBOLPOLICY` is implemented.

### 1e · Tradability vs `dwx_symbol_matrix.csv`

All cohort symbols are `canonical_name_verified=true`. **Only `SP500.DWX` carries an explicit `live_order_symbol=SP500` + `live_order_status=ORDER_ROUTABLE_CONFIRMED`.** XAUUSD, EURUSD, GBPUSD, GDAXI, AUDCAD, USDCAD, NZDUSD, XTIUSD, AUDUSD, USDJPY and the basket's EURJPY leg have **empty** live-order-routing cells in the matrix — they trade on the shared Darwinex-Live account that is the `.DWX` history source (so routability is presumed), but the matrix records no explicit confirmation. **Flag:** per-symbol live-order mapping must be confirmed before any deploy; do not treat the empty cells as confirmed-tradable.

### 1f · Near-duplicate / orthogonality flags

- **Same EA on two symbols** → identical signal logic, high intrinsic correlation, count as ~1 edge: `QM5_11165 weiss-rsi-ma` on AUDCAD **and** EURUSD; `QM5_10815 tv-post-vwap` on EURUSD **and** GDAXI (the GDAXI leg is excluded).
- **Family clusters** (same author/edge, different symbol) → stacking adds exposure, not diversification: Grimes pullback = `10911` + `10940` (+ excluded `10939`); Connors RSI2 = `11132` (+ excluded `12567` cum-rsi2-commodity); Williams 18MA = `11910` (+ excluded `11422`).
- **Gold cluster:** XAUUSD carries 4 audited (`1556, 10403, 10700, 10940`) + 2 excluded (`10513, 12567`) = 6 of 24.

## 2 · Gate status vs the book floor

The canonical book gate is **Q15** (vault `03 Pipeline/Q15 Final Portfolio Construction.md`): `BOOK BUILD PERMITTED ⇔ (qualified_candidates ≥ 25) AND (signed owner_order_artifact present & verified)`, where a qualified candidate is a `(EA, symbol)` pair whose **highest contiguous valid gate == Q14** with a terminal requalification verdict (`CHALLENGER_PROMOTED` or `KEEP_INCUMBENT`). The 5-Q10 auto-trigger was abolished (OWNER 2026-08-23). DL-089: incumbency is not proof — book-fitness requires the full current chain incl. the optimization branch (Q14→Q15→Q16).

- **`book_build_guard.py --status --venue both` (re-run this session):** `qualified_pairs=5`, `distinct_eas=5`, `strategy_families=5`, `allowed=false`, reasons = `qualified_pairs_below_minimum: 5 < 25` and `owner_order_missing`.
- **The 5 qualified pairs** (real census, from the admission record): `QM5_10706/GBPUSD`, `QM5_11421/EURUSD`, `QM5_11422/USDCAD` (all three are this cohort's ACTIVE_OPT_FORK exclusions), plus `QM5_13054/XTIUSD` and `QM5_1537/XAGUSD` (not in this cohort).
- **Cohort members at Q14-terminal: 0.** Admitting this cohort to *evaluation* does **not** move the counter above 5 and authorizes no book.

**Re-entry per member (from the admission record + 08-30 anchor audit):**
- **Q09-anchored (5):** `1556/XAU, 10403/XAU, 10911/GDAXI, 11708/EUR, 12969/USDJPY` — hash-bound Q08 reusable; re-enter at Q09 (reuse Q08, run current full-history pre-news baseline), then climb to Q14. **Cheapest path.**
- **Q02_NEW_IDENTITY (11):** `10700/XAU, 10815/EUR, 10940/XAU, 11132/SP500, 11165/AUDCAD, 11165/EUR, 11910/NZD, 12580/AUD, 12710/XTI, 12778/basket, 12966/GDAXI` — EX5/setfile drifted or unbound; must complete the new-identity contract and run the full chain from Q02.
- Legacy gate chains in the DB reach as high as Q10/Q11 for several members (e.g. `10403, 10911, 11708` show Q11 done PASS, `10911` even Q14 OPT_ELIGIBLE), **but these are mixed-era rows not bound to the current build** (DXZ book todo, Schema-v2 truth-chain). They are not counted by the v4 census and do not shortcut the re-entry.

## 3 · Pairwise correlation where evidence exists + orthogonal what-if set

### 3a · Method (read-only, no backtests)

Source = the existing Q08 trade-stream files under `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\` (the same store `portfolio_correlation.py` / `sleeve_correlation.py` consume). Per member: daily P&L = Σ of the per-trade `net` field (for forex/index streams `net` already carries the worst-case DXZ/FTMO commission + swap + fee; commodity streams carry essentially none — the flat commodity rate is $0 in live_commission.json and the omitted 0.005 % component is ≈ $2/trade, negligible for every figure below — verifier note 2026-09-03) bucketed by the UTC calendar day of the trade's exit `time`. Series aligned on the union window; **Pearson** on 0-filled daily vectors; **co-active overlap** = count of calendar days on which both strategies closed a trade. Union window across the 9 available streams: **2017-10-10 … 2025-12-30**.

### 3b · Availability

Only **9 of 16** audited members have a stream: `1556/XAU, 11132/SP500, 11165/AUDCAD, 11165/EUR, 11708/EUR, 11910/NZD, 12710/XTI, 12778/basket, 12969/USDJPY`. **Missing (7):** `10403/XAU, 10700/XAU, 10815/EUR, 10911/GDAXI, 10940/XAU, 12580/AUD, 12966/GDAXI` — no stream file exists, so no correlation is computable for them from existing evidence.

Per-member stream stats (net = sum of net-of-cost P&L over the stream, acct USD; sha = first 16 hex of the `.jsonl`):

| member | trades | active days | first | last | net | binding | sha256[:16] |
|---|---:|---:|---|---|---:|---|---|
| QM5_1556/XAUUSD | 53 | 53 | 2019-02-01 | 2025-12-05 | 6619.1 | representative | b1e84c8a1e8c74f8 |
| QM5_11132/SP500 | 73 | 73 | 2019-05-10 | 2025-12-23 | 6919.9 | superseded (set) | 35aef7994a5b8f57 |
| QM5_11165/AUDCAD | 181 | 181 | 2017-10-19 | 2025-12-05 | 2143.1 | superseded (set) | 46354e14c7ce9a31 |
| QM5_11165/EURUSD | 223 | 220 | 2017-11-20 | 2025-12-17 | 761.4 | superseded (set) | e30270fa71a427e5 |
| QM5_11708/EURUSD | 173 | 166 | 2018-06-08 | 2025-12-05 | 2607.6 | representative | 0fbccdfed14837c8 |
| QM5_11910/NZDUSD | 63 | 63 | 2018-03-23 | 2025-06-05 | 2509.5 | superseded (ex5+set) | 92c51571583c99de |
| QM5_12710/XTIUSD | 82 | 82 | 2018-10-05 | 2025-12-05 | 7579.5 | superseded (unbound) | c09e9ea0bdeb4d88 |
| QM5_12778/AUDUSD·EURJPY basket | 210 | 105 | 2018-05-04 | 2025-11-28 | 4502.8 | superseded (unbound) | 276adef910f3eca3 |
| QM5_12969/USDJPY | 300 | 300 | 2017-10-10 | 2025-12-30 | 10848.6 | representative | 1788388f79e41977 |

### 3c · Result — indicative only, NOT book-grade

- **Every** pairwise correlation is near zero: max |r| = **0.102** (11910/NZD × 1556/XAU), and **no pair reaches |r| ≥ 0.3**.
- **Every** pair fails `portfolio_correlation.py`'s own `min_overlap_days = 60`: the largest co-active overlap is **50 days** (1556/XAU × 12710/XTI); most pairs share **< 30** and many **< 20** trading days. Sparse daily D1 series 0-filled over 848 union slots drive the correlations toward zero mechanically.
- **Binding caveat:** only **3 of 9** streams (`1556, 11708, 12969` — the Q09 members) hash-bind to the current binary; the other 6 describe **superseded / unbound** identities (setfile MISMATCH or UNBOUND per the admission audit) that no longer exist in their measured form.

**Verdict on correlation evidence:** existing streams are **insufficient to certify pairwise correlation for book construction**. The numbers are a low-co-movement *screening prior* at best. The decisive orthogonality question (`sleeve_correlation.py`) stays unanswered until a Q14-terminal cohort produces bound streams with ≥60-day overlap.

### 3d · Candidate-only "what-if" orthogonal set (discussion basis — NOT weights, NOT a book)

Chosen for asset-class + edge-family spread, one member per family, no repeated EA, Q09-anchored preferred (cheapest re-entry). This is **not** an allocation and **not** a book; it is a discussion basis for OWNER.

| slot | member | anchor | edge family | asset class | stream binding |
|---|---|---|---|---|---|
| 1 | QM5_1556 / XAUUSD | Q09 | 12m momentum | gold | representative |
| 2 | QM5_12969 / USDJPY | Q09 | calendar / Gotobi | fx major | representative |
| 3 | QM5_11708 / EURUSD | Q09 | vol-squeeze breakout | fx major | representative |
| 4 | QM5_10911 / GDAXI | Q09 | pullback | eu index | no stream |
| 5 | QM5_12710 / XTIUSD | Q02_NEW | TS-momentum | oil | superseded (unbound) |
| 6 | QM5_11132 / SP500 | Q02_NEW | Connors RSI2 MR | us index (only ORDER_ROUTABLE_CONFIRMED) | superseded (set) |
| 7 | QM5_12778 / AUDUSD·EURJPY | Q02_NEW | stat-arb cointegration | fx market-neutral | superseded (unbound) |

Optional 8th: `QM5_12580/AUDUSD` (USD-exhaustion reversal, Q02_NEW) — adds a distinct FX mean-reversion edge. The set deliberately excludes the second `11165` symbol, the second Grimes/Williams/RSI2 names, and 3 of the 4 golds, to hold orthogonality.

## 4 · Risk notes

- **Gold concentration:** XAUUSD is 6 of 24 (4 audited, 2 excluded). A naive book would be gold-overweight and lose orthogonality; carry a gold/commodity cap into any evaluation.
- **Overlapping symbols / same-EA duplicates:** `11165` (AUDCAD+EURUSD) and `10815` (EURUSD+GDAXI) are the same signal logic on two symbols → correlated by construction. Family clusters (Grimes, Connors RSI2, Williams 18MA) compound this.
- **News exposure:** no audited member carries a bound current news calendar; Q09 is pre-news and Q10_NEWS is pending / CONFIG_LOCKED / REVIEW_REQUIRED across the set. For **FTMO** (145-cell compliance matrix, news-window constraints) unbound news is the dominant unpriced risk; for DXZ it is a smaller drag.
- **Cost drag on FTMO:** the worst-case commission is already in the streams, but FTMO's tighter 10%/5% geometry leaves less headroom, so the same drag consumes a larger share of the risk budget; slow D1 sleeves may not clear a 60-day sprint net of cost. DXZ's uptime scoring is far more forgiving of the cadence.
- **Mixed-era lineage:** 13 of 16 audited members re-enter at Q02/Q09; their legacy Q10/Q11 PASS chains and the FTMO-blueprint metrics (PF/DD) are **not bound to current builds** and must not be read as current performance.
- **Live incumbents inside the cohort:** `1556/XAU` (audited Q09) and `10706/GBP` (excluded ACTIVE_OPT_FORK) sit on the DXZ live book and are under probation review **2026-09-06**; DL-089 holds that incumbency is not book-proof — they still owe the full re-qual chain.

## 5 · What would make this cohort book-ready + the OWNER decisions needed

**Book-ready condition (unchanged, ROT):** each intended member must re-enter at its anchor, climb Q02→…→**Q14**, and earn a terminal requalification verdict (`CHALLENGER_PROMOTED` / `KEEP_INCUMBENT`); the qualified `(EA,symbol)` census must reach **≥ 25**; and a signed `decisions/YYYY-MM-DD_owner_book_order_<venue>.md` must exist. Only then does `book_build_guard` permit Q15, and only for the ordered venue(s). Nothing in this cohort shortcuts that.

Exact OWNER decisions (each a one-line Vorlage — options / recommendation / cost of waiting):

- **V1 — Re-entry sequencing of the 16 audited members.** Options: (a) push all 16; (b) push the 5 Q09-anchored first; (c) push only the 7-member what-if set; (d) none yet. **Rec: (b) then (c)** — Q09 members reuse a hash-bound Q08 and are the cheapest distance to Q14; 3 have representative streams. **Cost of waiting:** the 25-floor stays at 5, no book is evaluable, the ready-card reservoir idles.
- **V2 — Concentration cap for the eventual book.** Options: (a) 1 sleeve per symbol (esp. gold); (b) cap by asset-class; (c) no cap, rely on aggregate risk. **Rec: (a)** until an aggregate correlation control exists (mirrors the current FTMO `ONE_EA_PER_SYMBOL` code state). **Cost of waiting:** none today (no book), but unpriced concentration risk compounds if members are pushed blindly.
- **V3 — Venue targeting.** Options: (a) DXZ-only; (b) FTMO-only; (c) both. **Rec: (a) DXZ-first** — the slow D1 density fits an uptime book, not a 60-day sprint; revisit FTMO after density *veredelung*. **Cost of waiting:** FTMO cash-motor payouts deferred, but forcing slow sleeves into FTMO risks sprint failure.
- **V4 — Correlation evidence standard.** Options: (a) accept the sparse-stream correlation as a screening prior; (b) require fresh Q14-terminal streams with ≥60-day overlap before any orthogonality claim. **Rec: (b)** — existing streams fail the tool's own overlap floor and 6/9 bind to superseded identities. **Cost of waiting:** correlation truth is deferred until the first Q14 cohort exists.
- **V5 — News-calendar binding before FTMO evaluation.** Options: (a) require a bound current-calendar hash + terminal Q10_NEWS per member; (b) evaluate pre-news. **Rec: (a) for FTMO**, pre-news acceptable only for DXZ screening. **Cost of waiting:** FTMO evaluation blocked until Q10_NEWS clears (the known 19-36 day / near-zero-service-rate bottleneck).

**Recommended next step (not taken here):** none of the above requires action now — the operating gate is the 25-floor. The highest-leverage single move is **V1(b)**: commission re-entry of the 5 Q09-anchored members to grow the Q14 census. That is a separate OWNER/queue decision and was **not** enqueued by this dossier.

## 6 · Provenance

- **Inputs (sha256):**
  - `docs/ops/evidence/2026-09-03_q12-admission_39b77657_execution.md` — `e01fdd83fe2d9bd2fe3e98c5b3891be603e0c447e76fdfbcaad0dbe5a33c6016`
  - `docs/ops/evidence/2026-09-03_q12-admission_39b77657_execution.json` — `42b0b680dd0680240a5e4e4eea8704ce75b053889906ff1f018f332440156b32` (matches the value the admission MD binds — sidecar integrity confirmed)
  - `docs/ops/evidence/2026-08-30_359988fb_legacy_q12_anchor_audit.md` — `031da06e097eee937ac9a516d9f580711fcbd148575158e4b1e7bef7ed391204` (**differs** from the admission-bound value `0451794f…`; the file is CRLF/long-line in the current tree, consistent with a checkout line-ending normalization — the `.json` sidecar below carries the same content and its hash matches, so the substance is intact)
  - `docs/ops/evidence/2026-08-30_359988fb_legacy_q12_anchor_audit.json` — `574ae1fdad48cbecd933ddd6f17fc34d9797eda7d0e1a47d666e35e18a4daaf8` (matches the admission-bound value — integrity confirmed)
  - `framework/registry/dwx_symbol_matrix.csv` — `e7844d9a18db8723db2b31d839581d0cc348140cf883200524a1af26d465821d`
  - `framework/registry/live_commission.json` — `e9f3c23ae44e5b11c57bb874d4d4bec8cf1dc9987777f5c9ef3add6e2bb43eea`
- **Trade-stream store:** `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\` (9 files used; per-file sha256[:16] in §3b).
- **Vault sources read:** `03 Pipeline/Q15 Final Portfolio Construction.md`, `12 ToDo/08_DXZ_Live_Book.md`, `09 Strategy Wiki/FTMO Alpha Arsenal und 4-Sleeve Portfolio Blueprint 2026-08-22.md`, `03 Pipeline/` gate index (Q00-Q17), `docs/ops/Q09_PILOT_COST.md`.
- **Tooling read:** `tools/strategy_farm/book_build_guard.py`, `tools/strategy_farm/portfolio/portfolio_correlation.py`, `portfolio_common.py`, `sleeve_correlation.py`, `commission.py`.
- **DB:** `D:\QM\strategy_farm\state\farm_state.sqlite`. **Read-only proof:** opened `file:...?mode=ro`; `PRAGMA query_only=1`; `PRAGMA quick_check=ok`; a probe `UPDATE` was rejected (`OperationalError`). **Snapshot:** `2026-09-03T07:12:06+00:00`. Live re-check: `Q12_REVIEW_READY=24`, `RETIRED=6`, `book_build_guard qualified_pairs=5 allowed=false`.
- **Git HEAD** (worktree, descendant of admission HEAD `4884fbba…`): `2f0f1e3eb8aaacc6a0e4c0e10e81d10fed853767`.
- **Mutation statement:** no book, manifest, sleeve, weight, allocation, deploy artifact, live/T_Live state, gate threshold, verdict, trade stream, queue row, or `portfolio_candidates` state was created or changed. This dossier is read-only evidence; every downstream action remains a separate OWNER decision.

Machine-readable sidecar: `docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.json`.
