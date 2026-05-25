# Pipeline Rewrite Proposal — 2026-05-23

**Status:** DRAFT — awaiting OWNER approval before Vault rewrite + code rewrite.
**Author:** Claude (session 2026-05-23).
**Trigger:** OWNER call: pipeline has drifted from the canonical website
spec at https://quantmechanica.com/pipeline. Davey criteria are missing,
Q02 PASS is too loose (zero-trade / negative-net PASS observed),
walk-forward windows undefined, redundant Q04, opaque Q09 "Seed".
Factory is OFF, all strategies will restart from Q00 once new spec lands.

---

## 1. What broke (evidence)

- **Q02 code** (`framework/scripts/p2_baseline.py:174-188`) checks only
  `summary.result == "PASS"` AND `trades >= min_trades`. **No profit factor,
  no drawdown, no profitability check.** That's why we observed:
  - GBPUSD Q03 PASS with net = −$4,039.38, PF = 0.16, 8 trades
  - Zero-trade / zero-profit rows passing
- **Q05 Vault page** lists fold count + embargo but leaves window sizes
  and regime thresholds as "TBD".
- **Q04 Cross-Sectional** duplicates Q03's "robustness" intent without
  adding new evidence.
- **Davey criteria missing in code**: only `pbo_calculator.py` survives.
  Chopping Block, Edge Decay, Runs Test, Seasonal, Regime gates do not exist.
- **Stress collapsed**: original had two stages (MEDIUM + HARSH with
  concrete slippage/spread/commission/rejection params); current has one
  vague "Calibrated Stress".
- **Commission gate gone**: original Phase 04 explicitly tested $7/lot
  round-trip ECN. Current pipeline does not gate on commission.

---

## 2. Proposed topology — 14 phases (Q00 → Q13)

Naming hard rule: Qxx everywhere on user surfaces. Legacy P-keys stay
in storage only.

| Qxx | Name | Owner | Data window | Hard PASS criterion |
|---|---|---|---|---|
| **Q00** | Research Intake | OWNER | n/a | R1 source ∧ R2 mechanical ∧ R3 data available ∧ R4 no-ML |
| **Q01** | Build & Spec | Codex | n/a | `.ex5` compiles · smoke ≥1 trade · spec doc with strategy logic + parameters + universe + expected behaviour |
| **Q02** | Baseline Screening | Pipeline-Op | **2017-01-01 → 2022-12-31** (IS) | **PF > 1.30** ∧ **Trades > 200** ∧ **DD < 12%** (per symbol) — survivors advance per-symbol |
| **Q03** | Parameter Sweep | Pipeline-Op | 2017-01-01 → 2022-12-31 (IS) | ≥50% of grid configs are profitable AND plateau width ≥ 3 contiguous configs — use plateau-median params, not best |
| **Q04** | Walk-Forward + Commission | Pipeline-Op | Anchored expanding, **3 folds × 12mo OOS: 2023, 2024, 2025** | All 3 folds PF > 1.0 with $7/lot ECN commission applied · DEV→HO embargo clean. (New full fold auto-adds after 2026 closes.) |
| **Q05** | Stress MEDIUM | Pipeline-Op | Full history 2017→present | Slip +2 pips · spread × 2 · **commission × 2 baseline** → PF > 1.0, DD < 15% |
| **Q06** | Stress HARSH | Pipeline-Op | Full history | Slip 5 pips · spread × 3 · **commission × 3 baseline** · **10% random trade rejection** → PF > 1.0, DD < 15% |
| **Q07** | Multi-Seed | Pipeline-Op | Full history | 5 seeds (**42, 17, 99, 7, 2026**) · PF variance across seeds < 20% · no single seed PF < 1.0 |
| **Q08** | Davey Statistical Validation | Pipeline-Op | Full history | All 10 Davey sub-gates: see §3 |
| **Q09** | News Impact Mode | Pipeline-Op (default) / OWNER override | Full history × 7 news modes | **Default Mode 3** auto-applied; report surfaces all 7 modes; OWNER override path from EA detail page |
| **Q10** | Full-History Confirmation Backtest | Pipeline-Op | **Full available history per symbol with chosen news mode** | PF > 1.0 ∧ DD < 15% on the full-history canonical run. **This is the closing per-(EA, symbol) verdict — PASS means portfolio-ready on this symbol.** |
| **Q11** | Portfolio Construction | OWNER | Across all Q10 survivors | Family-cap 3 per edge type · symbol-cap 2 per instrument · pairwise \|r\| < 0.5 · target 10-15 EAs |
| **Q12** | Operational Readiness | OWNER | n/a | Compile proof · setfile audit (symbol, magic, risk mode) · symbol suffix check (backtest .DWX vs live) · binary timestamp matches source · DXZ Live account routing OK |
| **Q13** | Live Burn-In on DXZ Live | OWNER | **DarwinexZero Live account**, T_Live terminal, 14 days | Min-lot per trade · Myfxbook monitoring · KS-test kill-switch · T_Live AutoTrading toggle = OWNER + Claude only. The portfolio runs on the actual DXZ Live target — this is where we see how it performs outside our test environment. |

