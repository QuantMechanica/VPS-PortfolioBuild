# YouTube strategy synthesis — Batch-3 (rigorous systematic-quant channels)

**Date:** 2026-07-01 · **Author:** Claude (synthesis) · **Source video analysis:** agy (batch-3)
**Raw input:** `D:\QM\strategy_farm\research_charters\CHANNELS_BATCH3_STRATEGIES_2026-07-01.md`
**Predecessor:** `docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md` (Balke/Davey/batch-2)

Batch-3 targeted the *rigorous* quant sources (Quantified Strategies, Robot Wealth, Better
System Trader, Build Alpha, Financial Wisdom, Darwinex, Price Action Lab, Algotrading101) and
was **far higher-yield than batch-2** — as expected: structured systematic sources beat retail
channels. All recommended candidates are single-position, hard-stop / time-exit designs (no
grid → DL-081 not triggered). Provenance: rules ≠ copyright — mechanize the logic only.

---

## TIER 1 — new card candidates (best-first)

### T1. Turn-of-the-Month (Ultimo effect) — index seasonal · **TOP NEW PICK**
Enter long at the **close of the 5th-last trading day** of the month; exit at the **close of the
3rd trading day** of the next month; gate on **price > 200 SMA**. ~12 tr/yr, daily bars.
Structural driver: month-end fund inflows / salary / retirement contributions / window
dressing. **Mechanizable as-is.** *Why it earns a slot:* a pure **seasonal calendar clock** —
maximally orthogonal to our momentum/breakout/MR book (should be near-zero corr), lowest-freq,
cost-robust on index. **→ carded as the 2nd demonstrator (QM5_12847, SP500.DWX, force_build).**

### T2. Short-term index mean-reversion FAMILY (Quantified Strategies)
A cluster of cheap, cost-robust, index-MR edges (all long-only, >200 SMA, daily, MOC):
- **Connors RSI(2)**: RSI(2)<10 entry, exit RSI(2)>70 or close>SMA(5). (We already run a
  cum-RSI2 on commodity — 12567; the *index* version is the cost-robust sibling.)
- **IBS Pullback**: IBS<0.3 + pullback from 10-day high; exit close>yesterday-high.
- **3-Days-Down Overnight**: 3 consecutive down closes → buy MOC, exit next close.
These are variations on one theme (oversold-index snapback). Recommend carding **one** as a
family representative *after* the Turnaround-Tuesday demonstrator (12836) reports — they're
correlated to each other and to 12836's weekly-MR, so we want the corr read first.

### T3. Corroborations of the already-carded slate (no new work — confidence boosters)
- **Turnaround Tuesday (QS canonical)** → already folded into **12836** (Monday<Friday close +
  Monday-volume filter; the documented spec, better than my first draft).
- **Algotrading101 Donchian breakout** (20-ch + 2.5×ATR + 200-SMA slope) → essentially **12844**
  (commodity-trend-crude). Independent corroboration of the mechanic.
- **Davey "Show Me the Money"** (BB(20,2) breakout, 3-day hold or 2×ATR trail, 200-SMA) → same
  breakout family as 12700/12832/12844.

---

## TIER 2 — hold / needs-design / not-viable
- **Robot Wealth Kalman pairs** (cointegration, dynamic hedge ratio via Kalman filter) —
  needs-design (recursive state-space). We already have a cross-asset cointegration finding
  (AUDUSD~NZDUSD, OOS Sharpe 1.29). Kalman is the more advanced realization — revisit if we
  pursue stat-arb.
- **Bandy Signal-to-Noise regime filter** (dual-state trend/MR switch) — needs-design; an
  interesting *regime overlay* concept more than a standalone EA.
- **Build Alpha opening-range breakout** (ES/NQ/GC, OR 9:30–10:00 ET, exit-on-close/1.5×ATR) —
  mechanizable, but overlaps our existing ORB work (London-ORB family). Card only if it adds.
