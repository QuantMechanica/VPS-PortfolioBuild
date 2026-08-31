# QM5_41253_gbpusd-weekend-tail-fade - Strategy Spec

**EA ID:** QM5_41253

**Slug:** gbpusd-weekend-tail-fade

**Strategy ID:** AI-CODEX-GBP-WGAP-TAIL-20260831_S01

**Source:** AI-CODEX-GBP-WGAP-TAIL-20260831

**Author of this spec:** Codex

**Last revised:** 2026-08-31

## 1. Strategy Logic

On the first executable tick of a genuine GBPUSD.DWX broker-Monday D1 bar,
the EA consumes the week and compares the current Monday open versus the
immediately prior Friday close. It reconstructs exactly 52 earlier completed
Friday-to-Monday log gaps, sorts them, buys only below sorted index 5, and
sells only above sorted index 46. Both comparisons are strict, so boundary
ties and observations inside the empirical tails stay flat.

Each accepted signal opens one contrarian market position with a frozen
3.5 times completed-D1 ATR(20) hard stop and no target. Framework Friday close
at broker hour 21 is the normal exit; seven calendar days and a later broker
week are repair exits. The consumed-week state is persisted before history,
arithmetic, spread, ATR, news, sizing, margin, or order checks, so no failed
gate can create a same-week retry.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_prior_gap_count | 52 | locked | exact prior weekend-gap sample |
| strategy_lower_index | 5 | locked | sixth-smallest order statistic |
| strategy_upper_index | 46 | locked | sixth-largest order statistic |
| strategy_history_bars | 900 | locked | maximum D1 bars read per decision |
| strategy_entry_grace_minutes | 180 | locked | elapsed Monday-open entry grace |
| strategy_atr_period_d1 | 20 | locked | completed-D1 stop estimator |
| strategy_atr_sl_mult | 3.5 | locked | frozen ATR hard-stop multiple |
| strategy_max_hold_days | 7 | locked | stale-survivor repair ceiling |
| strategy_max_spread_points | 50 | locked | entry-only spread ceiling |
| strategy_deviation_points | 20 | locked | central market-order deviation contract |

There is one locked Q02 baseline and no optimization surface.

## 3. Symbol Universe

Designed for:

- GBPUSD.DWX - the approved, peer-reviewed-source FX carrier and exact slot-0
  registry symbol.

Explicitly not for:

- Every other .DWX symbol - the empirical distribution, card identity, and
  source membership are GBPUSD-specific; transport requires a new card.

The host and traded symbol are exact GBPUSD.DWX, slot 0, magic 412530000.
No companion, hedge, conversion, signal, or external runtime symbol is used.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | one QM_IsNewBar call on the host D1 chart |
| ATR timeframe | completed D1, shift 1 |

The current Monday bar supplies only its fixed open. All 52 empirical
observations are earlier completed Monday bars paired with their immediately
preceding completed Friday bars.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 8-11; at least 5 per full scored post-warm-up year |
| Typical hold time | Monday entry through Friday 21:00 broker time |
| Expected drawdown profile | sparse high-risk contrarian sleeve; card prior 30% |
| Regime preference | weekend overreaction followed by weekly mean reversion |
| Win rate target (qualitative) | unclaimed; Q02 must falsify the baseline |

Zero positions, a sub-five full scored year, or nonpositive governed economics
retires the unchanged baseline. The expected activity is a rank-density prior,
not a performance or decorrelation claim.

## 6. Source Citation

**Source ID:** AI-CODEX-GBP-WGAP-TAIL-20260831

**Source type:** governed AI synthesis supported by a complete-read
peer-reviewed paper.

**Pointer:** strategy-seeds/sources/AI-CODEX-GBP-WGAP-TAIL-20260831/source.md

**Supporting record:** Dao, McGroarty, and Urquhart (2016), A calendar effect:
weekend overreaction (and subsequent reversal) in spot FX rates, Journal of
Multinational Financial Management 37-38, 158-167,
DOI 10.1016/j.mulfin.2016.11.001.

**R1-R4 verdict (Q00):** R1 PASS_WITH_AI_SYNTHESIS_BOUNDARY and R2-R4 PASS per
strategy-seeds/cards/approved/QM5_41253_gbpusd-weekend-tail-fade_card.md.
The 52-gap window and 10% indexes are an untested, pre-result QM translation.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by QM_FrameworkInit. This build creates
only the fixed-risk backtest preset and authorizes no live preset or action.

## Framework Alignment

- no_trade: exact identity, host, D1 period, fixed-risk/news/Friday/stress
  contract, locked parameters, attempt state, bounded history, quote, spread,
  ATR, and open-position guards.
- trade_entry: current weekend gap, exact 52-gap finite order statistics,
  strict contrarian tails, valid market quote, and frozen broker hard stop.
- trade_management: malformed-position repair, later-week flattening, and
  seven-calendar-day stale repair.
- trade_close: framework Friday close, V5 close helper, server-side stop, and
  kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-31 | Initial build from approved card | farm task 189e41dd-940e-428e-979f-6287a1bdbea6 |
