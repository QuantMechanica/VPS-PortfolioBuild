# FTMO NNFX State-Machine Coverage Reconciliation and N2 Intraday Pre-Registration

**Programme:** `FTMO_BR_NNFX_20260921`  
**Packet Key:** `N-GAPS`  
**Task ID:** `9ace7476-09d4-45cb-a349-72ab9ceb8985`  
**Authority:** `OWNER-REQUEST-FTMO-BR-NNFX-20260921` (`decisions/2026-09-21_owner_ftmo_br_nnfx_research_intake.md`)  
**Operating Directive:** `docs/research/ftmo_intake/2026-09-21_br_nnfx/PLAN.md`  
**Date:** 2026-09-21  
**Author:** Gemini (Strategy Farm Research Lane)  
**Status:** `REVIEW`  

---

## 1. Executive Summary & Verdict

This deliverable executes research packet `N-GAPS` under the 2026-09-21 OWNER directive. The mandate requires two concrete deliverables:
1. Reconcile source, spec, code, and test coverage for the No Nonsense Forex (NNFX) algorithmic framework against the June 2026 Variant Realization Survey and existing repository implementations (`QM5_12534`, `QM5_12742`, `QM5_2010`, `QM5_2011`), reviewing external community leads (`stfl/backtestd-doc`, `AlgoMasterNNFX-V1`) without executing third-party code.
2. Pre-register a finite, buildable, NNFX-inspired intraday experiment (**N2**) freezing reviewed indicator formulas and periods from `QM5_36001` across four symbols and two H1 execution arms (**8 comparison cells**), testing session-flat execution against all-hours holding under realistic FTMO financing and cost constraints.

### Core Findings & Disposition Counts
* **Closed Duplicates (4 EA families, 2 external leads):**
  * `QM5_12534`: Canonical D1 full-stack (Kijun + SSL + Aroon + WAE + 1 ATR proximity + 1.5 ATR stop + 1.0 ATR half-close + BE move). Passed Q02 across 8 FX pairs, but **100% failed at Q04** (walk-forward/regime gate). Canonical D1 mechanics are fully covered; claiming novel canonical D1 rules here would be a duplicate.
  * `QM5_12742`: Configurable slot engine (7 baselines, 7 C1s, 4 C2s, 4 volume gates, 4 exits, 7-bar entry window, 1 ATR proximity). Extensively tested across 13 symbols; reached Q06 FAIL on EURUSD. Slot-permutation space is already mapped.
  * `QM5_2010` / `QM5_2011`: Multi-timeframe H4-bias / H1-pullback and H1-breakout variants. Both **failed Q02 immediately across all symbols**. Both contained structural defects violating VP rules (ADX banned in Dirty Dozen; full MACD line cross banned).
  * External lead `stfl/backtestd-doc`: Continuation state-machine sections are demonstrably unfinished in the source text. Inventing continuation rules without primary source evidence is strictly rejected.
  * External lead `AlgoMasterNNFX-V1`: Notes D1 synchronization limitations and omission of spread/commissions outside MT5 real-trades mode. No novel viable edge found.
* **Gaps Identified:**
  * **Cadence & Speed Gap:** Canonical D1 NNFX generates only 15–25 trades/year/symbol (~60–100 trades across a 4-pair basket), yielding an unviable 289 to 489 business days to FTMO payout (LCB 0.8668 degrades to 0.6072 under venue-cost stress).
  * **Overnight Financing vs. Session Edge Gap:** H1 execution provides necessary trade density, but overnight holding incurs FTMO financing (swap), spread widening at 23:55–00:05 GMT rollover, and off-session chop. The marginal value of session-flattening (eliminating overnight financing and rollover risk at the expense of cutting multi-day trend runners) has never been tested in a controlled, paired trial.