- **Financial Wisdom BB-MR** (lower-band cross + reversal, exit mid-band/5d, BB-width filter) —
  mechanizable; a generic MR, lower novelty than the QS family.
- **Price Action Lab parameter-less 3-day pattern** (Up,Down,Down+low-IBS → buy open, 1% target)
  — mechanizable, parameter-less (anti-overfit appeal); a variation of the QS index-MR family.

### NOT VIABLE for us
- **Robot Wealth FX Carry** — requires an interest-rate/swap data feed; our .DWX symbols apply
  **$0 swap** and we've DEFERRED swap injection ([[reference_swap_ftmo_dxz_5pers_2026-06-09]]).
  A carry edge is *entirely* the swap — un-backtestable for us until swap data lands. Skip.

---

## Deployment-layer finding (NOT a card): Darwinex D-Leverage / VaR sizing
Darwinex/DXZ scores accounts on **risk-standardized** performance (the Risk Engine normalizes
leverage). Their guidance: size to a **target monthly VaR ~6.5% (95% CL)**, keeping VaR in a
**3.25–6.5%** band, volatility lookback ~45 days. This is directly relevant to **our live
sizing + portfolio VaR targeting on DXZ** — it argues for a VaR-targeted `RISK_PERCENT` at the
book level rather than flat per-sleeve %. Feed into the portfolio/live-sizing layer
([[project_qm_portfolio_layer_status_2026-06-21]], [[project_qm_book_sizing_dxz_ftmo_2026-06-30]]),
not a strategy card. Worth a focused evaluation before live deployment.

---

## Methodology — corroborates the Davey adoptions with EXACT thresholds
Batch-3 independently produced concrete gate thresholds that **match and sharpen** the Davey Part-C
adoptions (`YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md`). Mapped to OUR pipeline (⚠️ agy invented its
own gate-numbering Q04–Q09 that does NOT match ours — our Qxx naming stands; only the thresholds
transfer):

| Technique | Threshold (batch-3) | Our gate |
|---|---|---|
| Walk-Forward Efficiency | OOS/IS annualized ≥ **50%** (PF-ratio ≥ 60%), ≥5 OOS windows | Q04 |
| Monte-Carlo trade-shuffle | 1000×; **95th-pct MaxDD ≤ 10%** (or ≤2× historical); P(net loss) < 1% | Q08 (have the stream) |
| Noise permutation | ±0.5×ATR on OHLC, 100 trials; median profit degrade ≤ **30%**; ≥95% runs profitable | Q05–Q07 stress |
| Multi-market baseline | PF > 1.0 on **≥2 of 3** adjacent instruments, no optimization | card-promotion / Q04 |
| Correlation cap | daily-returns **R ≤ 0.5** vs any single live sleeve (Davey said <0.3 — use the stricter 0.3) | Q11/DL-064 |
| Position cap | **1%** fixed-fractional; grid/martingale basket ≤1% + hard stop | live/DL-081 |
| Incubation | ≥ **90 days** or 100 trades; live within 1.5σ of backtest; live DD ≤ 1.2× MC-95th | Q12–Q14 |

**Net unchanged from the Davey read:** stricter *validation*, simpler *design*, nothing softened.
This is now corroborated by two independent source-sets → strong case to route the gate-wiring
(WFE at Q04, MC-95th sizing at Q08, corr cap at Q11) to Codex. Keep OUR corr threshold at the
stricter **0.3** (Davey), not batch-3's 0.5.

---

## Recommended sequencing
1. (done) 12836 Turnaround-Tuesday demonstrator upgraded to the QS canonical spec.
2. (done) 12847 Turn-of-the-Month = 2nd demonstrator (force_build).
3. After both demonstrators report Q02/Q04: card ONE short-term index-MR representative (T2).
4. Route the methodology gate-wiring to Codex (WFE/MC-sizing/corr-0.3) — the highest-ROI,
   ~zero-backtest-cost lever, now doubly corroborated.
5. Evaluate the Darwinex VaR-sizing framework for the live/book layer before deployment.
