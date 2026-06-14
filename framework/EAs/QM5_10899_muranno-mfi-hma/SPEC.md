# QM5_10899_muranno-mfi-hma - Strategy Spec

**EA ID:** QM5_10899
**Slug:** muranno-mfi-hma
**Source:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA evaluates the M15 close. It opens long when the closed candle is above SMA(200), MFI(21) crosses above the 18-period simple average of MFI while still below 50, and the same candle crosses and closes above HMA(65) with a bullish body. It opens short on the mirrored conditions below SMA(200), with MFI crossing below its 18-period average while above 50, a close below HMA(65), and a bearish body. It exits when the opposite MFI cross appears, price closes back through HMA(65), candle color flips against the position, or the position has been held for 24 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | MT5 timeframe enum | Timeframe used for all strategy signal reads. |
| `strategy_sma_period` | `200` | `1+` | Trend-filter SMA period on closed prices. |
| `strategy_mfi_period` | `21` | `1+` | Money Flow Index lookback using DWX tick volume. |
| `strategy_mfi_sma_period` | `18` | `1+` | Simple average length applied to MFI values. |
| `strategy_mfi_midline` | `50.0` | `0-100` | Midline filter: long MFI must be below it, short MFI above it. |
| `strategy_hma_period` | `65` | `4+` | Hull moving average period used for candle cross and exit. |
| `strategy_atr_period` | `14` | `1+` | ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | `1.0` | `>0` | ATR multiplier for the initial stop distance. |
| `strategy_spread_stop_frac` | `0.20` | `0-1` | Maximum spread as a fraction of stop distance. |
| `strategy_max_hold_bars` | `24` | `1+` | Maximum holding period in M15 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved liquid FX major with DWX tick data for MFI.
- `GBPUSD.DWX` - card-approved liquid FX major with DWX tick data for MFI.
- `USDJPY.DWX` - card-approved liquid FX major with DWX tick data for MFI.
- `AUDUSD.DWX` - card-approved liquid FX major with DWX tick data for MFI.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline artifacts require canonical DWX symbols.
- Symbols outside the card basket - MFI/tick-volume behavior was approved only for the listed FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry; `QM_IsNewBar(_Symbol, strategy_signal_tf)` for open-position exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | Intraday; maximum 24 M15 bars, approximately 6 hours |
| Expected drawdown profile | ATR-stopped scalping/trend-pullback losses bounded by one initial stop per trade |
| Regime preference | Trend-pullback with money-flow confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Source type:** book
**Pointer:** James Muranno, *Mechanical Day Trading Strategies*, local PDF `G:\My Drive\QuantMechanica\Ebook\PDF resources\Mechanical Day Trading Strategi - James Muranno.pdf`, pp. 56-58
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10899_muranno-mfi-hma.md`

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
| v1 | 2026-06-14 | Initial build from card | 043c2b16-89df-4dad-82f8-740181c937e4 |
