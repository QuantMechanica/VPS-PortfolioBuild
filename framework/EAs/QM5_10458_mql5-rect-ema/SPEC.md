# QM5_10458_mql5-rect-ema — Strategy Spec

**EA ID:** QM5_10458
**Slug:** `mql5-rect-ema`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades confirmed H1 closes outside a rectangle built from the prior completed bars. A long signal requires the last closed bar to close above rectangle resistance, with EMA(20) above SMA(50); a short signal requires the last closed bar to close below rectangle support, with EMA(20) below SMA(50). Stops use the farther of 1.5 ATR(14) or the opposite rectangle boundary, and take-profit is fixed at 2R. Open positions are also closed when a confirmed close breaks the opposite rectangle side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rectangle_lookback` | 20 | 2-500 | Number of completed bars used to define rectangle support and resistance. |
| `strategy_ema_period` | 20 | 2-500 | Fast EMA period for trend confirmation. |
| `strategy_sma_period` | 50 | 2-500 | Slow SMA period for trend confirmation. |
| `strategy_atr_period` | 14 | 2-500 | ATR period used for volatility stop distance. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier used as the minimum stop distance. |
| `strategy_take_profit_rr` | 2.0 | 0.1-10.0 | Take-profit as a multiple of initial risk. |
| `strategy_session_start_hhmm` | 0 | 0-2359 | Broker-time session start for the source time filter. |
| `strategy_session_end_hhmm` | 2400 | 1-2400 | Broker-time session end for the source time filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed liquid FX symbol with full DWX matrix support.
- `GBPUSD.DWX` — card-listed liquid FX symbol with full DWX matrix support.
- `USDJPY.DWX` — card-listed liquid FX symbol with full DWX matrix support.
- `GDAXI.DWX` — available DWX DAX custom symbol used as the matrix-backed port for card-listed `GER40.DWX`.
- `NDX.DWX` — card-listed liquid US index custom symbol with full DWX matrix support.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX` for DAX exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | hours to a few days |
| Expected drawdown profile | Breakout false-start losses controlled by fixed 1R stops. |
| Regime preference | breakout / volatility-expansion with trend confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/45639`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10458_mql5-rect-ema.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | 48ecdab0-87bb-4834-a9af-e575f144fd85 |
