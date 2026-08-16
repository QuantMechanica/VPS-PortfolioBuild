---
ea_id: QM5_20117
slug: wti-fri-lagrev
type: strategy
strategy_id: MEEK-HOELSCHER-WTI-DOW-2023_S05
source_id: MEEK-HOELSCHER-WTI-DOW-2023
status: APPROVED
g0_status: APPROVED
created: 2026-07-24
created_by: Research+Development
last_updated: 2026-08-16
source_authors: "Andrew C. Meek; Seth A. Hoelscher"
strategy_mechanic: friday-short-after-4p5pct-thursday-wti-log-surge
source_citation: "Meek, Andrew C. and Hoelscher, Seth A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2213876. DOI 10.1080/23322039.2023.2213876."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Meek, Andrew C. and Hoelscher, Seth A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2213876."
    location: "WTI data construction, Equation 2, Table 2, discussion, limitations, and conclusion; DOI https://doi.org/10.1080/23322039.2023.2213876; complete open copy https://www.econstor.eu/bitstream/10419/304091/1/10.1080_23322039.2023.2213876.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MEEK-HOELSCHER-WTI-DOW-2023]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/conditional-one-day-lag-reversal]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, conditional-mean-reversion, day-of-week, atr-hard-stop, intraday-time-exit, short-only, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_20117_XTI_FRI_LAGREV_D1
expected_trade_frequency: "Rare Friday-session WTI short after a completed Thursday log-price surge of at least 4.5%; estimate 3-8 consumed signals/year before holidays, spread, news, and execution gates."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 16.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify whether the small source-implied conditional Friday reversal survives the omitted overnight gap, continuous-CFD versus synchronized-futures basis, threshold sparsity, costs, WTI tails, and post-2021 decay."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, one_position_per_magic_symbol, restart_safe_attempt, friday_close, source_port_reduction, cfd_futures_basis, sparse_signal, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity-sleeve mission authorizes one new structural energy card/build: R1 PASS fully reviewed peer-reviewed open WTI futures paper; R2 PASS fixed 4.5% Thursday log-surge threshold derived above every Table 2 Friday/lag break-even point, Friday short, ATR stop, consumed weekly attempt, and no-weekend exit; R3 PASS registered XTIUSD.DWX D1 route; R4 PASS calendar/log-return/ATR arithmetic only with no machine learning, banned indicator, external runtime feed, grid, or martingale. Exact dedup was clean; the sole fuzzy source-family sibling was manually differentiated."
---

# WTI Thursday-Surge Friday Lag Reversal

## Hypothesis

Meek and Hoelscher estimate WTI ending-weekday returns with the prior daily
return in the mean equation. Their Table 2 WTI Friday coefficients are
positive, but the one-day lag coefficient is negative and statistically
significant in all five conditional-variance specifications. A sufficiently
large completed Thursday gain therefore changes the fitted Friday mean from
positive to negative.

This card tests the narrow tail state rather than another unconditional WTI
weekday sleeve: short the Friday session only after Thursday's completed
close-to-close log return is at least 4.5%, then flatten before the weekend.
It is a source-bounded Q02 falsification candidate, not a claim that a CFD
trade earns the paper's fitted mean or is already decorrelated from the book.

## Source and interpretation boundary

The sole lineage is the peer-reviewed, open-access Meek and Hoelscher (2023)
paper recorded at
`strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md`. Its complete
21-page repository copy was reviewed, including methods, contract rolls, all
tables, limitations, conclusion, disclosures, and references.

The paper uses Bloomberg WTI CL1/CL2 futures from 2002 through 2021. Around
expiry it substitutes the more-liquid second contract, computes daily log
returns, and estimates weekday effects under GARCH, EGARCH, PGARCH, QGARCH,
and TGARCH variance specifications.

Table 2 reports Friday coefficients of `0.001550`, `0.001017`, `0.001041`,
`0.001113`, and `0.001349`. The corresponding one-day lag coefficients are
`-0.036300`, `-0.030700`, `-0.032600`, `-0.032500`, and `-0.037900`, all
negative and statistically significant. The Friday coefficient divided by
the absolute lag coefficient yields model break-even Thursday returns of
`4.27%`, `3.31%`, `3.19%`, `3.42%`, and `3.56%`. A 4.5% log-return threshold
is above every break-even point. At exactly 4.5%, the fitted Friday means are
only about `-0.8` to `-4.3` basis points before costs.