**Changes vs current 15-phase Vault:**
- **Dropped:** Q04 Cross-Sectional (redundant with Q03), Q07 Calibrated Noise (folded into Q05/Q06 stress as jitter dimensions), Q08 Crisis Slices (folded into Q08 Davey Regime sub-gate).
- **Kept new from current vault:** Q00 Research Intake, Q09 News Mode Selection.
- **Restored from website:** Q02 hard PF/Trades/DD thresholds, Q04 commission gate, Q05/Q06 two-stage stress with concrete params, Q07 specific 5 seeds + variance gate, Q08 full Davey suite.
- **Defined:** Q04 anchored fold windows, all data windows per phase.

---

## 3. Q08 Davey Statistical Validation — sub-gates (all must PASS)

| Sub | Name | Criterion | Status |
|---|---|---|---|
| 8.1 | Correlation vs existing portfolio | Pairwise \|r\| < 0.50 against current Q12 survivors | NEW code |
| 8.2 | Deflated Sharpe + MC + FDR | DSR p < 0.05 (Tier 1) OR Benjamini-Hochberg FDR pass (Tier 2) | NEW code |
| 8.3 | Tail Dependence | Correlation under top/bottom 5% market moves ≤ baseline | NEW code |
| 8.4 | Seasonal | All 12 months net profit > 0 | NEW code |
| 8.5 | Neighborhood Stability | ±10% parameter perturbation: PF stays > 1.0, DD < 1.5× baseline | NEW code |
| 8.6 | **Chopping Block (Davey)** | Remove top 5% trades → PF > 1.0 | NEW code |
| 8.7 | PBO (CSCV) | PBO < 0.40 | `pbo_calculator.py` exists, wire up |
| 8.8 | Edge Decay | Rolling 12m PF decline < 40% over full history | NEW code |
| 8.9 | Runs Test (Wald-Wolfowitz) | p > 0.05 on win/loss sequence · top-20% months ≤ 70% of profit | NEW code |
| 8.10 | Regime + Crisis | Profitable in low/normal/high ATR regimes AND survives COVID-2020, SNB-2015, Ukraine-2022 slices (PF > 0.8 each — slices count as soft, not hard) | NEW code; absorbs old Q08 |

---

## 4. Migration plan

1. **OWNER reviews this proposal** — APPROVED 2026-05-23.
2. **Vault rewrite** — update `_HOME.md` + the 14 Q-pages + Pipeline Overview. Delete Q04 Cross-Sectional / Q07 Calibrated Noise / Q08 Crisis Slices old pages. Add new Q10 Full-History Confirmation page. Shift Q11/Q12/Q13 by one.
3. **Code rewrite** — gate-by-gate, starting with Q02 (foundation):
   - Rewrite verdict logic in `framework/scripts/p<N>_*.py` with strict criteria
   - Wire `pbo_calculator.py` and add 9 new Davey sub-gate modules (Chopping Block, Edge Decay, Runs Test, Seasonal, Regime, Tail Dep, DSR, Neighborhood, Correlation)
   - New Q04 commission gate with $7/lot ECN
   - New Q05/Q06 two-stage stress drivers with multiplier-of-baseline commission
   - New Q10 full-history confirmation runner
   - Update `phase_ids.py` from 15 P-keys to 14 Q-keys
