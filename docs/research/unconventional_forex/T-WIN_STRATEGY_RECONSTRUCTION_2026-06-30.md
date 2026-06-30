# T-WIN / U.F.O. — Complete 1:1 Reconstruction & V5 Build Spec (all 13 video batches)

**Source:** YouTube channel *UnconventionalForexTrading* — Dr. Marco Giavon ("MT Algo
Solutions", MT = *Manual Trading*). Reverse-engineered via the agy army (13 batches /
50 videos) + 4 raw transcripts. Per-video evidence: `batch_01..13.md`, `twin_*_clean.txt`
in this folder. Synthesis: Claude, 2026-06-30 (agy = video extraction only; the synthesis,
design decisions, and V5-compliance judgment are Claude's per OWNER 2026-06-30).

Card: **QM5_12821** `twin-csm-basket`. Build: task `af6dea49` (DL-081 bounded-grid).

> **Fidelity convention:** **[SPEC]** = stated/shown by Giavon on screen (mechanizable 1:1).
> **[DESIGN]** = NOT specified by the source — our V5 design decision (the videos leave it
> open; building it is unavoidable but it is NOT "from the videos"). Honoring the difference
> is the whole point of a faithful rebuild.

---

## ⚠️ Evidence caveat (read first — binds the verdict)

Giavon **states outright that a 28-pair system cannot be backtested in MT4** (video 46); every
result he shows (+60%, +200%, +428%, +66.6%/mo …) is a **forward demo, single-session,
day-by-day** run on accounts that expire/recreate monthly, with **$0 swap on ~90% of trades**
and commission deducted only in one small-account example. There is **no costed multi-year
backtest and no verifiable equity curve.** So the source provides a *mechanism*, not a
*validated edge*. The V5 pipeline — specifically **Q04 net-of-cost** and **Q08** — is the real
judge. The #1 viability risk is **FX-basket commission**: a 7-leg cluster pays commission on
every leg every cycle; the channel's headline returns assume ~zero cost. Build it faithfully,
but expect the net-of-cost gates to be the decider. (Hard rule: evidence over claims.)

---

## 1. Currency-Strength Model (CSM) — [SPEC, the hard core]

- **Universe:** 8 majors **USD EUR GBP AUD JPY CAD CHF NZD** → the **28 crosses** among them.
  Each currency appears in exactly **7 crosses**.
- **Per-pair measure:** percentage change from the **daily open at broker midnight**:
  `Perf(pair) = (Price_now - Price_dailyOpen) / Price_dailyOpen * 100`.
- **Currency strength (base-add / quote-subtract):**
  `Strength(C) = sum Perf(crosses where C is BASE) - sum Perf(crosses where C is QUOTE)`.
  Worked example (verbatim structure): `Strength_GBP = Perf_GBPUSD + Perf_GBPCAD + Perf_GBPAUD
  + Perf_GBPNZD + Perf_GBPCHF + Perf_GBPJPY - Perf_EURGBP`. The system is **zero-sum**
  (sum of strengths ~ 0).
- **Timeframes:** strength is read on **D1, W1, MN** for the bias (the decisive TFs); lower TFs
  only time entry. (The EA also showed a 9-TF panel M1..MN, but the *decision* is D/W/M.)
- **Exhaustion / ranking:** normalized to +/-100; a currency breaking **~95** (over/undervalued)
  is "exhausted". **Probability ratio** = how many of a currency's 7 crosses agree: **6/7 ~ 86%,
  7/7 = 100%** -- prefer >= 6/7.

**[DESIGN] CSM internal scaling:** the EA panel showed raw integer scores (GBP -1600, USD +700)
with no stated conversion to the +/-100 view. We compute strength directly from the %-change sum
and apply our own normalization; the raw-integer scale is not reproduced (it is an undisclosed
display multiplier).

## 2. Basket construction — [SPEC]

Never trade one pair alone; build a **synthetic basket** that nets the intermediate currencies
(usually EUR & USD -> net zero) and leaves clean **strongest-vs-weakest** exposure.

- **Mode B -- 4-pair net-zero "square"** (e.g. Sell AUD/JPY synthetically): `EUR/AUD Buy,
  EUR/JPY Sell, AUD/USD Sell, USD/JPY Sell` -> EUR 0, USD 0, AUD -2, JPY +2 = 2x synthetic Sell
  AUD/JPY.
- **Mode C -- 7-to-1 single-currency cluster (the mature "T-WIN" form, our PRIMARY):** take the
  single most-extreme currency and open **all 7 of its crosses** in the strength-implied
  direction. GBP-strong example: `GBP/USD, GBP/CAD, GBP/AUD, GBP/NZD, GBP/CHF, GBP/JPY all Buy
  + EUR/GBP Sell`. GBP-weak = the 6 GBP crosses Sell + EUR/GBP Buy.
- **Leg direction rule [SPEC]:** the strong/weak currency's base-or-quote role in each cross
  sets the side (if a currency is strong -> buy crosses where it's base, sell crosses where it's
  quote).
- **[DESIGN] leg count:** the source ranges 2->4->6 (his words) and 3/5/7/8 in practice. We use
  **Mode C = 7 legs** of the single most-extreme currency as the deterministic default; the leg
  set is fully determined by which currency is selected.

## 3. Entry -- [SPEC] gate, [DESIGN] thresholds

1. **Extreme divergence:** the selected currency's |strength| past the exhaustion gate
   (~ **+/-350-400 raw / >=95 normalized**). **[DESIGN]** we use normalized >= a tunable threshold.
2. **MTF coherence:** strength must agree on **Monthly + Weekly + Daily** simultaneously.
3. **Probability >= 6/7** of the currency's crosses agree.
4. **Pullback only -- never chase.** If the big move already happened, skip; enter on a
   retracement / ranging phase (at the 30-min fair-price oversold/overbought boundary).
5. **Session window [SPEC/DESIGN]:** **London open ~06:30-08:30 broker time** (primary);
   no entries before 03:00 or in the midnight-01:00 window.
6. **No-trade filters [SPEC]:** strength clustered near zero; MTF contradiction; bank holidays
   (frozen correlations); major news (close 30 min before, re-enter >= 1 h after).

## 4. Exit -- [SPEC]

- **CSM-flip (the mechanical natural TP):** the instant the selected currency leaves its extreme
  / the ranking flips, **flatten the whole basket** -- even at break-even.
- **Basket take-profit:** combined floating P&L target. **[DESIGN]** unit is inconsistent in the
  source (pips/EUR/%); we use the Money-Manager EA's stated **+15% equity** as the systematic TP,
  tunable.
- **Time-stops [SPEC]:** **intraday, no overnight** (mature era: 95% intraday, ~0 swap); hard
  **Friday pre-close liquidation**; close before midnight.

## 5. Risk layer -- DL-081 (REPLACES the broker-blind no-SL stance)

The source's MM is the contentious part: **no broker-side SL** ("don't give the broker
information"), legs "breathe", plus **enforcement (averaging into losers at S/R)** and
**doubling (pyramiding into winners)** -- but **no grid spacing or martingale factor is ever
stated** (analyst-invented 20-30 pip / 1.3-2.0x numbers are NOT from the videos). The source's
*own* unambiguous risk control is a **global equity stop (1-3%)** and a **Money-Manager EA =
-2% SL / +15% TP on equity**.

**V5 binding control (DL-081, OWNER 2026-06-30):** a hard **1%-of-account basket equity stop** --
when the basket's aggregate floating P&L hits **-1%**, **flatten ALL legs**. This bounds the idea
regardless of any scale-in schedule (aggressive martingale just hits -1% sooner). It is
*consistent with* the source's own global-equity-stop and is the ONE authorized risk layer.

- **[DESIGN] grid/enforcement + martingale:** permitted *inside* the 1% box, but since the source
  underspecifies it, the FIRST build runs **grid OFF** (clean CSM-basket + 1% stop) to get an
  honest net-of-cost read on the core edge *before* adding grid complexity. `ENABLE_GRID`,
  `GRID_STEP_PIPS`, `LOT_MULT` are exposed params (default off) for a later sweep.

## 6. Sizing & sessions -- [SPEC] lookup, [DESIGN] formula

- Account-proportional lot lookup actually shown: **10,000 -> 0.10 lot; 1,000 -> 0.03; 500 -> 0.01.**
- **[DESIGN]** no sizing *formula* is given; in backtest we use **RISK_FIXED** (canonical $1000),
  split equally across the legs; live = RISK_PERCENT with the 1% basket cap on top.
- ECN broker; all 28 majors must exist with proper spreads. (Our .DWX symbol set must cover the
  28 -- gap check is a build prerequisite.)

## 7. Build plan for Codex (the EA) -- QM5_12821

- **Multi-symbol single-host basket EA** (the QM5_10717 pattern): one EA instance computes the
  CSM over all 28 `.DWX` majors, selects the extreme currency, and sends the 7-leg cluster.
- **New primitive `QM_BasketEquityStop`** (or a self-contained group-stop like QM5_12823's): a
  magic-group floating-P&L monitor that flattens ALL legs at -1% of equity. Build it reusable
  (DL-081; the #20 dormant-basket sweep depends on it) but a self-contained group-stop is
  acceptable for v1.
- **Magic-group:** all legs share an ea_id-derived magic group so the stop + exits act on the set.
- **Params to expose:** `EXHAUSTION_NORM` (~95), `MTF_SET` (D1,W1,MN), `PROB_MIN` (6/7),
  `SESSION_START/END` (London), `BASKET_TP_PCT` (15%), `BASKET_SL_PCT` (1% -- hard cap),
  `MODE` (C 7-to-1 default / B square), `ENABLE_GRID` (off), `GRID_STEP_PIPS`, `LOT_MULT`,
  `NO_OVERNIGHT` (true), `FRIDAY_CLOSE_HHMM`.
- **V5 compliance:** RISK_FIXED backtest / RISK_PERCENT live; mandatory news-blackout (calendar);
  **no ML**; deterministic; no invented commission/swap (the pipeline injects real costs).

## 8. What the pipeline will decide

Q02 (gross) will likely PASS (the channel's whole point is gross profit). The **real test is
Q04/Q08 net-of-cost** -- 7 FX legs * commission per cycle is the headwind the source never paid.
If it survives net-of-cost, it's a genuine find; if not, we have definitively answered whether
the T-WIN basket has an edge once costs are real. Either way the CSM engine + basket
infrastructure are reusable assets (and unblock the #20 dormant-basket sweep).
