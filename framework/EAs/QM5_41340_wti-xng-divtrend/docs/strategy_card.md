---
card_schema_version: 2
type: strategy
strategy_id: MOP-EIA-WTI-XNG-SIGN-DIVERGENCE-20260905_S01
variant_id: MOP-EIA-WTI-XNG-SIGN-DIVERGENCE-20260905_S01
source_id: MOP-EIA-WTI-DECOUP-2026
ea_id: QM5_41340
slug: wti-xng-divtrend
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41340_wti-xng-divtrend_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41340_wti_xng_sign_divergence_trend_g0.md
source_approval: decisions/2026-09-05_wti_xng_sign_divergence_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250; Villar and Joutz (2006), U.S. EIA; Ramberg and Parsons (2012), The Energy Journal 33(2), 13-35."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: twelve_month_own_return_sign_and_monthly_cadence_for_wti_and_natural_gas
  - type: government_research
    citation: "Villar, J. A., and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "complete-report evidence strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: unstable_oil_gas_linkage_context
  - type: peer_reviewed_energy_paper
    citation: "Ramberg, D. J., and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete-paper evidence strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: weak_time_varying_oil_gas_relationship_and_adverse_context
strategy_mechanic: monthly-wti-exact-twelve-completed-month-return-sign-continuation-gated-by-strict-opposite-xng-twelve-completed-month-return-sign-with-xng-read-only
sources:
  - "[[sources/MOP-EIA-WTI-DECOUP-2026]]"
