# QM5_9937_ff-magic100-ema-pullback-h1 — Strategy Spec

**EA ID:** QM5_9937
**Slug:** `ff-magic100-ema-pullback-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades EMA(100) trend pullbacks on H1. In an uptrend — defined as the last closed H1 bar's close being above EMA(100) and the EMA sloping up by at least 0.15 × ATR(14) over the preceding 10 bars — the EA looks for a bearish retracement candle whose entire body sits above EMA(100). It places a buy-stop at that candle's high plus 0.05 × ATR, with SL at the candle's low minus 0.05 × ATR. If subsequent bearish candles form at a lower level while the trend gate remains valid, the pending order is moved to the newer candle to capture a deeper pullback entry. The pending order is cancelled if the close crosses back below EMA(100) or after 8 H1 bars without being triggered. The short mirror applies below EMA(100) with a bullish retracement candle and a sell-stop entry. TP is set at 2.5 R; SL is moved to breakeven when price advances +1 R from the entry. The trade is skipped if the initial risk exceeds 1.8 × ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 100 | 50–200 | EMA period for trend direction |
| `strategy_atr_period` | 14 | 7–21 | ATR period used for filters and sizing |
| `strategy_slope_bars` | 10 | 5–20 | Number of bars over which EMA slope is measured |
| `strategy_slope_min_atr` | 0.15 | 0.05–0.50 | Minimum EMA slope magnitude in ATR units |
| `strategy_entry_buffer_atr` | 0.05 | 0.01–0.20 | Entry stop offset beyond candle high/low in ATR units |
| `strategy_sl_buffer_atr` | 0.05 | 0.01–0.20 | SL offset beyond candle low/high in ATR units |
| `strategy_max_risk_atr` | 1.8 | 1.0–3.0 | Skip trade if initial SL distance exceeds this * ATR |
| `strategy_tp_r` | 2.5 | 1.5–5.0 | Take-profit distance as a multiple of initial risk |
| `strategy_expiry_bars` | 8 | 3–20 | Cancel pending order if untriggered after this many H1 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair with strong EMA trending behaviour on H1
- `GBPUSD.DWX` — major FX pair, suitable trend momentum for H1 pullbacks
- `USDJPY.DWX` — major FX pair, clean trending periods on H1
- `XAUUSD.DWX` — gold trends strongly on H1; ATR-based sizing accounts for volatility
- `NDX.DWX` — Nasdaq 100, prominent H1 trends; high-liquidity index

**Explicitly NOT for:**
- Monthly or weekly symbols — EMA(100) H1 slope insufficient signal for very long timeframes
- Symbols not in DWX matrix — no tick data available

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
| Trades / year / symbol | ~80 |
| Typical hold time | 4–24 hours (H1 trend moves) |
| Expected drawdown profile | Moderate, with BE at 1R reducing tail loss |
| Regime preference | trend |
| Win rate target (qualitative) | medium (breakeven cut reduces losses) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** Minotawr, "Magic 100", ForexFactory, 2020, https://www.forexfactory.com/thread/989445-magic-100
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9937_ff-magic100-ema-pullback-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 7ea54cd9-40bc-4381-8f30-31b995a0e95b |
