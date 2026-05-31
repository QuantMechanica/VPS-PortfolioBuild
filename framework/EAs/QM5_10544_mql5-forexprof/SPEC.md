# QM5_10544_mql5-forexprof - Strategy Spec

**EA ID:** QM5_10544
**Slug:** `mql5-forexprof`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates closed H1 bars. It opens long when EMA(10) crosses above both EMA(25) and EMA(50), and Parabolic SAR is below the closed-bar price. It opens short when EMA(10) crosses below both EMA(25) and EMA(50), and Parabolic SAR is above the closed-bar price. Broker SL/TP use ATR(14) with a 1.5R target, and open positions can close early when EMA(10) makes an opposite turn after the configured minimum profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Signal timeframe from the card. |
| `strategy_ema_fast_period` | `10` | `1+` | Fast EMA used for cross and turn exits. |
| `strategy_ema_mid_period` | `25` | `1+` | First confirmation EMA crossed by EMA(10). |
| `strategy_ema_slow_period` | `50` | `1+` | Second confirmation EMA crossed by EMA(10). |
| `strategy_sar_step` | `0.02` | `>0` | Parabolic SAR step. |
| `strategy_sar_maximum` | `0.20` | `>0` | Parabolic SAR maximum acceleration. |
| `strategy_sar_warmup_bars` | `120` | `10+` | Closed-bar warmup depth for deterministic SAR confirmation. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | `1.50` | `>0` | ATR multiple for stop distance. |
| `strategy_target_rr` | `1.50` | `>0` | Take-profit multiple of initial risk. |
| `strategy_min_profit_points` | `0` | `0+` | Minimum open profit, in points, before EMA turn exit may close. |
| `strategy_max_spread_points` | `0` | `0+` | Optional spread ceiling; `0` disables this extra filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary EURUSD H1 source symbol from the card.
- `USDCHF.DWX` - source forex pair included in the card's portable basket.
- `GBPUSD.DWX` - liquid major forex pair included for P2 saturation.
- `XAUUSD.DWX` - liquid gold symbol included in the card's DWX basket.

**Explicitly NOT for:**
- Equity indices - the card is built from forex/XAU EMA and SAR behaviour, not index session structure.
- Energy commodities - not listed in the card's P2 basket.

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
| Trades / year / symbol | `50` |
| Typical hold time | hours to days |
| Expected drawdown profile | Trend-following whipsaws around EMA clusters; capped by ATR stop. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/17210`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10544_mql5-forexprof.md`

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
| v1 | 2026-05-29 | Initial build from card | 97f5f17f-ecc3-4afc-91d2-9ab42b07aaf1 |