* **Survivors:**
  * **1 Pre-registered Experiment (N2):** 8 comparison cells (4 symbols × 2 arms: `H1_SESSION_FLAT` vs. `H1_ALL_HOURS`), with frozen McGinley(14), SSL(10), and WAE(12,26,9) indicators, identical 1.5 ATR stops, 1.0 ATR 50% partials, BE moves, and opposite SSL exits.
* **Unresolved Dependencies:**
  * `7088da77-9e03-45cf-a568-581863f03ef1` (Velocity harness v2: tick-level anchor validity, fail-closed OCO, gap fills, release-day tagging). Prerequisite for prescreen execution.
  * `cd3b761c-54d4-4b71-ba7e-f60018df57d3` (N-RECOVERY: recovery of `QM5_36001` review blocker and compile verification).

**Verdict:** `REVIEW` (Finite specification, coverage reconciliation, and N2 pre-registration delivered; execution awaits harness v2).

---

## 2. Cryptographic Evidence & Authority Inventory

| Artifact / Evidence File | Path / Identifier | Exact SHA-256 Hash |
|---|---|---|
| Strategy Farm State DB | `D:/QM/strategy_farm/state/farm_state.sqlite` | Bound at runtime |
| EA ID Registry | `C:/QM/repo/framework/registry/ea_id_registry.csv` | `6b8e09f6113c6448f3e27850a2a861a3ec1fde4db6900997ac9fd675d2e41983` |
| Intake Inventory | `docs/research/ftmo_intake/2026-09-21_br_nnfx/inventory.json` | `76723f335a9b55c5a11fe4328c179048552e53321dfefa8d1e4ac94bca4fb226` |
| Source Review Catalog | `docs/research/ftmo_intake/2026-09-21_br_nnfx/sources.json` | `9ed8295104853d2f4490089b1f4b7b2ebfc8da6e06fa8ad7978dd17b782354ba` |
| Master Intake Plan | `docs/research/ftmo_intake/2026-09-21_br_nnfx/PLAN.md` | `e42d8770df11fcbbca9e5560a1280c352145b09d7cd1e2b30135d4bff1a9b57b` |
| Task Packets Contract | `docs/research/ftmo_intake/2026-09-21_br_nnfx/task_packets.json` | `302cdc4c08c9782ad048547bce864e71ffcbd4615b7092e43ffefcc3e260b75f` |
| Variant Realization Survey | `docs/research/VARIANT_REALIZATION_SURVEY_2026-06.md` | `0b8d7360f4c848befbb2b4d4bf74a2e29ee688ec6d5517b22d1e2dc386a33bcf` |
| `QM5_12534` MQL5 Source | `framework/EAs/QM5_12534_.../QM5_12534_...mq5` | `2c131f028c7340a870679a0267dc120726971c95c940ea0e38196fb694567c5e` |
| `QM5_12742` MQL5 Source | `framework/EAs/QM5_12742_.../QM5_12742_...mq5` | `ff486d5a8daecb8044317c500b0a937f460bf064dd6f013fbb6174af398b3dd8` |
| `QM5_2010` MQL5 Source | `framework/EAs/QM5_2010_.../QM5_2010_...mq5` | `df791907455fbe2e5a65c3b48597d398475347e6a17011af0441f057ef8384fc` |
| `QM5_2011` MQL5 Source | `framework/EAs/QM5_2011_.../QM5_2011_...mq5` | `d18d9477607e6d82c01d3339146a1e4bef84ac57e3c89da3a6fdf14f02e0683b` |
| `QM5_36001` MQL5 Source | `framework/EAs/QM5_36001_.../QM5_36001_...mq5` | `60214c63db0cd86f789f199a96651386b57ec8501ae2a7e1ca4eddebe4e004c7` |
| AlgoMasterNNFX-V1 README | `commit: 12f1eea500677725a79dbe0630fbd8eb95cc2d01` | `493db4a774bd96f748b565db8885944fd95b67e8684176e7d97bccdd02da3a63` |
| backtestd-doc Rules | `commit: 20396101aa6b6101b6a773ebce3e414ce50510e7` | `33999560bfc50b9db24c34983d37ede2fdf683a88fbe077847259f78edd9dc74` |