concepts: ["[[concepts/time-series-momentum]]", "[[concepts/oil-gas-decoupling]]", "[[concepts/crude-oil-structural-premium]]"]
indicators: ["[[indicators/completed-month-log-return]]", "[[indicators/atr]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, oil-gas-sign-divergence, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
read_only_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 413400000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately five to eight completed WTI positions per full post-warm-up year when annual energy directions disagree; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct-WTI annual-sign trend admitted only when annual XNG direction opposes it; verify XNG read-only discipline and exact synchronized month ends. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_thirteen_synchronized_completed_month_ends, two_exact_twelve_month_log_returns, strict_opposite_signs, xng_read_only, monthly_attempt_state, fixed_risk, frozen_stop, next_month_exit, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-05 and G0 decision approve R1-R4 within explicit source-synthesis and continuous-CFD risks. Corrected-root dedup returned CLEAN across 4,820 registry rows, 1,439 cards, and 45 Wiki nodes; manual review separates the read-only annual sign-divergence gate from 63-D1 weak-correlation WTI and two-leg energy packages."
---

# QM5_41340 WTI/XNG Twelve-Month Sign-Divergence Trend

## Hypothesis

WTI supplies physical crude-oil exposure absent from the certified XAU,
SP500, NDX, and XNG carrier set. The hypothesis is that WTI's own twelve-month
trend is a cleaner crude-specific state when natural gas has moved in the
opposite direction over the same synchronized completed-month interval.
Natural gas is a read-only veto; the EA never orders it.

This conjunction does not prove profitability, low correlation, or a stable
oil/gas relationship. Q02 owns activity and baseline economics. Q09 alone owns
realized book overlap.

## Source traceability and claim boundary

The governed packet `strategy-seeds/sources/MOP-EIA-WTI-DECOUP-2026/source.md`
contains complete peer-reviewed evidence for twelve-month own-return-sign
momentum including WTI and natural gas, plus complete government and
peer-reviewed evidence that their linkage is weak and time varying. No source
tests the exact opposite-sign gate, CFD implementation, thresholds, risk,
costs, density, or QM portfolio.

## Non-duplicate decision

The corrected-root scan returned `CLEAN`. `QM5_21516_wti-decoup-trend` admits
WTI under a recent 63-D1 absolute Pearson-correlation threshold; this card does
not compute correlation and instead requires strict disagreement between two
exact annual signs. Existing XTI/XNG momentum/reversal, rank, ratio, residual,
weekday, and seasonal systems order both legs or use different horizons and
states. The annual XNG sign, read-only topology, annual WTI side, and single-
leg execution are jointly load-bearing.

## Exact market, clock, and formula

- Host/traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `413400000`.
- Read-only signal symbol: `XNGUSD.DWX`, D1; no magic or order authority.
- Decision: first processed D1 bar after a genuine broker-month transition,
  within a fixed 180-minute grace from that bar open.
- History: bounded 500-bar reads, exact timestamp intersection, then exactly
  thirteen consecutive synchronized completed broker-month endpoints ending
  in the immediately prior broker month.

```text
wti_12m = ln(WTI_latest_month_end / WTI_month_end_12_months_older)
xng_12m = ln(XNG_latest_month_end / XNG_month_end_12_months_older)

BUY  iff wti_12m > +1e-12 and xng_12m < -1e-12
SELL iff wti_12m < -1e-12 and xng_12m > +1e-12
FLAT otherwise
```

Each endpoint return must equal the sum of its twelve adjacent monthly log
returns within `1e-10`. A tie or agreeing signs consume the month flat.

## Entry rules

1. Require exact ID, host, D1, slot/magic, locked inputs, and fixed-risk mode.
2. Process malformed and prior-month exposure before entry-only gates.
3. Require a genuine new broker month inside the entry grace; persist that
   month before history, signal, news, spread, quote, ATR, sizing, or order.
4. Intersect completed XTI/XNG D1 histories by exact timestamps. Require
   strict chronology, positive finite prices, a prior-month endpoint, and no
   more than ten calendar days of endpoint staleness.
5. Reconstruct exactly thirteen consecutive synchronized broker-month ends
   and verify both chained twelve-month returns.
6. Admit only strict opposite signs and order WTI in its own sign.
7. Require no owned exposure or same-month entry deal, spread in `[0,1500]`
   points, executable quote, completed `ATR(20,D1)`, valid stop, metadata,
   sizing, and margin.
8. Open at most one WTI position with `RISK_FIXED=1000`, a frozen
   `3.5*ATR(20,D1)` broker hard stop, and no target. Never order XNG.

## Exit and management rules

- Close the prior WTI position on the first processed D1 bar of each new
  broker month before evaluating replacement risk, even if direction repeats.
- Close after forty elapsed calendar days as stale repair.
- Close duplicate, wrong-symbol, invalid-side, or missing-stop exposure owned
  by this magic.
- Broker stop and framework kill switch remain authoritative. Friday close is
  disabled for the monthly hold.
- No intramonth signal exit, target, trail, break-even, partial close, retry,
  scale-in, grid, martingale, pyramid, external feed, optimizer state, or ML.

## Parameters to test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_trend_months` | 12 | [12] |
| `strategy_history_bars_d1` | 500 | [500] |
| `strategy_sign_epsilon` | 1e-12 | [1e-12] |
| `strategy_chain_tolerance` | 1e-10 | [1e-10] |
| `strategy_entry_grace_minutes` | 180 | [180] |
| `strategy_max_endpoint_gap_days` | 10 | [10] |
| `strategy_atr_period_d1` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.5 | [3.5] |
| `strategy_max_hold_days` | 40 | [40] |
| `strategy_max_spread_points` | 1500 | [1500] |

## Risk and kill criteria

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, roll/basis/financing, sparse disagreement,
XNG regime dependence, shared macro shocks, stop slippage, and correlation to
the existing book are material risks.

Retire on zero trades or fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, wrong month/return count,
current-month leakage, agreeing-sign entry, XNG order, repeated attempt,
missing stop, invalid risk, hold beyond forty days, nondeterminism, or any
later hard-gate failure. No result-dependent tuning is authorized.

## Framework alignment

- no_trade: exact WTI/D1/ID/slot/magic, fixed risk, news/Friday/stress and
  locked-input guards.
- trade_entry: consumed month, synchronized endpoints, two annual signs,
  conjunction, WTI side, spread/quote/ATR/stop, one fixed-risk order.
- trade_management: malformed-state repair, later-month and stale exits.
- trade_close: framework close helper, broker stop, and kill switch.

## Safety boundary

Authorized: deterministic allocation, branch-only non-live V5 build, strict
compile/Q01, reference tests, one fixed-risk set, and one paced Q02 enqueue
below the CPU ceiling. Forbidden: manual backtests, optimization, live/demo/
shadow/stress sets, terminal control, AutoTrading, `T_Live`, deploy/live
manifest changes, portfolio admission/gate edits, and correlation waivers.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial WTI/XNG sign-divergence card | G0 | APPROVED; build pending |
