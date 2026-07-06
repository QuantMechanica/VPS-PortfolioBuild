---
ea_id: QM5_13022
slug: ftq-xau-riskoff-long
type: strategy
strategy_id: BL-SAFEHAVEN-2010_FTQ-XAU-RISKOFF
source_id: BL-SAFEHAVEN-2010
source_citation: "Baur and Lucey (2010), Is Gold a Hedge or a Safe Haven? An Analysis of Stocks, Bonds and Gold, The Financial Review; Baur and McDermott (2010), Is gold a safe haven? International evidence, Journal of Banking & Finance."
source_citations:
  - type: academic_journal
    citation: "Baur, Dirk G. and Brian M. Lucey. Is Gold a Hedge or a Safe Haven? An Analysis of Stocks, Bonds and Gold. The Financial Review, 45(2), 2010."
    location: "https://onlinelibrary.wiley.com/doi/10.1111/j.1540-6288.2010.00244.x"
    quality_tier: A
    role: primary
  - type: academic_journal
    citation: "Baur, Dirk G. and Thomas K. McDermott. Is gold a safe haven? International evidence. Journal of Banking & Finance, 34(8), 2010."
    location: "https://www.sciencedirect.com/science/article/pii/S0378426609003343"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/BL-SAFEHAVEN-2010]]"
concepts:
  - "[[concepts/flight-to-quality]]"
  - "[[concepts/safe-haven-asset]]"
  - "[[concepts/regime-filter]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [flight-to-quality, regime-gate-cross-symbol, long-only, donchian-breakout, atr-hard-stop, regime-flip-exit, time-stop, defensive-sleeve]
