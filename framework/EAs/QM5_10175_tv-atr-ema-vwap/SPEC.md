# QM5_10175_tv-atr-ema-vwap - Strategy Spec

**EA ID:** QM5_10175
**Slug:** `tv-atr-ema-vwap`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades an ATR stop-line trend flip confirmed by EMA(13) and session VWAP. A long entry requires the ATR trend state to flip bullish on the last closed bar, with the close above EMA(13) and above the current broker-day VWAP. A short entry requires the bearish mirror condition. Each entry places an ATR-based stop at 2.0x ATR(14) and a take profit at 2R; framework Friday-close and kill-switch controls remain active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 5-50 | ATR lookback used for the trend stop and initial risk distance. |
| `strategy_atr_mult` | 2.0 | 0.5-6.0 | ATR multiple for the stop line and initial stop loss. |
| `strategy_ema_period` | 13 | 5-100 | EMA trend confirmation period. |
| `strategy_reward_r` | 2.0 | 0.5-5.0 | Take-profit multiple of initial risk distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair named in the approved card.
- `GBPUSD.DWX` - liquid major FX pair named in the approved card.
- `XAUUSD.DWX` - gold CFD named by the source/card as a suitable ATR trend market.
- `NDX.DWX` - Nasdaq index CFD named in the approved DWX basket.
- `WS30.DWX` - Dow index CFD named in the approved DWX basket.

**Explicitly NOT for:**
- Non-DWX symbols - the build and setfiles are research/backtest `.DWX` artifacts only.
- Thin exotic FX pairs - the card is limited to liquid majors, gold, and major index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Hours to a few days, depending on ATR stop or 2R take profit. |
| Expected drawdown profile | Moderate trend-following drawdown during choppy, low-direction regimes. |
| Regime preference | Trend-following with volatility-confirmed directional moves. |
| Win rate target (qualitative) | Medium; reward/risk is designed around 2R winners. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView script page`
**Pointer:** `https://www.tradingview.com/script/IzWQ271v-ATR-Trend-System-Backtest/`
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10175_tv-atr-ema-vwap.md`

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
| v1 | 2026-07-07 | Initial Q01 spec for existing materialized build | `6b8d9ff7-97b3-49cd-b174-ff21ee5770bd` |
