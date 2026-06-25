# QM5_11260_cs-stoch-mfi - Strategy Spec

**EA ID:** QM5_11260
**Slug:** `cs-stoch-mfi`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades long-only M5 oscillator mean reversion. On each closed M5 bar, it computes StochRSI(14) from close-based RSI values and reads MFI(14) through the framework tick-volume MFI helper. It opens a long position when both StochRSI and MFI are below 20 on the same closed bar. It exits when StochRSI or MFI rises above 80, after 36 M5 bars, or through the ATR stop and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_stochrsi_period` | 14 | 2-100 | RSI lookback and stochastic window for StochRSI. |
| `strategy_hot_threshold` | 20.0 | 0-50 | Oversold entry threshold for both StochRSI and MFI. |
| `strategy_cold_threshold` | 80.0 | 50-100 | Overbought exit threshold for StochRSI or MFI. |
| `strategy_mfi_period` | 14 | 2-100 | MFI lookback using DWX tick volume. |
| `strategy_atr_period` | 14 | 1-100 | ATR lookback for stop and spread filter. |
| `strategy_sl_atr_mult` | 1.5 | 0.1-10.0 | Hard stop distance in ATR multiples. |
| `strategy_breakeven_trigger_r` | 0.8 | 0.1-5.0 | Move stop to entry after this R multiple. |
| `strategy_max_hold_bars` | 36 | 1-500 | Time stop in base-timeframe bars. |
| `strategy_spread_atr_fraction` | 0.25 | 0.0-2.0 | Block entries when spread is above this ATR fraction. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start of the liquid-session filter. |
| `strategy_session_end_hour` | 22 | 0-23 | Broker-hour end of the liquid-session filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair listed in the approved card basket.
- `GBPUSD.DWX` - liquid major FX pair listed in the approved card basket.
- `XAUUSD.DWX` - liquid gold CFD listed in the approved card basket.
- `NDX.DWX` - liquid US large-cap index CFD listed in the approved card basket.
- `GDAXI.DWX` - matrix-available DAX custom symbol used for the card's GER40 exposure.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - they cannot be backtested in the DWX tester.
- `GER40.DWX` - not present in the DWX symbol matrix; DAX exposure is registered as `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | Up to 36 M5 bars, about 3 hours |
| Expected drawdown profile | High risk; M5 oscillator reversion is cost-sensitive. |
| Regime preference | Mean-revert |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `GitHub`
**Pointer:** `https://github.com/CryptoSignal/Crypto-Signal/blob/master/docs/config.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11260_cs-stoch-mfi.md`

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
| v1 | 2026-06-25 | Initial build from card | 350b53fd-4e98-4228-b25e-c1e92265accd |
