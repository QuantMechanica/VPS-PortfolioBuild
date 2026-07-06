---
ea_id: QM5_13019
slug: crisis-short-idx-breakout
type: strategy
strategy_id: MOP-TSMOM-2012_CRISIS-SHORT-IDX
source_id: MOP-TSMOM-2012
source_citation: "Moskowitz, Ooi and Pedersen (2012), Time Series Momentum, Journal of Financial Economics; Fung and Hsieh (2001), The Risk in Hedge Fund Strategies: Theory and Evidence from Trend Followers, Review of Financial Studies."
source_citations:
  - type: academic_journal
    citation: "Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen. Time Series Momentum. Journal of Financial Economics, 104(2), 2012."
    location: "https://docs.lhpedersen.com/TimeSeriesMomentum.pdf"
    quality_tier: A
    role: primary
  - type: academic_journal
    citation: "Fung, William and David A. Hsieh. The Risk in Hedge Fund Strategies: Theory and Evidence from Trend Followers. Review of Financial Studies, 14(2), 2001."
    location: "https://faculty.fuqua.duke.edu/~dah7/RFS2001.pdf"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/MOP-TSMOM-2012]]"
concepts:
  - "[[concepts/crisis-alpha]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/regime-filter]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [short-only, regime-gate-sma200, donchian-breakout, vol-expansion-filter, atr-hard-stop, time-stop, crisis-alpha]
target_symbols: [GDAXI.DWX, WS30.DWX]
primary_target_symbols: [GDAXI.DWX]
markets: [GDAXI.DWX, WS30.DWX]
single_symbol_only: true
logical_symbol: QM5_13019_CRISIS_SHORT_IDX_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 short-only index breakout gated by bear regime plus vol expansion; episodic — approximately 5-10 entries/year/symbol clustered in bear regimes (2018Q4, 2020, 2022), with zero-trade calm years possible."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-06
expected_pf: 1.15
expected_dd_pct: 15.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-06 (Claude, Fable program #5): R1 Moskowitz/Ooi/Pedersen JFE time-series momentum crisis-alpha plus Fung/Hsieh RFS trend-follower sources; R2 deterministic rules below; R3 symbols verified in DWX matrix; R4 no ML/grid/martingale/external runtime data."
---

# Crisis-Alpha Short-Only Index Breakout

## Source

- Source: [[sources/MOP-TSMOM-2012]]
- Primary citation: Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje
  Pedersen. "Time Series Momentum." Journal of Financial Economics, 104(2),
  2012. URL: https://docs.lhpedersen.com/TimeSeriesMomentum.pdf.
- Supplement: Fung, William and David A. Hsieh. "The Risk in Hedge Fund
  Strategies: Theory and Evidence from Trend Followers." Review of Financial
  Studies, 14(2), 2001. URL: https://faculty.fuqua.duke.edu/~dah7/RFS2001.pdf.

## Hypothesis

Time-series momentum delivers its strongest returns in extreme equity market
environments — the documented crisis-alpha property of trend following
(Moskowitz/Ooi/Pedersen; Fung/Hsieh model trend followers as holders of
lookback-straddle-like convex payoffs). This card isolates exactly that
convex slice on equity indices: a short-only D1 breakout that is active only
in bear regimes with expanding volatility. It is deliberately convex where
the current book's long-biased index sleeves are concave, so it earns its
seat as a diversifier even at modest standalone PF.

## Mechanism

- Regime gate: only consider entries while the D1 close is below the
  SMA(200) — the market is in a bear regime.
- Vol expansion gate: only consider entries while ATR(14) is greater than
  ATR(14) measured 20 bars earlier — volatility is expanding, not decaying.
- Trigger: a D1 close below the Donchian(40) low inside both gates opens a
  short. The long side never trades: short-only by design.
- Exit engine: ATR hard stop, Donchian(15) high trail (cover on close
  above), and a max-hold time stop.

## Markets And Timeframe

- Symbols: `GDAXI.DWX` (primary) and `WS30.DWX` (secondary), built and
  tested per-symbol (`single_symbol_only: true`; the dispatcher fans out one
  build per target symbol — this is not a basket).
- Period: `D1`.
- Expected trade frequency: approximately 5-10 entries/year/symbol,
  clustered in bear regimes (2018Q4, 2020, 2022); zero-trade calm years are
  possible and expected. DL-076 pooled-OOS (PASS_LOWFREQ) may apply at Q04
  for this episodic shape.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker time, and V5
  framework state only. No VIX feed, macro CSV, API, or ML input is consumed
  at runtime.

## Rules

### Entry

- Evaluate only on a new D1 bar of the host chart, using completed bars.
- Entry Short, all three conditions on the same D1 close:
  - close < Donchian(`strategy_donchian_entry`) low of the prior bars
    (default 40);
  - close < SMA(`strategy_sma_regime`) (default 200);
  - ATR(`strategy_atr_period`) > ATR(`strategy_atr_period`) from
    `strategy_vol_expansion_lag` bars earlier (default 20) — vol expansion.
- Entry Long: never. Short-only by design.
- One position at a time: no entry while a position is open for this magic.
- No entry if spread exceeds `strategy_max_spread_points`.

### Exit & Stops

- Hard stop: fixed SL at ATR(`strategy_atr_period`, default 14) times
  `strategy_atr_sl_mult` (default 3.0) from entry price.
- Channel trail: cover on a D1 close above the
  Donchian(`strategy_donchian_trail`) high (default 15).
- Time stop: close after `strategy_max_hold_bars` D1 bars (default 25).
- Friday close remains enabled by the V5 framework.

## Risk & Filters

- Only trade the configured index symbol on D1 with the registered magic
  slot per symbol.
- Skip entries when D1 history, ATR, SMA, Donchian levels, or spread data
  are unavailable.
- Skip entries when spread exceeds the configured cap.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Short-only; the long branch does not exist.
- No pyramiding, gridding, martingale, or partial close.
- The Donchian(15) high trail is the only position management.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_donchian_entry
  default: 40
  sweep_range: [30, 40, 55]
- name: strategy_sma_regime
  default: 200
  sweep_range: [150, 200, 250]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_vol_expansion_lag
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 3.5]
- name: strategy_donchian_trail
  default: 15
  sweep_range: [10, 15, 20]
