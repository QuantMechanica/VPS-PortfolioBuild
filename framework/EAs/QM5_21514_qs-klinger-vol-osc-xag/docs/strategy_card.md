---
ea_id: QM5_21514
slug: qs-klinger-vol-osc-xag
type: strategy
source_id: 0b564ef2-810c-5b1d-9084-342ddb20575c
sources:
  - "[[sources/quantifiedstrategies-klinger-oscillator]]"
concepts:
  - "[[concepts/volume-force]]"
  - "[[concepts/cumulative-volume-trend]]"
  - "[[concepts/volume-momentum-crossover]]"
indicators:
  - "[[indicators/klinger-volume-oscillator]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr-stop]]"
strategy_type_flags: [klinger-signal-cross, single-symbol, atr-hard-stop, long-and-short, volume-proxy]
target_symbols: [XAGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_21514_XAGUSD_KVO_D1
period: D1
expected_trade_frequency: "An EMA(34)/EMA(55)-of-volume-force cross with a 13-bar signal line is comparable in cadence to a MACD(34,55,13) cross series; estimate 12-20 cross events/year on XAGUSD."
expected_trades_per_year_per_symbol: 15
last_updated: 2026-08-13
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Anonymous-author-OK per 2026-06-30 revision; source is QuantifiedStrategies.com, 'Klinger Oscillator Strategy - Understanding and Evaluating Performance' (https://www.quantifiedstrategies.com/klinger-oscillator-strategy/), which documents the Klinger Volume Oscillator (KVO, Stephen Klinger, 1977) and its standard signal-line-cross application, plus a disclosed backtest summary (363 trades since 1993, ~1% average profit/trade). QS's free content confirms the canonical formula parameters (34-period and 55-period EMA of volume force, 13-period EMA signal line) but gates the exact recommended entry/exit rule combination behind membership. Per R2's side-parameter allowance, this card uses the closed-form public KVO/signal-cross formula (the standard, widely-documented construction, corroborated independently across TradingView/CQG/LuxAlgo references) rather than any paywalled QS-specific rule."
r2_mechanical: PASS
r2_reasoning: "Deterministic: Volume Force is a closed-form arithmetic function of High/Low/Close/Volume and a cumulative trend-direction flag; KVO and its signal line are fixed-period EMAs of that series. Entry/exit trigger is a mechanical KVO-vs-signal-line cross. No discretion."
r3_data_available: PASS
r3_reasoning: "XAGUSD.DWX native D1 OHLC plus MT5 tick volume are sufficient; tick volume is used as the standard proxy for the source's exchange-volume concept, consistent with the existing OBV/MFI/Chaikin/NVI/PVT/EMV cards already in the book. No macro feed, no options/futures data."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no adaptive/PnL-dependent parameters; all EMA periods are fixed and the series depends only on price/volume history. No grid/martingale."
pipeline_phase: G0
expected_pf: 1.12
expected_dd_pct: 19.0
risk_class: medium
ml_required: false
g0_approval_reasoning: "R1 lineage recorded; R2 deterministic KVO and signal-line cross entry/exit rules with a conservative joint cadence of about 15 trades/year; R3 uses native XAGUSD.DWX OHLC and MT5 tick volume only; R4 is ML-free, deterministic, and one-position-per-magic compatible."
---

# XAGUSD Klinger Volume Oscillator Signal Cross

## Source

- Source: [[sources/quantifiedstrategies-klinger-oscillator]]
- Citation: QuantifiedStrategies.com, "Klinger Oscillator Strategy -
  Understanding and Evaluating Performance."
  https://www.quantifiedstrategies.com/klinger-oscillator-strategy/
  Underlying methodology: Stephen Klinger, 1977 ("Volume Force" / Klinger
  Volume Oscillator).
- Key finding used here: the Klinger Volume Oscillator combines price
  range, a day-over-day trend-direction flag, and volume into a "Volume
  Force" series, then compares a fast (34-period) EMA of that series
  against a slow (55-period) EMA, with a 13-period EMA acting as the
  signal line -- structurally the same "fast EMA minus slow EMA, crossed
  against a signal EMA" shape as MACD, but computed on a volume-derived
  series rather than price. QS reports the underlying strategy as
  producing many trades with a small average per-trade edge, working best
  combined with a second filter -- cited as sourcing motivation only, not
  as this card's claimed performance.

## Edge / Thesis

Price-range expansion accompanied by rising participation (volume) is a
stronger trend-continuation signal than price-range expansion alone.
Volume Force encodes both the direction of the day's move and its
relative range-expansion/contraction versus the running cumulative trend,
weighted by volume; smoothing that series with a fast/slow EMA pair and
crossing it against its own signal line surfaces shifts in
volume-confirmed momentum. MT5 CFD tick volume is used as the
participation proxy, consistent with every other volume-derived card
already in the book.

This is a price+tick-volume implementation; no options, futures
term-structure, or macro-feed data is used.

## Markets And Timeframe

- Target symbol: `XAGUSD.DWX` only.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: native MT5 D1 OHLC and tick volume on XAGUSD only; no
  external feed, no ML model.

## Entry Rules

- Evaluate only on a new completed D1 bar.
- Compute the daily movement measure `dm[1] = High[1] - Low[1]`.
- Compute the trend flag: `T[1] = +1` if
  `(High[1]+Low[1]+Close[1]) > (High[2]+Low[2]+Close[2])`, else `T[1] = -1`.
- Compute the cumulative measure `cm`: if `T[1] == T[2]` then
  `cm[1] = cm[2] + dm[1]`, else `cm[1] = dm[2] + dm[1]` (resets whenever
  the trend flag flips).
- Compute Volume Force:
  `VF[1] = Volume[1] * abs(2 * (dm[1]/cm[1] - 1)) * T[1] * 100`.
- Compute `KVO[1] = EMA(VF, strategy_kvo_fast_period)[1] -
  EMA(VF, strategy_kvo_slow_period)[1]` (defaults 34 / 55).
- Compute `Signal[1] = EMA(KVO, strategy_kvo_signal_period)[1]` (default
  13).
- Open LONG when `KVO[1]` crosses from `<= Signal[2]` to `> Signal[1]`
  (fresh cross above the signal line) AND no long position is already
  open.
- Open SHORT when `KVO[1]` crosses from `>= Signal[2]` to `< Signal[1]`
  (fresh cross below the signal line) AND no short position is already
  open.
- No entry if XAGUSD spread exceeds `strategy_max_spread_points`.
- No entry if fewer than
  `strategy_kvo_slow_period + strategy_kvo_signal_period +
  strategy_warmup_buffer` completed D1 bars of history are available.

## Exit Rules

- Signal-reversal exit: close LONG when `KVO` recrosses below `Signal`;
  close SHORT when `KVO` recrosses above `Signal`.
- Stop loss: fixed hard SL at `strategy_atr_sl_mult` x
  `ATR(strategy_atr_period, D1)` from entry, as a bounded-worst-case guard
  independent of the KVO signal.
- Max-hold exit: close after `strategy_max_hold_bars` completed D1 bars
  (default 60) as a stale-position guard.
- Friday close remains enabled by the V5 framework.
- No trailing stop, no take-profit, no partial close in v1.

## Filters

- Only trade `XAGUSD.DWX` on D1.
- Framework news, kill-switch, magic, and Friday-close guards remain
  active.
- Spread cap via `strategy_max_spread_points`.

## Trade Management Rules

- Both long and short.
- One open position per magic.
- No pyramiding, gridding, martingale, or scale-in.
- No partial close.
- A cross that closes an existing position may open the opposite position
  on the same bar (flip); no separate re-entry gate needed.

## Parameters To Test

- name: strategy_kvo_fast_period
  default: 34
  sweep_range: [21, 34, 45]
- name: strategy_kvo_slow_period
  default: 55
  sweep_range: [45, 55, 75]
- name: strategy_kvo_signal_period
  default: 13
  sweep_range: [9, 13, 21]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.5]
- name: strategy_max_hold_bars
  default: 60
  sweep_range: [30, 60, 100]
- name: strategy_warmup_buffer
  default: 20
  sweep_range: [10, 20, 40]
- name: strategy_max_spread_points
  default: 400
  sweep_range: [250, 400, 600]

## Dedup Assessment

| Card | Overlap? | Verdict |
|---|---|---|
| Any `obv*` / `mfi*` / `chaikin*` card (9 + 14 + 5 in book) | All are "volume-derived confirmation indicator" family | DIFFERENT FORMULA -- OBV is a raw signed-volume cumulative sum, MFI is a bounded RSI-style oscillator on typical-price money flow, Chaikin (A/D and CMF variants) weight volume by close-position-in-range; Klinger's Volume Force instead weights volume by a *cumulative trend-persistence* measure (`cm`, which resets only when the day-over-day typical-price trend flips) -- a structurally distinct, path-dependent construction none of the existing cards replicate |
| `qs-nvi-ema-sp500` / `qs-pvt-cross-ws30` (batch 1, same source) | All are "volume-index vs its own EMA/signal" family | DIFFERENT UPDATE RULE -- NVI updates only on down-volume days (sparse, asymmetric); PVT updates every bar by a %-magnitude-weighted volume term; this card's Volume Force updates every bar using the `dm/cm` range-and-trend-persistence ratio, and crosses a fast-EMA-minus-slow-EMA difference against a signal EMA (a MACD-shaped comparison), not a single series against one long EMA |
| Existing MACD-family cards | Same "fast EMA minus slow EMA, crossed against signal EMA" shape | DIFFERENT INPUT SERIES -- MACD is computed on price (Close); this card computes the identical mathematical shape on the derived Volume Force series, not price -- the underlying signal content (volume-confirmed trend shift) is distinct from any price-only MACD variant already in the book |
| Book-wide keyword scan | `klinger`, `kvo`, `volume force` | ZERO existing cards in the current ~3200-card book use the Klinger Volume Oscillator (verified by full-book slug/content grep 2026-08-13) |

## Low-Correlation Argument

- Volume Force's cumulative trend-persistence weighting (`cm` resets only
  on trend-flag flips) is a structurally distinct volume-weighting scheme
  from every other volume-derived card in the book.
- Applied to XAGUSD, diversifying away from XAUUSD (used by the batch-1
  KAMA card from this same source) while remaining in the metals family
  where tick-volume liquidity is adequate.
- The MACD-shaped fast/slow/signal EMA cascade applied to a volume series
  rather than price adds a frequency/timing profile distinct from both
  the book's price-MACD cards and its single-EMA volume-index cards.

## Net-Cost Check

XAGUSD.DWX is a liquid, live-routable metal CFD. ~15 trades/year with a
60-bar max hold implies moderate turnover; gross should closely
approximate net given the documented venue cost model for metals.

## Initial Risk Profile

- expected_pf: 1.12.
- expected_dd_pct: 19.0.
- expected_trade_frequency: approximately 12-20 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Framework Alignment

- no_trade: D1 XAGUSD.DWX guard, history-length/warm-up guard, spread cap.
- trade_entry: Volume Force fast/slow-EMA-difference cross above/below its
  signal EMA.
- trade_management: ATR hard stop, 60-bar max-hold time stop.
- trade_close: signal-reversal exit (opposite cross), ATR stop, time
  stop, framework Friday close.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | PENDING | this card |
