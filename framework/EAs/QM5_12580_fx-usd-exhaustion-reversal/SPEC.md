# QM5_12580_fx-usd-exhaustion-reversal - Strategy Spec

**EA ID:** QM5_12580
**Slug:** `fx-usd-exhaustion-reversal`
**Source:** `OWNER-CODEX-FX-USD-EXHAUSTION-20260626`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a D1 USD-major exhaustion reversal across seven Darwinex
custom FX symbols. Each chart instance trades only its own host symbol and magic
slot, but reads the full FX universe to compute a shared three-day USD basket
return z-score.

For USD-base symbols (`USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`) the pair return
is used directly as USD strength. For USD-quote symbols (`EURUSD.DWX`,
`GBPUSD.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`) the pair return is inverted. A positive
basket z-score means broad USD overbought; a negative z-score means broad USD
oversold. The EA fades that USD move only when the host symbol is also extended
from SMA(10) by at least an ATR-normalized threshold.

The implementation is deterministic: no ML, no grid, no martingale, no external
feed, and no hand-computed magic numbers. Foreign symbol reads are registered
with `QM_SymbolGuardInit` and warmed with `QM_BasketWarmupHistory`.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_basket_return_bars` | 3 | 2-5 | D1 bars in the USD basket return |
| `strategy_basket_z_lookback` | 80 | 60-120 | Prior basket observations for z-score |
| `strategy_basket_z_threshold` | 1.5 | 1.25-2.0 | Absolute z-score threshold for USD exhaustion |
| `strategy_sma_period` | 10 | 8-15 | Host-symbol local mean |
| `strategy_atr_period` | 14 | 10-20 | ATR period for extension and stop |
| `strategy_extension_atr_mult` | 1.2 | 1.0-1.5 | Minimum ATR extension from SMA |
| `strategy_stop_atr_mult` | 1.5 | 1.2-2.0 | Hard stop distance in ATR units |
| `strategy_hold_bars` | 4 | 3-6 | Maximum D1 holding period |

## 3. Symbol Universe

- `EURUSD.DWX` - magic slot 0.
- `GBPUSD.DWX` - magic slot 1.
- `AUDUSD.DWX` - magic slot 2.
- `NZDUSD.DWX` - magic slot 3.
- `USDJPY.DWX` - magic slot 4.
- `USDCHF.DWX` - magic slot 5.
- `USDCAD.DWX` - magic slot 6.

Every setfile is D1/backtest and keeps the `.DWX` suffix. Live deploy stripping,
if ever needed, is outside this EA build.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Cross-symbol refs: D1 closes for all seven FX symbols.
- Bar gating: `QM_IsNewBar(_Symbol, PERIOD_D1)`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Typical hold: 1-4 D1 bars.
- Regime preference: short-horizon exhaustion after synchronized USD moves.
- Friday entries are skipped; framework Friday close handling remains active.
- Only one open position with the same USD directional exposure is allowed
  across this EA's seven magic slots.

## 6. Source Citation

OWNER-approved Codex strategy proposal from 2026-06-26:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12580_fx-usd-exhaustion-reversal.md`.

No external performance claim is imported. The hypothesis must earn promotion
through the farm gates.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, T6 terminal, or deploy file is touched by this build.
