---
ea_id: QM5_12552
slug: ema-stretch-mr-bounded-grid
type: strategy
source_id: owner-yt-ioynBnSofU4-2026-06-16
sources:
  - "[[sources/youtube-ioynBnSofU4-multicurrency-mr-grid]]"
concepts:
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/exponential-moving-average]]"
  - "[[indicators/average-true-range]]"
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present (owner-yt-ioynBnSofU4-2026-06-16); OWNER-provided YouTube video is a valid R1 source type per 2026-05-23 revision."
r2_mechanical: PASS
r2_reasoning: "Entry (EMA200/ATR/RSI with explicit thresholds), scale-in (ATR-spaced grid formula), TP (4 deterministic modes), stop (shared ATR-based S), and sizing (backward-solved 1% budget) are all fully specified — no discretion."
r3_data_available: PASS
r3_reasoning: "Requires only OHLC + EMA/ATR/RSI available on all .DWX symbols; card explicitly lists EURUSD.DWX, GBPUSD.DWX and others as primary test targets."
r4_ml_forbidden: PASS
r4_reasoning: "No ML; grid is deterministic (ATR-spaced formula), max N=5 levels bounded in code, lot_mult ≤ 1.3 with shared catastrophic stop S limiting full-ladder loss to 1% of equity — satisfies the grid carve-out in R4."
pipeline_phase: G0
period: H1
expected_trades_per_year_per_symbol: 24
last_updated: 2026-06-16
g0_approval_reasoning: "R1-R4 PASS; scale-in BOUNDED 1%-worst-case (shared stop S + backward-solved lots), NOT martingale; video 1.5x averaging-down replaced. Single-symbol, factory fans multi-currency."
card_body_incomplete: true
card_body_missing: "source_citation"
expected_pf: 1.2
expected_dd_pct: 12.0
---

# EMA-Stretch Mean-Reversion with Bounded 1%-Risk ATR Scale-In

## Quelle

- Source: OWNER-provided YouTube system, video id `ioynBnSofU4` (multi-currency mean-reversion grid EA).
- Primary URL (captured 2026-06-16): https://www.youtube.com/watch?v=ioynBnSofU4
- Author / institution: video author (channel not machine-readable from the JS-rendered page); the mechanic is a standard, widely-documented EMA-stretch + RSI mean-reversion archetype (confirmed against multiple public MQL5/TradingView implementations).
- Date captured: 2026-06-16. OWNER directive: build it, but make the grid prop-safe.

## Mechanik

Single-symbol EA. **Multi-currency is achieved by the factory** fanning this EA across the
.DWX universe via per-symbol setfiles (each symbol gets its own magic slot and an
independent 1%-bounded basket) — NOT by an in-EA market-watch loop. This keeps risk
isolated per symbol and pipeline/T_Live-compatible.

### Entry

Evaluated on completed H1 bars (`QM_IsNewBar`). Indicators on completed bars: `EMA(200, close)`,
`ATR(100)` (the "long ATR"), `ATR(14)` (the "short ATR"), Wilder `RSI(14)`.

- **Long (level 1)** when `Ask < EMA200 - (M_entry * ATR(100))` AND `RSI(14) < (50 - rsi_offset)`.
- **Short (level 1)** is the mirror: `Bid > EMA200 + (M_entry * ATR(100))` AND `RSI(14) > (50 + rsi_offset)`.
- Defaults: `M_entry = 10.0`, `rsi_offset = 15` (long below RSI 35 / short above 65).
- One basket per direction per symbol at a time; no new level-1 entry while a basket is open.

### Scale-In Grid (BOUNDED — replaces the video's 1.5x martingale)

- Up to `N` levels total (default `N = 5`), level 1 = the entry above; levels 2..N are adds in the SAME direction when the basket is in drawdown.
- **Add distance** for the next level: `d = max(grid_min_pips, grid_base_atr_mult * ATR(14) * (ATR(14)/ATR(100)))`. The volatility ratio `ATR(14)/ATR(100)` widens spacing in high vol and the `grid_min_pips` floor prevents stacking in calm markets. A level only adds after `>= grid_min_bars` closed bars since the last fill (no rapid-fire).
- **Lot ladder:** `L_k = L_1 * lot_mult^(k-1)`, with `lot_mult` in `[1.0, 1.3]` (default `1.15` — gentle, NOT 1.5). Constant lots (`lot_mult = 1.0`) are a valid sweep point.
- **Shared catastrophic stop `S`** (the bound): a single hard price level for the WHOLE basket, `S = entry1_price -/+ (stop_span_atr * ATR(100))` (below for long / above for short), with `stop_span_atr` chosen to sit beyond where level N would fill (default `stop_span_atr = 14.0`, i.e. approximately the entry stretch plus the full grid span and buffer). The same `S` is sent as the broker SL on EVERY fill, so a gap through `S` still closes at `S ± slippage` (bounded modulo slippage).

### Position Sizing — the 1% bound (OWNER requirement)

The initial lot `L_1` is **solved backward** from a fixed total-risk budget so that, if ALL `N` levels fill at their planned prices `p_1..p_N` and price then reaches `S`, the summed loss is exactly `risk_budget_pct` of equity:

```
L_1 = (risk_budget_pct/100 * AccountEquity)
      / ( Σ_{k=1..N} lot_mult^(k-1) * |p_k - S| * value_per_lot_per_price_unit )
L_k = L_1 * lot_mult^(k-1)
```