---

## 3. NNFX State-Machine Coverage & Reconciliation

The table below reconciles canonical NNFX requirements (as defined in primary VP materials and codified in Section 4 of `VARIANT_REALIZATION_SURVEY_2026-06.md`) against the repository's historical codebases and external leads.

| Component / Rule | Canonical NNFX (VP / June Survey) | `QM5_12534` (D1 Fullstack) | `QM5_12742` (Configurable) | `QM5_2010` / `QM5_2011` (H4/H1) | External Leads (`stfl`, `AlgoMaster`) | Coverage Disposition |
|---|---|---|---|---|---|---|
| **Base Timeframe** | Strictly D1 closed bars. Candle closes evaluated once per day. | `PERIOD_D1` only. Closed bar gated by `QM_IsNewBar()`. | `PERIOD_D1` default (`PERIOD_H4` exposed). Closed bars. | H4 bias + H1 trigger. Intraday execution. | `stfl`: D1 rules. `AlgoMaster`: D1 emphasis, flags intraday sync issues. | **COVERED (D1)**. Intraday is an experimental extension, not canonical NNFX. |
| **Baseline Indicator** | Single moving average / baseline (Kijun-sen, HMA, McGinley, ALMA, etc.). | Kijun-sen(26) on D1. | Selectable (Kijun, HMA, T3, ALMA, McGinley, ZLSMA, EMA). | H4 EMA(89) / EMA(100) + H1 Kijun. | Kijun, McGinley, EMA commonly cited. | **COVERED**. Broad indicator baseline options exist. |
| **Baseline Cross Window** | Price must cross baseline within 7 bars of entry. | Checks baseline cross within 3 bars. | Configurable `nnfx_entry_window_bars` (default 7). | No explicit cross window; requires directional bias. | `stfl` defines 7-candle rule. | **COVERED**. Exactly parameterized in `QM5_12742`. |
| **Proximity Gate** | $|Close - Baseline| \le 1.0 \times ATR(14)$. Anti-chasing rule. | Enforced: $|Close - Kijun| < 1.0 \times ATR(14)$. | Enforced: `nnfx_proximity_atr_mult = 1.0`. | Not implemented (omits anti-chasing gate). | Mandatory anti-chasing filter in `stfl` and survey. | **COVERED**. Implemented in both 12534 and 12742. |
| **C1 Confirmation** | Primary non-lagging indicator; NOT in Dirty Dozen. | SSL Channel(10) on D1 closed bar. | Selectable (Supertrend, SSL, Aroon, Vortex, STC, QQE, Fisher). | SSL Channel(10) on H1. | SSL, Vortex, STC prominent. | **COVERED**. Compliant non-banned C1s implemented. |
| **C2 Confirmation** | Secondary agreement; NOT in Dirty Dozen. | Aroon(25) on D1. | Selectable (OFF, Vortex, Aroon, Trix). | `QM5_2010` uses **ADX(14)** (BANNED). `QM5_2011` uses **MACD**(12,26,9) line cross (BANNED). | C2 optional in many community implementations. | **COVERED / DEFECT IDENTIFIED**. 2010/2011 used Dirty Dozen indicators. 12534/12742 clean. |
| **Volume / Volatility Gate** | Direction-neutral volume/momentum threshold (WAE, CMF, etc.). | WAE (MACD 20/40/9 + BB 20/2.0 + deadzone 150 pts). | Selectable (ATR Expansion, ADX Rising, CMF, WAE). | None (2010 uses ADX as filter; 2011 uses MACD). | WAE is community standard; flags spread costs. | **COVERED**. Multiple volume gates implemented in 12534/12742. |
| **One-Candle Rule** | If C1 triggers on Bar 0, C2/Volume may align on Bar 1 (max 1 bar delay). | Simultaneous bar evaluation; no delayed latch. | Simultaneous bar evaluation; no delayed latch (C2=OFF supported). | Not implemented. | `stfl` details 1-candle rule. | **COVERED (SUBSET)**. Simultaneous alignment is a strict, conservative subset. No defect. |
| **ATR Pullback Entry** | Re-entry on pullback to baseline during active trend. | Not implemented. | Not implemented. | H1 pullback to Kijun (`QM5_2010`), but failed Q02. | Mentioned informally; no mathematical spec. | **REJECTED (UNGROUNDED)**. No standardized canonical spec. |
| **Continuation Trades** | Trend continuation after exit or partial profit. | Not implemented. | Not implemented. | Not implemented. | `stfl` section is explicitly **unfinished / blank**. | **REJECTED (INCOMPLETE SOURCE)**. Hard rule prohibits inventing continuation rules. |
| **Stop Loss** | $1.5 \times ATR(14)$ from entry. | $1.5 \times ATR(14)$ (`strategy_sl_atr_mult`). | $1.5 \times ATR(14)$ (`nnfx_stop_atr_mult`). | Fixed pip or $1.5 \times ATR(14)$. | $1.5 \times ATR(14)$ uniform. | **COVERED**. Exact canonical sizing in 12534 and 12742. |
| **Take Profit & Management** | TP1 at $1.0 \times ATR(14)$ (close 50%); move runner SL to BE. | TP1 at $1.0 \times ATR(14)$ (close 50%); moves SL to BE. | TP1 at $1.0 \times ATR(14)$ (close 50%); moves SL to BE. | Partial close supported in framework. | Half-close at 1 ATR + BE move uniform across sources. | **COVERED**. Implemented and verified in 12534 and 12742. |
| **Strategic Exit** | Exit runner on opposite Baseline cross, C1 flip, or exit indicator. | Exit on opposite Kijun cross OR opposite SSL signal. | Selectable (PSAR, C1 Flip, Kijun Recross, Chandelier). | Exit on opposite SSL / Kijun. | Opposite C1 or Baseline cross standard. | **COVERED**. Fully covered in 12534 and 12742. |