The authors propose the opposite-tail example—buy Friday after a significant
Thursday decline. They do not test this reciprocal short, a 4.5% threshold,
Darwinex CFDs, Friday-open execution, ATR stops, or transaction-cost
profitability. This card is a transparent algebraic port of the reported
coefficients. The small conditional mean, threshold choice, and all
implementation economics must be falsified.

## Non-duplicate decision

The deterministic check for slug `wti-fri-lagrev`, strategy ID
`MEEK-HOELSCHER-WTI-DOW-2023_S05`, and mechanic `Friday short after a 4.5%
Thursday WTI log surge` found no exact duplicate. It returned one fuzzy hit
from the same paper family, `xng-thu-tue`; manual review returned
`CLEAN / SOURCE_FAMILY_SIBLING`.

- `QM5_12753_wti-thu-pb-fri-bounce` buys Friday after a Thursday decline of
  at least 1%; this card sells only after a Thursday gain of at least 4.5%.
- `QM5_12597_wti-fri-prem` buys every eligible Friday without a return setup.
- `QM5_20110_xti-xng-fri-rv` is a long-XTI/short-XNG package with no
  Thursday-return condition and no valid standalone leg.
- `QM5_20047_wti-mon-loss-bnc` buys Monday after a Friday loss.
- WTI weekend-gap, COT-window, one-week, multiweek, month, event, and
  medium-term reversal EAs do not own the Thursday-surge/Friday-short state.

The paper family and Friday clock overlap are disclosed. The setup tail,
direction, single carrier, entry subset, and lifecycle are distinct.

## Markets, timeframe, and cadence

- Symbol: `XTIUSD.DWX`, D1, magic slot 0, magic `201170000`.
- Decision: once per genuine broker-calendar Friday D1 bar.
- Expected cadence: approximately 3-8 consumed signals/year.
- Normal hold: Friday session only.
- Backtest risk: exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The entry, management, and exit rules below are the complete authorized v1
baseline. Changing the threshold, weekday, direction, hold, gap treatment, or
adding a trend/event filter creates a new card.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, D1, magic slot 0, and every locked strategy
   input.
2. Evaluate only on a genuine new D1 bar whose broker weekday is Friday.
3. Require the previous completed D1 bar to be Thursday and the bar before it
   to be Wednesday. Broker holidays that break that sequence remain flat.
4. Compute Thursday log return as
   `100 * ln(ThursdayClose / WednesdayClose)` and require it to be at least
   `strategy_min_thu_log_return_pct=4.5`.
5. Require the first observed host tick to be within
   `strategy_entry_grace_minutes=10` of the `D1_bar_open + strategy_session_offset_min`. A late attach
   consumes the week and remains flat.
6. Before fallible history, signal, news, spread, ATR, price, or order checks,
   persist the Friday attempt. Position/deal history and a terminal-global
   marker prevent same-Friday re-entry after restart, rejection, stop, or
   blocked news.
7. Require no EA-owned open position and spread no greater than
   `strategy_max_spread_points=1000`.
8. SELL at market with a broker hard stop `3.0 * ATR(20)` above the executable
   price. ATR uses the completed Thursday D1 bar. No take-profit is authorized.

## 5. Exit Rules

1. Broker-side hard stop.
2. At broker Friday hour 21 or later, close the position. The explicit strategy
   lifecycle and enabled framework Friday-close contract are redundant safety
   layers.
3. If Friday close is missed, close on the first current D1 bar whose broker
   weekday is not Friday.
4. Close after `strategy_max_hold_days=3` calendar days as a final stale guard.
5. Framework kill-switch closure remains authoritative.

News filtering may block new risk only. It may not delay Friday, non-Friday,
hard-stop, stale, or kill-switch exits.

## 6. Filters (No-Trade Module)

- Fail closed for an invalid symbol/timeframe/slot, unlocked parameter, missing
  bar, broken Wednesday-Thursday-Friday sequence, non-positive close, invalid
  logarithm, invalid ATR/price/stop, negative/excess spread, late attach,
  consumed Friday, or open owned position.
- No external futures chain, inventory, CFTC, API, CSV, analyst forecast,
  GARCH runtime model, or portfolio signal is permitted.

## 7. Trade Management Rules

- Short only; one position per magic/symbol.
- One consumed attempt per Friday, even when news, spread, price, risk sizing,
  or order submission blocks entry.
