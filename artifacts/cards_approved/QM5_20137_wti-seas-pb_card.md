---
ea_id: QM5_20137
slug: wti-seas-pb
type: strategy
strategy_id: KELOHARJU-YANG-WTI-SEASPULL-2026_S01
source_id: KELOHARJU-YANG-WTI-SEASPULL-2026
status: APPROVED
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 peer-reviewed Journal of Finance seasonality primary plus governed academic commodity-reversal supplement; R2 exact same-calendar sign, opposite completed-month gate, monthly renewal, ATR stop, and consumed attempt; R3 registered XTIUSD.DWX D1 route; R4 deterministic OHLC/calendar/ATR only; deterministic and manual dedup CLEAN."
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, The Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; supplemented by Yang, Goncu, and Pantelous (2017), Momentum and Reversal in Commodity Futures, SSRN 3069253."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "Commodity construction in Sections 5.4.3-5.6 and Tables 8-9; DOI https://doi.org/10.1111/jofi.12398; complete NBER version https://www.nber.org/system/files/working_papers/w20815/w20815.pdf"
    quality_tier: A
    role: primary
  - type: academic_paper
    citation: "Yang, Hongbing; Goncu, Ahmet; and Pantelous, Athanasios A. (2017). Momentum and Reversal in Commodity Futures."
    location: "SSRN 3069253, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253"
    quality_tier: B
    role: supplement
sources:
  - "[[sources/KELOHARJU-YANG-WTI-SEASPULL-2026]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/commodity-pullback]]"
  - "[[concepts/energy-seasonal-risk-premium]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/arithmetic-mean]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, same-calendar-month, conditional-reversal, symmetric-long-short, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
expected_trade_frequency: "After the five-year same-month warm-up, approximately 5-7 completed WTI packages/year when the prior completed month opposes the seasonal sign."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.03
expected_dd_pct: 24.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
q02_work_item_id: 7dff45e1-d4c7-4f5c-b8e0-2f2ea254a725
review_focus: "Falsify whether the strict prior-month counter-move gate adds a distinct WTI seasonal return stream after warm-up and costs; Q09 alone may judge realized book correlation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, magic_schema, cfd_futures_basis, long_history_warmup, portfolio_correlation]
---

# WTI Same-Calendar Seasonal Pullback

## Hypothesis

Recurring physical demand, storage, hedging, and capital-allocation pressures
can give a calendar month a persistent WTI return sign. A just-completed month
that moved against the upcoming historical month-of-year sign may offer a
better entry state than unconditional seasonal exposure: follow the recurring
calendar direction only after that counter-move.

This is a predeclared composite hypothesis, not a source backtest. The
seasonal state comes from the Keloharju, Linnainmaa, and Nyberg commodity
lineage; the counter-move condition comes from the governed academic
commodity-reversal lineage. Direct WTI exposure is economically different
from the certified XAU/SP500/NDX/XNG book, but realized decorrelation is
unclaimed until the governed portfolio phase.

## Source And Evidence Boundary

The primary source is the peer-reviewed 2016 *Journal of Finance* article and
its complete 57-page NBER version, reviewed end to end in the durable parent
packet. It ranks a broad commodity cross-section by average returns in the
same calendar month of prior years, requires at least five years, and
explicitly includes crude oil.

Yang, Goncu, and Pantelous provide academic commodity momentum/reversal
lineage. Neither paper reports this single-WTI interaction, the strict
previous-month disagreement gate, Darwinex performance, an ATR stop, or
post-2011 portfolio correlation. The reduction in breadth, futures/CFD basis,
limited local history, rolls, financing, gaps, costs, and interaction
sparsity are Q02 kill risks, not assumptions.

## Concept And Non-Duplicate Decision

At the first tradable D1 bar of each broker month, reconstruct:

`seasonal = mean[ln(month_end / prior_month_end)]`

for the decision calendar month over up to ten prior years, and:

`pullback = ln(last_completed_month_end / preceding_month_end)`.

Trade in the seasonal direction only when the signs are strictly opposite:

- `seasonal > 0` and `pullback < 0`: BUY WTI;
- `seasonal < 0` and `pullback > 0`: SELL WTI;
- aligned signs, zero, or invalid state: remain flat.

