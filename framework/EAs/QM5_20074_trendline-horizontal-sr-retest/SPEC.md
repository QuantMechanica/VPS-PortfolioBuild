# QM5_20074_trendline-horizontal-sr-retest - Strategy Spec

**EA ID:** QM5_20074
**Slug:** `trendline-horizontal-sr-retest`
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (ForexFactory Trendline-Trader cluster, horizontal-S/R variant)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

This H1 EA identifies HORIZONTAL support/resistance levels (zero slope) from
confirmed 3-bar-fractal swing prices over the last 200 bars: the sorted swing
highs (or lows) are partitioned into clusters whose price span is at most
0.5*ATR(14), and any cluster with at least 3 members becomes a level at the
cluster mean. A level is broken when one closed bar closes beyond it by at least
0.3*ATR while the prior bar had not yet crossed that threshold (a fresh cross).
After a break, the EA watches up to 20 bars for a retest bar that wicks back to
the broken level (within 0.1*ATR) and closes back on the break side; it then
enters a market order at the open of the next bar. It goes long on the retest of
a broken resistance and short on the retest of a broken support. Positions exit
on a fixed RR=2.0 take-profit, an opposite-side S/R break against the position,
or a 50-bar time-stop, whichever comes first. This is the horizontal-cluster
sibling of QM5_20076 (diagonal sloped line) and shares no level-construction
code with it.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fractal_k` | 3 | 2-4 | Swing fractal half-width (bars each side). |
| `strategy_lookback_bars` | 200 | fixed | Scan window for swing clustering (bars). |
| `strategy_atr_period` | 14 | fixed | ATR period (H1) for cluster/break/retest/stop scaling. |
| `strategy_min_swings` | 3 | 2-4 | Minimum swing-cluster count to declare a level. |
| `strategy_cluster_atr_frac` | 0.5 | 0.3-0.7 | Cluster-width tolerance as a fraction of ATR. |
| `strategy_break_atr_frac` | 0.3 | 0.2-0.5 | Close must break the level by this fraction of ATR. |
| `strategy_retest_atr_frac` | 0.1 | fixed | Retest touch tolerance as a fraction of ATR. |
| `strategy_sl_atr_frac` | 0.3 | 0.2-0.5 | SL buffer beyond the retest extreme, fraction of ATR. |
| `strategy_retest_bars` | 20 | 10-40 | Retest window (bars after the break). |
| `strategy_rr` | 2.0 | 1.5-3.0 | Reward:risk multiple for the take-profit. |
| `strategy_time_stop_bars` | 50 | fixed | Max-hold flatten horizon (~2 trading days). |
| `strategy_time_stop_enabled` | true | toggle | Enable the tertiary time-stop exit. |
| `strategy_opp_break_exit` | true | toggle | Enable the secondary opposite-side S/R break exit. |
| `strategy_spread_cap_pts` | 25 | fixed | Spread cap in points (blocks only a genuinely wide spread). |

## 3. Symbol Universe

**Designed for (registered in `magic_numbers.csv`):**
- `EURUSD.DWX` - liquid FX major with dense round-number S/R clusters, slot 0.
- `GBPUSD.DWX` - liquid FX major, clean horizontal levels, slot 1.
- `XAUUSD.DWX` - gold, strong horizontal support/resistance shelves, slot 2.
- `GDAXI.DWX` - DAX 40 index, option-strike S/R clustering, slot 3.
- `NDX.DWX` - Nasdaq 100 index, clean horizontal levels, slot 4.
- `WS30.DWX` - Dow 30 index, strong round-number S/R density, slot 5.

**Explicitly NOT for:**
- Persistently trending-without-consolidation instruments where flat S/R rarely
  forms; sloped structure is covered by the diagonal sibling QM5_20076.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (framework closed-bar gate; structural state advances once per closed H1 bar) |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 25; Q02 requires at least 5/year |
| Typical hold time | intraday-to-swing, up to 50 H1 bars (~2 trading days) |
| Expected drawdown profile | approximately 15% peak; clustered losses when levels fail to hold on retest |
| Regime preference | ranging / consolidating instruments that print repeated horizontal S/R |
| Win rate target (qualitative) | medium (RR=2.0 tolerates a sub-50% win rate) |

## 6. Source Citation

This EA was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** community forum cluster
**Pointer:** ForexFactory Trading Systems "Trendline Trader" cluster (horizontal
S/R break + retest variant); canonical approved card at
`artifacts/cards_approved/QM5_20074_trendline-horizontal-sr-retest.md`.
**R1-R4 verdict (Q00):** APPROVED. R1 lineage recorded and R2-R4 PASS per
`artifacts/cards_approved/QM5_20074_trendline-horizontal-sr-retest.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-11 | Initial build from card | 5fdad0a7-0719-4846-ba82-c13302374f37 |
