---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-GSR-RUNFADE-2026_S04
variant_id: SCHWEIKERT-CME-GSR-RUNFADE-2026_S04
source_id: SCHWEIKERT-CME-GSR-RUN-2026
ea_id: QM5_20275
slug: gsr-runfade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20275_gsr-runfade_card.md
execution_contract_status: DRAFT
created: 2026-08-11
created_by: Research+Development
last_updated: 2026-08-11
g0_status: APPROVED
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo, and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI https://doi.org/10.1016/j.jbankfin.2017.11.010; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: primary_state_dependent_long_run_relation
  - type: peer_reviewed_paper
    citation: "Yaya, O. S., Vo, X. V., and Olayinka, H. A. (2021). Gold and silver prices, their stocks and market fear gauges: Testing fractional cointegration using a robust approach. Resources Policy 72, 102045."
    location: "DOI https://doi.org/10.1016/j.resourpol.2021.102045; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: supplemental_robust_long_run_relation
  - type: exchange_education
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade; governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: intermarket_relative_value_carrier
strategy_mechanic: synchronized-d1-gold-silver-log-ratio-five-consecutive-same-sign-relative-returns-fresh-run-exhaustion-reversion-basket
sources:
  - "[[sources/SCHWEIKERT-CME-GSR-RUN-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/relative-return-run-exhaustion]]"
  - "[[concepts/structural-mean-reversion]]"
indicators:
  - "[[indicators/completed-d1-log-return]]"
  - "[[indicators/consecutive-sign-run]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, relative-value, structural-mean-reversion, run-exhaustion, paired-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20275_XAU_XAG_RUNFADE_D1
symbol: QM5_20275_XAU_XAG_RUNFADE_D1
host_symbol: XAUUSD.DWX
symbol_slots:
  XAUUSD.DWX: 0
  XAGUSD.DWX: 1
