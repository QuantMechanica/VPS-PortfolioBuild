---
ea_id: QM5_20110
slug: xti-xng-fri-rv
type: strategy
strategy_id: MEEK-HOELSCHER-ENERGY-DOW-2023_S04
source_id: MEEK-HOELSCHER-WTI-DOW-2023
status: APPROVED
g0_status: APPROVED
created: 2026-07-24
created_by: Research+Development
last_updated: 2026-07-24
source_citation: "Meek, Andrew C. and Hoelscher, Seth A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2213876. DOI 10.1080/23322039.2023.2213876."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Meek, Andrew C. and Hoelscher, Seth A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2213876."
    location: "Tables 2 and 6, limitations, and conclusion; DOI https://doi.org/10.1080/23322039.2023.2213876; complete open text https://www.econstor.eu/bitstream/10419/304091/1/10.1080_23322039.2023.2213876.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MEEK-HOELSCHER-WTI-DOW-2023]]"
concepts:
  - "[[concepts/cross-energy-weekday-relative-value]]"
  - "[[concepts/friday-energy-return-differential]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, relative-value, approximately-dollar-neutral-basket, atr-hard-stop, intraday-time-exit, low-frequency]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20110_XTI_XNG_FRI_RV_D1
expected_trade_frequency: "One paired XTI/XNG Friday-session package per eligible broker week; approximately 45-52 completed packages/year before holidays, synchronization, spread, news, and execution-safety gates."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.02
expected_dd_pct: 22.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_QUEUED
review_focus: "Falsify the Friday long-WTI/short-XNG differential after CFD session mapping, costs, equal-notional rounding, combined stop risk, and legging. Standalone component overlap is explicit; only Q09 may judge realized book correlation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, one_position_per_magic_symbol, basket_atomicity, friday_close, cfd_futures_basis, source_port_reduction, known_component_overlap, dollar_not_beta_neutral, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy-sleeve mission: R1 PASS one fully reviewed peer-reviewed open paper; R2 PASS fixed Friday long-XTI/short-XNG package, joint fixed-risk/equal-notional sizing, hard stops, atomic repair, and no-weekend exit; R3 PASS synchronized registered XTI/XNG D1 logical route; R4 PASS calendar/ATR arithmetic only with no machine learning, banned indicator, external runtime feed, grid, or martingale. Deterministic exact/fuzzy dedup returned CLEAN; known standalone Friday-leg overlap is disclosed."
---

# XTI/XNG Friday Relative-Value Basket

## Hypothesis

Meek and Hoelscher report heterogeneous Friday returns across two liquid
energy futures. WTI's Friday coefficient is positive and statistically
significant in all five reported conditional-variance models, while natural
gas has a consistently negative but statistically insignificant Friday
coefficient. A simultaneous long-WTI/short-natural-gas package can test that
one-session differential while targeting zero net dollar notional instead of
adding another outright energy-beta sleeve.

This is a falsification candidate, not a profitability or neutrality claim.
Equal USD notionals do not neutralize volatility, curve basis, gaps, financing,
contract construction, or nonlinear CFD behavior. Only the governed pipeline
may measure realized economics and correlation.

## Source and interpretation boundary

The sole lineage is the peer-reviewed, open-access Meek and Hoelscher (2023)
paper recorded at
`strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md`. Its complete
21-page repository copy was reviewed, including methods, all tables,
limitations, conclusion, disclosures, and references.

The paper combines front- and second-month futures around contract expiry and
uses close-to-close log returns from 2002 through 2021. Table 2 reports WTI
Friday coefficients from `+0.001017` to `+0.001550`; Table 6 reports
natural-gas Friday coefficients from `-0.000607` to `-0.000745`. The raw
long-WTI/short-XNG difference is about 17-23 basis points across model columns,
but the authors never test that pair, its covariance, equal-notional sizing,
Darwinex CFDs, or transaction-cost profitability.

The executable EA enters on the first Friday D1 tick and closes at the broker
Friday-close boundary. This approximates, but does not reproduce, the source's
ending-Friday close-to-close futures return. Futures-roll/CFD basis, the
omitted inter-bar gap, costs, holidays, legging, natural-gas tails, and sample
decay are binding kill risks.

## Non-duplicate decision

The deterministic check for slug `xti-xng-fri-rv`, strategy ID
`MEEK-HOELSCHER-ENERGY-DOW-2023_S04`, and mechanic `Friday D1 long XTI short
XNG equal-notional one-session relative-value basket` returned `CLEAN`.
Manual review establishes
`NO_IDENTICAL_TWO_LEG_PACKAGE / KNOWN_EXACT_COMPONENT_OVERLAP`:

