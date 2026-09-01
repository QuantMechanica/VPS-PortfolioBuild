# QM5_1257_lemishko-fx-cointpair - Strategy Spec

**EA ID:** QM5_1257

**Slug:** `lemishko-fx-cointpair`

**Source:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Last revised:** 2026-09-02

## 1. Strategy Logic

The selected logical basket binds pair slot 8 to `GBPUSD.DWX` and
`USDJPY.DWX`. Once per calendar month, the EA estimates an ordinary least
squares hedge relationship from 252 completed D1 closes. It admits the month
only when the residual passes the fixed ADF critical-value rule and has an
estimated half-life between 2 and 30 days. The intercept, beta, and monthly
qualification decision remain frozen until the next month.

On each completed H1 bar, the EA computes the frozen-beta residual z-score over
60 bars. It opens both legs as one package at an absolute z-score of 2.0 and
does not pyramid. It closes the package on the directional mean crossing, a
daily residual excursion of 3.5 standard deviations, or the 10-day time stop.
If either entry leg fails, the other leg is rolled back immediately.

This is structural, fixed-rule cointegration trading. It contains no machine
learning, grid, martingale, or intramonth parameter adaptation.

## 2. Parameters

| Parameter | Default | Contract |
|---|---:|---|
| `strategy_pair_slot` | `0` | Set to `8` by the selected logical-basket setfile. |
| `strategy_formation_days` | `252` | Completed D1 closes used for monthly OLS, ADF, and half-life estimates. |
| `strategy_zscore_h1_bars` | `60` | Completed H1 residual bars used for the entry/exit z-score. |
| `strategy_entry_z` | `2.0` | Absolute H1 z-score entry threshold. |
| `strategy_exit_z` | `0.0` | Directional mean-cross exit band. |
| `strategy_stop_daily_z` | `3.5` | Structural residual-stop threshold. |
| `strategy_coint_entry_p` | `0.05` | Fixed entry critical-value selector for the ADF statistic. |
| `strategy_coint_exit_p` | `0.10` | Legacy compatibility input; the current source declares but does not consume it. |
| `strategy_half_life_min` | `2.0` | Minimum admitted residual half-life in days. |
| `strategy_half_life_max` | `30.0` | Maximum admitted residual half-life in days. |
| `strategy_max_hold_days` | `10` | Package time stop. |
| `strategy_r_stop` | `1.5` | Card-required combined-pair risk-stop multiplier; the current source declares but does not enforce it. |
| `strategy_max_leg_weight` | `0.70` | Maximum gross-notional share assigned to either leg. |
| `strategy_atr_period` | `14` | D1 ATR period used for per-leg protective stops and sizing. |
| `strategy_atr_stop_mult` | `3.0` | D1 ATR stop multiplier. |
| `strategy_max_spread_cost_frac` | `0.20` | Maximum transaction-cost share of expected residual reversion. |
| `strategy_deviation_points` | `20` | Maximum market-order deviation in points. |

## 3. Symbol Universe

The approved EA enumerates the seven major-FX `.DWX` symbols into 21 fixed
pair slots. The active evidence-bound basket in this repository is only:

- host / first leg: `GBPUSD.DWX`;
- companion leg: `USDJPY.DWX`;
- logical symbol: `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`;
- pair slot: `8` (magic slots `8` and `29`).

The current Q03 row does not authorize substituting another pair, changing the
hedge method, or adding a rescue filter.

## 4. Timeframe

| Function | Timeframe |
|---|---|
| Monthly OLS, ADF, half-life, and structural stop observation | D1 |
| Residual z-score, entry evaluation, and mean-cross exit | H1 |
| Tester host | `GBPUSD.DWX`, H1 |

All statistics consume completed bars. The hedge estimate and qualification
decision are latched for the calendar month.

## 5. Expected Behaviour

- One two-leg package at a time, with no pyramiding.
- Entries occur only in months that pass both stationarity and half-life gates.
- Holding time is capped at 10 days.
- Exposure is residual/convergence exposure rather than an intended naked FX
  direction.
- Q02 established executable cadence on the selected package; it did not prove
  economic merit. The historical Q04 failure remains binding evidence and the
  V4 Q03 row is a rebaseline contract, not a waiver or promotion.

## 6. Source Citation

Tetiana Lemishko, Alexandre Landi, and Juliana Caicedo-Llano,
*Cointegration-Based Strategies in Forex Pairs Trading*, SSRN abstract 4771108
(2024). The OWNER-approved localized Strategy Card is
`docs/strategy_card.md`.

## 7. Risk Model

The canonical backtest setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` on a USD 100,000 tester account. Gross package sizing is
split by the absolute frozen OLS weights, capped so neither leg exceeds 70% of
gross notional. Each leg receives a D1 ATR protective stop, and a failed second
leg triggers immediate rollback of the first.

The approved card additionally requires a combined-pair stop at 1.5R. The
current source declares `strategy_r_stop=1.5` but does not reference it after
declaration, so it does not yet enforce that package-level loss boundary. This
is a card-fidelity blocker, not permission to alter the approved risk contract.

This specification documents non-live pipeline execution only. It does not
authorize T_Live, AutoTrading, deployment, or portfolio admission.

## 8. Current Preflight Blockers

- Strict build hardening reports `EA_Q08_MAE_HOOK_MISSING`: the framework-
  managed `OnTick()` does not call `QM_FrameworkTrackOpenPositionMae()` as its
  first action.
- The card-required combined-pair 1.5R stop is not enforced because
  `strategy_r_stop` is declaration-only in the current source.
- `strategy_coint_exit_p` is also declaration-only; the approved card defines
  mean crossing, time, daily-residual, and combined-risk exits, not a separate
  0.10 cointegration-exit rule.
- Pending Q03 work item `162a6230-d6fa-424c-a539-b873cc9a5559` is bound to the
  current MQ5, EX5, and setfile hashes. A source repair therefore requires a
  governed rebuild and fresh append-only execution identity; editing the MQ5
  alone would make the pending row stale.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-18 | Initial approved build lineage | Existing OWNER-approved Lemishko/Landi/Caicedo card and registered EA identity. |
| v2 | 2026-09-02 | Current-spec localization | Added the missing repository `SPEC.md`, recorded the exact slot-8 V4 Q03 rebaseline contract, and documented the two current source blockers; no strategy, source, binary, setfile, manifest, or risk change. |
