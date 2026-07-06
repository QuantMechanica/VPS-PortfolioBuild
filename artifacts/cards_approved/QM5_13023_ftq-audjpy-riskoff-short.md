---
ea_id: QM5_13023
slug: ftq-audjpy-riskoff-short
type: strategy
strategy_id: RS-SAFEHAVEN-FX-2010_FTQ-AUDJPY-SHORT
source_id: RS-SAFEHAVEN-FX-2010
source_citation: "Ranaldo and Soederlind (2010), Safe Haven Currencies, Review of Finance; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum, Journal of Financial Economics."
source_citations:
  - type: academic_journal
    citation: "Ranaldo, Angelo and Paul Söderlind. Safe Haven Currencies. Review of Finance, 14(3), 2010."
    location: "https://academic.oup.com/rof/article/14/3/385/1592184"
    quality_tier: A
    role: primary
  - type: academic_journal
    citation: "Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen. Time Series Momentum. Journal of Financial Economics, 104(2), 2012."
    location: "https://docs.lhpedersen.com/TimeSeriesMomentum.pdf"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/RS-SAFEHAVEN-FX-2010]]"
concepts:
  - "[[concepts/flight-to-quality]]"
  - "[[concepts/safe-haven-currency]]"
  - "[[concepts/carry-unwind]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [flight-to-quality, short-only, sma-regime-stack, donchian-breakout, atr-hard-stop, channel-trail, time-stop, defensive-sleeve, fx-cross]
target_symbols: [AUDJPY.DWX]
primary_target_symbols: [AUDJPY.DWX]
markets: [AUDJPY.DWX]
single_symbol_only: true
logical_symbol: QM5_13023_FTQ_AUDJPY_RISKOFF_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 short-only AUDJPY breakdown gated by a stacked bearish SMA alignment on AUDJPY itself; episodic — approximately 5-12 entries/year clustered in risk-off regimes (2018Q4, 2020, carry unwinds), with sparse calm years possible."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-06
expected_pf: 1.12
expected_dd_pct: 14.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-06 (Claude, router d5199d43 flight-to-quality cell): R1 Ranaldo/Soederlind Review of Finance safe-haven currencies plus Moskowitz/Ooi/Pedersen JFE time-series momentum; R2 deterministic rules; R3 symbols verified in DWX matrix; R4 no ML/grid/martingale/external runtime data."
---

# Flight-To-Quality AUDJPY Short In Its Own Risk-Off Regime

## Source

- Source: [[sources/RS-SAFEHAVEN-FX-2010]]
- Primary citation: Ranaldo, Angelo and Paul Söderlind. "Safe Haven
  Currencies." Review of Finance, 14(3), 2010. URL:
  https://academic.oup.com/rof/article/14/3/385/1592184.
- Supplement: Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen.
  "Time Series Momentum." Journal of Financial Economics, 104(2), 2012.
  URL: https://docs.lhpedersen.com/TimeSeriesMomentum.pdf — documents FX
  time-series momentum including crisis performance.

## Hypothesis

AUD/JPY is the canonical FX risk barometer: a high-beta carry currency
(AUD) quoted against the classic funding safe-haven (JPY). Ranaldo and
Söderlind document that safe-haven currencies such as the yen appreciate
systematically when risk appetite deteriorates; risk-off episodes therefore
produce persistent AUDJPY downtrends as carry positions unwind and JPY
strengthens. A short-only D1 momentum system on AUDJPY, active only in its
OWN bear regime, captures this defensive flight-to-quality premium with no
external data dependency — the pair itself is the risk gauge. The card is a
defensive-sleeve diversifier: it earns in exactly the risk-off phases where
the book's long-risk sleeves suffer.

## Mechanism

- Regime gate (self-contained, no cross-symbol reads): only consider
  entries while the AUDJPY D1 close is below its SMA(`strategy_sma_regime`,
  default 200) — the pair is in a bear regime.