magics:
  XAUUSD.DWX: 202750000
  XAGUSD.DWX: 202750001
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eight fresh-run XAU/XAG packages per full post-warm-up year under a symmetric independent-sign design reference; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a fresh five-session gold/silver relative-return exhaustion package whose paired returns differ from outright XAU, SP500, NDX, and XNG book drivers; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [synchronized_completed_bars, chronological_return_orientation, fresh_run_definition, one_logical_basket, aggregate_fixed_risk, orphan_repair, restart_attempt_state, friday_close_exception, magic_schema, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-11_qm5_20275_gsr_runfade_g0.md: R1 one bounded lineage to two peer-reviewed DOI records plus a governed CME exchange carrier; R2 locked seven synchronized ratios, five strict same-sign returns, sixth-return break, inverse sides, aggregate fixed risk, ATR stops, first-counter-return and stale exits; R3 registered XAUUSD.DWX and XAGUSD.DWX D1 histories; R4 deterministic native arithmetic only. The checker covered 4,339 registry rows and 448 cards with no exact or fuzzy identity; manual review separated score, regression, MAD, quantile, channel, calendar, moment, and monthly rank families. No source efficacy, neutrality, or decorrelation transfers."
---

# QM5_20275 Gold/Silver Fresh-Run Fade

## Hypothesis

Gold and silver share precious-metals exposure but differ in monetary,
safe-haven, industrial, and business-cycle sensitivity. Five consecutive D1
moves in their relative log price may represent a short-lived displacement;
the first length-five run is faded through opposite legs and closed when the
relative move first counters the run.

The package seeks relative-value exposure and suppresses part of the common
metal direction. Opposite legs and equal stop-risk do not establish dollar,
beta, volatility, factor, market, or portfolio neutrality. Q02 owns density
and economics; unchanged downstream gates, especially Q09, own robustness and
realized overlap with the certified XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The single source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-GSR-RUN-2026/source.md`. Its governed
peer-reviewed parents support a potentially state-dependent long-run
gold/silver relation. Its CME parent defines the ratio and supports an
intermarket relative-value carrier.

None of the sources specifies a five-return run, preceding break, inverse
package, first-counter-return exit, Darwinex CFDs, fixed-cash sizing, ATR
stops, or lifecycle controls. Those are transparent QM hypotheses. No source
return, alpha, Sharpe ratio, drawdown, trade count, cost, CFD equivalence,
neutrality, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation checker returned `CLEAN` across 4,339 EA
registry rows and 448 cards for the exact slug, strategy identity, and
declared mechanic. Manual review resolves the expected family neighbors:

- `QM5_12577` and `QM5_20157` use arithmetic mean/standard-deviation ratio
  scores;
- `QM5_20161` estimates a rolling OLS log-price residual;
- `QM5_20263` uses a rolling median/MAD score;
- `QM5_20265` fades a completed outside-to-inside channel failure;
- `QM5_20268` fades two observations in a frozen empirical tail; and
- existing XAU/XAG calendar, moment, momentum, reversal, and variance-ratio
  packages make monthly decisions without this daily fresh-run event.

No card requires exactly five newest strict same-sign daily relative returns,
a sixth return that breaks the run, an immediate inverse package, and a first-
counter-return exit. Those rules plus the consumed event timestamp are jointly
load-bearing. Verdict: `CLEAN_FRESH_D1_SIGN_RUN_EXHAUSTION`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20275_XAU_XAG_RUNFADE_D1`.
- Host: `XAUUSD.DWX`, D1, slot 0, intended magic `202750000`.
- Second leg: `XAGUSD.DWX`, slot 1, intended magic `202750001`.
- Decision clock: once on each new host D1 bar using completed bars only.
- Formation: seven synchronized completed D1 ratios, forming six relative
  returns; the newest five form the candidate run and the sixth proves it is
  fresh.
- Expected cadence: approximately eight completed packages per full post-
  warm-up year under the design reference; retire below five.
- Q02 window: `2018.07.02` through `2024.12.31`, bounded to synchronized XAG
  history.
- Runtime data: Darwinex-native D1 time/close, ATR, spread, quote, position,
  deal, calendar, and contract metadata only.

## Formula

For completed D1 shift `k`, newest at `k=1`, define:

```text
r[k] = ln(XAU_close[k]) - ln(XAG_close[k]), k=1..7
d[k] = r[k] - r[k+1],                      k=1..6

upper = d[1]>0 and d[2]>0 and d[3]>0 and d[4]>0 and d[5]>0 and d[6]<=0
lower = d[1]<0 and d[2]<0 and d[3]<0 and d[4]<0 and d[5]<0 and d[6]>=0
```

All paired timestamps must match exactly. All closes, ratios, and returns must
be positive where required and finite. Zero breaks the qualifying run. The
upper and lower events are mutually exclusive. Return magnitude never scales
risk.

## Rules

These are the complete authorized baseline. There is no parameter sweep and
no fallback to a standardized score, fitted residual, robust scale, order
statistic, channel, oscillator, calendar direction, external series, or prior
pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20275`, host `XAUUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Run lifecycle repair and exits before entry-only gates. Evaluate entry only
   once per new host D1 bar.
3. Reject owned exposure or a same-event entry deal. Load exactly seven
   completed D1 bars from both legs and require identical timestamps at every
   shift, positive finite closes, and finite ratios/returns.
4. Require either the exact upper or lower fresh-run event. Equality inside
   the newest five returns is flat; equality in the sixth return is a valid
   run break.
5. Consume and persist the newest completed event timestamp before spread,
   quote, ATR, sizing, news, or order checks. A rejection, failure, stop, or
   restart cannot retry that event.
6. For an upper event, SELL XAU and BUY XAG. For a lower event, BUY XAU and
   SELL XAG. Maintain exactly zero or two opposite legs.
7. Require each leg's spread cap, executable quote, completed `ATR(20,D1)`,
   valid point/digit/volume metadata, and valid fixed-risk sizing.
8. Split one aggregate fixed-cash stop-risk budget equally between legs after
   independent `3.5*ATR(20,D1)` stop normalization. Open both legs or close
   any orphan immediately. No take-profit is used.

## 5. Exit Rules

1. On each new host D1 bar, align the newest two completed ratios and compute
   `d[1]=r[1]-r[2]`.
2. Close an upper-run package (SELL XAU / BUY XAG) when `d[1] <= 0`.
3. Close a lower-run package (BUY XAU / SELL XAG) when `d[1] >= 0`.
4. Close both legs immediately on orphan, duplicate, same-side, wrong-side,
   stopless, or invalid synchronized-state composition.
5. Close after twelve elapsed calendar days. Broker hard stops and the
   framework kill switch remain authoritative.
6. Friday close is disabled. No intraday signal flip, profit target, trail,
   break-even, partial close, scale-in, grid, martingale, or pyramid.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject owned exposure, consumed attempt, timestamp mismatch, insufficient
  history, nonpositive or nonfinite prices, invalid ratio/return, malformed
  fresh run, excessive spread, invalid quote, unavailable ATR, invalid stop,
  invalid volume metadata, or failed basket atomicity.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle repair
  and exits run before entry-only filters.
- Runtime may not read futures curves, inventory, volume, open interest,
  files, APIs, analyst forecasts, trained outputs, or portfolio results.

## 7. Trade Management Rules

- Maintain at most one logical package and exactly one position per registered
  leg magic. Any invalid package composition is flattened.
- Preserve original hard stops; close on the first completed counter-return,
  invalid package/state, or twelve-day timeout.
- Restart recovery combines a terminal-persistent attempted-event marker with
  owned positions and deal history. A marker from a future tester time is
  cleared so historical replay remains deterministic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_run_length_d1` | 5 | [5] | newest strict same-sign returns |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 12 | [12] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | paired-order deviation |

Every value, shift, comparison, side, attempt, risk allocation, and lifecycle
rule is locked. Any change requires a new card and full pipeline run.

## Author Claims

The cited authors support investigating a state-dependent gold/silver
relationship; CME documents a ratio-spread carrier. They do not claim that
this fresh-run fade works, that five returns is optimal, that spot CFDs
reproduce futures, or that the package diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the aggregate package. Each leg receives half the
cash stop-risk after independent ATR normalization. Risk is high: XAG gaps,
unequal metal beta, CFD roll/basis and financing, legging, synchronized-
history gaps, persistent structural breaks, minimum-lot rounding, and hard-
stop slippage can dominate the premise. Opposite legs are not proof of market
neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full post-
  warm-up year.
- Fail on timestamp mismatch, reversed return orientation, accepting zero
  inside the five-return run, omitting the sixth-return break, wrong inverse
  sides, repeated event attempt, unpaired or stopless exposure, aggregate-risk
  breach, hold beyond twelve days, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the run length, break rule, direction,
  exit, stop, hold, spread cap, retry rule, or carrier.

## Strategy Allowability Check

- [x] R1: PASS. One bounded lineage points to two named-author peer-reviewed
  DOI records and a governed CME exchange packet.
- [x] R2: PASS. Exact shifts, signs, event, direction, attempt, aggregate risk,
  hard stops, counter-return exit, and stale guard are deterministic.
- [x] R3: PASS with disclosed basis risk. Registered XAU/XAG D1 histories and
  native V5 execution state supply every runtime input.
- [x] R4: PASS. Deterministic logarithm, comparison, arithmetic, ATR, and
  calendar operations only; no trained model, external feed, grid,
  martingale, scale-in, or pyramiding.
- [x] Dedup: no exact fresh five-return XAU/XAG run-fade identity; all close
  family neighbors manually resolved.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: consumed-event persistence, synchronized ratio loading, exact
  fresh-run event, spread/quote/ATR/stop checks, and one aggregate-risk
  opposite-leg package.
- trade_management: composition repair, synchronized counter-return exit,
  invalid-state exit, and twelve-day stale exit.
- trade_close: framework package-close helper, per-leg broker hard stops, and
  kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a
manual backtest; live, demo, shadow, optimization, or stress setfile;
AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio admission;
portfolio-gate edit; correlation waiver; or neutrality claim.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-11 | initial source-bounded fresh-run ratio card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-11 | APPROVED | `decisions/2026-08-11_qm5_20275_gsr_runfade_g0.md` |
| Q01 Build Validation | TBD | NOT_RUN | TBD |
| Q02 Baseline Screening | TBD | NOT_ENQUEUED | TBD |
