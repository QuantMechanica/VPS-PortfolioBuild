# QM5_13041_xti-loose-supply-fade - Strategy Spec

**EA ID:** QM5_13041
**Slug:** `xti-loose-supply-fade`
**Source:** `EIA-XTI-DAYS-SUPPLY-FADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It uses the official EIA crude-oil days-of-supply series and WPSR pages as
source lineage only. Runtime is price-only and deterministic: Darwinex D1 OHLC,
ATR, SMA, spread, and broker calendar state.

On each new D1 bar the EA inspects the prior completed Wednesday/Thursday bar,
the usual WPSR proxy window. A short entry requires a bearish ATR-sized bar that
closes near its low, breaks below the prior Donchian low, sits in the lower part
of the 126-D1 close channel, rejects a short rebound, and trades below a falling
`SMA(50)`. A monthly latch allows only one new entry per broker-calendar month.

This is deliberately not `QM5_13040_xti-days-supply-brk`: that EA is a
long-only tight-cover breakout; this one is a short-only loose-supply breakdown
fade with lower-channel anchoring and short-side exits.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_report_start_dow` | 3 | fixed | First broker day-of-week for WPSR proxy window |
| `strategy_report_end_dow` | 4 | fixed | Last broker day-of-week for WPSR proxy window |
| `strategy_breakdown_lookback` | 55 | 34-84 | Donchian low lookback excluding signal bar |
| `strategy_anchor_lookback` | 126 | 84-189 | Close-channel lookback for loose-supply price proxy |
| `strategy_rebound_lookback` | 5 | 3-8 | Pre-signal rebound rejection window |
| `strategy_min_rebound_atr` | 0.40 | 0.25-0.65 | Minimum rejection from rebound high in ATR units |
| `strategy_max_anchor_position` | 0.30 | 0.20-0.40 | Maximum close-channel position |
| `strategy_sma_period` | 50 | 34-84 | D1 trend filter period |
| `strategy_sma_slope_shift` | 10 | 5-15 | Completed D1 bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.55 | 0.40-0.80 | Minimum signal-bar range in ATR units |
| `strategy_min_close_location` | 0.60 | 0.55-0.70 | Minimum close location toward the signal-bar low |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.50 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.25 | 2.50-4.25 | ATR target distance |
| `strategy_max_hold_days` | 12 | 8-18 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Direction: short only.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA trend failure,
  and max-hold guard.
- Regime preference: WTI loose-stock-cover continuation proxy during weekly
  petroleum information windows.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration crude-oil days-of-supply and weekly
petroleum data pages:

- https://www.eia.gov/dnav/pet/PET_SUM_SNDW_A_EPC0_VSD_DAYS_W.htm
- https://www.eia.gov/petroleum/supply/weekly/

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
