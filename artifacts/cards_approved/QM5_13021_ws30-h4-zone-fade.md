---
ea_id: QM5_13021
slug: ws30-h4-zone-fade
type: strategy
strategy_id: QM5-10094-GHH4ZONE-PORT-2026-07-06_WS30
source_id: QM5-10094-GHH4ZONE-PORT-2026-07-06
source_citation: "QM5_10094 gh-h4-zone card + Q04 graveyard mining 2026-07-06 (docs/research/Q04_GRAVEYARD_MINING_2026-07-06.md); original external source: phatnomenal/blackXAU_AUTOMATED-BOT-TRADE (blackXAU2.mq5, GitHub)."
source_citations:
  - type: derivative_internal
    citation: "QM5_10094 gh-h4-zone card + Q04 graveyard mining 2026-07-06 (docs/research/Q04_GRAVEYARD_MINING_2026-07-06.md)."
    location: "docs/research/Q04_GRAVEYARD_MINING_2026-07-06.md"
    quality_tier: B
    role: primary
  - type: github_repository
    citation: "phatnomenal. blackXAU_AUTOMATED-BOT-TRADE, blackXAU2.mq5 (zone update, breakout, and retest entry logic) — original external source of the QM5_10094 gh-h4-zone card."
    location: "https://github.com/phatnomenal/blackXAU_AUTOMATED-BOT-TRADE/blob/main/blackXAU2.mq5"
    quality_tier: B
    role: supplement
sources:
  - "[[sources/QM5-10094-GHH4ZONE-PORT-2026-07-06]]"
concepts:
  - "[[concepts/support-resistance]]"
  - "[[concepts/session-levels]]"
  - "[[concepts/rejection-fade]]"
indicators:
  - "[[indicators/daily-high-low]]"
  - "[[indicators/atr]]"