4. **Data wipe** — backup `farm_state.sqlite` + `D:/QM/reports/` to `D:/QM/archive/2026-05-23-pipeline-reset/`, then `DELETE FROM work_items`. Reset `agent_tasks` to feed Q01 builds. Keep: cards in `cards_approved/`, EA `.ex5` binaries, `magic_numbers.csv`.
5. **Dashboard alignment** — only after gate code stabilises, rewrite dashboard to:
   - Hide parameter-sweep variant rows (show "N tried, X profitable, best per symbol")
   - Show backtest time window in every phase header
   - Remove the latest-vs-fallback-stats logic (OWNER: no fallbacks)
   - Re-link MT5 reports correctly (the missing-graphs bug)
6. **Restart** — first source extraction → Codex builds → pipeline runs Q01→Q13 autonomously per parallel-within-source rule.

---

## 5. Resolved design decisions (OWNER call 2026-05-23)

1. **Q04 walk-forward windows** — Anchored expanding-window, **12-month OOS per fold**. **3 clean folds: OOS 2023, OOS 2024, OOS 2025.** 2025 is the latest closed year — no partial 2026 fold (informational or otherwise). New full fold auto-adds after 2026 closes (Jan 2027). PASS = all 3 folds profitable (PF > 1.0 commission-adjusted).
2. **Q05/Q06 stress commission** — **Multipliers of baseline** per instrument. MED = 2× baseline, HARSH = 3× baseline. Baseline lives in `framework/registry/tester_defaults.json` per instrument; survives broker schedule changes.
3. **Q08.10 Crisis slices** — **Soft, informational.** Surfaced in EA detail page per applicable slice; never blocks Q09 promotion. Hard regime coverage is enforced by Q08.10 Regime (3 ATR regimes) only.
4. **Q09 News Mode** — **Default Mode 3** (pause 30min pre + 30min post). Pipeline auto-applies. All 7 modes reported; OWNER can override per EA from the EA detail page. No pipeline stall.
5. **Q12 Live Burn-In** — **Skip demo; straight to funded prop, min-lot, 14 days** on dedicated VPS, Myfxbook monitoring, KS-test kill-switch. T_Live AutoTrading toggle remains OWNER+Claude-only (Hard Rule).
6. **HR16** — **Parallel within source, sequential across sources.** All EAs from one approved card-batch enter Q01 together and race through gates. Next source unlocks only after the previous source's last EA exits the pipeline (PASS or terminal FAIL). Research throttle (≥ 5 ready cards) remains.

7. **Research-extraction workflow (OWNER call 2026-05-23):** Per source — Gemini/Claude extracts ALL mechanical strategies from the paper as Strategy Cards in one pass, then Codex programs every EA, then the deterministic orchestration runs Q01→Q13 autonomously. Token usage is bounded to the research-extraction step; everything downstream is Codex + pipeline runners. This is what keeps the AI burn rate predictable.

8. **Q10 Full-History Confirmation (NEW PHASE):** When Q09 has decided the news mode for an EA, the pipeline runs a single canonical backtest per (EA, symbol) over the full available history with the chosen news mode applied. PASS criterion: PF > 1.0 AND DD < 15%. This is THE closing per-(EA, symbol) verdict — only PASS rows enter Q11 portfolio analysis. OWNER call: "Das ist der Abschluss und der EA ist auf dem Symbol tatsächlich bereit um eine Portfolio Analyse zu machen."

9. **Q13 Live target = DarwinexZero Live account.** The portfolio runs on the existing T_Live terminal against the DXZ Live €100k account. This is where we see how it performs outside our test environment. No demo, no separate prop firm — DXZ Live is the goal.

---

## 6. What this proposal does NOT cover

- MT5-report missing-graphs bug — separate debug task once dashboard work resumes.
- Strategy-card schema changes (Q01 spec doc requirement) — separate template doc.
- Codex/Claude/Gemini routing changes — none expected; gates run automated, OWNER decides Q00/Q09/Q10/Q11/Q12.