- `QM5_20016_xti-xng-mon-rv` trades short XTI/long XNG on Monday under a
  different source sample and weekday effect.
- `QM5_12597_wti-fri-prem` independently owns an outright WTI long and has no
  XNG hedge, combined risk budget, package invariant, or orphan repair.
- `QM5_20094_xng-fri-short` independently owns an outright XNG short and has
  no WTI hedge, combined risk budget, package invariant, or orphan repair.
- Existing XTI/XNG ratio, return-spread, breakout, momentum, carry,
  volatility, and seasonal baskets require price state or longer formation
  windows rather than a locked one-session Friday differential.

Neither leg is authorized alone. The testable object is the jointly sized
package and its logical-basket return stream. Component overlap is not hidden
and pairing does not create a correlation waiver.

## Markets, timeframe, and cadence

- Host: `XTIUSD.DWX`, D1, magic slot 0.
- Foreign leg: `XNGUSD.DWX`, D1, magic slot 1.
- Logical tester symbol: `QM5_20110_XTI_XNG_FRI_RV_D1`.
- Decision cadence: at most one consumed attempt per broker week.
- Normal entry: first tradable tick of a broker-calendar Friday D1 bar.
- Normal exit: broker Friday at hour 21, before the weekend.
- Expected cadence: approximately 45-52 paired packages/year.
- Entire-package backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

Standalone XTI or XNG tests are invalid. Both current D1 bars must be
synchronized to the host decision.

## rules

The entry, management, and exit sections below are the complete authorized v1
baseline. A weekday, direction, standalone leg, gap filter, return filter,
trend filter, or hold-window change creates a new card.

## 4. Entry Rules

1. Require the exact `XTIUSD.DWX` D1 host, slot 0, registered foreign symbol,
   and all locked strategy inputs.
2. Evaluate entry only once on a genuine new host D1 bar whose broker weekday
   is Friday (`strategy_entry_dow=5`, Sunday=0).
3. Require the first observed host tick within
   `strategy_entry_grace_minutes=5` of the D1 open. A late attach remains flat
   for that broker week.
4. Require the current XTI and XNG D1 bar timestamps to match the host bar
   time, plus valid prior completed `ATR(20)`, bid/ask, point, tick-size,
   tick-value, contract-size, and volume metadata for both legs.
5. Require nonnegative spreads no greater than each leg's locked cap.
6. Require no owned position or prior same-week deal for either registered
   magic. Persist the weekly attempt before the news gate or order submission;
   a restart, news block, rejection, rollback, or stop cannot retry that week.
7. Jointly solve BUY `XTIUSD.DWX` and SELL `XNGUSD.DWX` volumes so:
   - the sum of both frozen ATR-stop losses is at most one framework
     `RISK_FIXED` package budget; and
   - rounded absolute USD notionals target 1:1 within
     `strategy_max_notional_error_pct=20`.
8. Place each hard stop at `3.0 * ATR(20)` from its own executable price. No
   take-profit is authorized.
9. Confirm the first leg before sending the second. If the second fails, close
   the first immediately and consume the week.

## 5. Exit Rules

1. Broker-side hard stop on either leg.
2. Every-tick malformed-package repair: a foreign magic, duplicate leg,
   wrong-direction pair, orphan, or actual-notional error above the locked cap
   closes all owned exposure.
3. At broker Friday hour 21 or later, close both legs before any new-entry
   logic. This explicit package close and the enabled framework Friday-close
   contract are intentionally redundant safety layers.
4. On the first new host D1 bar after entry, close both legs before considering
   any entry. This is a stale safety path, not an authorized weekend hold.
5. Close both after `strategy_max_hold_days=3` calendar days if the normal
   Friday boundary and next-D1 repair path were unavailable.
6. Framework kill-switch closure remains authoritative for both registered
   magics.

News filtering may block new risk only. It may never delay package repair,
Friday close, hard-stop handling, next-D1 close, or stale close.

## 6. Filters (No-Trade Module)

