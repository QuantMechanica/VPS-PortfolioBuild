---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-ADF-LZ-AGREE-TREND-20260905_S01
variant_id: AI-CODEX-WTI-ADF-LZ-AGREE-TREND-20260905_S01
source_id: AI-CODEX-WTI-ADF-LZ-AGREE-TREND-20260905
ea_id: QM5_41339
slug: wti-adf-lz-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41339_wti-adf-lz-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41339_wti_monthly_adf_lz76_agreement_trend_g0.md
source_approval: decisions/2026-09-05_wti_monthly_adf_lz76_agreement_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; Abraham Lempel; Jacob Ziv; Janusz Szczepanski; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "Codex (2026), WTI monthly ADF/LZ76 agreement trend; Chan (2013), Algorithmic Trading, Wiley; Szczepanski (2009), Information Sciences 179(9), DOI 10.1016/j.ins.2008.12.019; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-lag-one-intercept-adf-t-at-least-minus2p594-and-newest-twenty-log-return-signs-lz76-exhaustive-history-complexity-at-most-six-agreement-gated-twelve-month-return-sign-continuation
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, dual-diagnostic-agreement, augmented-dickey-fuller, lz76-complexity, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 413390000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately four to seven completed positions per full post-warm-up year is an uncalibrated prior; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE
r1_reasoning: "Complete approved Wiley ADF extraction, accessible peer-reviewed LZ76 method manuscript with original IEEE provenance, and complete peer-reviewed WTI continuation record are hash-bound with explicit claim boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, ADF path, newest-twenty sign word, exact exhaustive-history parser, inclusive gates, conjunction, side, attempt, fixed risk, stop, spread, and lifecycle are locked."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; roll, basis, financing, gaps, and broker-month labels remain risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS, strings, substring equality, integer counts, comparisons, ATR risk, quotes, positions, deals, and persistent state are used."
parameters_to_test: "Locked Q02 baseline only: 60 completed month-end closes; ADF lag one/intercept/no trend, 58 observations, dof 55, determinant floor 1e-12, inclusive t>=-2.594; newest 20 monthly return signs, tie epsilon 1e-12, exact LZ76 parsing, inclusive complexity<=6; 12-month direction epsilon 1e-12; history 1800 D1 bars; entry grace 180 minutes; endpoint staleness 10 days; ATR(20)*3.5 stop; stale exit 40 days; spread ceiling 1500 points."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify direct-WTI monthly ADF/LZ76 agreement outside the certified XAU/SP500/NDX/XNG book. Verify shared endpoints, ADF arithmetic, sign word, phrase parser, inclusive gates, disagreement abstention, twelve-month side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
g0_approval_reasoning: "OWNER mission 2026-09-05 and G0 decision approve R1-R4 within disclosed source-synthesis and continuous-CFD risks. Corrected-root dedup found no exact identity; expected fuzzy neighbors are manually separated by the joint ADF plus variable-length phrase-novelty state."
---

# QM5_41339 WTI Monthly ADF and LZ76 Agreement Trend

## Hypothesis

