# QM5_10528_mql5-vlt-compress — Strategy Spec

**EA ID:** QM5_10528
**Slug:** `mql5-vlt-compress`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

On each newly closed H1 bar, the EA compares that bar's high-low range with the prior `strategy_count_candles` closed bars. If the latest closed bar is the smallest range in the window, it removes old stop orders for the same symbol and magic, then places a Buy Stop above that bar's high and a Sell Stop below that bar's low. The stop loss is the farther of 1.0 ATR(14) from entry or the opposite side of the compressed bar, the target is 1.5R, and any open position is closed after 12 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_count_candles` | 20 | 2+ | Number of closed bars used to decide whether the latest closed bar has the smallest range. |
| `strategy_trigger_offset_points` | 10 | 1+ | Stop-entry offset in symbol points above the compressed bar high and below its low. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the hard stop distance. |
| `strategy_atr_sl_mult` | 1.0 | 0.1+ | ATR multiple used in the stop-loss comparison. |
| `strategy_tp_rr` | 1.5 | 0.1+ | Take-profit multiple of initial risk. |
| `strategy_time_stop_bars` | 12 | 1+ | Maximum hold time in current-chart bars before strategy exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid DWX major FX pair with continuous H1 OHLC data suitable for volatility-compression breakouts.
- `GBPUSD.DWX` — liquid DWX major FX pair from the approved card's portable basket.
- `USDJPY.DWX` — liquid DWX major FX pair from the approved card's portable basket.
- `XAUUSD.DWX` — DWX metal symbol from the approved basket; the rule uses only OHLC range and stop entries.

**Explicitly NOT for:**
- `SPX500.DWX` — unavailable canonical symbol; the card is not an index strategy and does not target this symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `65` |
| Typical hold time | `up to 12 H1 bars` |
| Expected drawdown profile | `ATR-normalized breakout losses bounded by fixed hard stop` |
| Regime preference | `volatility-expansion breakout after compression` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/18455`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10528_mql5-vlt-compress.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-29 | Initial build from card | 2c7dff44-f8d3-4964-8525-80e19f83f1a2 |
