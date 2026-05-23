# Existing EA Code Inventory — OWNER's Dropbox

**Phase:** Explore Step 1 (Task #3 of Dropbox strategy-research initiative)
**Snapshot date:** 2026-05-23
**Scope:** all `.mq5` / `.mqh` / `.set` / `.ipynb` trading code on disk under `C:\Users\Administrator\Dropbox\` — excludes video courses (covered in Task #2).

Source-of-truth check: every row below was derived from header comments / top 30-50 lines of the file, NOT full body reads. ML/ONNX flags are HARD — V5 Hard Rule forbids ML libraries inside live EAs; ML-flagged code is mineable for ideas but cannot be reproduced as-is in V5.

---

## Headline numbers

| Cluster | .mq5 | .mqh | .set | ML EAs | Status |
|---|---:|---:|---:|---:|---|
| (a) Ftmo/week1-2 (rule-based ICT/SMC) | 13 | 1 | 23 | 0 | **HOT** — V5-compatible, single-symbol EAs |
| (a) Ftmo/week3-4 (ML stack) | 36 | 12 | 22 | 39 | **GATED** — engines mineable, EAs not |
| (b) FTMO March 2026/EAs | 11 | 0 | 30 | 0 | **HOT** — multi-strategy portfolios, fully documented |
| (b) FTMO March 2026/SM_Portfolio_Deploy | 7 | 2 | 110 | 0 | **HOT** — 40-combo deployed pkg, MD5-locked |
| (c) Trustful Trading/YoutubeCodeFIles | 20 | 2 | 0 | 0 | **WARM** — educational, single-pattern EAs |
| (d) Finanzen/Forex Robots | 4 | 0 | ? | 0 | **COLD** — grid/martingale + MT4 legacy |
| (e) Finanzen/CodeTrading (.ipynb) | 2 nb | — | — | 0 | **COLD** — one broken, one martingale |
| (f) Finanzen/Hinterleitner | 6 | 0 | 37 | 0 | **WARM** — educational + 1 closed-source EA |
| **TOTAL** | **99** | **17** | **>222** | **39** | |

---

## (a) Ftmo/week1-4 — ICT/SMC sprint code

OWNER ran a 4-week sprint mining ICT/SMC strategy material. Weeks 1-2 are rule-based and V5-compatible. Weeks 3-4 pivoted to ML (XGBoost → ONNX) and produced 39 EAs that violate V5 Hard Rule "no ML libraries in EAs" — **the EA layer cannot be ported, but the underlying engines can.**

### Week 1 — rule-based ICT/SMC

| Path | Purpose | Tags | TF/Symbol | ML |
|---|---|---|---|---|
| `Ftmo/week1/ICT_SilverBullet_PRO_*_M5.mq5` (×7) | ICT Silver Bullet — Swing/FVG/Sweep detection with 2-position entry + trailing | ICT, SilverBullet, FVG, Liquidity | M5 / EURNZD, GBPAUD, NZDUSD, AUDUSD, XAUUSD, US100, US30 | FALSE |
| `Ftmo/week1/ICT_SMC_Suite_*_M15.mq5` (×5) | ICT SMC — BoS/CHoCH structure detection (BoS / CHoCH / Both modes) | ICT, SMC, BoS, CHoCH | M15 / EURNZD, CADJPY, GBPAUD, GBPJPY, NZDUSD | FALSE |
| `Ftmo/week1/Donchian_Suite_v5.mq5` | Donchian breakout — realistic backtest edition with spread/slippage/conservative limits | Donchian, Breakout | Multi | FALSE |
| `Ftmo/week1/SMC_Logger.mqh` | Engine: SMC trade-decision logger (signals/entries/filters/partials/trailing) | SMC, Logging | — | FALSE |
| (13 .set files for the 7 EAs) | | | | |

### Week 2 — QM_Framework wrappers

| Path | Purpose | Tags | TF/Symbol | ML |
|---|---|---|---|---|
| `Ftmo/week2/AsianRangeUltimate.mq5` | Asian-Range breakout — Ultimate edition (v4 state machine + v3 consolidation + pattern filters + liquidity sweeps + FVG entries) | Asian-Range, Breakout, Liquidity, FVG | M1 / auto-detect (FX/Gold/Indices) | FALSE |
| `Ftmo/week2/QM_AsianBreakout.mq5` | Asian-Range breakout — QM_Framework version (session detection, breakout/retest/pending, DD tracking, Friday close) | Asian-Range, Breakout, Framework | M1 / auto-detect | FALSE |
| `Ftmo/week2/QM_Donchian.mq5` | Donchian — QM_Framework migration (DD tracking, Friday close, BE/trailing, dashboard) | Donchian, Breakout, Framework | M15 / EURUSD | FALSE |
| `Ftmo/week2/QM_SilverBullet.mq5` | ICT Silver Bullet — QM_Framework migration (QM RiskManager + SessionControl) | ICT, SilverBullet, FVG, Framework | M5 | FALSE |
| `Ftmo/week2/QM_SMC.mq5` | ICT SMC Suite — QM_Framework version (BoS/CHoCH + QM modules) | ICT, SMC, BoS, CHoCH, Framework | M15 | FALSE |
| `Ftmo/week2/QM_FVGSessionEA_v5` (3 .set files, no source visible at this level) | FVG session EA | FVG, Session | M1 / GBPJPY, USDCAD, USDCHF | FALSE |
| (10 .set files across pairs/TF) | | | | |

### Week 3 — ML ICT EAs (v1) + reusable engine library

| Path | Purpose | Tags | TF/Symbol | ML |
|---|---|---|---|---|
| `Ftmo/week3/Donchian_Suite_v5.mq5` | Same as week1 (Donchian breakout) | Donchian | Multi | FALSE |
| `Ftmo/week3/ICT_ML_<SYMBOL>.mq5` (×9: AUDUSD, USDJPY, XAUUSD, EURNZD, GBPAUD, USDCAD, GER40, US100, US500) | **ML** — XGBoost ONNX, 95 features (Structure / Imbalance / POI / Liquidity / Session), separate buy/sell models | ICT, ML, Structure, Imbalance, POI, Liquidity | M5+ | **TRUE** |
| `Ftmo/week3/ML_v2/ICT_ML_<SYMBOL>_v2.mq5` (×11: AUDUSD, CADJPY, EURNZD, EURUSD, GBPAUD, GBPJPY, NZDUSD, US30, US500, USDCAD, USDCHF) | **ML v2** — XGBoost ONNX, 212 features (expanded), separate buy/sell models | ICT, ML | M5+ | **TRUE** |

**Reusable engines** (`Ftmo/week3/ML_v2/*.mqh`) — these are FEATURE CALCULATORS; strip the ONNX scoring gate and they become V5-legal building blocks:
- `BaseEngine.mqh` — multi-timeframe feature foundation (M5/M15/H1/H4/D1 buffers, session detection Asian/London/NY/Overlap)
- `StructureEngine.mqh` — Swing detection, BoS, CHoCH, 50-swing tracking
- `ImbalanceEngine.mqh` — FVG/iFVG, BPR, Volume Imbalance, SIBI/BISI classification
- `POIEngine.mqh` — Order Blocks, Breaker Blocks, Mitigation Blocks, Rejection Blocks (distance + status)
- `LiquidityEngine.mqh` — BSL/SSL, Equal Highs/Lows, sweep detection, hunt ID
- `ProfileTimeEngine.mqh` — market profile + time-based pattern detection
- `PrecisionToolsEngine.mqh` — classic TA indicators (feature enhancement)
- `FeatureLogger.mqh` — 212-feature CSV writer (for ONNX inference; not V5-relevant unless stripped)
- `NewsFilter.mqh` — high-impact event filtering (30 min before / 15 min after)

**Documented OOS (`OOS_RESULTS_V2.md`)** — quote-only, no independent verification:
- 6-month backtest 2025-01-01 → 2025-07-01, 17 symbols
- Top-6: NZDUSD (+$16,445 PF 1.47), GBPJPY (+$15,244 PF 2.16), GBPAUD (+$15,253 PF 1.50), EURNZD (+$11,726 PF 1.81), US500 (+$13,606 PF 1.59), USDCHF (+$16,250 PF 1.37)
- Portfolio: +$139,357 across 15 profitable symbols (88% win rate)
- Recommended-for-FTMO: 11 symbols with PF ≥ 1.2 and MaxDD < 5%
- Blacklist: USDJPY (-$1,091), EURJPY (-$2,358), GER40 (unavailable)

### Week 4 — ML Live v4.1 + engine duplicates

| Path | Purpose | Tags | TF/Symbol | ML |
|---|---|---|---|---|
| `Ftmo/week4/ICT_MLLive_v4_1.mq5` | **ML Live** v4.1 — APlusGate quality filter + RR3/RR5 separate buy/sell models with 412 ICT features, news/session/spread filters | ICT, ML, Gate, RiskReward | M15 | **TRUE** |
| `Ftmo/week4/ML/Source/ICT_ML_<SYMBOL>_v2.mq5` (×18) | ML v2 (212 features) — duplicate of week3 set, expanded to 18 symbols (adds AUDJPY, EURJPY, GBPUSD, USDJPY, XAUUSD) | ICT, ML | M5+ | **TRUE** |
| `Ftmo/week4/QM_TMS_ICT_v5.ex5` (no .mq5 source visible) | QM TMS ICT v5 (compiled only) | ICT, QM | — | unknown |

Engines duplicated at `Ftmo/week4/` root (same as week3) + adds `ML_Guard.mqh`, `ML_TradeFilters.mqh`, `ML_TradeStats.mqh` (week4-only — V5-incompatible by name).

**Documented OOS (`ML/README.md` German)** — quote-only:
- H1 2025: all 17 symbols profitable (100%); portfolio +$155,114; best DD 1.23% (EURNZD)
- Top-6 safest: EURNZD (DD 1.23%), GBPJPY (1.74%), AUDUSD (1.79%), CADJPY (2.12%), GBPUSD (2.53%), NZDUSD (2.62%)
- Install: models in Common/Files, M15, 0.25-0.5% risk, Friday close 20:00

**Documented Live (`README.md` German):**
- Live top-2: USDCHF (+$175,556 PF 1.81), EURNZD (+$43,222 PF 1.58)
- Blacklist: EURUSD, GBPUSD, XAUUSD, GBPAUD, GER40, AUDUSD
- Train/Val/OOS: 2021-2023 / 2024 / 2025
- Deploy: M15, 0.5% risk, 3 trades/day, 08:00-20:00, 30 min news buffer

### V5 mining decisions for cluster (a)

- **Port directly to V5:** week 1 SilverBullet + SMC Suite + Donchian; week 2 AsianRangeUltimate + QM_AsianBreakout + QM_Donchian + QM_SilverBullet + QM_SMC + QM_FVGSessionEA_v5. These are 11 candidate Strategy Cards.
- **Strip ONNX, port engines:** BaseEngine / StructureEngine / ImbalanceEngine / POIEngine / LiquidityEngine / ProfileTimeEngine — these are pure feature calculators and become high-value V5 building blocks once the inference call is removed.
- **Skip:** all 39 ICT_ML_*.mq5 EAs (ML-gated), ICT_MLLive_v4_1 (ML-gated), `FeatureLogger` (CSV-for-ONNX has no V5 use), `ML_Guard` / `ML_TradeFilters` / `ML_TradeStats` (ML-only wrappers).
- **Verify (Q08 hard evidence gate):** all OOS / Live numbers quoted above are vendor claims — must be reproduced on QM5 backtests before any card promotion.

---

## (b) FTMO March 2026 — production-grade portfolio drop

This cluster is by far the most mature artefact OWNER has on disk: an end-to-end, deploy-ready, fully-documented FTMO portfolio with strategy mining, sweep results, MANIFEST checksums, 3 risk profiles, and per-symbol performance reports. **Zero ML.**

### Main portfolio EAs (`FTMO March 2026/EAs/`) — 11 multi-strategy aggregators

Each EA bundles 2-3 strategies for one symbol. All use Darwinex symbol suffixes (`.DWX` / `.DXW`).

| # | EA | Strategy bundle | Tags | TF |
|---|---|---|---|---|
| 1 | `FTMO_AUDUSD_Portfolio_v1` | NNFX H1 Asian + ParSAR H1 + SilverBullet PM | NNFX, trend, breakout, session | H1, M15 |
| 2 | `FTMO_EURUSD_Portfolio_v1` | SilverBullet London + Judas Swing + LDN Close | FVG, MSS, session, fakeout, ADR | M15 |
| 3 | `FTMO_GBPUSD_Portfolio_v2` | SilverBullet London + MMXM C13 + ADR Exhaustion Reversal | FVG, mean-reversion, session, ADR | M15, H1 |
| 4 | `FTMO_NDX_Portfolio_v2` | SilverBullet NY AM + ORB + RSI MR | FVG, breakout, MR | M15, H1 |
| 5 | `FTMO_USDCAD_Portfolio_v3` | NNFX H1 + ParSAR H1 + Bollinger MR H4 | NNFX, SAR, Bollinger | H1, H4 |
| 6 | `FTMO_USDJPY_Portfolio_v1` | Asian Range Breakout + Ichimoku H4 + NNFX H1v2 | Asian, Ichimoku, NNFX | M15, H4, H1 |
| 7 | `FTMO_XAUUSD_Portfolio_v1` | TrendPullback D1/H4/H1 + ParSAR + WeeklyRev | EMA-pullback, SAR, weekly-SR, RSI | D1, H4, H1 |
| 8 | `FTMO_EURGBP_Portfolio_v2` | NNFX H1 + (ParSAR disabled) + Bollinger MR H4 | NNFX, Bollinger, low-vol | H1, H4 |
| 9 | `FTMO_GDAXI_Portfolio_v1` | ParSAR H4 + WeeklyRev (S1 disabled) | SAR, weekly-levels, low-freq | H4 |
| 10 | `FTMO_XAGUSD_Portfolio_v1` | TrendPullback + ParSAR + WeeklyRev | EMA-pullback, SAR, weekly-SR | D1, H4, H1 |
| 11 | `FTMO_XTIUSD_Portfolio_v1` | TrendPullback + ParSAR (S3 disabled) | EMA-pullback, SAR | D1, H4, H1 |

### Strategy mining package (`FTMO March 2026/SM_Portfolio_Deploy/`)

- `EAs/` + `Experts/` — 7 source EAs (SM_003 RoundNumber, SM_007 MondayRange, SM_012 TurnaroundTue, SM_015 OvernightDrift, SM_017 EngulfingH4, SM_018 SupplyDemand, SM_370 EndOfDayMomentumClose)
- `Include/FTMO/` — `FTMO_Strategy_Base.mqh` (risk mgmt base class), `PortfolioUtils.mqh` (shared utilities)
- `Sets/` + `Sets_VPS/` — 55 + 55 = 110 .set files (mirror copies), 40 deployed combos
- `Backtest_Data/` — 6 CSVs (all_pass_trades, daily_pnl_matrix, ftmo_sim_best_detail, plus sweep results for SM_003/007/012/015/017)
- `Docs/` — PORTFOLIO_ASSEMBLY_REPORT, STRATEGY_MINING_FINAL_REPORT, strategy_registry (full 23-strategy registry with results + sweeps + failure analysis), lessons_learned, production_config.json
- `MANIFEST.txt` — MD5-hashed manifest, 35 files / 673 KB, generated 2026-03-05

### Risk profiles (`FTMO March 2026/Settings/`) — uniform multipliers

| Profile | Risk multiplier | Total exposure | Use case |
|---|---|---|---|
| Original | 1.00x | ~16.65% | Backtested, high risk |
| Conservative | 0.33x | ~5.50% | First 2 weeks of FTMO challenge |
| Aggressive | 0.42x | ~7.00% | After 2+ weeks stable |

FTMO safety caps consistent across all three: `InpMaxDailyLossPct = 4.5%` (vs FTMO 5%), `InpMaxTotalDrawdownPct = 9.0%` (vs FTMO 10%), `InpMaxDailyRiskBudget = 5.0%/EA`.

### Documented portfolio claims (`Documentation/PERFORMANCE.md`)

Quote-only — vendor numbers, not QM-verified:

- Aggregate (11 symbols, 30 strategies, 22,255 trades, 2017-2025): **PF 1.34, Sharpe 3.92, DD 7.41%, net +$1.09M**
- README headline: Sharpe 8.70, PF 8.97, Max DD -0.36%, 18.3% annual return, avg pair correlation 0.007 (Edge family split: NNFX 24.7% / MeanReversion 23.9% / Calendar 22.5% / Trend 21.2% / Session 7.7%)
- Per-symbol highlights:
  - XAGUSD: PF 1.38, Sharpe 8.41, DD 3.72% — best smoothness
  - GBPUSD: PF 1.29, Sharpe 6.98 — smoothest equity curve
  - XTIUSD: PF 1.32, DD 3.63% — second-lowest DD
  - GDAXI: PF 1.36, DD 4.36%, 3 trades/month — safe diversifier
  - AUDUSD: 75% WR, 26 trades/month — highest frequency
- Kill rules: Max DD +2.5σ, 15 consecutive losers, monthly loss > 8%, rolling PF drop > 30%, WR drop > 15 pp

### V5 mining decisions for cluster (b)

- **Highest-value cluster in the entire Dropbox.** 11 portfolio EAs × 2-3 sub-strategies = ~30 mineable Strategy Cards. All ML-free.
- **Verify FIRST, port SECOND.** Performance numbers spread across two docs and disagree slightly (README vs PERFORMANCE.md). Q08 evidence required before any card is promoted.
- **SM_015 Overnight Drift is the standout** (PF 1.55, 83% sweep pass on GBPUSD) — prime first card candidate.
- **Edge-family diversification matches Mission Baseline.** NNFX / MR / Calendar / Trend / Session sleeves already correlated < 0.01 — confirms QM5 diversification thesis.
- **Symbol-mapping note:** EAs ship with `.DWX` / `.DXW` suffixes — already aligned with our Darwinex setup.

---

## (c) Trustful Trading / YoutubeCodeFIles — educational YouTube EAs

Companion code to a YouTube trading channel. Pattern: one base concept per EA, multiple feature-progression variants (esp. TimeRange family). All MT5 source readable, all rule-based, all ML-free.

### `Experts/Youtube/` — 20 EAs

| EA | Concept | Tags | Notable knob |
|---|---|---|---|
| `BollingerBandsEA` | BB breakout / mean-rev | indicator | Period 21, σ 2.0 |
| `CandlePatternEA` | Pattern recognition w/ 2-condition GUI | pattern | Pattern ratio/body/range |
| `DonchianChannelEA` | Donchian breakout w/ offset | breakout | Period 20, Offset 0-49% |
| `FirstEA` | Time-range scalper (basic ed.) | time-range | Hardcoded 10-12 |
| `HighLowBreakoutEA` | N-bar HL breakout + trailing SL | breakout | Bars 20 |
| `HighLowBreakoutEACCriteria` | Near-duplicate of above | breakout | — |
| `MAPullbackEA` | MA pullback w/ ATR exit | pullback | MA 21, ATR 21, Trigger 2.0σ, Dynamic TP |
| `MovingAverageEA` | Dual MA crossover | indicator | 14/21 |
| `PatternRecognitionEA` | CSV-based pattern correlation matching | pattern | Min corr 0.85, pattern size 80% |
| `RsiEA` | RSI OB/OS | indicator | 21, level 70 |
| `RsiMaFilterEA` | RSI + dual-TF MA filter | indicator | RSI 21/70, MA 21 on H1 |
| `StochasticEA` | Stoch w/ clear-bar filter | indicator | K-21, level 80 |
| `StreakEA` | Consecutive candle momentum | streak | Streak 3 |
| `TimeRangeEA` | Time-range breakout (base) | time-range | Range 600-720 min |
| `TimeRangeEADynamicLots` | + dynamic lots (3 modes) | time-range | fixed/money/pct |
| `TimeRangeEADynamicLotsTrSL` | + trailing SL | time-range | + trailing |
| `TimeRangeEADynamicLotsTrSLV2` | V2 (near-identical to V1) | time-range | — |
| `TimeRangeEAPanel` | + GraphicalPanel UI | time-range | + Panel |
| `TimeRangeEAPending` | + pending orders at range | time-range | + pending |
| `VolumeProfile` | Volume profile (indicator-only, no trading) | indicator | VP bars 50 |

### `Indicators/Youtube/` + `Include/Youtube/`

- `Indicators/Youtube/MyDonchianChannel.mq5` — Donchian upper/lower bands
- `Include/Youtube/CandlePatternGUI.mqh` — CAppDialog UI wrapper for CandlePatternEA
- `Include/Youtube/GraphicalPanel.mqh` — CAppDialog UI wrapper for TimeRangeEAPanel

### V5 mining decisions for cluster (c)

- **MAPullbackEA** and **StreakEA** look like the most original ideas (everything else is textbook-tier).
- **TimeRange family** is a single base EA with 6 incremental feature deltas — V5 should treat it as ONE Strategy Card with parameters covering the feature toggles, not 7 separate cards.
- **VolumeProfile** is an indicator-only file, no trade logic — skip.
- **No documented backtest performance** for any of these — pure educational code; entire cluster must be Q02-screened before any card is built.

---

## (d) Finanzen/Forex Robots — legacy / high-risk EAs

Mixed-vintage archive of standalone robots.

| Path | Concept | Notable | ML |
|---|---|---|---|
| `Gunpowder3.mq5`, `Gunpowder4.mq5` | Grid/martingale (Elite v1.04, based on Icarus 4.31) | Grid 40, Progression 3, **Max 100 open positions**, hedge 10, no SL/TP | FALSE |
| `MT4/Ftmo trader pro mt4.ex4` (+ .set) | MT4-only compiled blackbox | not MT5, opaque | unknown |
| `MT4/Pro Candles EA unlimited.ex4` (+ .set) | MT4-only compiled blackbox | not MT5, opaque | unknown |
| `MT4/Robust Profit EA unlimited.ex4` (+ .set) | MT4-only compiled blackbox | not MT5, opaque | unknown |
| `Russian/correlation.mq5` | 2-symbol correlation indicator | not an EA | FALSE |
| `Russian/Pending orders UP DOWN.mq5` | Pending grid placement script (V. Karputov) | BuyStop/SellLimit grid, 15-pip gap | FALSE |
| `Russian/Quantum#P London Trading EA v1.6.1` | MQL4 London session scalper | legacy MT4 | unknown |
| `Russian/RS-connect(STOP & LIMIT&step).ex4` | MT4 order-mgmt tool | binary | unknown |
| `Russian/TrailingNetLimitOrders_Free.ex4` | MT4 trailing-stop tool | binary | unknown |
| `History to csv or excel.ex4` | MT4 history exporter utility | not strategy | — |
| `Set Files -20230324T121536Z-001.zip` | Compressed set files bundle (~7 MB, not unzipped) | unknown | — |
| `testergraph.report.2022.11.28.csv` | Backtest equity curve, $10K start, 2019-01-09 | report-only | — |
| `TOP Performance/m1_highrisk_with_autolot GFA.set` (+ .txt) | High-risk grid system | **Risk 100%, Stop -100, Distance -50, Auto Lot, Take Profit Average, 20+ pairs** | FALSE |

### V5 mining decisions for cluster (d)

- **Skip Gunpowder + GFA grid configs.** Grid/martingale with 100 open positions and "Risk 100%" cannot pass V5 risk hard rules (DXZ 5%/20% DD caps, FTMO 10% total).
- **Skip MT4-only binaries.** V5 is MT5; legacy MT4 binaries are non-portable blackboxes and no source is available.
- **Skip Russian pending-orders script.** Order-placement utility, not a strategy.
- **One useful artefact:** the `testergraph.report.2022.11.28.csv` is the only audit trail in this cluster — useful as a calibration example for our backtest-report format, not for strategy mining.

---

## (e) Finanzen/CodeTrading — Python research notebooks

| Notebook | Concept | Result | ML |
|---|---|---|---|
| `_LevelBreakOut_EURUSD_D1.ipynb` | Pivot-based level breakout + RSI filter on AAPL.US D1 | **Broken — 0 trades** (zone detection found no signals); buy & hold ref 55.84% | FALSE (pandas_ta, backtesting only) |
| `EURUSD_SR_WITH_CANDLES_Backtesting_MARTINGALE.ipynb` | S/R breakout + engulfing/star pattern + Martingale sizing on EURUSD D1, 2003-2021 | PF 2.10, WR 65.7%, +1,510% return — **but Max DD -98.59%** | FALSE |

Plus 4 historical CSVs: AAPL.US (2017-2024, 2,676 bars), EURUSD ASK (2003-2021, 6,632 bars), EURUSD BID (2010-2024, 5,258 bars), recent EURUSD snapshot (22 rows).

### V5 mining decisions for cluster (e)

- **Skip the level-breakout notebook** — broken at the zone-detection stage.
- **Skip the Martingale notebook** — -98.59% DD is account-killer behaviour and structurally incompatible with V5 risk rules. The S/R + engulfing entry logic underneath is mechanizable but the sizing model defines this strategy and cannot be salvaged.
- **CSVs are duplicates** of data already in `D:\QM\data` — no extraction value.

---

## (f) Finanzen/Michael Hinterleitner Trading

Two subfolders (no `FTMO_Portfolio_V2/` — flagged earlier; my first-pass listing was wrong).

### `MT5_EA-Zubehör_v2/`

- `MomentumTrailer_EA_MT5.ex5` — **compiled only, no .mq5 source** → opaque blackbox, cannot mechanize
- `MTEA Indicators/Average True Range.mq5` (+ .ex5) — standard ATR 14
- `MTEA Indicators/donchian_channels2.mq5` (+ .ex5) — Donchian variant
- `MTEA Setfiles/MomentumTrailer_EA_MT5_LIVE.set` + `_TEST.set` — live + backtest configs
- `WICHTIGE_HINWEISE.pdf` — German operational notes (unread, requires extraction)
- `Zusatzinfos.txt` — additional German notes (unread)

### `MT5_FX-Crashkurs_2022/` — 1,946 files

A complete MT5 development-environment backup (course material).

- `MQL5/Experts/Advisors/` — 4 reference EAs:
  - `ExpertMACD.mq5` (12/24/9, 50 TP / 20 SL pips)
  - `ExpertMAMA.mq5` (Mama indicator)
  - `ExpertMAPSAR.mq5` (ParabolicSAR)
  - `ExpertMAPSARSizeOptimized.mq5` (SAR + position sizing)
- `MQL5/Indicators/Examples/` — 100+ educational indicators (full standard library + "Sq*" extensions for ADX/ATR/BBWidthRatio/KAMA/SuperTrend etc.)
- `MQL5/Scripts/` — Alglib, ArrayList/HashMap/LinkedList, stats tests, canvas/OpenCL examples
- Backup `terminal64.exe`, `metaeditor64.exe`, `metatester64.exe`, profiles, sets, templates, logs (492 .hcc, 260 .hcs, 183 .ex5, 156 .welcome, 35 .set)

Plus duplicate ZIPs at root (`MT5_EA-Zubehör_v2.zip`, `MT5_FX-Crashkurs_2022.zip`).

### V5 mining decisions for cluster (f)

- **Read `WICHTIGE_HINWEISE.pdf` + `Zusatzinfos.txt`** before deciding on MomentumTrailer — the EA itself is closed source but the notes may describe the strategy well enough to reimplement.
- **Crash-course Advisor EAs** (MACD, MAMA, MAPSAR, MAPSARSizeOptimized) are textbook-tier — only mine if the course videos demonstrate a non-trivial parameter tuning or filter overlay (will be covered in Task #2 Finanzen/Forex catalogue + later Gemini batches).
- **Sq* indicator family** is interesting — these are non-standard variants. Worth a deeper read pass in a follow-up task.

---

## Cross-cluster ML-flag summary

39 ML EAs total — all in `Ftmo/week3-4`. Origin: same author / sprint, XGBoost → ONNX pipeline, separate buy/sell models, 95-412 ICT features. **None of these EAs can be ported to V5** (Hard Rule). The 8-9 reusable engines under `ML_v2/` and `week4/` ARE portable once ONNX inference is removed.

Zero ML detected anywhere else.

---

## Recommended next moves (input to Plan phase)

1. **Cluster (b) FTMO March 2026 first.** Production-ready, fully documented, ML-free, 30+ Strategy Cards extractable. Highest ROI for the time spent.
2. **Cluster (a) weeks 1-2 second.** 11 V5-compatible ICT/SMC EAs with set files ready for Q02 backtest.
3. **Cluster (a) engine port third.** Strip ONNX from BaseEngine/StructureEngine/ImbalanceEngine/POIEngine/LiquidityEngine/ProfileTimeEngine → land as reusable library under `framework/include/ict/`. Separate Codex task.
4. **Cluster (c) MAPullback + StreakEA fourth.** Original ideas worth a Q02 screen.
5. **Cluster (f) Hinterleitner notes fifth.** Read the PDFs before deciding MomentumTrailer reimplementation.
6. **Skip:** all ML EAs, Gunpowder, GFA grid, Martingale notebook, MT4-only binaries, level-breakout notebook.

Vendor performance claims (Ftmo OOS, FTMO March 2026 PERFORMANCE.md, Hinterleitner notes) must all clear Q08 hard-evidence gate on QM5 backtests before any card promotes — these are starting points, not endorsements.