The deterministic pre-allocation helper scanned 4,194 EA-registry rows and
376 research cards and returned CLEAN. Manual review resolves the nearest
neighbors:

- `QM5_20099_wti-samecal` follows the seasonal sign unconditionally.
- `QM5_20136_wti-caltrend` requires agreement with a completed 63-D1 trend;
  this card requires disagreement with the exact prior calendar-month return.
- `QM5_12709_commodity-reversal-1m` ranks four commodities and trades a paired
  winner/loser package without a same-calendar estimator.
- `QM5_12594_yang-wti-reversal` is a weekly medium-horizon SMA reversion rule.
- `QM5_20047_wti-mon-loss-bnc` is a one-session weekday bounce.
- `QM5_13120_energy-momrev` is an XTI/XNG 12/18-month cross-sectional rank.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The exact prior-month disagreement gate, historical same-calendar estimator,
and seasonal direction are jointly load-bearing. Removing the gate duplicates
the unconditional parent; changing it to medium-horizon agreement duplicates
the information object of the trend-confirmed sibling.

## Markets And Timeframe

- Host and traded symbol: exact `XTIUSD.DWX`, D1, magic slot 0.
- Decision cadence: first genuine D1 bar of each broker calendar month.
- Seasonal formation: up to ten prior same-calendar-month returns; minimum
  five valid observations.
- Pullback formation: two consecutive, completed broker-calendar month-end
  closes immediately before the decision month.
- Expected cadence after warm-up: approximately 5-7 completed packages/year;
  Q02 must prove or retire it.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: native MT5 D1 OHLC, ATR, spread, broker calendar, deal history,
  and framework state only.

## Rules

1. On a new broker-month D1 boundary, close any prior-month position before
   considering new risk.
2. Persist the new month's attempt before history, signal, spread, news, ATR,
   price, or order checks. There is no same-month retry.
3. Reconstruct completed month ends only; current-month prices never enter
   either signal.
4. Average valid WTI log returns for the decision calendar month across the
   prior ten years and require at least five observations.
5. Reconstruct the immediately completed broker-month log return from its
   month-end close and the preceding month-end close.
6. BUY only when the seasonal average is strictly positive and the completed
   prior-month return is strictly negative.
7. SELL only when the seasonal average is strictly negative and the completed
   prior-month return is strictly positive.
8. Exact zero, aligned signs, missing consecutive month ends, invalid
   arithmetic, or insufficient history remains flat for the consumed month.
9. Require a nonnegative entry spread no greater than 1,500 points and a valid
   completed `ATR(20)`.
10. Place one normalized frozen stop `3.5 * ATR(20)` from the executable
    market price. Fixed-risk lot sizing remains framework-owned.

## 4. Entry Rules

- Require exact `XTIUSD.DWX` D1 host, slot 0, and every locked input.
- Act only when current and prior D1 bars belong to different broker months.
- Require the recorded month key to equal the current signal month.
- Require the strict seasonal/pullback sign-disagreement state.
- Require no position or entry deal already owned by this EA in the month.
- Open one BUY or SELL through the registered slot-0 magic; no pending order,
  retry, second entry, or scale-in is authorized.

## 5. Exit Rules

- Close on the first D1 bar belonging to a later broker month, before all
  entry-only gates.
- Close after 35 elapsed calendar days if a normal month transition is
  unavailable.
- The frozen broker hard stop and framework kill switch remain authoritative.
- There is no take-profit, same-month signal exit, trailing stop, break-even
  move, partial close, or reversal.
- Friday close is disabled because the source-period package spans weekends.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact symbol, timeframe, magic slot, or locked input
  contract.
- Reject malformed history, fewer than five seasonal samples, missing
  consecutive prior month ends, nonpositive closes, invalid logarithms,
  invalid ATR/price/point metadata, negative spread, or excessive spread.
- Lock both news axes and legacy news mode OFF for the Q02 native-price
  baseline. Lifecycle exits are never delayed by entry-news logic.
- No futures curve, contract chain, inventory, volume, open interest, COT,
  weather, external calendar, analyst forecast, API, CSV, discretionary
  input, or trained output is permitted at runtime.