- Momentum stack gate: only consider entries while the AUDJPY D1 close is
  below its SMA(`strategy_sma_mom`, default 50) AND that SMA(50) is itself
  below the SMA(200) — a stacked bearish alignment (price < fast SMA < slow
  SMA) confirming the downtrend is established, not a one-bar dip.
- Trigger: a D1 close below the Donchian(`strategy_donchian_entry`,
  default 20) low inside both gates opens a short. The long side never
  trades: short-only by design.
- Exit engine: ATR hard stop, Donchian high trail (cover on close above),
  SMA(50) reclaim exit, and a max-hold time stop.

## Markets And Timeframe

- Traded symbol: `AUDJPY.DWX` only (`single_symbol_only: true`). Verified in
  the DWX symbol matrix (enabled, canonical name verified) with D1 history
  2017-2026 on T1-T5.
- Period: `D1`.
- Fully self-contained: every input is computed from AUDJPY.DWX bars — no
  cross-symbol data reads, so backtest and live environments are identical.
- Expected trade frequency: approximately 5-12 entries/year, clustered in
  risk-off regimes (2018Q4, 2020, carry-unwind episodes); sparse calm years
  are possible. DL-076 pooled-OOS (PASS_LOWFREQ) may apply at Q04 if the
  yearly distribution is lumpy.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, Donchian levels,
  broker time, and V5 framework state only. No VIX feed, macro CSV, API, or
  ML input is consumed at runtime.

## Rules

### Entry

- Evaluate only on a new D1 bar of the host chart, using completed bars.
- Entry Short, all three conditions on the same AUDJPY D1 close:
  - regime gate: close < SMA(`strategy_sma_regime`, default 200);
  - momentum stack: close < SMA(`strategy_sma_mom`, default 50) AND
    SMA(`strategy_sma_mom`) < SMA(`strategy_sma_regime`) — stacked bearish
    alignment;
  - trigger: close < Donchian(`strategy_donchian_entry`, default 20) low of
    the prior bars.
- Entry Long: never. Short-only by design.
- One position at a time: no entry while a position is open for this magic.
- No entry if spread exceeds `strategy_max_spread_points`.

### Exit & Stops

- Hard stop: fixed SL at ATR(`strategy_atr_period`, default 14) times
  `strategy_atr_sl_mult` (default 2.5) from entry price.
- Channel trail: cover on a D1 close above the
  Donchian(`strategy_donchian_trail`) high (default 15).
- SMA reclaim exit: cover on a D1 close back above
  SMA(`strategy_sma_mom`, default 50) — the risk-off downtrend leg that
  justified the position has stalled.
- Time stop: close after `strategy_max_hold_bars` D1 bars (default 40).
- Friday close remains enabled by the V5 framework.

## Validation Note (smoke window — REQUIRED for the builder)

This is a REGIME-GATED episodic EA: it is deliberately SILENT outside
risk-off regimes. A calm-year smoke window (e.g. 2024) yields zero trades BY
DESIGN and must not be read as a build defect (q01_trade_generation false
positive). **Smoke/validation runs MUST use 2022** (canonical bear-regime
year: equity index below SMA200 for most of the year, risk-off alignment) —
FromDate 2022.01.01, ToDate 2022.12.31. Q02+ gates run full history and are
unaffected. Expected smoke behavior in 2022: multiple entries.

## Risk & Filters

- Only trade AUDJPY.DWX on D1 with the registered magic slot.
- Skip entries when D1 history, ATR, SMA, Donchian levels, or spread data
  are unavailable.
- Skip entries when spread exceeds the configured cap.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Short-only; the long branch does not exist.
- No pyramiding, gridding, martingale, or partial close.
- The Donchian(15) high trail and the SMA(50) reclaim exit are the only
  position management.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_sma_regime
  default: 200
  sweep_range: [150, 200, 250]