WTI supplies physical energy exposure through production, storage, transport,
refining, hedging, geopolitics, and demand. The hypothesis is that a completed
twelve-month WTI move is suitable for one further broker month only when a
lag-one ADF state does not show strong error correction and the newest twenty
monthly return signs have low variable-length phrase novelty. These overlapping
gates do not prove persistence, predictability, profit, or decorrelation.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-LZ-AGREE-TREND-20260905/source.md`,
approved before extraction. Parent sources define ADF, LZ76, and WTI
continuation separately; none tests this exact conjunction, sample,
thresholds, continuous CFD, costs, activity, or book fit.

## Non-Duplicate Decision

The corrected-root receipt found no exact identity. ADF-only and LZ-only EAs
each omit one load-bearing gate. Other agreement EAs use KPSS partial sums,
frequency-domain entropy, or raw successive-return dispersion, none of which
parses variable-length sign phrases. Fixed fixtures pin both disagreement
directions and executable up/down agreement paths. Q09 receives no waiver.

## Markets, Timeframe, And Cadence

Exact host and traded symbol is `XTIUSD.DWX`, D1, slot zero, magic
`413390000`. Decide once on the first executable tick after a genuine broker-
month transition within 180 minutes. Use sixty completed month-end closes and
exclude current-month prices. Hold until the next broker month; forty days is
stale repair.

## Exact Formula

For `x[t]=ln(C[t])`, `t=2..59`, regress
`x[t]-x[t-1]` on an intercept, `x[t-1]`, and `x[t-1]-x[t-2]`. Use centered
OLS, `SSE/55`, governed energy/determinant floors, and require
`adf_t>=-2.594` inclusively.

For `i=0..19`, set `r[i]=x[40+i]-x[39+i]`. Encode `1` above `+1e-12`, `0`
below `-1e-12`, and fail on ties. Parse the exact LZ76 unique exhaustive
history; require reconstruction, `2<=C<=9`, and `C<=6` inclusively.

```text
mom12=x[59]-x[47]
BUY  iff both gates qualify and mom12 > +1e-12
SELL iff both gates qualify and mom12 < -1e-12
FLAT otherwise
```

## Rules

Use only the exact completed-month sample and arithmetic above. Both gates
must qualify, the strict momentum sign alone selects direction, and the month
is consumed before any fallible entry check. One fixed-risk position, one
frozen hard stop, one monthly package, and no retry or adaptive behavior are
permitted.

## Entry Rules

1. Require exact identity, WTI D1 host, slot/magic, locked inputs, and fixed-risk mode.
2. Process malformed/later-month/stale exits before entry-only gates.
3. Require a genuine new broker month inside the entry grace.
4. Persist the month as consumed before every fallible gate; never retry.
5. Reconstruct sixty consecutive completed endpoints and compute both gates on their exact shared slices.
6. Require both inclusive gates and strict twelve-month direction.
7. Require spread in `[0,1500]`, quotes, ATR(20), metadata, sizing, and margin.
8. Open at most one position with frozen `3.5*ATR` hard stop and no target.

## Exit Rules

Framework kill switch and broker stop remain authoritative. Close on the first
processed tick in a later broker month, after forty elapsed calendar days, or
immediately for duplicate/wrong-side/malformed exposure. No intramonth signal
exit, target, trail, break-even, partial close, retry, scale-in, grid,
martingale, or pyramid.

## Filters And Trade Management

Fail closed outside exact identity, risk/news/Friday/stress, input, endpoint,
arithmetic, sign, phrase, spread, quote, ATR, sizing, and margin contracts.
Lifecycle repair runs before entry gates on every tick. Runtime uses no files,
APIs, curves, inventory, volume, open interest, forecasts, optimizer output,
portfolio state, or trained artifact.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_level_count` | 60 | [60] |
| `strategy_regression_observations` | 58 | [58] |
| `strategy_residual_dof` | 55 | [55] |
| `strategy_adf_t_min` | -2.594 | [-2.594] |
| `strategy_lz_return_count` | 20 | [20] |
| `strategy_complexity_ceiling` | 6 | [6] |
| `strategy_sign_epsilon` | 1e-12 | [1e-12] |
| `strategy_energy_floor` | 1e-18 | [1e-18] |
| `strategy_determinant_relative_floor` | 1e-12 | [1e-12] |
| `strategy_momentum_months` | 12 | [12] |
| `strategy_direction_epsilon` | 1e-12 | [1e-12] |
| `strategy_history_bars` | 1800 | [1800] |
| `strategy_entry_grace_minutes` | 180 | [180] |
| `strategy_endpoint_stale_days` | 10 | [10] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.5 | [3.5] |
| `strategy_stale_days` | 40 | [40] |
| `strategy_max_spread_points` | 1500 | [1500] |

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Continuous-CFD roll/basis and financing, WTI gaps,
single-carrier concentration, overlapping diagnostic samples, small-sample
ADF size, sign information loss, stop slippage, and book correlation are
material risks.

## Kill Criteria

Retire at zero positions or fewer than five positions in any full scored post-
warm-up year, nonpositive governed economics, formula/fixture mismatch,
current-month leakage, wrong word/phrase/boundary, repeated attempt, missing
stop, invalid risk, hold beyond forty days, nondeterminism, or later hard gate
failure. No result-dependent tuning is authorized.

## Framework Alignment

- no_trade: exact WTI/D1/ID/slot/magic, locked inputs, fixed risk, news/Friday/stress guards.
- trade_entry: month persistence, endpoints, ADF, LZ76, conjunction, side, spread/quote/ATR/stop, one fixed-risk order.
- trade_management: malformed-state repair, recovered-direction validation, later-month and stale exits.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live V5 build, strict
compile/Q01, reference tests, one fixed-risk set, and one paced Q02 enqueue
below the CPU ceiling. Forbidden: manual backtests, optimization, live/demo/
shadow/stress sets, terminal control, AutoTrading, `T_Live`, deploy/live
manifest changes, portfolio admission/gate edits, and correlation waivers.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial ADF/LZ76 agreement card | G0 | APPROVED; build pending |
