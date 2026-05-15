---
source_id: SRC11
tier: T1_5_drive_quantmechanica_v4_archive
parent_issue: QUA-1604
lane: 4_of_4
status: intake_complete_one_candidate_proposed
authored-by: Research Agent
date-checked: 2026-05-15
source-path: G:\My Drive\QuantMechanica
source-name: Legacy local QuantMechanica V4 project inventory
prior-survey: strategy-seeds/sources/tier1_5_company_research_survey.md (QUA-423, 2026-04-28)
---

# SRC11 — Legacy local QuantMechanica V4 inventory (Lane 4 of QUA-1604)

## 1. Source identification

- **Source:** `G:\My Drive\QuantMechanica\` — the legacy QM V4-era project drive.
- **Date checked:** 2026-05-15
- **Tier:** T1.5 (per `SOURCE_QUEUE.md` tier_schema — Drive QuantMechanica V4 archive, registered as Tier 1.5 under QUA-416 / QUA-400 Rule 6)
- **Issue:** [QUA-1604](/QUA/issues/QUA-1604) Lane 4

## 2. Prior survey reuse

A T1.5 survey of the highest-signal sub-tree (`Company\Research\strategies\`) was completed on 2026-04-28 under [QUA-423](/QUA/issues/QUA-423) and is committed at `strategy-seeds/sources/tier1_5_company_research_survey.md`. That survey indexes **five** V4 strategy concept docs with their original primary citations:

| # | V4 doc | Primary source (the citation a V5 card MUST use) | V5 fit rating |
|---|---|---|---|
| 1 | `ath-breakout-atr-trail.md` | Wilcox & Crittenden (2005). *Does Trend Following Work on Stocks?* Blackstar Funds LLC. | **YES** |
| 2 | `good-carry-bad-carry.md` | Bekaert & Panayotov (2018/2019). *Good Carry, Bad Carry.* JFQA. SSRN 2516907. | MAYBE — paper requires options-implied skew (not MT5-native); V4 proxy degrades thesis |
| 3 | `modernising-turtle-trading.md` | Faith, C. M. (2007). *Way of the Turtle.* McGraw-Hill. ISBN 978-0-07-148664-4. | YES |
| 4 | `seasonality-trend-mr-bitcoin.md` | Padysak & Vojtko (2022). SSRN 4081000. | MAYBE — paper is BTC-only; V4 transfers to XAUUSD/indices |
| 5 | `two-regime-trend-following.md` | Zakamulin & Giner (2023). SSRN 4497739. | YES with overlap-audit caveat |

All five carry full primary-source citations (no `BLOCKED_NO_PRIMARY_SOURCE`). Per QUA-1604: *"stage one candidate only after source notes exist"* — source notes pre-exist via the QUA-423 survey, so this Lane 4 intake can proceed directly to candidate staging.

## 3. Other sub-trees inspected today

To confirm the QUA-423 survey is still the highest-signal slice and no other directly-promotable corpus has materialized since 2026-04-28:

| Sub-tree | State | Disposition |
|---|---|---|
| `G:\My Drive\QuantMechanica\Company\Research\strategies\` | 5 V4 docs (unchanged) | **Use this — staged via QUA-423 survey.** |
| `G:\My Drive\QuantMechanica\MT5 Marketplace\` | 4 SM_XXX subdirs (SM_124, SM_128, SM_137, SM_138) — all contain only `Images\` subdirs, no code/setfiles/docs | SKIP — empty skeletons; nothing to extract |
| `G:\My Drive\QuantMechanica\Include\` | `FTMO\` only | SKIP — prop-firm rules folder, not strategy material |
| `G:\My Drive\QuantMechanica\tools\` | (empty) | SKIP |
| `G:\My Drive\QuantMechanica\Ebook\PDF resources\` | 59 PDFs | OUT-OF-SCOPE for this lane — already governed by `SOURCE_QUEUE.md` T1 layer; QUA-1604 Lane 4 is "old EAs/setfiles/books one at a time" and books are covered under the SRC01–SRC06 T1 stream |
| `G:\My Drive\QuantMechanica\Backups\` | Backup archive | SKIP — not source material |
| `G:\My Drive\QuantMechanica\Website\strategy-database\strategies\` | Per QUA-423 §"Next steps" still on hold | DEFER — separate T1.5 batch, not in this lane's intake budget |

Conclusion: the QUA-423-surveyed `Company\Research\strategies\` is the highest-signal-per-byte slice in the inventory, and it remains the right candidate pool.

## 4. Candidate proposed for G0

### SRC11_S01 — ATH Breakout + ATR Trailing Stop (Trend Following) — primary source Wilcox & Crittenden 2005

**Source citation (primary — the citation the V5 card MUST use):**
> Wilcox, C., & Crittenden, E. (November 2005). *Does Trend Following Work on Stocks?* Blackstar Funds LLC. Paper PDF: https://paperswithbacktest.com/api/paper/does-trend-following-work-on-stocks/pdf — Editorial: https://paperswithbacktest.com/strategies/does-trend-following-work-on-stocks

**Inspiration trail (NOT to be cited as primary):**
> Local V4 concept doc: `G:\My Drive\QuantMechanica\Company\Research\strategies\ath-breakout-atr-trail.md` — surveyed under [QUA-423](/QUA/issues/QUA-423). Per the T1.5 binding rule, this doc is *inspiration only*; the V5 card cites the Wilcox & Crittenden paper as primary, not the V4 doc. The V4 doc is acknowledged in the card's "inspiration trail" / `prior-art:` field.

**Mechanical-rules screen (V5 G0 pre-check):**

| Element | Rule (from primary source as adapted in V4 doc) | Status |
|---|---|---|
| Instrument universe | Liquid Darwinex D1 macro: XAUUSD, GDAXI, NDX, WS30, XTIUSD, USD-bloc FX majors. Cross-rates likely fail (no drift) — diagnostic, not problem | ✓ named with explicit failure-set hypothesis |
| Timeframe | D1 | ✓ named |
| Long entry | `Close[t] >= max(Close[t-EntryATH_N .. t-1])` AND no position open → enter long at `Open[t+1]` | ✓ deterministic |
| Short entry | Symmetric: `Close[t] <= min(Close[t-EntryATH_N .. t-1])` → enter short at `Open[t+1]` | ✓ deterministic |
| Stop loss (primary, trailing) | Long: `trail = max(trail, High_since_entry - ATR(TrailATR_Period)_at_current_bar * TrailATR_Mult)`; close at `Open[t+1]` if `Low[t] <= trail`. ATR recomputed each bar (Blackstar-faithful). Short: symmetric. | ✓ deterministic |
| Stop loss (hard safety) | `entry_price ± ATR(TrailATR_Period)[entry] * HardStopATRMult` (ATR frozen at entry). Catastrophic-gap backstop. | ✓ deterministic |
| Take profit | NONE — trail-only is load-bearing for the heavy-tail payoff thesis | ✓ deterministic (and explicitly justified — Blackstar's central insight) |
| Pyramiding | NONE (one position per symbol) | ✓ |
| Time-stop | NONE | ✓ |
| Default parameters | `EntryATH_N=252`, `TrailATR_Mult=10.0`, `TrailATR_Period=42`, `HardStopATRMult=15.0` | ✓ all explicit, all Blackstar-original or pragmatic-D1-substitution |

**Author performance claim (from primary source Wilcox & Crittenden 2005):**
> *"buy on a breakout above the all-time-high close, exit on a wide volatility-scaled trailing stop ... produced a long-term positive-expectancy distribution with heavy positive skew"* (paraphrased from study)
>
> Critical: the V4 doc and V5 card must NEVER paraphrase the study's specific U.S. equity 1983–2004 backtest numbers as predictions for V5 universe. The thesis is **method positive-expectancy**, not a transferable PF/Sharpe number. Per V5 doctrine, P2 produces V5's own evidence.

**V5 flags:**
- `TREND_FOLLOWING` — V5 supports this family
- `D1_MULTI_INSTRUMENT` — D1 is in V5 default basket
- `LONG_SHORT_SYMMETRIC` — short-leg ablation required at P3 (V4 doc pre-registers)
- `HEAVY_TAIL_TRADE_DISTRIBUTION` — most trades lose; few large winners pay. P2/P3.5 must measure trade-distribution skew, not just hit-rate.
- `WIDE_STOP_SIZING_RISK` — 10×ATR(42) stop on D1 may produce sub-minLot sizes on volatile symbols at fixed-risk. Pre-flagged for P1 smoke check.
- No ML / SMC / Elliott / Gann.

**Differentiation from existing QM cards:**
- vs. Chan `chan-at-ts-mom-fut`, `chan-at-xs-mom-fut`: those are time-series / cross-sectional momentum on futures with monthly rebalance; this card is daily-bar N-period-high BREAKOUT with ATR trail — entry trigger and exit logic are different.
- vs. Lien `lien-20day-breakout`: Lien is a 20-day donchian (short lookback) on FX with fixed stop; this is a 252-day ATH (long lookback) with ATR-recomputed trail. Different lookback regime and different exit mechanic.
- vs. Davey `davey-es-breakout`: Davey is ES-specific short-lookback breakout; this is multi-instrument long-lookback ATH.
- The V4 doc pre-registers a P3.5 head-to-head against `lien-20day-breakout` and the Turtle 55-day breakout (referenced QUAA-238). This is the binding overlap audit.

**Rule-complete:** YES (no ambiguity to resolve at G0).

## 5. Lane disposition

- **Sub-trees inspected:** 8 (table above)
- **Candidates available from pre-surveyed pool:** 3 YES + 2 MAYBE
- **Candidates forwarded to G0 this lane:** 1 (SRC11_S01 — strongest YES; cleanest primary citation; mechanical concept fully exposed)
- **Other 4 V4 docs:** held in reserve; CEO can promote any of them on a follow-up SRC after SRC11_S01 lands at G0.

**Why pick SRC11_S01 over the other YES candidates first:**
- Turtle (`modernising-turtle-trading.md`) — primary source is a book + 1983 private training material, well-known but already extensively replicated in retail trading literature; V5 differentiation requires careful overlap audit against `lien-20day-breakout` and similar.
- Two-Regime (`two-regime-trend-following.md`) — requires implementing a 2-state Gaussian HMM regime detector, which is a non-trivial framework addition; better to stage after framework supports HMM.
- ATH Breakout — primary source is a peer-of-academic 2005 study with explicit return-distribution-skew thesis; the framework support needed is already there (`iATR`, `CopyClose`, ArrayMax/Min); zero new framework features needed. Lowest friction to G0 → build → P1/P2.

**Lane 4 status:** COMPLETE.

## 6. Next-lane gate

Lane 4 is the final lane of QUA-1604.

Lane 4 produces: **1 candidate (SRC11_S01) + evidence-backed skip of 7 other sub-trees + explicit reserve list of 4 additional pre-surveyed candidates available for future SRC slots.**

QUA-1604 four-lane sequential intake is complete on this heartbeat:
- Lane 1 (SRC08 ForexFactory): 1 candidate (SRC08_S01)
- Lane 2 (SRC09 BabyPips): 1 candidate (SRC09_S01)
- Lane 3 (SRC10 MQL5 Market): 1 candidate (SRC10_S01)
- Lane 4 (SRC11 Legacy local): 1 candidate (SRC11_S01)

Total: 4 candidates surfaced — within the per-lane "at most 1-2" cap and within reasonable parent-issue total budget. Awaiting CEO ratification before any G0 child issue is opened.
