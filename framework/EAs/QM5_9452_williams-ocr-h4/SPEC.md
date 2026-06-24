# QM5_9452_williams-ocr-h4 - Strategy Spec

**EA ID:** QM5_9452
**Slug:** williams-ocr-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `sources/forexfactory-strategies-and-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades a Larry Williams open-close range continuation pattern on closed H4 bars. A long signal requires a bullish bar whose body is at least 85% of the full range, whose range is at least 1.5 times ATR(14), whose close is above SMA(50), and whose prior bar was not an opposite bearish OCR bar. A short signal mirrors those rules below SMA(50). Entries are market orders on the next H4 bar with a fixed SL beyond the OCR bar by 0.2 ATR, a TP at 1.5 ATR from entry, and a time stop after 8 completed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR period for wide-range test, SL buffer, TP distance, and spread cap. |
| `strategy_sma_period` | 50 | 1+ | SMA period for trend alignment. |
| `strategy_ocr_ratio_min` | 0.85 | 0.01-1.00 | Minimum body divided by full bar range. |
| `strategy_range_atr_mult` | 1.5 | >0 | Minimum closed-bar range as a multiple of ATR. |
| `strategy_sl_atr_buffer` | 0.2 | >=0 | ATR buffer beyond the OCR bar high or low for SL. |
| `strategy_tp_atr_mult` | 1.5 | >0 | ATR multiple used for the profit target from entry. |
| `strategy_time_stop_bars` | 8 | 1+ | Close after this many completed H4 bars plus the next close. |
| `strategy_spread_atr_mult` | 0.20 | >=0 | Skip entries when modeled spread exceeds this ATR fraction. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with continuous H4 OHLC coverage.
- `GBPUSD.DWX` - FX major with continuous H4 OHLC coverage.
- `USDJPY.DWX` - FX major with continuous H4 OHLC coverage.
- `AUDUSD.DWX` - FX major with continuous H4 OHLC coverage.
- `USDCAD.DWX` - FX major with continuous H4 OHLC coverage.
- `USDCHF.DWX` - FX major with continuous H4 OHLC coverage.
- `NZDUSD.DWX` - FX major with continuous H4 OHLC coverage.
- `XAUUSD.DWX` - liquid metal CFD with H4 OHLC coverage.
- `XTIUSD.DWX` - liquid oil CFD with H4 OHLC coverage.
- `GDAXI.DWX` - DAX index CFD named in the card and present in the DWX matrix.
- `NDX.DWX` - Nasdaq index CFD named in the card and present in the DWX matrix.
- `WS30.DWX` - Dow index CFD named in the card and present in the DWX matrix.
- `UK100.DWX` - FTSE index CFD named in the card and present in the DWX matrix.

**Explicitly NOT for:**
- `FRA40.DWX` - card target, but absent from `framework/registry/dwx_symbol_matrix.csv`.
- `JP225.DWX` - card target, but absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Several H4 bars, capped after 8 closed H4 bars plus the next close |
| Expected drawdown profile | Volatility-expansion continuation with fixed ATR stop per trade |
| Regime preference | Trend-following / volatility-expansion continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum / book lineage
**Pointer:** `https://www.forexfactory.com/thread/post/14001700` and Larry Williams, *Long-Term Secrets to Short-Term Trading* (Wiley 1999)
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9452_williams-ocr-h4.md`

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
| v1 | 2026-06-25 | Initial build from card | 8ee5d954-999e-40ce-9e98-2223757530ca |
