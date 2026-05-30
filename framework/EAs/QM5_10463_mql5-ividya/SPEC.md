# QM5_10463_mql5-ividya — Strategy Spec

**EA ID:** QM5_10463
**Slug:** `mql5-ividya`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates once per newly opened H1 bar using the last closed bar. It goes long when the previous close crosses from below to above VIDYA and goes short when the previous close crosses from above to below VIDYA. If an existing position receives the opposite closed-bar signal, it is closed by the strategy exit hook. Each new entry uses an ATR(14) stop at 1.5 times ATR and a fixed take-profit at 2R, with no trailing or partial close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | M30, H1, H4 | Timeframe used for VIDYA signal and ATR stop reads |
| `strategy_vidya_cmo_period` | `9` | 2-100 | Chande Momentum Oscillator period for VIDYA |
| `strategy_vidya_ema_period` | `12` | 2-200 | EMA smoothing period for VIDYA |
| `strategy_vidya_price` | `PRICE_CLOSE` | MT5 applied price enum | Price source used by VIDYA |
| `strategy_atr_period` | `14` | 2-100 | ATR period used for the protective stop |
| `strategy_atr_sl_mult` | `1.5` | 0.1-10.0 | Stop distance multiplier applied to ATR |
| `strategy_reward_r` | `2.0` | 0.1-10.0 | Take-profit distance in multiples of initial risk |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major with OHLC history for H1 indicator testing
- `GBPUSD.DWX` — liquid FX major with OHLC history for H1 indicator testing
- `USDJPY.DWX` — liquid FX major with OHLC history for H1 indicator testing
- `USDCHF.DWX` — liquid FX major with OHLC history for H1 indicator testing
- `USDCAD.DWX` — liquid FX major with OHLC history for H1 indicator testing
- `AUDUSD.DWX` — liquid FX major with OHLC history for H1 indicator testing
- `NZDUSD.DWX` — liquid FX major with OHLC history for H1 indicator testing
- `XAUUSD.DWX` — liquid metal CFD explicitly listed by the card baseline
- `SP500.DWX` — liquid S&P 500 custom symbol available for backtest-only index coverage
- `NDX.DWX` — liquid Nasdaq 100 index CFD for US large-cap coverage
- `WS30.DWX` — liquid Dow 30 index CFD for US large-cap coverage
- `GDAXI.DWX` — liquid DAX index CFD for European index coverage
- `UK100.DWX` — liquid FTSE 100 index CFD for European index coverage

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — broker/custom data availability is not verified

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
| Trades / year / symbol | `45` |
| Typical hold time | hours to a few days |
| Expected drawdown profile | trend-following whipsaws during sideways periods |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/39703`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10463_mql5-ividya.md`

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
| v1 | 2026-05-28 | Initial build from card | fa8f7622-0db2-4ce1-aa53-f7f9b49bbad2 |