- No same-day retry, pending-order lifecycle, scale-in, partial close, trailing
  stop, break-even move, target, adaptive fit, random path, grid, martingale,
  pyramid, or external runtime feed.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_min_thu_log_return_pct` | 4.5 | [4.5] | above every Table 2 Friday/lag break-even |
| `strategy_session_offset_min` | 61.6 | [61.6] | XTIUSD.DWX tick-measured maximum |
| `strategy_entry_grace_minutes` | 10 | [10] | tight window around the session-tick anchor |
| `strategy_min_stub_ticks` | 20 | [20] | reject thin weekend/holiday D1 stubs |
| `strategy_min_attach_ticks` | 20 | [20] | minimum ticks within 5 minutes of the qualifying tick |
| `strategy_atr_period` | 20 | [20] | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 3 | [3] | stale guard only |
| `strategy_max_spread_points` | 1000 | [1000] | entry spread ceiling |
| `qm_friday_close_hour_broker` | 21 | [21] | no-weekend close |

There is no baseline parameter sweep.

## Kill criteria

- Retire on zero trades, fewer than two completed trades/year on average,
  wrong weekday/direction, entry without the completed 4.5% log surge,
  duplicate Friday entry, weekend hold, nondeterminism, invalid risk mode, or
  any governed PF/DD failure.
- Treat the omitted overnight gap, continuous-CFD/futures-roll basis, sparse
  positive tail, post-2021 decay, and costs larger than the fitted conditional
  mean as first-order falsification risks.
- Do not rescue failure by lowering the threshold, holding across the weekend,
  flipping direction, adding a gap/trend/event filter, or fitting a weekday
  subset.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The frozen `3.0 * ATR(20)` stop is the only initial risk
distance. WTI gap/tail risk, Friday execution, sparse samples, CFD financing,
roll construction, slippage, and the small source-implied mean make the
carrier high risk. No live preset is authorized.

## Strategy allowability check

- [x] R1: fully reviewed, peer-reviewed, open-access WTI futures paper with
  DOI and reproducible full text.
- [x] R2: fixed calendar sequence, log-return threshold, direction, consumed
  attempt, hard stop, and exits.
- [x] R3: registered native `XTIUSD.DWX` D1 route.
- [x] R4: deterministic calendar/log-return/ATR arithmetic; no machine
  learning, banned indicator, external signal, grid, or martingale.
- [x] Dedup: no exact hit; the one fuzzy source-family sibling is mechanically
  distinct after manual review.

## Framework alignment

- no_trade: exact host/timeframe/slot and locked-input guards, completed bar
  sequence, consumed Friday, grace, spread, ATR, and news checks.
- trade_entry: one Friday market short after the locked Thursday log surge,
  with frozen hard stop.
- trade_management: every-tick non-Friday and stale repair.
- trade_close: framework Friday close, explicit stale closure, broker stop,
  and kill switch.

## Safety boundary

This approval covers the card, deterministic registry allocation, EA build,
strict compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue.
It does not authorize a live setfile, AutoTrading, `T_Live`, a deploy/T_Live
manifest, portfolio admission, a portfolio-gate change, portfolio KPIs, or a
correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-24 | source/card/build/strict compile complete | Q01 | PASS; Q02 enqueue deferred at CPU ceiling |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-24 | APPROVED under OWNER mission; R1-R4 PASS | this card |
| Q01 Build Validation | 2026-07-24 | PASS; compile 0 errors/0 warnings | `docs/ops/evidence/2026-07-24_qm5_20117_wti_fri_lagrev_build_cpu_ceiling_stop.md` |
| Q02 Baseline Screening | 2026-07-24 | PENDING; not queued at seven-factory CPU ceiling | same evidence |

## OWNER-approved session-tick entry-clock amendment (2026-08-16)

This amendment supersedes every earlier raw-D1-label/five-minute entry-clock
description in this card. No formation, signal, direction, exit, sizing,
risk, consumed-attempt, or original advance/never-shift mechanic changes.

- Anchor the qualifying window at
  `D1_bar_open + strategy_session_offset_min`, not the raw D1 label.
- `strategy_session_offset_min = 61.6` minutes: conservative tick-measured maximum for `XTIUSD.DWX`.
- `strategy_entry_grace_minutes = 10`, measured tightly around that anchor.
- `strategy_min_stub_ticks = 20`; a thin weekend/holiday D1 stub consumes
  the card's original attempt/date/window flat.
- `strategy_min_attach_ticks = 20` within five minutes after the qualifying
  tick; failure consumes the original attempt/date/window flat.
- Preserve this card's existing advance-versus-never-shift semantics exactly.
