# FTMO Demo Acceptance Contract — v1

**Authority:** `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`, directive §50 (representative demo),
**§51 (this document: acceptance criteria defined *before* the demo is judged)**, §52 (purchase packet),
§56 (risk below the limits, not at them), §95 (definition of purchase-decision readiness).
Verbatim directive: `docs/ops/evidence/2026-09-17_fable_full_executive_authority/owner_directive_verbatim.md`.

**Version:** v1 · **Written:** 2026-09-18, *before* any judgement of the D2g6 cycle · **Owner:** Fable.
**Status:** binding for the cycle identified in §1. **The paid purchase decision remains OWNER-only (ROT).**

**Relationship to existing contracts.** This document **extends** `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md`
(roster identity, `roster_hash`, cycle start, material-change classification, the cycle state machine) — all of
that remains valid and is *not* restated here. It **supersedes** that document's §5 outcome table: the five
readiness enums are collapsed into the four directive-§95 verdicts of §6 below, and
`READY_FOR_OWNER_REVIEW` is no longer a terminal outcome (it maps to `BUY_RECOMMENDED` with the OWNER
handoff attached). It **binds** the estimator of `docs/ftmo/FTMO_KPI_CONTRACT.md` (v1) and the rule facts of
`docs/ftmo/FTMO_RULES_SNAPSHOT_2026-09-18.md` unchanged; nothing here redefines an estimator.

---

## 1. Scope — the frozen configuration this contract binds

This contract judges exactly one object: **FTMO demo book v3, roster D2g6**, running on FTMO-Demo account
**1514536732** (100k 2-Step Standard), cycle `FTMO_DEMO_BOOK_V3_D2G6_20260918`, started
**2026-09-18T04:47Z** (cutover receipt `docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/CUTOVER_RECEIPT.md`;
live cycle read-model `D:/QM/reports/state/ftmo_demo_cycle.json`, `cycle_start_utc` 2026-09-18T04:50:00Z).

| Binding | Value |
|---|---|
| `roster_hash` (composition identity) | `5432d3db11b02c64a3c5357d94d9f59b425c270e600b87ad65ddf42310771e53` |
| Roster artifact | `…/2026-09-18_ftmo_demo_book_v3_D2g6/roster.json`, sha256 `53a1387081ab6b6267afc785a242a8fbe1c9a338fcc71910493fe5b67b9a690b` |
| Book risk | **1.71875 %** (13213 @ 0.15625 %; 10706 / 10700 / 11422 / 10403 / 41219 @ 0.3125 % each) |
| Setfile manifest | `sets_manifest_sha256` `62efe535e71794542bbccf163237f40819f708e6a9c1cb8d5e56587bc3107f57` (`qm.ftmo-trial-setpath/v2`) |
| Governor binding | `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json` sha256 `0ed0df9f28077dc2c526e708cd6008672fcffdeec1e20abd32e5f15a27cf79ba` |
| Governor presets | bootstrap `e2640e6e8b28bb9248dba911f1e45d45c1d04f34b0f72b063024e7c7c95da565` · active `f1b277a6bf46ce6fa634e3e3a264f0ccbe667e5013417f6cf5c36f5a3d8fa5c6` |
| Magic registry | `framework/registry/magic_numbers.csv` sha256 `6671944eb975e09b303fb4afd1cb40dc6e6b50d8111af48fbced020050851381` |
| Rulepack | `FTMO_2S_100K_STANDARD_V2`, canonical sha256 `9fe21a1d0b1d760d29fd8daed09bec03315289d078da83f232c5d86eff7bf8f9` |

**Running binaries (alias builds).** The sealed factory `.ex5` files fail on FTMO venue symbol names
(`EA_MAGIC_RESOLUTION_FAILED`, `X.DWX` vs `X`), so the six sleeves run as alias rebuilds from identical sources
(`RECEIPT_alias_builds.md`). The installed hashes this contract binds:

| EA | symbol | risk % | alias ex5 sha256 | magic |
|---|---|---|---|---|
| QM5_13213_balke-gmt3-range-breakout | USDJPY | 0.15625 | `85b5d4ed6443d77cc24db2b8046a42473e9e0572407680731d0e60733ad9d2e8` | 132130000 |
| QM5_10706_tv-mon-ls | GBPUSD | 0.3125 | `e6701607ef44e02733558bde9cf096aed9ab8e83a57fea4d64c84ad6259574e4` | 107060001 |
| QM5_10700_tv-liq-break | XAUUSD | 0.3125 | `5dcb1a235f5b78cdff274eaa32e48d4713d19f1415da3a2153c98e48b501d6a1` | 107000003 |
| QM5_11422_williams-18ma-outside-bar-entry-d1 | USDCAD | 0.3125 | `76e59831ca36c4bd55312686c56c1266f1f11c784b4942250e362b9a9a6c5bb1` | 114220004 |
| QM5_10403_et-turtle20x | XAUUSD | 0.3125 | `fbe198f7210b52853741ae3c987416b0b51ebd2a521c70fe18b71061de27ebcc` | 104030002 |
| QM5_41219_cum-rsi2-commodity-requal8 | XAUUSD | 0.3125 | `e00915b9ac7cbffe177680863f77871262629a42dc64e5385e4580707b1d10ae` | 412190000 |

**Lineage caveat, stated up front:** because the running binaries are alias rebuilds and not the sealed gate
binaries, this cycle produces **DEMO-BURN-IN evidence**, not gate evidence. It can *falsify* the modelled
behaviour; it cannot *confer* a gate verdict. Any hash in the table above changing during the cycle is a
representative-breaking material change under `FTMO_DEMO_VALIDATION_CONTRACT.md` §3 and restarts the clock.

**Modelled reference.** Every threshold in §4 is derived from the frozen W38 per-sleeve streams at exactly this
roster and these weights — `D:/QM/reports/book_evolution/2026-W38/ftmo/fable_alt_rosters_20260918/deployable2/`
(`finfull_D2g6.json`, `streams_fin_full/QM/q08_trades/*.jsonl`, each stream sha-verified at load), common window
**2019-01-22 … 2025-11-21** (2 496 calendar days, 1 784 business days, 1 626 active book days), financed panel.
Headline first-passage (chain v2, seed 20260915, 10 000 paths, block 10): **LCB 0.8839**, E2E 0.9034,
P1 max-loss 0.0152, P1 daily-loss 0.0, end-to-end p50 **487 business days**; cost-stressed (x1.5 + 2 USD/lot)
E2E 0.8494; holdout panel (2023+) LCB 0.9759.

---

## 2. Minimum evidence — period **and** content

Fourteen calendar days is a **floor, never a trigger** (directive §50). The cycle is judgeable only when all
four of the following hold. Where 14 days cannot deliver the content, the honest answer is EXTEND, not a
lowered bar.

### 2.1 Period

`validation_days >= 14` **and** no representative-breaking material change since `cycle_start_utc`
(state `REPRESENTATIVE` per the validation contract). Earliest judgement date: **2026-10-02T04:47Z**.

### 2.2 Trade count — expected entries in 14 calendar days

Computed from the entry timestamps of the six bound streams over the common window, as the empirical
distribution of **2 483 overlapping 14-calendar-day windows** (calendar-aligned, so weekends, holidays and
seasonality are preserved; the non-overlapping check on 178 windows reproduces mean and p10 exactly).

| Sleeve | entries in window | per calendar day | **expected entries / 14 d** | p10 | P(0 entries in 14 d) |
|---|---|---|---|---|---|
| 13213 USDJPY | 1 322 | 0.5296 | **7.42** | 5 | 0.005 |
| 10706 GBPUSD | 300 | 0.1202 | **1.68** | 1 | 0.029 |
| 10700 XAUUSD | 323 | 0.1294 | **1.81** | 0 | 0.151 |
| 10403 XAUUSD | 192 | 0.0769 | **1.08** | 0 | 0.271 |
| 11422 USDCAD | 175 | 0.0701 | **0.98** | 0 | 0.370 |
| 41219 XAUUSD | 72 | 0.0288 | **0.40** | 0 | 0.681 |
| **BOOK** | **2 384** | **0.9551** | **13.37** (empirical mean 13.35) | **10** | — |

**Book 14-day entry count:** mean **13.4**, **p10 = 10**, p05 = 9, p25 = 12, p50 = 13, p90 = 17, min 3, max 23.
Variance-to-mean ratio **0.583** — the count is *under*dispersed relative to Poisson, so a Poisson band is
conservative (wider) than reality; both are quoted in §4.

**Floor:** `book_entries_14d >= 9` (empirical p05). Below that the cycle is under-evidenced → EXTEND.

**Concentration warning, binding on interpretation:** 13213 alone supplies **56 %** of expected entries
(7.4 of 13.4). The other five sleeves together contribute ~5.9 entries per 14 days. A "14-day demo with
13 trades" is therefore *not* 13 independent observations of the book — it is roughly one well-observed sleeve
and five sleeves each seen once or not at all.

