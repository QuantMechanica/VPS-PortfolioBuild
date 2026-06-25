# QM5_11616_robo-ema8-28-cci30-m30 - Strategy Spec

**EA ID:** QM5_11616
**Slug:** robo-ema8-28-cci30-m30
**Source:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d (see `strategy-seeds/sources/ed246754-1f4d-5bed-8dd3-3b5cbf1b420d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades the RoboForex EMA + CCI strategy on the close of each M30 bar. A long entry is opened when EMA(8) is above EMA(28) and CCI(30) crosses above zero from the prior closed bar. A short entry is opened when EMA(8) is below EMA(28) and CCI(30) crosses below zero from the prior closed bar. Each market entry submits a 2x ATR(14) stop loss and a 4x ATR(14) take profit; there is no discretionary close beyond those orders and framework close rules.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 8 | `>0` | Fast EMA period used for the trend stack. |
| `strategy_slow_ema_period` | 28 | `>0` | Slow EMA period used for the trend stack. |
| `strategy_cci_period` | 30 | `>0` | CCI period used for the zero-line entry trigger. |
| `strategy_atr_period` | 14 | `>0` | ATR period used for stop-loss and take-profit distance. |
| `strategy_atr_sl_mult` | 2.0 | `>0` | Stop-loss distance as a multiple of ATR(14). |
| `strategy_atr_tp_mult` | 4.0 | `>0` | Take-profit distance as a multiple of ATR(14). |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed M30 DWX FX major.
- `GBPUSD.DWX` - Card-listed M30 DWX FX major.
- `USDJPY.DWX` - Card-listed M30 DWX FX major.
- `USDCHF.DWX` - Card-listed M30 DWX FX major.
- `AUDUSD.DWX` - Card-listed M30 DWX FX major.

**Explicitly NOT for:**
- Non-DWX symbols - Build and backtest artifacts must use canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Not specified in card frontmatter. |
| Expected drawdown profile | Not specified in card frontmatter. |
| Regime preference | Trend-following, from card concepts and EMA-stack rule. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Source type:** book / educational PDF
**Pointer:** RoboForex Educational Team, `Forex Strategy Collection`, page 45, strategy `EMA + CCI`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11616_robo-ema8-28-cci30-m30.md`

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
| v1 | 2026-06-25 | Initial build from card | ae07b8f4-cc37-4aed-864e-e4616fc84e75 |