- name: strategy_sma_mom
  default: 50
  sweep_range: [30, 50, 100]
- name: strategy_donchian_entry
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_donchian_trail
  default: 15
  sweep_range: [10, 15, 20]
- name: strategy_max_hold_bars
  default: 40
  sweep_range: [25, 40, 55]
- name: strategy_max_spread_points
  default: 40
  sweep_range: [30, 40, 60]

## Expected Behavior

- Flat stretches in risk-on regimes (gates closed); bursts of shorts in
  risk-off regimes as carry unwinds and JPY strengthens — return profile is
  intentionally episodic and defensive at the book level.
- Winners ride carry-unwind legs via the Donchian(15) trail; losers are
  failed breakdowns cut at the ATR hard stop or released on the SMA(50)
  reclaim.
- expected_pf 1.12, expected_dd_pct 14, approximately 8 trades/year. The
  frequency floor (Operating Rules 2026-07-03, >=5 trades/yr) is expected to
  hold on pooled history; calm single years can print few trades — evaluate
  against DL-076 pooled-OOS where applicable.

## Author Claims

The sources establish the safe-haven-currency mechanism (JPY appreciation
under risk-off) and FX time-series momentum including crisis performance in
general; this card imports no source performance number. Q02 and later
phases must validate or reject the mechanical short-only AUDJPY realization
on Darwinex bars.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one setfile for
AUDJPY.DWX. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the
portfolio gate. FX commission is the known kill-risk for FX sleeves
(approximately $45/trade class); at approximately 8 trades/year this card is
structurally low-frequency, but Q02 gross and Q04 commission-injected
economics remain the judges.

## Initial Risk Profile

- expected_pf: 1.12.
- expected_dd_pct: 14.
- expected_trade_frequency: approximately 5-12 entries/year.
- risk_class: medium — shorts trade with the risk-off flow but against the
  long-run carry drift of the pair; entries only occur under a stacked
  bearish SMA alignment with ATR stop, channel trail, SMA reclaim exit, and
  time stop bounding each trade.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Ranaldo/Söderlind Review of Finance safe-haven
  currency literature plus Moskowitz/Ooi/Pedersen JFE time-series momentum.
- [x] R2 mechanical: fixed SMA(200) regime gate, SMA(50)/SMA(200) stacked
  bearish alignment, Donchian(20) breakdown trigger, ATR hard stop,
  Donchian(15) trail, SMA(50) reclaim exit, and time stop.
- [x] R3 testable: `AUDJPY.DWX` exists in the DWX symbol matrix with D1
  history 2017-2026.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: the short-index crisis cell is owned by QM5_13019 and
  the gold flight-to-quality long by QM5_13022; this card is the
  self-contained FX-cross realization of the defensive cell, and no existing
  JPY-cross sleeve is a short-only risk-off momentum system.

## Framework Alignment

- no_trade: host-symbol/D1 guard, magic-slot guard, parameter guard, spread
  cap, bear-regime gate, stacked-SMA alignment gate, and valid data checks.
- trade_entry: short-only Donchian(20) D1 breakdown inside both gates.
- trade_management: Donchian(15) high trail, SMA(50) reclaim monitoring, and
  max-hold tracking.
- trade_close: ATR hard stop, channel-trail cover, SMA reclaim cover, time
  stop, and framework Friday close.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce the card-scaled minimum trade
count on pooled 2017-2026 history, if Q02 PF is below 1.0 after costs, if
the stacked-SMA gate degenerates (never open or always open) on Darwinex
AUDJPY history, or if Q04 commission-injected economics kill the after-cost
edge.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-06 | initial flight-to-quality AUDJPY short card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-06 | APPROVED | this card |
| Q01 Build Validation | 2026-07-06 | PENDING | `artifacts/qm5_13023_build_result.json` |
| Q02 Baseline Screening | 2026-07-06 | PENDING | enqueue after compile |