### 2.3 Regime coverage

Derived the same way, per 14-calendar-day window:

| Coverage statistic | mean | p05 | p10 | p50 |
|---|---|---|---|---|
| distinct book **entry days** | 8.67 | 7 | 7 | 9 |
| distinct **sleeves active** (≥1 entry) | 4.49 | 3 | 3 | 4 |

Distribution of sleeves active in 14 days: 2 → 1.4 %, 3 → 11.4 %, 4 → 37.2 %, 5 → 36.5 %, 6 → 13.5 %.
**Requirement:** ≥ **4 of 6** sleeves place at least one entry, and ≥ **7** distinct book entry days.
Three active sleeves is the p10 and is an ATTENTION, not a failure. **Two or fewer → EXTEND.**
Observing all six sleeves in 14 days has modelled probability 0.135 and is therefore *not* required.

"Sessions with each sleeve active" cannot be demanded uniformly: for 41219 the modelled probability of *zero*
entries in 14 days is 0.68, for 11422 0.37, for 10403 0.27. Requiring each sleeve to be seen would reject a
correctly-functioning book ~86 % of the time.

### 2.4 Cost observation

Realised **spread, commission, swap** per sleeve versus the modelled band. Modelled values at 1.71875 %
(round-turn commission per lot; financing per night per lot; median lot at the stream's 1 % source risk):

| Sleeve | commission / lot (round turn) | mean nights held | financing / night / lot | median lot @1 % source risk |
|---|---|---|---|---|
| 13213 USDJPY | 5.00 USD | 0.00 | 0.000 | 4.76 |
| 10706 GBPUSD | 6.46 USD | 0.56 | −9.045 | 3.98 |
| 10700 XAUUSD | **0.00 — MODEL GAP** | 0.84 | −88.730 | 0.73 |
| 11422 USDCAD | 5.00 USD | 1.70 | −6.379 | 1.69 |
| 10403 XAUUSD | **0.00 — MODEL GAP** | 2.65 | −96.577 | 0.20 |
| 41219 XAUUSD | **0.00 — MODEL GAP** | 2.00 | −142.779 | 0.14 |

Book financing drag: **−71.91 USD per 14 calendar days** (−0.072 % of 100 k), of which 10700 −32.70,
10403 −17.33, 10706 −9.91, 41219 −6.07, 11422 −5.90, 13213 0.00.

The three XAUUSD sleeves carry **zero modelled commission**. If FTMO Global Markets charges commission on
metals, the model understates cost on 3 of 6 sleeves. Closing this is an explicit deliverable of this cycle
(§4 A9) and a purchase-packet item (§7). Spread is not in the streams at all: the modelled cost is
commission + financing + the venue cost model's spread assumption, and realised spread must come from the
Market Watch specification export named in `demo_metrics._EXPORTER_GAPS["spread_cost"]`.

**Requirement:** for every sleeve with **≥ 5 closed trades** (resp. ≥ 5 swap-charged nights), realised
commission per lot and financing per night per lot within **±50 %** of the table. Below 5 observations the
check is `UNMEASURED` and is reported as such — never silently passed.

---

## 3. Hard stop conditions during the cycle

Any of these stops the cycle immediately, produces an evidence record, and forces a verdict of `NOT_READY`
or `RECOMPOSE` (never a silent continuation). Stopping the EAs and the terminal is within Fable's authority;
the FTMO account itself is a demo, so no OWNER-only live toggle is involved.

| # | Condition | Detection | Consequence |
|---|---|---|---|
| S1 | **Rule breach on demo** — equity strictly below the 95 000 daily floor (Prague-midnight anchored) or below the 90 000 static Max-Loss floor | account governor + `demo_metrics` `worst_day_pct <= -5.0` / `realized_max_dd_pct <= -10.0` | stop; `NOT_READY`; the book is disqualified for purchase in its current form |
| S2 | **Governor halt** — the account governor fires its kill switch, or its runtime proof (`KS_DAY_ANCHOR_SET` / `KS_BOOK_TAG_SET`) is absent on a Prague weekday | `ftmo_trial_pulse` ALARM, `live_launcher_events.jsonl` | stop; classify: a *correct* halt = evidence, a *defective* halt = instrumentation defect → repair, then EXTEND |
| S3 | **Economically dark sleeve** — a sleeve exceeds its own calibrated silence budget (below), not a uniform day count | per-sleeve entry observation | investigate wiring vs. market; if wiring → repair + EXTEND; if unmodelled behaviour → `RECOMPOSE` |
| S4 | **Runtime instability** — any sleeve not `INIT_OK`, an unexplained `DEINIT`, a terminal restart not initiated by Fable, a launcher `profile_contract_failed`, or a journal gap > 12 h on a trading day | terminal logs, `live_launcher_events.jsonl`, journal continuity | stop the clock; repair; the interrupted days do not count toward the 14 |
| S5 | **Unexplained deviation from modelled behaviour** — a trade on a symbol not in the roster, a lot size > 3× the sleeve's modelled median at the deployed risk, a position held over a weekend by a sleeve whose stream never does, > 6 sleeves concurrently open, or realised joint open risk > 1.71875 % | pulse + journal reconciliation against the streams | stop; `NOT_READY` until explained; an explanation that changes mechanics is representative-breaking |
| S6 | **Configuration drift** — any hash in §1 changes | `demo_cycle` material-change classifier | new cycle; this contract's judgement is void for the old evidence |

**S3 calibration — the uniform "dark > 5 trading days" rule is wrong for this book.** The empirical
inter-entry calendar gap distribution of the bound streams:

| Sleeve | gap p50 | p90 | **p95 (silence budget)** | max |
|---|---|---|---|---|
| 13213 | 1 | 4 | **5** | 26 |
| 10706 | 7 | 14 | **15** | 30 |
| 10700 | 7 | 19 | **24** | 35 |
| 10403 | 9 | 29 | **32** | 48 |
| 11422 | 8 | 31 | **40** | 101 |
| 41219 | 22 | 72 | **106** | 271 |

`demo_cycle.DARK_AFTER_TRADING_DAYS = 5` is calibrated for 13213 and **only** 13213. Applied to the other
five it generates false alarms at high rates (41219's own p50 gap is 22 days). Within a 14-day cycle, S3 can
therefore fire legitimately for **13213 only**; for every other sleeve, silence for the whole cycle is inside
its modelled behaviour. The contract consequently separates:

- **wiring liveness** — proven by `INIT_OK` + heartbeat + a governed-magic tag in the pulse, *not* by trades;
  a sleeve that is attached, initialised and heartbeating is alive even with zero entries;
- **economic darkness** — alarms only past the sleeve's own p95 silence budget above.

---

## 4. Acceptance metrics and thresholds

All thresholds are derived from the modelled distributions of the bound configuration — not from targets,
hopes, or round numbers. Sign convention: losses negative, USD on a 100 000 account. "14 d" statistics are
over the 2 483 overlapping 14-calendar-day windows of the common window.

| ID | Metric | Modelled reference | PASS | ATTENTION | FAIL → escalation |
|---|---|---|---|---|---|
| **A1** | elapsed calendar days, representative | — | ≥ 14 | — | < 14 → EXTEND |
| **A2** | book entries | mean 13.4 · p10 10 · p05 9 | ≥ 10 | 9 | < 9 → EXTEND · ≤ 7 (Poisson α=0.045) → RECOMPOSE review |
| **A3** | 13213 entries | mean 7.4 · p10 5 · p05 5 · p01 3 | ≥ 5 | 3–4 | ≤ 2 (Poisson α=0.022) → RECOMPOSE |
| **A4** | distinct sleeves active | mean 4.5 · p10 3 | ≥ 4 | 3 | ≤ 2 → EXTEND |
| **A5** | distinct book entry days | mean 8.7 · p10 7 | ≥ 7 | 5–6 | < 5 → EXTEND |
| **A6a** | worst day, **closed basis** | 14 d worst-day p50 −473 · p95 −797 · model min −862 | ≥ −797 | −797 … −862 | < −1293 (1.5× model min) → RECOMPOSE · ≤ −5000 → NOT_READY (S1) |
| **A6b** | worst day, **intraday incl. floating** (the FTMO basis) | 14 d worst-day p50 −953 · p95 −1600 · model min −1796 | ≥ −1600 | −1600 … −1796 | < −2694 → RECOMPOSE · ≤ −5000 → NOT_READY (S1) |
| **A7a** | max drawdown, closed basis | p50 −696 · p95 −1706 · p99 −2310 · model min −3902 | ≥ −1706 | −1706 … −2310 | < −3902 → RECOMPOSE · ≤ −10000 → NOT_READY (S1) |
| **A7b** | max drawdown, intraday (MAE-aware) | p50 −1117 · p95 −2263 · p99 −2845 · model min −4486 | ≥ −2263 | −2263 … −2845 | < −4486 → RECOMPOSE · ≤ −10000 → NOT_READY (S1) |
| **A8** | net P/L over the cycle | p01 −2242 · p05 −1481 · p50 **+194** · p95 +2451 · **P(14 d net < 0) = 0.434** | **not an acceptance criterion** | — | < −2242 (p01) *and* A6/A7 in ATTENTION or worse → RECOMPOSE review |
| **A9** | commission per lot per sleeve | 13213 5.00 · 10706 6.46 · 11422 5.00 · XAU sleeves **0.00 (model gap)** | within ±50 %, ≥ 5 trades | ±50–100 % | > 2× modelled → re-cost + re-run first passage → EXTEND; if LCB then < 0.70 → RECOMPOSE |
| **A10** | financing drag | −71.91 USD / 14 d book; per-sleeve per-night-per-lot table §2.4 | within ±50 %, ≥ 5 swap nights | ±50–100 % | > 2× → re-run first passage with measured rates → EXTEND |
| **A11** | joint exposure | max concurrent sleeves 6; ≥4 concurrent only **0.9 %** of time (0 open 48.3 %, 1 → 28.5 %, 2 → 17.0 %, 3 → 5.3 %); max joint open risk 1.71875 % | ≤ 6 concurrent and ≤ 1.71875 % | — | any excess → NOT_READY (governor/sizing defect, S5) |
| **A12** | runtime stability | 6/6 INIT_OK, launcher verifier PASS, continuous journal | all clean | repaired, ≥ 14 clean days remain | unrepaired → NOT_READY; repaired → EXTEND |
| **A13** | rules snapshot age | ≤ 7 d (policy) | ≤ 7 | 8–30 | > 30 → NOT_READY |
| **A14** | configuration identity | §1 hashes | exact match | — | mismatch → NOT_READY (contract unbound) |
| **A15** | first-passage LCB on the bound config | full 0.8839 · 2023+ 0.9759 · cost-stressed E2E 0.8494 | ≥ 0.80 in both panels | 0.70–0.80 | < 0.70 → RECOMPOSE |

### 4.1 Statistical test and power — say plainly what 14 days can decide

**Test.** Per-sleeve and book placement rates are tested as a one-sided lower-tail count test against the
modelled 14-day entry distribution: reject "density is as modelled" at α = 0.05 if the observed count falls
below the critical value. The **primary** band is the empirical window distribution of §2.2 (under-dispersed,
VMR 0.583); the Poisson band is reported as the conservative cross-check. No upper-tail rejection is defined —
more trades than modelled is a behaviour question (S5), not a density failure.

**Power at 14 days (Poisson, α ≤ 0.05):**

| Unit | λ (14 d) | rejection region | power vs. 25 % density loss | vs. 50 % loss | vs. 75 % loss |
|---|---|---|---|---|---|
| BOOK | 13.35 | k ≤ 7 (α = 0.045) | 0.22 | **0.65** | 0.98 |
| 13213 | 7.41 | k ≤ 2 (α = 0.022) | — | **0.29** | — |
| 10706 | 1.68 | **none** — even k = 0 has p = 0.186 | — | — | — |
| 10700 | 1.80 | **none** — k = 0 has p = 0.165 | — | — | — |
| 10403 | 1.08 | **none** — k = 0 has p = 0.340 | — | — | — |
| 11422 | 0.98 | **none** — k = 0 has p = 0.375 | — | — | — |
| 41219 | 0.40 | **none** — k = 0 has p = 0.670 | — | — | — |

**What this means, unvarnished.** At the book level, 14 days has a ~65 % chance of catching a halving of trade
density and only ~22 % of catching a 25 % shortfall. At the sleeve level it has **no** rejection region at all
for five of six sleeves: a completely dead 10706, 10700, 10403, 11422 or 41219 is statistically
indistinguishable from a correctly working one over 14 days. Those sleeves are therefore validated in this
cycle for **wiring, cost and behaviour**, not for **density** — density stays an assumption carried from the
backtest streams, and that assumption is a named residual risk in the purchase packet, not something the demo
retires.

### 4.2 What 14 days cannot establish — stated before judgement

1. **Profitability.** Modelled P(14-day net < 0) = **0.434** and the modelled 14-day median is **+194 USD**.
   A losing fortnight is the modal-adjacent outcome of a healthy book. "The demo made money" is not evidence
   of edge at this horizon and is not in the acceptance table.
2. **Progress to +10 %.** End-to-end p50 is **487 business days**; P(Phase-1 pass within 60 calendar days) is
   0.0019. Expected 14-day progress toward the 10 000 USD target is ~2 % of it. Speed is not testable here,
   and directive §51 explicitly subordinates time.
3. **Tail risk.** The modelled worst 14-day drawdown across 2 483 windows is −4 486 USD (intraday basis) —
   45 % of the Max-Loss limit — but P1 max-loss breach probability is 0.0152 over a *full* challenge. One
   14-day sample carries essentially no information about the breach tail. The demo can only *disconfirm*
   (by breaching), never confirm survival.
4. **Joint exposure tails.** Four or more sleeves are simultaneously open only 0.9 % of the time; five or more
   0.1 %. The correlated-exposure scenario that matters is unlikely to occur once in 14 days.
5. **Per-sleeve density** — see §4.1.
6. **Regime breadth.** Fourteen days spans one macro cycle segment at most. Regime coverage in §2.3 is a
   *participation* check (are the sleeves engaging with the market at all), never a claim about regime
   robustness; that claim rests on the 2019–2025 streams and the 2023+ holdout panel.
7. **Gate validity.** The alias-build lineage (§1) means nothing here upgrades a gate verdict.

The demo's honest job is therefore **falsification and fidelity**: does the live venue behave like the model
(costs, fills, sizing, timing, wiring, governor), and does anything break. It is not a profit trial.

---

## 5. Evidence sources

| Item | Source | Status |
|---|---|---|
| Cycle state, roster identity, material changes | `tools/strategy_farm/ftmo/demo_cycle.py` → `D:/QM/reports/state/ftmo_demo_cycle.json` | live |
| Realised account/sleeve metrics | `tools/strategy_farm/ftmo/demo_metrics.py` ← `…\MQL5\Files\QM\journal\live_deals_normalized.csv` | live |
| First-passage / LCB | `tools/strategy_farm/ftmo/first_passage.py` → `D:/QM/reports/state/ftmo_first_passage.json` | **stale: still `roster_label=demo_8`, schema v1, 2026-09-15T18:00Z — must be rebuilt for D2g6** |
| Rules freshness | `tools/strategy_farm/ftmo/rules_snapshot.py`, `docs/ftmo/FTMO_RULES_SNAPSHOT_2026-09-18.md` | live |
| Runtime health, governor proof | `ftmo_trial_pulse.py`, `D:/QM/reports/state/live_launcher_events.jsonl` | live; **see GAPS G1/G2** |
| Verdict read-model | `tools/strategy_farm/ftmo/demo_acceptance.py` → `D:/QM/reports/state/ftmo_demo_acceptance.json` | this contract |

**Known instrumentation gaps that must be closed for A3/A4/A6b/A7b/A9 to be measurable**
(`docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/GAPS.md`, ticket `57bfd3af`):

- **G2** `ftmo_trial_pulse.EXPECTED_MAGICS` still holds the incumbent eight magics (intersection with D2g6: 2).
  Until re-pinned, per-sleeve entry counts (A3/A4) are `UNMEASURED`.
- **G1** the launcher's profile verifier was re-pinned at cutover; any further profile edit re-opens it.
- `intratrade_equity` exporter absent → A6b/A7b are `UNMEASURED`; A6a/A7a (closed basis) carry the check.
- `spread_cost` exporter absent → realised spread is `UNMEASURED`; A9 covers commission and swap only.

An `UNMEASURED` decision-critical check never counts as a pass. It downgrades the verdict to `EXTEND_DEMO`
(§6) and appears by name in the packet.

**Three evidence-scoping rules, each of which would otherwise silently judge the wrong book.** They are
enforced in code and covered by tests:

1. **Cycle scoping.** `demo_metrics` splits the journal on balance deposits, not on roster changes, so its
   "latest cycle" still contains the *previous* roster's deals. Realised metrics are scoped to
   `cycle_start_utc` (2026-09-18T04:50Z) before any threshold is applied; without a known cycle start the
   metrics are `EVIDENCE_MISSING`, never the raw journal.
2. **Roster alignment.** A first-passage read-model whose `roster_label` is not `D2g6` cannot score A15 —
   at cutover the live state file was still `demo_8`, and reading its numbers would have attributed another
   book's probability to this one. Mismatch → `UNMEASURED` naming the label found.
3. **Partial windows.** A2/A3/A4/A5/A10 are 14-day-window statistics. Before the window is complete they can
   only be `PASS` (a threshold already exceeded) or `UNMEASURED` — never `FAIL` or `ATTENTION`. A partial
   count is not a shortfall.

---

## 6. Decision rule — exactly one verdict

Evaluated in strict precedence order; the first matching rule wins. Decision-critical checks are
**A1, A2, A6a, A7a, A11, A12, A13, A14, A15**.

```
1. NOT_READY        if any of:
     - S1 realised FTMO rule breach on demo                      (A6a/A6b ≤ −5000 or A7a/A7b ≤ −10000)
     - A14 configuration identity mismatch                       (this contract does not bind what is running)
     - A11 joint exposure or joint risk above the modelled cap   (governor or sizing defect)
     - A12 unrepaired runtime instability                        (S4)
     - A13 rules snapshot older than 30 days
     - S5 unexplained deviation, still unexplained
     - the demo evidence itself is unreadable (journal absent)   → reason UNMEASURED_EVIDENCE

2. RECOMPOSE        if any of:
     - A6/A7 worse than any modelled 14-day path (beyond the escalation thresholds in §4)
     - A3 ≤ 2 entries for 13213                                  (the density carrier is not carrying)
     - A2 ≤ 7 book entries                                       (Poisson α = 0.045)
     - A9/A10 realised cost > 2× modelled AND the re-costed LCB < 0.70
     - A15 LCB < 0.70 on the bound configuration
     → the fault is structural; more demo days cannot fix it. Build a different book, restart the cycle.

3. EXTEND_DEMO      if any of:
     - A1 fewer than 14 representative days, or the clock was stopped by S4 repair
     - A2 < 9, A4 ≤ 2, or A5 < 5                                 (under-evidenced, time can fix it)
     - any decision-critical check is UNMEASURED
     - A9/A10 out of band, first passage re-run pending or LCB re-computed into 0.70–0.80
     - A15 LCB in 0.70–0.80
     → say explicitly how many additional days close the gap, and which exporter/ticket unblocks it.

4. BUY_RECOMMENDED  if and only if:
     - state REPRESENTATIVE, A1 PASS, no S1–S6 outstanding
     - A2, A5, A6a, A7a, A11, A12, A13, A14 PASS
     - A3, A4, A9, A10 PASS or ATTENTION-with-stated-reason (never UNMEASURED if decision-critical)
     - A15 LCB ≥ 0.80 in both the full and the 2023+ panel, cost-stressed E2E ≥ 0.80
     → recommendation only. The purchase packet of §7 goes to OWNER; OWNER buys, or does not.
```

**Reason strings are mandatory.** Every verdict carries the list of check IDs that produced it, each with its
observed value, its modelled reference, and — for `EXTEND_DEMO` — the concrete unblocker. A verdict without
reasons is not a verdict.

**ATTENTION never blocks on its own** but three or more ATTENTION checks downgrade `BUY_RECOMMENDED` to
`EXTEND_DEMO`: individually tolerable deviations that all point the same way are evidence, not noise.

---

## 7. Purchase packet — what §52/§95 require

If and only if the verdict is `BUY_RECOMMENDED`, write `docs/ftmo/FTMO_CHALLENGE_PURCHASE_PACKET.md`
containing, in this order (directive §52 list, with the §95 readiness definition mapped onto it):

| § | Packet item | Source |
|---|---|---|
| 1 | Exact product: FTMO Challenge 2-Step, USD 100 000, Standard | `FTMO_RULES_SNAPSHOT` |
| 2 | **Current official fee** — re-verified on the day from the FTMO order page, with currency, any promotion, and a screenshot-free evidence line (order-page amount, timestamp) | **open GAP**; engine currently assumes list fee 540 USD |
| 3 | Current rules snapshot + freshness timestamp (≤ 7 days) | `rules_snapshot.py refresh` |
| 4 | Selected EAs, source shas, ex5 shas, setfile shas, symbols, timeframes | §1 of this contract |
| 5 | Portfolio weights, per-sleeve and book risk, account-level risk contract (§56) | roster.json, governor binding |
| 6 | Demo results against every check of §4, with PASS/ATTENTION/UNMEASURED stated | `ftmo_demo_acceptance.json` |
| 7 | Historical results and the 2023+ holdout | `FTMO_ALT_ROSTER_DEPLOYABLE2_2026-09-18.md` |
| 8 | Stress results: cost x1.5 / slippage 0-1-2 USD per lot | `finfull_D2g6.json` sensitivity block |
| 9 | First-passage distributions and credible intervals, LCB, p50/p90 time | first-passage chain v2 |
| 10 | Uncertainty and the **strongest** failure mode, named honestly | §4.2 + breach attribution (XAUUSD 52 % of modelled breaches, Friday 41 %) |
| 11 | Daily-Loss and Max-Loss headroom, measured and modelled | §4 A6/A7 |
| 12 | Server-request compliance: ≤ 200 simultaneous orders, < 2 000 positions/day | pulse counters |
| 13 | Stop/disable procedure: exact commands to flatten and halt, and who may run them | RUNBOOK + governor kill switch |
| 14 | Exact OWNER action, one concise question: **BUY / DO NOT BUY** | — |

**Facts to re-verify on the purchase day (never carried over):** the fee amount and currency on the live order
page including promotions; the profit split (80 % 2-Step) and fee-refund policy; first-payout eligibility
(14th day after the first funded trade); the daily-loss anchor and Prague timezone; the minimum-trading-day
count (4/phase); leverage; and the Challenge-phase news/weekend exemptions still marked `CARRIED_OVER` in the
rules snapshot. Purchase, payment method and the live AutoTrading toggle remain OWNER-only.

---

## 8. Machine-readable sidecar — `qm.ftmo-demo-acceptance/v1`

Written by `tools/strategy_farm/ftmo/demo_acceptance.py` to
`D:/QM/reports/state/ftmo_demo_acceptance.json`; consumed by `challenge_readiness.py`. Read-only: no DB
write, no MT5, no purchase path (covered by `tests/test_ftmo_no_purchase_guard.py`).

```powershell
cd C:/QM/repo
python -m tools.strategy_farm.ftmo.demo_acceptance                       # verdict to stdout
python -m tools.strategy_farm.ftmo.demo_acceptance --out D:/QM/reports/state/ftmo_demo_acceptance.json
python -m tools.strategy_farm.ftmo.demo_acceptance --first-passage <path-to-D2g6-first-passage.json>
```

```jsonc
{
  "schema": "qm.ftmo-demo-acceptance/v1",
  "contract_version": "v1",
  "contract_doc": "docs/ftmo/FTMO_DEMO_ACCEPTANCE_CONTRACT_v1.md",
  "generated_at_utc": "2026-09-18T12:00:00Z",
  "cycle_id": "FTMO_DEMO_BOOK_V3_D2G6_20260918",
  "roster_hash": "5432d3db…",
  "bound": true,                       // false => roster_hash drifted, verdict NOT_READY
  "validation_days": 0.31,
  "state": "RUNNING",                  // from demo_cycle
  "verdict": "EXTEND_DEMO",            // BUY_RECOMMENDED | EXTEND_DEMO | RECOMPOSE | NOT_READY
  "reasons": ["A1 representative_days=FAIL observed=0.001"],
  "unblockers": ["A11: evidence source missing"],
  "attention": [],
  "counts": {"PASS": 2, "ATTENTION": 0, "FAIL": 1, "UNMEASURED": 14},
  "checks": [
    {
      "id": "A2",
      "metric": "book_entries",
      "status": "UNMEASURED",          // PASS | ATTENTION | FAIL | UNMEASURED
      "observed": 0,
      "reference": {"mean": 13.37, "p10": 10, "p05": 9, "poisson_reject_at": 7},
      "decision_critical": true,
      "escalation": "EXTEND_DEMO",     // verdict this check forces when FAIL
      "attention_escalates": false,    // true only for A15: ATTENTION alone extends the demo
      "note": "partial cycle window: 14-day count statistics not judged yet"
    }
  ]
}
```

Invariants: `verdict` is exactly one of the four enums; every `FAIL` check's `escalation` is ≥ the reported
verdict in the precedence order of §6; every `UNMEASURED` check that is `decision_critical` forbids
`BUY_RECOMMENDED`; `bound=false` forces `NOT_READY`; the realised metrics behind every check are scoped to
`cycle_start_utc` and the A15 input is roster-aligned (§5).

**First observation (2026-09-18, ~5 h into the cycle), recorded here as the baseline:** `bound=true`,
`state=RUNNING`, `validation_days=0.001`, verdict **`EXTEND_DEMO`** — 2 PASS (A14 configuration identity,
A15 LCB 0.8839 against the D2g6 evidence file), 1 FAIL (A1, window not complete), 14 UNMEASURED. That is the
expected shape on day 0 and is not a judgement of the book.

---

## 9. Changelog

- **v1 (2026-09-18, Fable)** — written before any judgement of the D2g6 cycle, per directive §51. Thresholds
  derived from the frozen W38 D2g6 streams; supersedes the outcome table of
  `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md` §5 and keeps the rest of that contract in force. Changing a
  threshold requires a hypothesis, an independent critic, a new version here, and re-evaluation of the cycle
  under both versions — a threshold is never moved because the running book is failing it.