- `risk_budget_pct` default **1.0** (OWNER: total at-risk across the whole ladder ≤ 1% equity).
- Fewer levels filled ⇒ strictly less than 1% at risk; the budget is sized for the full ladder, which is the maximum exposure ⇒ **worst-case is bounded at 1%**. This is the R4-critical property.
- `p_k` are the planned add prices (entry1 minus the cumulative grid distances). `value_per_lot_per_price_unit` via `SYMBOL_TRADE_TICK_VALUE / SYMBOL_TRADE_TICK_SIZE`. Clamp `L_1` to broker min/step; if the bounded `L_1` rounds below the symbol min lot, the basket trades fewer levels or skips (never up-sizes past the 1% budget).
- Backtest uses `RISK_FIXED` equity convention; live uses `RISK_PERCENT` per V5 standard. The 1% budget is the framework risk model's input, not a second ad-hoc sizer.

### Exit / Take-Profit (whole basket exits together; `tp_mode` enum)

1. `TP_SLOW_MA` — close all when price crosses back through `EMA(200)`.
2. `TP_RSI_RECOVERY` — close all when `RSI(14)` recovers past the opposite offset (>=65 for long / <=35 for short).
3. `TP_VWAP_PIPS` — compute lot-weighted VWAP of the open basket; hard TP at `VWAP + vwap_target_pips` (long).
4. `TP_VWAP_ATR` — hard TP at `VWAP + (vwap_atr_mult * ATR(100))` (long); mirror for short.

- Modes 3/4 send a hard broker TP on every position (modify on each new fill as VWAP shifts).
- Modes 1/2 are virtual: close at market when the condition triggers on a closed bar.
- Optional **time exit**: close the basket after `max_hold_hours` (default off).

### Stop Loss

- The shared catastrophic `S` above is the hard stop for every position in the basket.
- Optional **trailing**: once the basket is in aggregate profit, trail `S` toward break-even in the profit direction only, in steps of `trail_step_points` (never loosens). Trailing only tightens the bound, never widens it.

### Zusaetzliche Filter

- H1 timeframe (primary); closed bars only; act on bar close.
- Spread filter before any fill (block only a genuinely wide spread; never block on zero/degenerate spread — .DWX quotes ask==bid in the tester).
- News (`QM_NewsAllowsTrade2`) + Friday-close + kill-switch via framework defaults.

## Concepts

- [[concepts/mean-reversion]] - primary (price-stretch reversion to a slow EMA)

## R1-R4 Bewertung

| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | OWNER-sourced video system + a standard, multiply-documented EMA-stretch/RSI mean-reversion archetype. |
| R2 Mechanical | PASS | EMA200/ATR/RSI entry, deterministic ATR-spaced scale-in ladder, shared ATR stop, 4 deterministic TP modes — fully specified, no discretion. |
| R3 Data Available | PASS | OHLC + EMA/ATR/RSI only; portable to every .DWX symbol. No external/macro feed. |
| R4 ML Forbidden | PASS | No ML/adaptive params. The scale-in is a BOUNDED-worst-case ladder: a single shared catastrophic stop `S` + a backward-solved lot ladder cap the full-ladder loss at 1% of equity. The video's 1.5x averaging-down martingale is explicitly REPLACED — worst case is bounded, satisfying HR14. |

## R3

Mean-reversion grids historically suit ranging FX majors; start on EURUSD.DWX, GBPUSD.DWX,
USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX, EURGBP.DWX (range-prone), then sweep USDJPY.DWX / EURJPY.DWX
and XAUUSD.DWX. Index CFDs (NDX/WS30/GDAXI) trend strongly — likely worse for stretch-reversion,
include only as a falsification cell. All rules need only OHLC + standard indicators, fully .DWX-portable.

## Author Claims

- The OWNER-provided summary claims a sophisticated multi-currency mean-reversion grid with ATR-volatility-adjusted spacing and multiple VWAP/EMA/RSI take-profit modes "looks very promising".
- NOTE (Claude): the original's appeal is partly the martingale equity-curve illusion. This card KEEPS the edge (stretch-reversion entry + multi-mode basket TP) and REMOVES the unbounded risk (1.5x averaging-down -> 1%-bounded ladder). The empirical question is whether the stretch-reversion edge survives net of cost WITHOUT the martingale carrying the equity curve.

## Parameters To Test

- `M_entry` (entry ATR stretch): 6.0, 8.0, 10.0, 12.0
- `rsi_offset`: 10, 15, 20
- `atr_long_period`: 100 ; `atr_short_period`: 14
- `grid_levels` N: 3, 5
- `lot_mult`: 1.0, 1.15, 1.3
- `grid_base_atr_mult`: 0.5, 1.0, 1.5 ; `grid_min_pips`: per-symbol floor
- `stop_span_atr`: 10.0, 14.0, 18.0
- `risk_budget_pct`: 1.0 (fixed per OWNER; do not sweep above 1.0)
- `tp_mode`: TP_SLOW_MA, TP_RSI_RECOVERY, TP_VWAP_PIPS, TP_VWAP_ATR
- `vwap_target_pips`, `vwap_atr_mult`, `max_hold_hours`

## Pipeline-Verlauf

- G0: 2026-06-16, PENDING -> (Claude G0). Built framework-native single-symbol; factory fans multi-currency.

## Verwandte Strategien

- [[strategies/QM5_10142_rsi2-sma]] - Connors RSI(2) mean-reversion (single-entry cousin).
- [[strategies/QM5_10026_rw-fx-squeeze-mr]] - FX squeeze mean-reversion.

## Lessons Learned

- Designed 2026-06-16 from an OWNER video. KEY DECISION: the source martingale (1.5x averaging-down, unbounded) was replaced with a 1%-bounded ladder (shared stop S + backward-solved lots) to satisfy HR14/R4 and the DXZ 5%-daily/20%-total + FTMO 10% DD limits. If the edge only works WITH the unbounded martingale, it must die in the pipeline (Q04/Q05/Q08) — that is the correct outcome.