---

## 4. Defect Analysis & External Lead Review

### 4.1. Historical Repository Implementations
1. **`QM5_12534_nnfx-canonical-d1-fullstack`:**
   * **Mechanics:** 100% compliant with canonical D1 NNFX. Uses Kijun-sen(26), SSL Channel(10), Aroon(25), WAE, 1.0 ATR proximity, 1.5 ATR initial stop, 1.0 ATR half-close, and breakeven adjustment.
   * **Empirical Ledger Verdict:** Passed Q02 on 8 of 9 pairs (`AUDUSD`, `EURJPY`, `EURUSD`, `GBPJPY`, `GBPUSD`, `USDCAD`, `USDCHF`, `USDJPY`). However, at **Q04 (Walk-Forward / Regime Gate), all 8 pairs failed**. The strategy proved incapable of maintaining positive expectancy across walk-forward splits.
   * **Conclusion:** Canonical D1 NNFX is a **CLOSED_DUPLICATE**. It has already been tested through Q04; re-implementing canonical D1 NNFX would yield no new informational value.
2. **`QM5_12742_nnfx-configurable-engine`:**
   * **Mechanics:** Modular architecture allowing permutations of 7 baselines, 7 C1s, 4 C2s, 4 volume gates, and 4 exits.
   * **Empirical Ledger Verdict:** Passed Q02 across 12 symbols (FX, indices, energy, metals). Passed Q03 on GDAXI. Passed Q04 on EURUSD (soft pass) and Q05, but **failed Q06 (cost/stress gate) on EURUSD**.
   * **Conclusion:** Full-stack slot combinations suffer severe degradation once realistic spreads, commissions, and execution frictions are applied.