- Do not enter unless both `XTIUSD.DWX` and `XNGUSD.DWX` expose synchronized, closed D1 bars whose Friday date matches.
- Do not enter outside the first five minutes after the first tradable tick of the Friday D1 session.
- Do not enter when either leg lacks 20 complete D1 bars, has a stale bar older than three calendar days, has a non-positive quote, or cannot support a valid 3 x ATR(20) hard stop.
- Do not enter if the package marker already records an entry for that Friday, either leg already has an EA-owned position, either leg fails symbol/trade checks, or the calculated equal-notional sizes differ by more than 20% in absolute USD notional.
- Do not retry a rejected package later in the session. A partial second-leg failure triggers immediate first-leg rollback.

## 7. Trade Management Rules

- One position per magic and exactly two positions per healthy package.
- One long host leg and one short foreign leg; no pending-order lifecycle.
- Position/deal history plus a terminal-global marker makes the weekly attempt
  restart-safe.
- Manage both registered magics on every host tick, including foreign-leg
  kill-switch and close paths.
- No independent leg, same-week retry, scale-in, partial close, trailing stop,
  break-even move, price target, adaptive fit, random path, grid, martingale,
  pyramid, or external runtime feed.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | locked | registered foreign leg |
| `strategy_entry_dow` | 5 | [5] | locked Friday entry |
| `strategy_entry_grace_minutes` | 5 | [5] | first-bar-tick tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | per-leg hard-stop distance |
| `strategy_notional_ratio` | 1.0 | [1.0] | equal absolute USD notionals |
| `strategy_max_notional_error_pct` | 20.0 | [20.0] | post-rounding/fill package cap |
| `strategy_friday_close_hour_broker` | 21 | [21] | no-weekend package close |
| `strategy_max_hold_days` | 3 | [3] | stale guard only |
| `strategy_xti_max_spread_pts` | 1000 | [1000] | WTI entry spread cap |
| `strategy_xng_max_spread_pts` | 2500 | [2500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [20] | paired-order deviation |

There is no baseline parameter sweep.

## Kill criteria

- Retire below five completed paired packages per eligible year.
- Fail on a standalone leg, wrong weekday/direction, duplicate weekly entry,
  weekend hold, excess notional mismatch, unclosed orphan, nondeterminism,
  risk-mode mismatch, or any governed PF/DD failure.
- The generic tester can count leg deals; density must be verified as logical
  paired packages rather than inferred from raw leg count.
- Do not rescue failure by changing the weekday, holding across the weekend,
  adding a trend/return/gap filter, or retuning the hedge ratio.

## risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the complete two-leg package. The build must not
materialize a live setfile. Equal notional is not beta or volatility
neutrality; the dominant risks are natural-gas tails, futures/CFD construction,
first-tick timing, transaction costs, legging, rounded contract sizes,
Friday-close reliability, component overlap, and post-2021 decay.

## Strategy allowability check

- [x] R1: one fully reviewed peer-reviewed open paper and one source ID.
- [x] R2: fixed calendar, directions, lifecycle, hedge, repair, and risk.
- [x] R3: registered synchronized XTI/XNG D1 logical route.
- [x] R4: deterministic calendar/price/ATR arithmetic; no machine learning,
  banned indicator, external signal, grid, or martingale.
- [x] Expected package cadence exceeds the five-per-year Q02 floor.
- [x] Dedup CLEAN; exact standalone component overlap is disclosed.
- [x] One combined fixed-risk budget; no standalone test or live preset.

## Framework alignment

- no_trade: exact host/timeframe/slot and locked-input guards, synchronized
  bars, weekly attempt/deal history, ATR, spread, metadata, and news checks.
- trade_entry: fixed Friday directions, joint fixed-risk/equal-notional lot
  solve, frozen stops, and immediate partial-package rollback.
- trade_management: every-tick composition/notional/orphan repair, Friday
  close, next-D1 stale close, max-hold close, and foreign-magic kill-switch.
- trade_close: framework close helper on both legs plus broker hard stops.

## Safety boundary

This approval covers the card, deterministic registry allocation, EA build,
strict compile, one logical `RISK_FIXED` backtest setfile, and one paced Q02
enqueue. It does not authorize a live setfile, AutoTrading, `T_Live`, a
deploy/T_Live manifest, portfolio admission, portfolio-gate edits, portfolio
KPIs, or a correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-24 | initial source-backed cross-energy Friday package | Q01 | PENDING |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-24 | APPROVED under OWNER mission; R1-R4 PASS | this card |
| Q01 Build Validation | - | PENDING | `framework/EAs/QM5_20110_xti-xng-fri-rv/` |
| Q02 Baseline Screening | - | NOT QUEUED | logical basket only |
