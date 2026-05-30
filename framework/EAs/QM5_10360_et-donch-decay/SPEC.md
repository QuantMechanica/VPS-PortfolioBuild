# QM5_10360_et-donch-decay - Strategy Spec

**EA ID:** QM5_10360
**Slug:** `et-donch-decay`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA places a stop-entry straddle around the most recent 30 closed H1 bars: a buy stop at the highest high and a sell stop at the lowest low. Entries are skipped when the channel is too narrow versus spread, too wide versus ATR(30), or below the minimum ATR filter. The protective stop starts halfway back through the entry channel and then tightens with a Donchian exit lookback that shrinks by 2 bars every 5 bars in trade, with a floor of 6 bars. When one side fills, any opposite pending stop for the same symbol and magic is cancelled.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_channel_bars` | 30 | 20-55 | Donchian channel length used for breakout stops. |
| `strategy_atr_period` | 30 | 10-60 | ATR period for volatility width filtering. |
| `strategy_max_width_atr_mult` | 3.0 | 1.0-6.0 | Maximum channel width allowed, expressed as a multiple of ATR. |
| `strategy_min_width_spreads` | 4.0 | 1.0-10.0 | Minimum channel width required, expressed as current spread multiples. |
| `strategy_min_atr_points` | 10.0 | 0.0-1000.0 | Minimum ATR in symbol points before entries are allowed. |
| `strategy_decay_interval_bars` | 5 | 3-8 | Bars in trade between exit lookback reductions. |
| `strategy_decay_step_bars` | 2 | 1-4 | Number of bars removed from the exit lookback at each decay step. |
| `strategy_min_exit_lookback` | 6 | 6-14 | Floor for the shrinking exit lookback. |
| `strategy_order_expiry_bars` | 1 | 1-4 | Pending stop order expiry in current-chart bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major from the card basket.
- `GBPUSD.DWX` - liquid FX major from the card basket.
- `XAUUSD.DWX` - liquid gold CFD from the card basket.
- `GDAXI.DWX` - canonical DWX DAX symbol used in place of card text `GER40.DWX`.
- `SP500.DWX` - S&P 500 custom symbol approved for backtest use.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; use `SP500.DWX`.

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
| Trades / year / symbol | `35` |
| Typical hold time | multi-bar H1 trend hold with shrinking channel exit |
| Expected drawdown profile | whipsaw risk in noisy range breakouts |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/code-interpretation.57248/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10360_et-donch-decay.md`

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
| v1 | 2026-05-25 | Initial build from card | f723bc07-7b28-4a4d-8287-8bec495f03b9 |