## 7. Trade Management Rules

- One position for magic `201370000` and one consumed decision per broker
  month.
- Close-before-renew runs on every broker-month boundary.
- Maintain the original server-side hard stop; never trail or move it.
- Restart recovery uses a terminal-persistent consumed-month marker plus
  position/deal history. A future-dated stale marker is cleared at
  initialization for deterministic historical reruns.
- No profit target, scale-in, pyramid, grid, martingale, random path, adaptive
  fit, or discretionary override.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | bounded prior same-month window |
| `strategy_min_history_years` | 5 | [5] | source-aligned minimum samples |
| `strategy_history_bars` | 3000 | [3000] | D1 reconstruction buffer |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | strict signs; no fitted deadband |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly renewal |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

There is no baseline parameter sweep. The same-calendar state and the exact
prior-month disagreement state are both required.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: disabled.
- Framework kill switch and broker hard stop: authoritative.
- Forced session flatten: none.

## Author Claims

Keloharju, Linnainmaa, and Nyberg support recurring same-calendar information
in a broad commodity cross-section. Yang, Goncu, and Pantelous support
commodity momentum/reversal lineage. Neither source claims that this
interaction, this CFD carrier, these risk controls, or this portfolio
objective is profitable.

No source performance statistic is imported as a QM expectation.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, continuous-CFD roll/basis, financing, limited
same-month samples, source-sample decay, sign instability, and interaction
sparsity are first-order kill risks.

Retire on zero trades or fewer than five completed packages/year after
warm-up. Fail on look-ahead, direction without strict sign disagreement,
duplicate same-month entry, hold beyond 35 days, missing hard stop, invalid
risk mode, nondeterminism, or any governed PF/DD failure. Do not rescue
failure by changing the estimator, lookback, sign rule, entry clock, stop,
hold, spread cap, retry policy, or risk mode after results.

Later gates must reject the sleeve if its realized return stream does not
diversify the certified book. No correlation waiver is authorized.

## Strategy Allowability Check

- [x] R1: peer-reviewed primary seasonality source plus named-author academic
  reversal supplement, each with a durable completely read repository packet.
- [x] R2: fixed same-calendar estimator, exact prior-month return, strict
  disagreement, monthly attempt state, hard stop, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 history route and native V5 data only.
- [x] R4: deterministic calendar/OHLC/ATR arithmetic; no trained model,
  banned indicator, external signal, grid, martingale, scale-in, or
  pyramiding.
- [x] Dedup: deterministic CLEAN plus manual parent/neighbor differentiation.

## Framework Alignment

- no_trade: exact host/D1/slot, locked-input, history, arithmetic,
  sign-disagreement, spread, quote, stop, consumed-month, and owned-position
  guards.
- trade_entry: seasonal direction after an exact prior-month counter-move,
  with one frozen ATR stop.
- trade_management: close at the next month or 35-day stale boundary before
  entry-only gates.
- trade_close: framework position close plus broker hard stop and kill switch.

## Falsification And Requalification

Any change to the seasonal sample, minimum history, prior-month endpoint
definition, sign rule, entry clock, stop, stale limit, spread cap, retry state,
symbol, timeframe, or risk mode requires a new binary and full pipeline
requalification. Ambiguous history or state must fail closed.

## Safety Boundary

This approval covers one card, deterministic registries, EA build, strict
compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a live setfile, AutoTrading, `T_Live`, a deploy or T_Live
manifest, portfolio admission, a portfolio-gate change, portfolio KPIs, or a
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-25 | initial source-backed WTI seasonal-pullback card | G0 | APPROVED |
| v1 | 2026-07-25 | strict compile and targeted build validation complete | Q01 | PASS |
| v1 | 2026-07-25 | paced baseline handoff; no manual backtest launched | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | APPROVED | this card |
| Q01 Build Validation | 2026-07-25 | PASS: strict compile 0 errors/0 warnings; schema/spec/build checks PASS | `docs/ops/evidence/2026-07-25_qm5_20137_wti_seasonal_pullback_build_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-25 | ENQUEUED, pending, attempt 0 | work item `7dff45e1-d4c7-4f5c-b8e0-2f2ea254a725`; same evidence |