- name: strategy_max_hold_bars
  default: 25
  sweep_range: [15, 25, 35]
- name: strategy_max_spread_points
  default: 150
  sweep_range: [100, 150, 250]

## Expected Behavior

- Multi-quarter flat stretches in bull regimes; bursts of shorts in bear
  regimes with expanding volatility — return profile is intentionally
  episodic and right-skewed at the book level (crisis alpha).
- Winners ride panic legs via the Donchian(15) trail; losers are failed
  breakdowns cut at the ATR hard stop.
- expected_pf 1.15, expected_dd_pct 15, approximately 7 trades/year/symbol.
  The frequency floor (Operating Rules 2026-07-03, >=5 trades/yr) is
  expected to hold on pooled history; calm single years can print zero
  trades — evaluate against DL-076 pooled-OOS where applicable.

## Author Claims

The sources establish the crisis-alpha property of time-series momentum in
general; this card imports no source performance number. Q02 and later
phases must validate or reject the mechanical short-only index realization
on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.15.
- expected_dd_pct: 15.
- expected_trade_frequency: approximately 5-10 entries/year/symbol.
- risk_class: medium — shorts run against the long-term index drift, but
  entries only occur under a bear-regime gate with ATR stop, channel trail,
  and time stop bounding each trade.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Moskowitz/Ooi/Pedersen JFE time-series momentum
  and Fung/Hsieh RFS trend-follower crisis-alpha literature.
- [x] R2 mechanical: fixed Donchian(40) breakdown, SMA(200) regime gate,
  ATR(14) vol-expansion comparison, ATR hard stop, Donchian(15) trail, and
  time stop.
- [x] R3 testable: `GDAXI.DWX` and `WS30.DWX` exist in the DWX symbol matrix
  with D1 history 2018-2026.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: the current index sleeves are long-biased breakout,
  zone, and momentum systems; no existing sleeve is a short-only bear-regime
  vol-expansion breakout.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one setfile per index
symbol. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the
portfolio gate.

## Framework Alignment

- no_trade: host-symbol/D1 guard, magic-slot guard, parameter guard, spread
  cap, bear-regime gate, vol-expansion gate, and valid data checks.
- trade_entry: short-only Donchian(40) D1 breakdown inside both gates.
- trade_management: Donchian(15) high trail and max-hold tracking.
- trade_close: ATR hard stop, channel-trail cover, time stop, and framework
  Friday close.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce the card-scaled minimum trade
count on pooled 2018-2026 history, if Q02 PF is below 1.0 after costs, or if
the regime/vol gates degenerate (never open or always open) on Darwinex
index history.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-06 | initial crisis-alpha short-only index breakout card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-06 | APPROVED | this card |
| Q01 Build Validation | 2026-07-06 | PENDING | `artifacts/qm5_13019_build_result.json` |
| Q02 Baseline Screening | 2026-07-06 | PENDING | enqueue after compile |
