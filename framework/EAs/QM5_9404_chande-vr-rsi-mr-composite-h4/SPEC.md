# QM5_9404_chande-vr-rsi-mr-composite-h4 - Strategy Spec

**EA ID:** QM5_9404
**Slug:** `chande-vr-rsi-mr-composite-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (ForexFactory Chande/Kroll thread cluster and Chande/Kroll 1994 book lineage)
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA trades a Chande volatility-regime mean-reversion setup on closed H4 bars. It computes `VR = ATR(14) / ATR(50)` and only trades when `VR < 0.70`, the card's consolidation regime.

Long setup: RSI(3) is below 10, the closed H4 close is above SMA(200), and the trigger bar rejected its low by at least `0.40 * ATR(14)`. The long stop is the trigger-bar low minus `0.40 * ATR(14)`.

Short setup: RSI(3) is above 90, the closed H4 close is below SMA(200), shorts are enabled, and the trigger bar rejected its high by at least `0.40 * ATR(14)`. The short stop is the trigger-bar high plus `0.40 * ATR(14)`.

Entries are market orders on the first tick of the next H4 bar. Exits occur when RSI(3) crosses back through the 50 midline, or when the position has been open for 8 H4 bars. The framework enforces one position per magic/symbol, fixed-risk sizing, news filtering, Friday close, and kill-switch checks.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 only for this card | Signal timeframe and warm-up timeframe. |
| `strategy_atr_short_period` | 14 | 2-100 | Short ATR leg for Chande VR and stop distance. |
| `strategy_atr_long_period` | 50 | Greater than short ATR | Long ATR leg for Chande VR. |
| `strategy_rsi_period` | 3 | 2-20 | Fast RSI period for mean-reversion entries and exits. |
| `strategy_trend_sma_period` | 200 | 20-400 | Long trend filter. |
| `strategy_vr_max` | 0.70 | 0.20-1.00 | Maximum VR allowed for consolidation-regime trades. |
| `strategy_long_rsi_level` | 10.0 | 1-40 | Oversold threshold for long entries. |
| `strategy_short_rsi_level` | 90.0 | 60-99 | Overbought threshold for short entries. |
| `strategy_exit_rsi_mid` | 50.0 | 40-60 | RSI midline exit trigger. |
| `strategy_rejection_atr_mult` | 0.40 | 0.10-2.00 | ATR fraction required for trigger-bar rejection and stop padding. |
| `strategy_spread_atr_mult` | 0.20 | 0.00-1.00 | Skip entries when current spread exceeds this ATR fraction. |
| `strategy_time_stop_bars` | 8 | 1-40 | Maximum H4 bars held before time-stop exit. |
| `strategy_shorts_enabled` | `true` | boolean | Enables the card's short-side mirror setup. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with H4 mean-reversion history.
- `GBPUSD.DWX` - liquid FX major with H4 mean-reversion history.
- `USDJPY.DWX` - liquid FX major with H4 mean-reversion history.
- `AUDUSD.DWX` - liquid FX major with H4 mean-reversion history.
- `USDCAD.DWX` - liquid FX major with H4 mean-reversion history.
- `USDCHF.DWX` - liquid FX major with H4 mean-reversion history.
- `NZDUSD.DWX` - liquid FX major with H4 mean-reversion history.
- `XAUUSD.DWX` - metal CFD with ATR-normalized H4 volatility regimes.
- `XTIUSD.DWX` - WTI CFD with ATR-normalized H4 volatility regimes.
- `GDAXI.DWX` - index CFD with H4 consolidation/reversion episodes.
- `NDX.DWX` - index CFD with H4 consolidation/reversion episodes.
- `WS30.DWX` - index CFD with H4 consolidation/reversion episodes.
- `UK100.DWX` - index CFD with H4 consolidation/reversion episodes.

**Explicitly NOT for:**
- `FRA40.DWX` - named by the approved card but absent from `framework/registry/dwx_symbol_matrix.csv` at build time.
- `JP225.DWX` - named by the approved card but absent from `framework/registry/dwx_symbol_matrix.csv` at build time.
- Non-DWX symbols - magic resolution and farm setfile routing are DWX-specific.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 70 from the approved card |
| Typical hold time | Less than or equal to 8 H4 bars, usually hours to about 1.3 days |
| Expected drawdown profile | Medium, driven by clustered failed fades during trend expansion that slips through the VR gate |
| Regime preference | Low-volatility consolidation mean reversion |
| Win rate target (qualitative) | Medium to high, with asymmetric single-bar stop risk |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum plus book lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9404_chande-vr-rsi-mr-composite-h4.md`; copied locally to `docs/strategy_card.md`
**R1-R4 verdict (Q00):** all PASS in the approved card

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3%-0.5% |

ENV-to-mode validation is enforced by `QM_FrameworkInit` through `EA_INPUT_RISK_MODE_MISMATCH`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-30 | Initial build from approved card | Build task `09eae252-3419-414c-9a83-41385f431b0c` |
