---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XNG_MAJ1312_S13
variant_id: MOP-TSMOM-2012_XNG_MAJ1312_S13
source_id: MOP-XNG-MOMVOTE-2026
ea_id: QM5_20259
slug: xng-mom-vote
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20259_xng-mom-vote_card.md
execution_contract_status: DRAFT
created: 2026-08-07
created_by: Research+Development
last_updated: 2026-08-07
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, Tobias J., Ooi, Yao Hua, and Pedersen, Lasse Heje (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Complete 23-page published paper; DOI https://doi.org/10.1016/j.jfineco.2011.11.003; governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: primary
strategy_mechanic: monthly-xng-one-three-twelve-month-return-sign-majority-vote
sources:
  - "[[sources/MOP-XNG-MOMVOTE-2026]]"
  - "[[sources/MOP-TSMOM-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/multi-horizon-trend]]"
  - "[[concepts/majority-vote]]"
indicators:
  - "[[indicators/one-month-log-return]]"
  - "[[indicators/three-month-log-return]]"
  - "[[indicators/twelve-month-log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, natural-gas, time-series-momentum, multi-horizon-vote, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 202590000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately twelve completed XNG monthly packages/year after thirteen consecutive month ends; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify a symmetric monthly XNG multi-scale trend vote whose clock, directionality, and hold differ from certified QM5_12567; only Q09 may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [consecutive_completed_months, nested_return_orientation, strict_component_signs, majority_vote, monthly_attempt_state, monthly_package_renewal, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-07_qm5_20259_xng_mom_vote_g0.md: tier-A peer-reviewed complete-read source packet with explicit natural-gas membership and monthly own-return sign rules; locked thirteen month ends, nested one/three/twelve-month returns, strict nonzero components, two-of-three vote, persisted monthly attempt, ATR stop, rollover, and stale exit; registered XNGUSD.DWX D1 route; deterministic native arithmetic only. Dedup scanned 4,316 registry rows and 433 cards, found no exact collision, and three expected source/mechanic-family fuzzy neighbors plus XNG single-horizon, sign-breadth, generic-vote, and incumbent-RSI systems were manually resolved. The vote is a transparent QM hypothesis and no source efficacy or decorrelation transfers."
---

# QM5_20259 XNG Multi-Horizon Momentum Vote

## Hypothesis

Natural-gas production, storage, transport, hedging, weather-demand, and export
regimes can trend at different speeds. A fixed majority of the completed one-,
three-, and twelve-month return signs may retain persistent XNG direction while
allowing aligned short/intermediate states to recognize a reversal before the
slow state changes.

This is a falsifiable direct-energy carrier, not a profitability or
decorrelation claim. Q02 owns density and baseline economics. Q09 alone may
measure overlap with the certified XAU/SP500/NDX/XNG book after the candidate
survives every preceding gate. A different clock and direction rule on the same
XNG carrier are not assumed to be decorrelated.

## Source Traceability And Claim Boundary

The governed extraction is
`strategy-seeds/sources/MOP-XNG-MOMVOTE-2026/source.md`. Its completely
reviewed parent records Moskowitz, Ooi, and Pedersen's peer-reviewed article,
published-paper retrieval hash, monthly own-return sign family, and explicit
natural-gas membership. The repository separately implements the one-, three-, and
twelve-month source-family directions.

The two-of-three aggregation is a transparent QM multi-scale hypothesis. The
source does not test this vote, a standalone Darwinex CFD, broker-month
endpoint reconstruction, equal fixed risk at both vote strengths, ATR stops,
spread caps, attempt persistence, or the QM portfolio. No source PF, return,
Sharpe ratio, drawdown, XNG-specific result, trade count, cost, or correlation
statistic transfers.

## Non-Duplicate Decision

The deterministic checker scanned 4,316 registry rows and 433 cards. It found
no exact identity and three expected source/mechanic-family fuzzy neighbors.
Manual review fixes the boundary:

- `QM5_20258_wti-mom-vote` uses the same fixed vote on WTI. The exact XNG
  carrier is load-bearing; no WTI result transfers.
- `QM5_20204_xng-tsmom1m`, `QM5_20063_xng-tsmom3m`, and
  `QM5_12804_xng-tsmom12m-atr` follow one XNG horizon alone; the twelve-month
  sibling also requires a volatility corridor.
- `QM5_13116_xng-signmom` compares the breadth of twelve separate monthly
  return signs with a fixed 0.40 threshold, not nested cumulative horizons.
- `QM5_12358_tmom-fut-mom` votes on rolling 20/60/120 D1-bar returns, evaluates
  daily, exits on a daily vote reversal, and does not register XNG. This rule
  uses completed calendar months, a consumed monthly attempt, and renewal.
- `QM5_12567_cum-rsi2-commodity` uses a long-only two-day cumulative RSI(2)
  pullback aligned with SMA(200) and a five-D1-bar maximum hold. This rule has
  no oscillator or price-level trend filter, is symmetric, and holds monthly.
- XNG calendar, storage, weather, volatility-memory, reversal, ratio, carry,
  breakout, and event EAs use different information sets and lifecycles.

The XNG carrier, calendar-month endpoints, exact nested horizons, strict signs,
majority aggregation, monthly attempt clock, and package renewal are jointly
load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_FUZZY_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XNGUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; intended magic `202590000` after deterministic allocation.
- Decision clock: first processed D1 bar of each genuine broker-month
  transition.
- Formation: thirteen consecutive completed broker-month endpoints.
- Expected cadence: approximately twelve completed packages/year after
  warm-up; retire below five per full post-warm-up year.
- Runtime data: native MT5 D1 time/close, ATR, spread, quotes, positions, deal
  history, broker calendar, and contract metadata only.

## Formula

From thirteen chronological completed month-end closes `C[0]..C[12]`, with
`C[12]` belonging to the month immediately before the decision month:

```text
R1  = ln(C[12] / C[11])
R3  = ln(C[12] / C[9])
R12 = ln(C[12] / C[0])
vote = sign(R1) + sign(R3) + sign(R12)
```

Require all three components to be finite and strictly nonzero. BUY when
`vote` is `1` or `3`; SELL when it is `-1` or `-3`. A zero component,
nonconsecutive or stale endpoint, invalid price, or invalid arithmetic consumes
the month flat. Vote strength does not change the fixed Q02 risk budget.

## Rules

The following rules are the complete authorized Q02 baseline. There is no
signal-parameter sweep.

## 4. Entry Rules

1. Require exact EA ID `20259`, `XNGUSD.DWX` D1, slot 0, registered magic, and
   every baseline input locked to its declared value.
2. Evaluate only on a new D1 bar that opens a genuine new broker month; use
   completed bars only.
3. Persist the broker month as evaluated before reconstructing history or
   applying signal, spread, quote, news, stop, sizing, or order gates. A flat,
   invalid, rejected, failed, or stopped outcome cannot retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen consecutive completed broker-month-end closes
   from bounded D1 history. Require positive prices, strictly increasing
   endpoint timestamps, no missing month, and the newest endpoint in the
   immediately preceding broker month.
6. Compute the exact one-, three-, and twelve-month log returns from the common
   newest endpoint. Require every component to be finite and strictly nonzero.
7. Sum the three signs. BUY for a positive two-of-three majority and SELL for a
   negative majority. There is no threshold, weighting, volatility state,
   calendar direction, significance gate, or post-result override.
8. Require spread in `[0,3000]` points, executable quote, completed
   `ATR(20,D1)`, valid stop geometry, volume metadata, and no owned exposure.
9. Attach one frozen `3.5 * ATR(20,D1)` hard stop, size through the V5 fixed-
   risk layer, and open exactly one position. There is no take-profit.

## 5. Exit Rules

1. Close the current package on the first processed D1 bar of the next broker
   month before considering the new month's vote, even when direction repeats.
2. Close after forty elapsed calendar days as a stale guard.
3. Immediately flatten duplicate positions, a wrong-symbol position, an
   invalid position type, or a missing-stop position bearing this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because a valid package spans the full source
   month and may cross weekends.
6. No intramonth signal reversal, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact `XNGUSD.DWX` D1 slot 0 or on unlocked inputs.
- Require consecutive completed month endpoints, positive closes, valid
  logarithms, three nonzero component returns, registered magic, valid attempt
  state, acceptable spread, executable quote, ATR, stop, and volume metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures curve, external file/API, inventory, volume,
  open interest, analyst input, trained output, optimizer result, or portfolio
  state.

## 7. Trade Management Rules

- The EA may own exactly one `XNGUSD.DWX` position under slot 0.
- Month-transition and stale exits run before entry-only news gates.
- Restart recovery combines a terminal-persistent evaluated-month marker with
  owned position and deal history; future-dated tester state is cleared.
- A broker stop, failed qualified order, or lifecycle exit cannot cause a
  same-month retry.
- No randomness, adaptive fit, external state, partial close, scale-in, or
  pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_fast_months` | 1 | [1] | newest completed return horizon |
| `strategy_medium_months` | 3 | [3] | intermediate completed return horizon |
| `strategy_slow_months` | 12 | [12] | slow completed return horizon |
| `strategy_required_votes` | 2 | [2] | fixed majority threshold |
| `strategy_history_bars_d1` | 800 | [800] | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 3000 | [3000] | entry spread ceiling |

Changing a horizon, vote rule, zero handling, carrier, stop, holding clock,
spread cap, or retry policy requires a new card and full pipeline run.

## Author Claims

Moskowitz, Ooi, and Pedersen define own-return-sign time-series momentum across
futures, explicitly include natural gas, and study multiple monthly formation
lags. They do not claim that this three-horizon majority, a standalone Darwinex XNG
CFD port, or equal risk at both vote strengths is profitable, frequent enough,
or diversifying. Q02 and later gates are the only strategy evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: continuous-CFD roll and financing, natural-
gas gaps, weather and storage shocks, false trends, short-horizon reversals,
full risk on a 2-1 vote, hard-stop slippage, single-energy concentration, and
post-publication decay may dominate the intended state. The signal clock,
directionality, and hold differ from incumbent `QM5_12567`, but the shared XNG
carrier can still trigger portfolio-correlation rejection.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on missing or nonconsecutive endpoints, wrong return orientation,
  incorrect component signs or vote, entry with a zero component, repeated
  month attempt, missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing a horizon, vote, zero policy, direction,
  stop, hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: tier-A peer-reviewed source with complete-read record; natural gas and
  monthly own-return-sign rules are explicit.
- [x] R2: fixed endpoints, three nested returns, strict signs, vote, risk, hard
  stop, attempt state, rollover, and stale exit.
- [x] R3: registered `XNGUSD.DWX` D1 route; no external runtime data.
- [x] R4: deterministic logarithm/calendar/ATR arithmetic; no banned signal
  indicator, adaptive fit, grid, martingale, or pyramid.
- [x] Dedup: no exact collision; expected source siblings manually resolved.

## Framework Alignment

- no_trade: exact symbol/D1/EA/slot, locked inputs, news/Friday contract,
  magic, and cheap parameter guards.
- trade_entry: month-end reconstruction, three return signs, majority vote,
  persisted attempt, spread/quote/ATR/stop checks, sizing, and one order.
- trade_management: owned-state validation, next-month close, stale close, and
  malformed-state repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, build, strict compile/Q01, one non-live
`RISK_FIXED` backtest setfile, and one paced Q02 handoff. It does not authorize
a manual backtest; live, demo, shadow, stress, or optimization setfile;
AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio admission;
portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-07 | initial source-bounded XNG momentum-vote card | G0 | APPROVED |
| v1-q01 | 2026-08-07 | deterministic V5 build and strict compile | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-07 | APPROVED | `decisions/2026-08-07_qm5_20259_xng_mom_vote_g0.md` |
| Q01 Build Validation | 2026-08-07 | PASS | compile `D:/QM/reports/compile/20260807_041819/summary.csv`; build check `D:/QM/reports/framework/21/build_check_20260807_041819.json` |
| Q02 Baseline Screening | 2026-08-07 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-07_qm5_20259_xng_mom_vote_q01_cpu_stop.md` |
