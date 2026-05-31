# QM5_10563_mql5-vwma-candle - Strategy Spec

**EA ID:** QM5_10563
**Slug:** `mql5-vwma-candle`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA trades closed-bar color changes in a volume-weighted moving-average candle. It computes VWMA(open) and VWMA(close) over the configured lookback using tick volume by default; the candle is bullish when VWMA(close) is above VWMA(open), bearish when below. It opens long when the last closed candle changes from bearish to bullish, opens short when it changes from bullish to bearish, and closes an open position on the opposite closed-bar color change. Initial protection is ATR(14) times 2.0 for the stop and 1.5R for the target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_vwma_length` | 12 | 1-200 | Number of closed bars used in the volume-weighted moving-average candle. |
| `strategy_atr_period` | 14 | 1-200 | ATR period used for the initial hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiple for the hard stop distance. |
| `strategy_tp_rr` | 1.5 | 0.1-10.0 | Reward-to-risk multiple for the take-profit target. |
| `strategy_use_real_volume` | false | true/false | Use real volume instead of tick volume when available. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - source test used GBPUSD H4 and the rule is portable to DWX FX tick volume.
- `EURUSD.DWX` - liquid major FX pair matching the portable FX logic.
- `GBPJPY.DWX` - liquid cross FX pair listed in the card's R3 basket.
- `XAUUSD.DWX` - liquid metal symbol listed in the card's R3 basket.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest universe requires canonical `.DWX` symbols.

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
| Trades / year / symbol | `55` |
| Typical hold time | H4 color-change holds, typically hours to days |
| Expected drawdown profile | Moderate stop-defined drawdowns from ATR-based fixed-risk entries |
| Regime preference | Volume-weighted trend/color-change continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/15899`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10563_mql5-vwma-candle.md`

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
| v1 | 2026-05-29 | Initial build from card | b5255c0c-b9ba-4503-ad42-7b0c2a2b1ae4 |