strategy_type_flags: [zone-fade, session-levels, rejection-close, atr-hard-stop, vol-regime-filter, time-stop]
target_symbols: [WS30.DWX]
primary_target_symbols: [WS30.DWX]
markets: [WS30.DWX]
single_symbol_only: true
logical_symbol: QM5_13021_WS30_H4_ZONE_FADE
period: H4
timeframes: [H4, D1]
expected_trade_frequency: "H4 prior-day-zone rejection fade on WS30 with a high-vol regime filter; estimate 20-30 entries/year after the touch-and-reject condition and the ATR percentile filter."
expected_trades_per_year_per_symbol: 25
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-06
expected_pf: 1.12
expected_dd_pct: 12.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [survivor_port_purity, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-06 (Claude, Fable program #5): R1 derivative-internal QM5_10094 gh-h4-zone card plus Q04 graveyard mining 2026-07-06 port precedent and original GitHub source; R2 deterministic rules below; R3 symbols verified in DWX matrix; R4 no ML/grid/martingale/external runtime data."
---

# WS30 H4 Prior-Day Zone Fade

## Source

- Source: [[sources/QM5-10094-GHH4ZONE-PORT-2026-07-06]]
- Primary citation (derivative internal): QM5_10094 gh-h4-zone card + Q04
  graveyard mining 2026-07-06. Evidence:
  `docs/research/Q04_GRAVEYARD_MINING_2026-07-06.md` (gh-h4-zone: index-only,
  ~28 tr/yr, medPF 1.37 gross; GDAXI folds missed the Q04 net floor by 0.05
  twice — the cleanest honest near-miss on low-commission symbols; a
  WS30/SP500-to-NDX port of the zone mechanism is the named design
  candidate). Original card:
  `framework/EAs/QM5_10094_gh-h4-zone/docs/strategy_card.md`.
- Supplement (original external source of the 10094 family): phatnomenal,
  blackXAU_AUTOMATED-BOT-TRADE, `blackXAU2.mq5` — zone update, breakout, and
  retest entry logic. URL:
  https://github.com/phatnomenal/blackXAU_AUTOMATED-BOT-TRADE/blob/main/blackXAU2.mq5.

## Hypothesis

The gh-h4-zone family (QM5_10094, GDAXI H4) died at Q04 as an honest
near-miss: real gross edge (medPF 1.37), net floor missed by 0.05 twice,
with fold instability sourced in high-volatility regimes. This card ports
the zone mechanism to `WS30.DWX` — the lower-commission index — and filters
out the instability source directly: prior-day session high/low zones traded
as H4 rejection fades, with entries suppressed whenever H4 ATR is in its top
quintile. Port precedent: the hand-port 12567-to-XNGUSD full-cascade rule —
this port runs the FULL Q02-Q08 cascade and survivor-port purity applies (no
parameter re-tuning against the graveyard evidence).

## Mechanism

- Zones: each new D1 session defines two levels — the prior D1 session high
  and the prior D1 session low.
- Rejection fade at the upper zone: an H4 bar that trades into the prior-day
  high but closes back below it shows supply at the level; fade it short.
- Rejection fade at the lower zone: an H4 bar that trades into the prior-day
  low but closes back above it shows demand; fade it long.
- Instability filter: skip all entries when ATR(14, H4) is above its 80th
  percentile of the trailing 250 H4 bars — the high-vol regime that made the
  GDAXI folds unstable is excluded by rule.
- Exit engine: ATR hard stop, opposite zone as target, and a max-hold time
  stop.

## Markets And Timeframe

- Symbol: `WS30.DWX`.
- Period: `H4` (entries and exits on H4 bar close; zones derived from the
  prior D1 session high/low).
- Expected trade frequency: approximately 20-30 entries/year before Q02
  validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 H4/D1 OHLC, spread, ATR, broker time, and V5
  framework state only. No external feed, CSV, API, or ML input is consumed
  at runtime.

## Rules

### Entry

- Evaluate only on a completed `WS30.DWX` H4 bar.
- Compute zones from the prior D1 session: `zone_high` = prior D1 high,
  `zone_low` = prior D1 low.
- Entry Short (upper-zone rejection): the completed H4 bar's high touched or
  exceeded `zone_high` AND the H4 close is back below `zone_high`.
- Entry Long (lower-zone rejection): the completed H4 bar's low touched or
  undercut `zone_low` AND the H4 close is back above `zone_low`.
- Instability filter: skip entirely when ATR(`strategy_atr_period_h4`,
  default 14, H4) is above the `strategy_vol_pct_threshold` percentile
  (default 80) of its trailing `strategy_vol_pct_window_h4` H4 bars
  (default 250).
- One position at a time: no entry while a position is open for this magic.
- No entry if `WS30.DWX` spread exceeds `strategy_max_spread_points`.

### Exit & Stops

- Hard stop: fixed SL at ATR(`strategy_atr_period_h4`, default 14, H4) times
  `strategy_atr_sl_mult` (default 2.0) from entry price.
- Target: the opposite zone — shorts target `zone_low`, longs target
  `zone_high`, fixed at entry.
- Time stop: close after `strategy_max_hold_bars_h4` H4 bars (default 12).
- Friday close remains enabled by the V5 framework.

## Risk & Filters

- Only trade `WS30.DWX` on the H4 chart with `qm_magic_slot_offset=0`.
- Skip entries when H4/D1 history, ATR series, the percentile window, or
  spread data are unavailable.
- Skip entries when spread exceeds the configured cap.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short at opposing zones.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- Stop and target are fixed at entry; only the time stop can close earlier.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_atr_period_h4
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
- name: strategy_vol_pct_threshold
  default: 80
  sweep_range: [70, 80, 90]
- name: strategy_vol_pct_window_h4
  default: 250
  sweep_range: [180, 250, 350]
- name: strategy_max_hold_bars_h4
  default: 12
  sweep_range: [8, 12, 16]
- name: strategy_max_spread_points
  default: 100
  sweep_range: [60, 100, 180]

## Expected Behavior

- Range-day harvesting: fades trigger on days where price probes but fails
  to break the prior-day extremes; trending breakout days produce the losing
  stop-outs.
- The vol-percentile filter suppresses activity in panic regimes — expect
  gaps in activity during 2020-03/2022-style stretches, by design.
- expected_pf 1.12, expected_dd_pct 12, approximately 25 trades/year on H4.
  Success criterion versus the parent: WS30 commission (~$4.4/trade, index
  class) plus the regime filter must convert the parent's 0.05 net miss into
  a net pass. Port runs the full Q02-Q08 cascade — no gate skipping.

## Author Claims

The graveyard evidence documents an honest gross edge in the parent family
(medPF 1.37) that failed net by 0.05 on GDAXI; no performance number is
imported for the WS30 realization. Q02 and later phases must validate or
reject the port on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.12.
- expected_dd_pct: 12.
- expected_trade_frequency: approximately 20-30 entries/year.
- risk_class: medium — fades carry breakout risk at the zones, bounded by
  the ATR hard stop, fixed target, and 12-bar time stop.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: derivative-internal port of the carded QM5_10094
  gh-h4-zone family with graveyard-mining evidence artifact plus the
  original GitHub source carried over.
- [x] R2 mechanical: fixed prior-day zones, deterministic touch-and-reject
  H4 close condition, ATR percentile filter, ATR hard stop, fixed opposite-
  zone target, and time stop.
- [x] R3 testable: `WS30.DWX` exists in the DWX symbol matrix with H4 and D1
  history 2018-2026.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: the parent QM5_10094 is a GDAXI M5 breakout-retest
  (momentum direction, long-only); this is a WS30 H4 rejection FADE
  (counter-direction at the zone, symmetric, vol-filtered) — same zone
  primitive, different symbol, timeframe, and trade direction; 10094/GDAXI
  remains in flight in the Q05 salvage lane with no overlap in symbol or
  mechanism direction.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `WS30.DWX` H4
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the
portfolio gate.

## Framework Alignment

- no_trade: WS30/H4 host guard, magic-slot guard, parameter guard, spread
  cap, vol-percentile regime filter, and valid data checks.
- trade_entry: prior-day zone touch-and-reject H4 close fade, long and
  short.
- trade_management: max-hold tracking; stop and target fixed at entry.
- trade_close: ATR hard stop, opposite-zone target, time stop, and framework
  Friday close.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce the card-scaled minimum trade
count, if Q02 PF is below 1.0 after costs, if the vol filter degenerates
(never or always active) on WS30 H4 history, or if the port fails the same
Q04 net floor the parent failed — the family is then dead on low-commission
symbols too and must not be re-mined.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-06 | initial WS30 H4 zone-fade port of the gh-h4-zone family | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-06 | APPROVED | this card |
| Q01 Build Validation | 2026-07-06 | PENDING | `artifacts/qm5_13021_build_result.json` |
| Q02 Baseline Screening | 2026-07-06 | PENDING | enqueue after compile |
