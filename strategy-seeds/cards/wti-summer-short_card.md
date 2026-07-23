---
ea_id: QM5_20093
slug: wti-summer-short
strategy_id: BURAKOV-WTI-HALLOWEEN-2018_S02
source_id: BURAKOV-WTI-HALLOWEEN-2018
status: APPROVED
created: 2026-07-24
created_by: Research+Development
last_updated: 2026-07-24
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: R1 tier-B complete peer-reviewed source; R2 deterministic WTI June-October short regime with disclosed monthly renewal and V5 risk; R3 registered XTI D1 route; R4 structural calendar/ATR only, no ML or banned indicator; repository mechanic audit CLEAN."
source_citations:
  - type: academic_paper
    citation: "Burakov, D., Freidin, M. and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Section 3 alternative-two definition; Tables 2-3 West Texas row; https://www.econjournals.com/index.php/ijeep/article/view/6092"
    quality_tier: B
    role: primary
strategy_type_flags: [calendar-seasonality, monthly-renewal, short-only, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
expected_trade_frequency: "Five short WTI monthly packages/year, June-October; Q02 must verify five completed packages/year."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING
q02_status: QUEUED
q02_work_item_id: 41e49d0a-00dd-47c2-ace0-4bd1b1cb0c55
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, low_frequency, cfd_source_basis, portfolio_correlation]
---

# WTI June-October Summer Short

## Hypothesis

Burakov, Freidin and Solovyev report an average `-5.3%` West Texas summer
return from the last May close through the last October close in 1985-2016,
versus `+16.65%` in winter. Mechanize only that negative leg as a sparse WTI
short sleeve and let Q02 falsify persistence after CFD costs and financing.

## Source and interpretation boundary

The sole lineage is the complete open peer-reviewed 2018 paper. Section 3
defines alternative two as end-May through end-October for summer. Table 2
reports the WTI summer mean; Table 3 reports the winter/summer comparison at
`p=0.0096` (t-test) and `p=0.0031` (preferred Wilcoxon). These statistics do
not establish tradable Darwinex performance. The paper tests multiple energy
markets and partitions, ends in 2016, and uses an IMF West Texas series rather
than the Darwinex continuous CFD.

The source uses one seasonal interval. V5 renews at each June-October broker
month boundary to create five separately auditable fixed-risk packages. This
is disclosed execution plumbing, not a source-authored result.

## Concept and non-duplicate decision

This carrier shorts WTI only in June, July, August, September and October and
is flat November-May. `QM5_20015` is the disjoint winter-long source leg.
`QM5_12567` is a price-conditioned cumulative-RSI2 pullback. Existing WTI
calendar, event, trend and ratio carriers do not implement this complete
five-month unconditional summer-short regime. Realized portfolio correlation
remains a downstream kill test; this card changes no portfolio gate.

## Markets, timeframe and cadence

- Exact host: `XTIUSD.DWX`, D1, magic slot 0.
- Decision: first tradable D1 bar of each broker month.
- Expected cadence: exactly five eligible packages/year.
- Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1.

## Rules

The following entry, exit, filter, management, and fixed-risk rules are locked
for the initial Q02 baseline.

## Entry rules

- On the first D1 bar of June through October, close any prior-month package,
  then submit one SELL only after the prior position is absent.
- Consume the month attempt before downstream gates; never retry after a stop,
  rejection, restart, or missed boundary.
- Require completed-bar ATR(20), spread at most 1500 points, and a frozen
  `4.0 * ATR(20)` hard stop; no take-profit or price filter.
- Require exact constants, no same-magic position, and no same-month entry
  deal. Framework kill-switch and news gates remain authoritative.

## Exit rules

- Close at the first D1 boundary of the next broker month before renewal.
- Close and remain flat on the first November boundary.
- Close after 35 calendar days if a boundary is unavailable.
- No trailing stop, break-even, partial close, scale, grid, or martingale.

## Filters (No-Trade Module)

- Fail closed unless symbol/timeframe/slot and every locked parameter match.
- Zero modeled `.DWX` spread is valid; invalid price, spread, ATR, stop
  arithmetic, history, or persistent state fails closed.
- Friday close is disabled because the source interval spans weekends.

## Trade Management Rules

Management runs before entry-news gating, owns only the registered magic, and
retries a due strategy close on later ticks. The frozen broker stop remains
active intramonth.

## Parameters to test

| parameter | default | authorized baseline |
|---|---:|---:|
| `strategy_first_short_month` | 6 | 6 |
| `strategy_last_short_month` | 10 | 10 |
| `strategy_atr_period` | 20 | 20 |
| `strategy_atr_sl_mult` | 4.0 | 4.0 |
| `strategy_max_hold_days` | 35 | 35 |
| `strategy_max_spread_points` | 1500 | 1500 |

No sweep, neighboring month, direction flip, or price filter is authorized.

## Initial risk profile and kill criteria

Retire at Q02 for fewer than five completed packages/year, zero trades,
incorrect month/direction behavior, repeat attempts, nondeterminism, risk-mode
mismatch, or governed PF/DD failure. Futures/CFD basis, roll construction,
financing, gaps, multiple testing, post-publication decay, and book correlation
are explicit kill risks.

## Strategy allowability check

- [x] R1: complete named-author peer-reviewed open source, tier B.
- [x] R2: fixed months, direction, renewal, stop, spread and state rules.
- [x] R3: registered `XTIUSD.DWX` D1 route; no external runtime feed.
- [x] R4: calendar and ATR only; no ML or banned indicator.
- [x] Non-duplicate mechanic; complementary S01 is disclosed.

## Framework alignment

- no_trade: exact host/slot and locked baseline guard.
- trade_entry: first monthly D1 bar, June-October SELL, ATR stop.
- trade_management: boundary, out-of-season and stale close.
- trade_close: framework strategy close plus broker hard stop.

## Risk and safety boundary

Build and enqueue one `RISK_FIXED` backtest only. No live setfile, AutoTrading,
T_Live, deploy manifest, portfolio admission, or portfolio-gate change.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-24 | initial source-backed WTI summer-short build | Q02 | pending |
