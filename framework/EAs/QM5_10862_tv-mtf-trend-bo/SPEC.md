# QM5_10862_tv-mtf-trend-bo - Strategy Spec

**EA ID:** QM5_10862
**Slug:** `tv-mtf-trend-bo`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades stop-order breakouts in the direction of a D1 EMA trend filter. A long setup requires the latest closed signal bar close to be above D1 EMA(240) and three consecutive higher closed-bar closes; the buy stop is placed 0.1% above the signal bar high. A short setup mirrors this with close below D1 EMA(240), three consecutive lower closes, and a sell stop 0.1% below the signal bar low. Open trades have no fixed target and are managed only by a 2.5% trailing stop, capped by the ATR fallback rule when the percentage stop is too wide.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_timeframe` | `PERIOD_CURRENT` | `H1`, `H4`, `D1` | Closed-bar timeframe for the momentum sequence and signal candle. |
| `strategy_ema_period` | `240` | `120`-`240` | D1 EMA period used for the MTF trend context. |
| `strategy_consecutive_closes` | `3` | `2`-`4` | Number of consecutive higher or lower closed-bar closes required. |
| `strategy_breakout_offset_pct` | `0.10` | `0.05`-`0.20` | Percent offset beyond the signal high or low for the stop order. |
| `strategy_trailing_stop_pct` | `2.50` | `1.50`-`3.50` | Dynamic trailing stop distance as a percent of price. |
| `strategy_atr_period` | `14` | `14` | ATR period for the fallback hard stop. |
| `strategy_atr_fallback_mult` | `2.50` | `2.50` | ATR multiplier used when the percent stop exceeds the wide-stop threshold. |
| `strategy_atr_wide_threshold` | `3.00` | `3.00` | Percent stop is replaced when it is wider than this ATR multiple. |
| `strategy_pending_bars` | `3` | `3` | Pending stop order lifetime in signal bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX market from the card's R3 P2 basket.
- `GBPUSD.DWX` - liquid major FX market from the card's R3 P2 basket.
- `XAUUSD.DWX` - liquid metal market from the card's R3 P2 basket.
- `NDX.DWX` - liquid US index market from the card's R3 P2 basket.
- `GDAXI.DWX` - verified DAX custom symbol used as the DWX matrix equivalent for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | D1 EMA(240) trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Hours to days |
| Expected drawdown profile | Low-to-moderate trend breakout drawdown with gap and slippage risk. |
| Regime preference | Trend-following breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/plDp6ZIw/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10862_tv-mtf-trend-bo.md`

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
| v1 | 2026-06-06 | Initial build from card | 4b642b8c-802e-4e17-8a01-3d619cb8c336 |
