# Orthogonal Return Sources — Wave 2 (2026-08-24)

**Ticket:** `rb-orthogonal-strategies`

**Authority:** OWNER instruction quoted in the ticket: “Wir können Codex auch neue Strategien entwickeln lassen!”

**Boundary:** research and incoming G0 drafts only. No build, backtest, enqueue, verdict, registry, factory, portfolio, deploy, or `T_Live` mutation.

## 1. Method and corpus boundary

The mandated approved corpus is `D:/QM/strategy_farm/artifacts/cards_approved/`. It contained 3,272 root Markdown cards at census time. The historical schema has no `family`, `mechanism`, or `strategy_family` front-matter field on any of those cards; only 101 cards have the older, mostly unique `strategy_mechanic` field. Therefore a literal field count cannot describe the corpus. The reproducible census in `tools/strategy_farm/orthogonal_card_census.py` reports the empty raw fields and adds a disclosed deterministic taxonomy based on card identity metadata, title, `concepts`, and `strategy_type_flags`—never backtest results.

The Q08 frontier join uses `D:/QM/reports/rebaseline/census_2026-08-23.csv` and includes every row whose `highest_contiguous_valid_gate >= Q08` in the v3 census vocabulary. It has 26 `(EA, symbol)` pairs / 26 distinct EAs. Twenty EAs join to the mandated runtime card corpus; six do not: `QM5_12849`, `QM5_12855`, `QM5_13054`, `QM5_13128`, `QM5_13301`, and `QM5_20266`. Frontier card counts below therefore describe the 20 joined cards; pair and join denominators remain explicit.

Reproduce:

```powershell
python tools/strategy_farm/orthogonal_card_census.py `
  --approved-dir D:/QM/strategy_farm/artifacts/cards_approved `
  --census-csv D:/QM/reports/rebaseline/census_2026-08-23.csv
```

## 2. Approved-card family distribution

| Canonical family | Approved cards | Q08-valid joined cards |
|---|---:|---:|
| Mean reversion | 1,038 | 10 |
| Trend / momentum | 788 | 5 |
| Breakout | 545 | 3 |
| Other / unclassified | 458 | 1 |
| Calendar / seasonality | 228 | 1 |
| Relative value / statistical arbitrage | 132 | 0 |
| Carry / funding | 34 | 0 |
| Volatility regime | 32 | 0 |
| Event driven | 17 | 0 |
| **Total** | **3,272** | **20** |

This top-level result is the reason for selecting mechanisms rather than adding another generic trend, breakout, or mean-reversion indicator stack. It is a semantic census, not a profitability or independence claim.

## 3. Candidate mechanism census and exclusions

| Screened mechanism class | Approved cards | Q08-valid joined cards | Wave-2 disposition |
|---|---:|---:|---|
| Index volatility/liquidity reversal | 0 | 0 | **SELECT** |
| FX local-session inventory drift | 1 | 0 | **SELECT** |
| Carry-unwind crisis momentum | 2 | 0 | **SELECT** |
| FX benchmark-fix rebalancing | 4 | 0 | **SELECT** |
| Scheduled-announcement risk premium | 8 | 0 | **SELECT, duplicate-default guard** |
| Index gap response | 19 | 0 | EXCLUDE: Wave 1 already drafted the small-gap fade; the rejected appendix closes generic all-gap resurrection and caps the index-intraday-MR cluster. |
| Commodity monthly momentum | 56 | 0 | EXCLUDE: not thin after canonical-seed drift is considered. The worktree approved seed corpus has 165 classified cards and 133 `QM5_41xxx` cards, including dense WTI monthly/weekly variants. |
| Cross-instrument relative value | 115 | 1 | EXCLUDE: the worktree approved seed corpus has 174 classified cards, with dense XAU/XAG and energy RV coverage. The rejected appendix also forbids a second GSR sleeve. |

Corpus drift is material but does not change the mandated count: runtime `cards_approved` has 8 `QM5_41*.md` files, while `strategy-seeds/cards/approved` in this worktree has 133. Runtime remains the ticket’s stated source of truth; the larger seed corpus is used only as a duplicate guard so stale synchronization cannot justify “new” monthly commodity or XAU/XAG clones.