target_symbols: [XAUUSD.DWX]
primary_target_symbols: [XAUUSD.DWX]
markets: [XAUUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13022_FTQ_XAU_RISKOFF_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 long-only gold breakout gated by a bear-equity regime read from a cross-symbol data input; episodic — approximately 4-9 entries/year clustered in equity risk-off regimes (2018Q4, 2020, 2022), with zero-trade calm years possible."
expected_trades_per_year_per_symbol: 6
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
hard_rules_at_risk: [low_frequency_sample, env_symbol_mapping, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-06 (Claude, router d5199d43 flight-to-quality cell): R1 Baur/Lucey Financial Review gold safe-haven plus Baur/McDermott JBF international safe-haven evidence; R2 deterministic rules; R3 symbols verified in DWX matrix; R4 no ML/grid/martingale/external runtime data."
---

# Flight-To-Quality Gold Long In Equity Risk-Off Regimes

## Source

- Source: [[sources/BL-SAFEHAVEN-2010]]
- Primary citation: Baur, Dirk G. and Brian M. Lucey. "Is Gold a Hedge or a
  Safe Haven? An Analysis of Stocks, Bonds and Gold." The Financial Review,
  45(2), 2010. URL:
  https://onlinelibrary.wiley.com/doi/10.1111/j.1540-6288.2010.00244.x.
- Supplement: Baur, Dirk G. and Thomas K. McDermott. "Is gold a safe haven?
  International evidence." Journal of Banking & Finance, 34(8), 2010. URL:
  https://www.sciencedirect.com/science/article/pii/S0378426609003343.

## Hypothesis

Gold's safe-haven property is regime-conditional: Baur/Lucey and
Baur/McDermott document that gold acts as a safe haven for equities
specifically during periods of equity market stress, not unconditionally.
Trading gold long ONLY while the equity market is in a bear regime isolates
that defensive flight-to-quality premium instead of diluting it across calm
regimes where gold is at best an uncorrelated hedge. The card is a
defensive-sleeve diversifier for the book: it is designed to earn precisely
when the long-biased equity sleeves are losing.

## Mechanism

- Equity regime gate (cross-symbol DATA input, never traded): only consider
  entries while the D1 close of the regime symbol (input
  `strategy_regime_symbol`, default `SP500.DWX`) is below its
  SMA(`strategy_regime_sma`, default 200) — the equity market is in a bear
  regime.
- Gold own-momentum gate: only consider entries while the XAUUSD D1 close is
  above its own SMA(`strategy_mom_sma`, default 50). This guards against
  liquidation-cascade phases where gold sells off WITH equities (e.g.
  March 2020): the flight-to-quality bid must already be visible in gold
  itself.
- Trigger: a D1 close above the Donchian(`strategy_donchian_entry`,
  default 20) high inside both gates opens a long. The short side never
  trades: long-only by design.
- Exit engine: ATR hard stop, regime-flip exit (regime symbol closes back
  above its SMA), Donchian low trail, and a max-hold time stop.

## Markets And Timeframe

- Traded symbol: `XAUUSD.DWX` only (`single_symbol_only: true`). Verified in
  the DWX symbol matrix with D1 history 2017-2026 on T1-T5.
- Regime symbol: `SP500.DWX` is a DATA input only — it is never traded, never
  receives orders, and carries no magic slot. `SP500.DWX` exists
  backtest-only (custom symbol, OWNER-provided ticks 2018-07 onward; the
  broker does not route orders on SP500), which is acceptable here precisely
  because it is read-only regime input. See Risk for the mandatory live
  symbol mapping.
- Period: `D1`.
- Expected trade frequency: approximately 4-9 entries/year, clustered in
  bear-equity regimes (2018Q4, 2020, 2022); zero-trade calm years are
  possible and expected. DL-076 pooled-OOS (PASS_LOWFREQ) may apply at Q04
  for this episodic shape.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC for XAUUSD.DWX and the regime symbol,
  spread, ATR, SMA, Donchian levels, broker time, and V5 framework state
  only. No VIX feed, macro CSV, API, or ML input is consumed at runtime.

## Rules

### Entry

- Evaluate only on a new D1 bar of the host chart, using completed bars.
- Entry Long, all three conditions on the same D1 close:
  - regime gate: D1 close of the regime symbol
    (`strategy_regime_symbol`, default `SP500.DWX`) <
    SMA(`strategy_regime_sma`, default 200) of the regime symbol;
  - momentum gate: XAUUSD D1 close > SMA(`strategy_mom_sma`, default 50) of
    XAUUSD;
  - trigger: XAUUSD D1 close > Donchian(`strategy_donchian_entry`,
    default 20) high of the prior bars.
- Entry Short: never. Long-only by design.
- Fail-closed: if the regime symbol's D1 series or its SMA cannot be
  computed (missing symbol, no data, insufficient history), NO entry is
  taken. The regime gate never defaults to open.
- One position at a time: no entry while a position is open for this magic.
- No entry if spread exceeds `strategy_max_spread_points`.

### Exit & Stops

- Hard stop: fixed SL at ATR(`strategy_atr_period`, default 14) times
  `strategy_atr_sl_mult` (default 2.5) from entry price.
- Regime-flip exit: close the position when the regime symbol's D1 close is
  back above its SMA(`strategy_regime_sma`) — the bear-equity regime that
  justified the position has ended.
- Channel trail: close on a D1 close below the
  Donchian(`strategy_donchian_trail`) low (default 10).
- Time stop: close after `strategy_max_hold_bars` D1 bars (default 60).
- Friday close remains enabled by the V5 framework.

## Risk & Filters

- Only trade XAUUSD.DWX on D1 with the registered magic slot.
- Skip entries when D1 history, ATR, SMA, Donchian levels, or spread data
  are unavailable on the traded symbol.
- Skip entries (fail-closed) when the regime symbol's data or SMA is
  unavailable — a broken regime feed must produce zero trades, not
  unconditional trades.
- Skip entries when spread exceeds the configured cap.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## Trade Management Rules

- Long-only; the short branch does not exist.
- No pyramiding, gridding, martingale, or partial close.
- The Donchian(10) low trail and the regime-flip exit are the only position
  management.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_regime_symbol
  default: SP500.DWX
  sweep_range: [SP500.DWX]
  note: fixed data input, not swept; live preset MUST override with the
  broker's equivalent index symbol (see Risk).
- name: strategy_regime_sma
  default: 200
  sweep_range: [150, 200, 250]
- name: strategy_mom_sma
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
  default: 10
  sweep_range: [8, 10, 15]
- name: strategy_max_hold_bars
  default: 60
  sweep_range: [40, 60, 80]
- name: strategy_max_spread_points
  default: 80
  sweep_range: [50, 80, 120]

## Expected Behavior

- Long flat stretches in bull-equity regimes (the regime gate is closed);
  bursts of long gold entries during equity risk-off episodes — return
  profile is intentionally episodic and defensive at the book level.
- Winners ride flight-to-quality legs via the Donchian(10) trail and are
  released on regime normalization; losers are failed breakouts cut at the
  ATR hard stop.
- expected_pf 1.15, expected_dd_pct 15, approximately 6 trades/year. The
  frequency floor (Operating Rules 2026-07-03, >=5 trades/yr) is expected to
  hold on pooled history; calm single years can print zero trades — evaluate
  against DL-076 pooled-OOS where applicable.

## Author Claims

The sources establish the regime-conditional safe-haven property of gold in
general; this card imports no source performance number. Q02 and later
phases must validate or reject the mechanical long-only gold realization on
Darwinex bars.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one setfile for
XAUUSD.DWX. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the
portfolio gate.

Environment portability (hard requirement, `env_symbol_mapping` in
hard_rules_at_risk): the regime symbol is a DATA input only and is never
traded. `SP500.DWX` exists backtest-only and is NOT live-routable — the live
preset MUST override `strategy_regime_symbol` with the broker's equivalent
equity index symbol at deploy time, and the deploy verification must check
that override. Fail-closed rule: if the configured regime symbol's SMA
cannot be computed (symbol missing, no data), the EA takes NO entries.

## Initial Risk Profile

- expected_pf: 1.15.
- expected_dd_pct: 15.
- expected_trade_frequency: approximately 4-9 entries/year.
- risk_class: medium — long gold during equity stress runs with the
  documented safe-haven bid, but entries only occur under a dual gate
  (bear-equity regime plus gold own-momentum) with ATR stop, regime-flip
  exit, channel trail, and time stop bounding each trade.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Baur/Lucey Financial Review and Baur/McDermott
  Journal of Banking & Finance gold safe-haven literature.
- [x] R2 mechanical: fixed SMA(200) cross-symbol regime gate, SMA(50) gold
  momentum gate, Donchian(20) breakout trigger, ATR hard stop, regime-flip
  exit, Donchian(10) trail, and time stop.
- [x] R3 testable: `XAUUSD.DWX` (D1 2017-2026) and `SP500.DWX` (D1
  2018-2026, data input only) exist in the DWX symbol matrix.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic. The cross-symbol regime
  read uses MT5 chart data of a registered DWX symbol, not an external feed.
- [x] Non-duplicate: the short-index crisis cell is owned by QM5_13019; this
  card is the long-defensive complement (gold demand side of
  flight-to-quality), and no existing gold sleeve is bear-equity-regime
  gated.

## Framework Alignment

- no_trade: host-symbol/D1 guard, magic-slot guard, parameter guard, spread
  cap, bear-equity regime gate (fail-closed on missing regime data), gold
  momentum gate, and valid data checks.
- trade_entry: long-only Donchian(20) D1 breakout inside both gates.
- trade_management: Donchian(10) low trail, regime-flip monitoring, and
  max-hold tracking.
- trade_close: ATR hard stop, regime-flip exit, channel-trail exit, time
  stop, and framework Friday close.

## Kill Criteria

Kill or recycle the card if Q02 cannot produce the card-scaled minimum trade
count on pooled 2018-2026 history, if Q02 PF is below 1.0 after costs, if
the regime gate degenerates (never open or always open) on Darwinex history,
or if the gold momentum gate filters out substantially all bear-regime
breakouts (dual-gate starvation).

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-06 | initial flight-to-quality gold long card | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-06 | APPROVED | this card |
| Q01 Build Validation | 2026-07-06 | PENDING | `artifacts/qm5_13022_build_result.json` |
| Q02 Baseline Screening | 2026-07-06 | PENDING | enqueue after compile |