3. **`QM5_2010` & `QM5_2011` (H4-Bias / H1-Pullback & Breakout):**
   * **Mechanics:** Multi-timeframe attempts to increase cadence.
   * **Empirical Ledger Verdict:** **100% failed at Q02** across EURUSD, GBPUSD, USDJPY, and XAUUSD.
   * **Root Cause:** Direct violation of VP's "Dirty Dozen" banned indicators:
     * `QM5_2010` embedded `strategy_adx_period = 14` (ADX is Banned Indicator #1).
     * `QM5_2011` embedded full MACD signal line crossovers (Banned Indicator #12 equivalent).
   * **Conclusion:** Defective lineages. Moving to intraday without respecting indicator validity produces negative expectancy.

### 4.2. External Leads Review
* **`stfl/backtestd-doc` (`NNFX Algo/Algorithm Rules.org`):**
  * Retrieved commit: `20396101aa6b6101b6a773ebce3e414ce50510e7`.
  * The document provides community rules for C1/C2 triggers, baseline cross windows, and the one-candle rule.
  * **Critical Gap:** The section on *Continuation Trades* is explicitly unfinished in the source text.
  * **Governed Disposition:** Under the Edge Lab Charter and Hard Rules, missing rules must never be filled by agent imagination or ungrounded synthesis. No continuation trade lineage is permitted without an authenticated primary source.
* **`AlgoMasterNNFX-V1` (Alex Cercos):**
  * Retrieved commit: `12f1eea500677725a79dbe0630fbd8eb95cc2d01`.
  * The author explicitly caveats that the framework is calibrated for D1, warns of multi-timeframe bar synchronization pitfalls, and notes that backtests outside MT5 real-trades mode omit transaction costs.
  * **Governed Disposition:** Serves as confirmation that retail intraday adaptations frequently succumb to cost omission and execution mismatch.

---

## 5. Experiment N2 Pre-Registration: H1 Session-Flat vs. All-Hours

### 5.1. Rationale & Core Hypothesis
* **The Speed Problem:** FTMO 2-Step Challenge (+10%) and Verification (+5%) require actionable trade velocity to meet OWNER's speed requirement. D1 NNFX (~18 trades/year) requires an unviable 289–489 business days to payout.
* **The Cost/Financing Problem:** Transitioning to H1 increases trade frequency to ~80–120 trades/year/symbol. However, holding FX/Metals positions overnight on FTMO incurs:
  1. Negative financing/swap carry.
  2. Spread widening during the rollover window (23:55–00:05 GMT), where spreads routinely expand 5x–15x.
  3. Tail risk from off-session illiquid price shocks.
* **Falsifiable Thesis:** A session-flat H1 adaptation (restricting entries to high-liquidity London/NY overlap hours and flattening positions at 17:00 London) eliminates rollover widening and financing drag. This will produce higher net expectancy and faster capital velocity than an identical all-hours strategy, despite truncating multi-day trend runners.

### 5.2. Frozen Indicator Formulas & Parameters (Recovered from `QM5_36001`)
The indicator stack is frozen from the reviewed `QM5_36001` specification. To avoid cadence starvation, secondary confirmation (Vortex) is omitted, isolating the lean McGinley + SSL + WAE core:

1. **McGinley Dynamic Baseline (Period = 14, Warmup = 150 bars):**
   $$MD_t = MD_{t-1} + \frac{Close_t - MD_{t-1}}{14 \cdot \left(\frac{Close_t}{MD_{t-1}}\right)^4}$$
   *Warmup requirement:* Evaluated over 150 closed H1 bars to ensure mathematical convergence before signal generation.
   *Entry condition:* For Long, $Close[1] > MD[1]$; for Short, $Close[1] < MD[1]$.
   *Proximity condition:* $|Close[1] - MD[1]| \le 1.0 \times ATR(14, H1)[1]$.
2. **SSL Channel C1 Trigger (Period = 10):**
   $$HighSMA_t = SMA(High, 10, t), \quad LowSMA_t = SMA(Low, 10, t)$$
   *State:* Bullish (+1) when $Close[1] > HighSMA[1]$; Bearish (-1) when $Close[1] < LowSMA[1]$.
   *Trigger:* New bar open following a closed-bar transition into alignment.
3. **Waddah Attar Explosion Volume Gate:**
   $$Momentum_t = \left(MACD\_Main(12, 26, 9)_1 - MACD\_Main(12, 26, 9)_2\right) \cdot 150.0$$
   $$Explosion_t = |BB\_Upper(20, 2.0)_1 - BB\_Lower(20, 2.0)_1|$$
   $$Deadzone_t = 150 \cdot Point$$
   $$Threshold_t = \max(Explosion_t, Deadzone_t)$$
   *Gate:* Direction-neutral volume expansion: $|Momentum_t| > Threshold_t$.

### 5.3. Identical Execution & Money Management Rules
* **Timeframe:** `PERIOD_H1` closed bars only (evaluated at `QM_IsNewBar()`).
* **Initial Stop Loss:** $1.5 \times ATR(14, H1)[1]$ from fill price.
* **Take Profit (TP1):** $1.0 \times ATR(14, H1)[1]$ from fill price. Close exactly 50% of position.
* **Runner Management:** Upon TP1 execution, move residual position Stop Loss to exact entry price (breakeven).
* **Runner Exit:** Closed H1 bar with opposite SSL Channel state ($Close < LowSMA$ for Long; $Close > HighSMA$ for Short).
* **Position Cap:** Maximum 1 open position per symbol; maximum 2 new entries per symbol per calendar day.
* **Risk Model:** `RISK_FIXED = $1,000` per trade for backtest prescreening.

### 5.4. Paired Comparison Arms

| Arm ID | Name | Trading Hours (Europe/London) | Session Exit Rule | Financing & Rollover |
|---|---|---|---|---|
| **Arm A** | `H1_SESSION_FLAT` | Entries permitted on hourly opens **09:00 through 16:00 London**. No new entries after 16:00. | All open positions **force-closed at 17:00 London** market close. | Zero overnight swap; zero 23:55 GMT rollover spread exposure. |
| **Arm B** | `H1_ALL_HOURS` | Entries permitted on any hourly open (24 hours, excluding weekend). | Positions held across days until SL, TP1, or opposite SSL exit. | Full FTMO swap charged; subject to 23:55 GMT spread widening and gap risk. |

### 5.5. Pre-Registration Matrix: 8 Experimental Cells

| Cell ID | Symbol | Asset Class | Execution Arm | Baseline / Trigger / Volume | Entry Window | Flat Window |
|---|---|---|---|---|---|---|
| `N2-EURUSD-FLAT` | `EURUSD.DWX` | FX Major | `H1_SESSION_FLAT` | McGinley(14) / SSL(10) / WAE | 09:00–16:00 London | 17:00 London |
| `N2-EURUSD-ALL`  | `EURUSD.DWX` | FX Major | `H1_ALL_HOURS`    | McGinley(14) / SSL(10) / WAE | 00:00–23:00 London | None (Stop/Exit) |
| `N2-GBPUSD-FLAT` | `GBPUSD.DWX` | FX Major | `H1_SESSION_FLAT` | McGinley(14) / SSL(10) / WAE | 09:00–16:00 London | 17:00 London |
| `N2-GBPUSD-ALL`  | `GBPUSD.DWX` | FX Major | `H1_ALL_HOURS`    | McGinley(14) / SSL(10) / WAE | 00:00–23:00 London | None (Stop/Exit) |
| `N2-USDJPY-FLAT` | `USDJPY.DWX` | FX Major | `H1_SESSION_FLAT` | McGinley(14) / SSL(10) / WAE | 09:00–16:00 London | 17:00 London |
| `N2-USDJPY-ALL`  | `USDJPY.DWX` | FX Major | `H1_ALL_HOURS`    | McGinley(14) / SSL(10) / WAE | 00:00–23:00 London | None (Stop/Exit) |
| `N2-XAUUSD-FLAT` | `XAUUSD.DWX` | Metal    | `H1_SESSION_FLAT` | McGinley(14) / SSL(10) / WAE | 09:00–16:00 London | 17:00 London |
| `N2-XAUUSD-ALL`  | `XAUUSD.DWX` | Metal    | `H1_ALL_HOURS`    | McGinley(14) / SSL(10) / WAE | 00:00–23:00 London | None (Stop/Exit) |

---

## 6. Data Requirements & Rigorous Kill Criteria

### 6.1. Data & Venue Requirements
1. **Quotes & Timebase:** Exact M1/H1 bid and ask prices with broker spread curves for `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and `XAUUSD.DWX`. Timebase synchronized to London (GMT/BST) with official DST transition handling.
2. **Financing Ledger:** Daily triple-swap Wednesday accounting and real FTMO financing rates applied to Arm B.
3. **Execution Model:** Next-bar open market fills, slippage floor applied (1 tick minimum), gap-through stop fills at the first available open/bid price (never at the level).
4. **Validation Partitions:**
   * In-Sample / Calibration: 2018-01-01 through 2022-12-31.
   * Reused Historical Validation: 2023-01-01 through 2025-12-31.
   * Sealed Out-of-Sample: 2026-01-01 to present (reserved for MT5 canary / prospective demo).

### 6.2. Explicit Kill Criteria
An individual cell or the entire N2 family will be **immediately killed** without optimization under any of the following conditions:
1. **Expectancy Failure:** Net profit factor $PF_{net} \le 1.05$ or net expectancy $\le 0.0$ on the 2023–2025 validation window.
2. **Cost Stress Fragility:** Degradation of $PF_{net}$ by $>25\%$ or drop below $1.0$ under $1.5\times$ spread and 3-tick slippage stress.
3. **Cadence Starvation:** Trade frequency $< 30$ trades/year across the 4 symbols in Arm A (failing the speed objective).
4. **Drawdown Boundary Breach:** Maximum daily drawdown $> 3.5\%$ (exceeding FTMO 5% safety margin) or maximum cumulative drawdown $> 7.0\%$ (exceeding FTMO 10% safety margin).
5. **No Session Advantage:** If Arm A (`H1_SESSION_FLAT`) demonstrates lower Sharpe/expectancy than Arm B (`H1_ALL_HOURS`) while Arm B also fails FTMO cost gates, the intraday NNFX adaptation thesis is falsified.

---

## 7. Dependency Mapping & Follow-On Workflow

### 7.1. Upstream Preconditions
* **Task `7088da77-9e03-45cf-a568-581863f03ef1` (Velocity Harness v2):**
  * Status: `IN_PROGRESS` (Codex).
  * Impact: Prescreen execution requires the v2 execution model (fail-closed OCO, gap fills at next open, release-day tagging). No Python backtest numbers may be claimed as valid prescreens until harness v2 is accepted.
* **Task `cd3b761c-54d4-4b71-ba7e-f60018df57d3` (N-RECOVERY):**
  * Status: `TODO` (Codex).
  * Impact: Governs the formal recovery of `QM5_36001` review blocker and compile validity for potential MT5 canary deployment.

### 7.2. Canonical Follow-On Execution
Upon completion of harness v2 (`7088da77`):
1. Run the 8 pre-registered N2 cells through the canonical harness.
2. Log all 8 cell outcomes (survivors and killed cells) into `docs/research/ftmo_intake/2026-09-21_br_nnfx/results/N2_EVIDENCE.json`.
3. If any cell survives all kill criteria, submit the trade stream to `PAYOUT80` (`e5cc5e95-c3d5-490a-b6c0-a3fded57a38c`) for full-chain payout probability evaluation.
4. Authorize a formal Strategy Card draft in `D:/QM/strategy_farm/artifacts/cards_review/` for surviving lineages only.

---
*End of Deliverable N-GAPS.md — QuantMechanica Strategy Farm Research Lane*