## 4. Five selected classes, rationale, and source basis

### 4.1 Index volatility/liquidity reversal — 0 approved / 0 frontier

Mechanism: constrained intermediaries withdraw liquidity during turmoil, raising expected compensation to liquidity provision. Wave 2 tests a closed-bar, high-realized-volatility session displacement followed by a bounded reversal. The source supports the liquidity/reversal mechanism; it does **not** establish the index-CFD carrier, the realized-volatility proxy, or the chosen H1 rule. Those translations are explicit refutation criteria. Primary source: Stefan Nagel (2012), “Evaporating Liquidity,” *Review of Financial Studies* 25(7), 2005–2039, [DOI 10.1093/rfs/hhs066](https://doi.org/10.1093/rfs/hhs066).

Why it is not generic index MR: entry requires a predeclared high-volatility state and a same-session displacement/reversal sequence; G0 is instructed to enforce the existing index-MR cluster cap and reject carrier-only duplication.

### 4.2 FX local-session inventory drift — 1 approved / 0 frontier

Mechanism: currencies tend to depreciate in their own local trading hours as local participants buy foreign currency and dealers warehouse the resulting inventory imbalance. Four cards isolate EUR, GBP, JPY, and AUD local-session carriers with source-fixed direction and day-flat ownership. Primary source: Francis Breedon and Angelo Ranaldo (2013), “Intraday Patterns in FX Returns and Order Flow,” *Journal of Money, Credit and Banking* 45(5), 953–965; [Swiss National Bank full paper](https://www.snb.ch/public/asset/en/www-snb-ch/publications/research/working-papers/2011/working_paper_2011_04/publications0_en/working_paper_2011_04.n.pdf).

Refutation is sign stability net of cost after 2015, across DST regimes, and outside announcement dates. No trend filter or optimized broker-hour window is added.

### 4.3 Carry-unwind crisis momentum — 2 approved / 0 frontier

Mechanism: falling risk appetite and funding liquidity force sudden reductions in high-yielding carry positions, producing crash-like appreciation of funding currencies and co-movement among investment currencies. Four JPY-cross cards use one predeclared price-only proxy: broad JPY strength, a target 20-day low, and elevated realized volatility. Primary source: Markus K. Brunnermeier, Stefan Nagel, and Lasse H. Pedersen (2009), “Carry Trades and Currency Crashes,” *NBER Macroeconomics Annual* 23, 313–347, [NBER paper and publication record](https://www.nber.org/papers/w14473), DOI 10.1086/593088.

The absence of historical rate/position data is a first-order translation risk. G0 must compare `QM5_13023` and `QM5_20292`; duplicate rejection is required unless the carrier/rule boundary is material.

### 4.4 FX benchmark-fix rebalancing — 4 approved / 0 frontier

Mechanism: international equity managers adjust currency hedges at the London 16:00 benchmark fix; equity appreciation predicts associated currency depreciation before the end-of-month fix. Four cards separate EUR/GBP and month-end/quarter-end clocks. They trade only the pre-fix flow and explicitly do not clone the post-fix fades. Primary source: Michael Melvin and John Prins (2015), “Equity Hedging and Exchange Rates at the London 4 p.m. Fix,” *Journal of Financial Markets* 22, 50–72, [DOI 10.1016/j.finmar.2014.11.001](https://doi.org/10.1016/j.finmar.2014.11.001).

The local-equity-index direction proxy is not a result transferred from the paper. Each card is refuted if that sign is unstable, if costs erase it, or if any return is earned outside the fixed pre-fix window. G0 must compare `QM5_10763`, `QM5_12973`, `QM5_20034`, and `QM5_32007`.

### 4.5 Scheduled-announcement risk premium — 8 approved / 0 frontier

Mechanism: investors require compensation on days when scheduled macroeconomic uncertainty is resolved. Four cards predeclare distinct event/carrier tests (inflation/SP500, payroll/WS30, FOMC/NDX, international FOMC/GDAXI), with no attempt to predict the release. Primary source: Pavel Savor and Mungo Wilson (2013), “How Much Do Investors Care About Macroeconomic Risk? Evidence from Scheduled Economic Announcements,” *Journal of Financial and Quantitative Analysis* 48(2), 343–375, [DOI 10.1017/S002210901300015X](https://doi.org/10.1017/S002210901300015X).

This is the most duplicate-prone chosen class. Existing broad/event cards include `QM5_10260`, `QM5_1094`, `QM5_1213`, `QM5_12971/12972`, `QM5_13128`, and `QM5_20023`. Incoming drafts say duplicate rejection is the default. Their purpose is G0 comparison and carrier/event isolation—not a claim that four event subsets are independent return sources. The day-flat mapping is refuted if the paper’s premium resides only in the omitted overnight leg.

## 5. Incoming G0 cards (20)

Canonical intake: `D:/QM/strategy_farm/artifacts/cards_draft/`. All files are `DRAFT / PENDING_REVIEW`; no EA registry ID is allocated.

### Index volatility/liquidity reversal

1. `PENDING_FD6BDE09_ws30-highvol-liquidity-reversal.md`
2. `PENDING_0E30F570_sp500-highvol-liquidity-reversal.md`
3. `PENDING_C992226C_gdaxi-highvol-liquidity-reversal.md`
4. `PENDING_8C049562_uk100-highvol-liquidity-reversal.md`

### FX local-session inventory drift

1. `PENDING_CCE37C90_eurusd-local-session-inventory-drift.md`
2. `PENDING_6008900C_gbpusd-local-session-inventory-drift.md`
3. `PENDING_CB600D2E_usdjpy-local-session-inventory-drift.md`
4. `PENDING_1C937FC6_audusd-local-session-inventory-drift.md`

### Carry-unwind crisis momentum

1. `PENDING_37F8C8E4_audjpy-carry-unwind-crisis-momentum.md`
2. `PENDING_04E5F6D9_nzdjpy-carry-unwind-crisis-momentum.md`
3. `PENDING_AFB377B5_gbpjpy-carry-unwind-crisis-momentum.md`
4. `PENDING_A3A88F5E_eurjpy-carry-unwind-crisis-momentum.md`

### FX benchmark-fix rebalancing

1. `PENDING_11F7C177_eurusd-month-end-benchmark-fix-hedge-flow.md`
2. `PENDING_2EF79507_gbpusd-month-end-benchmark-fix-hedge-flow.md`
3. `PENDING_F0F2A56F_eurusd-quarter-end-benchmark-fix-hedge-flow.md`
4. `PENDING_0CD18DF4_gbpusd-quarter-end-benchmark-fix-hedge-flow.md`

### Scheduled-announcement risk premium

1. `PENDING_58BFD084_sp500-scheduled-announcement-risk-day.md`
2. `PENDING_D3C58BB1_ws30-scheduled-announcement-risk-day.md`
3. `PENDING_3E181AE9_ndx-scheduled-announcement-risk-day.md`
4. `PENDING_E23718DE_gdaxi-scheduled-announcement-risk-day.md`

## 6. Governance and limitations

- The Wave-1 four-card set remains untouched. Wyckoff/SMC/ICT, Gold-Reaper cloning, and every item in the 2026-08-13 Rejected Appendix remain closed.
- Card pending IDs are deterministic content-lane identifiers, not allocated EA IDs. Deterministic registries allocate only after approval.
- All 20 targets are present in `framework/registry/dwx_symbol_matrix.csv`; this confirms carrier registration, not economic viability or live order routing.
- No expected PF, drawdown, win rate, significance, trade count, or correlation is claimed. `expected_trade_frequency` is `UNKNOWN_Q02_MEASURES`.
- Four cards per class are candidate carriers/subsets, not four independent sources. G0 duplicate review and later measured correlations may collapse or reject most of them.
- The runtime/seed corpus synchronization drift should be repaired separately; it was not mutated here.
