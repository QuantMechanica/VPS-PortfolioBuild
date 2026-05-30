# QM5_10441_mql5-vr-rsi — Strategy Spec

**EA ID:** QM5_10441
**Slug:** `mql5-vr-rsi`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates only completed H1 bars and confirms the H1 signal with completed D1 RSI state. It enters long when H1 RSI(14) is above 20 and rising versus the prior closed H1 bar, while D1 RSI(14) is also above 20 and rising versus the prior closed D1 bar. It enters short when H1 RSI(14) is below 80 and falling, while D1 RSI(14) is also below 80 and falling. The EA exits on the opposite confirmed signal, at a 2R take-profit, at the ATR stop, or after 10 H1 bars in the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 1+ | RSI lookback used on H1 and D1 completed bars. |
| `strategy_rsi_oversold` | 20.0 | 0-100 | Long threshold; both H1 and D1 RSI must be above this level and rising. |
| `strategy_rsi_overbought` | 80.0 | 0-100 | Short threshold; both H1 and D1 RSI must be below this level and falling. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the H1 stop and D1 stop-cap check. |
| `strategy_atr_sl_mult` | 1.5 | 0+ | Initial stop distance as a multiple of H1 ATR(14). |
| `strategy_take_profit_r` | 2.0 | 0+ | Take-profit distance in multiples of initial stop distance. |
| `strategy_d1_atr_cap_mult` | 3.0 | 0+ | Blocks entries where the H1 stop distance exceeds this multiple of D1 ATR. |
| `strategy_time_stop_h1_bars` | 10 | 1+ | Closes positions that remain open after this many H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary liquid FX pair from the approved card basket.
- `GBPUSD.DWX` — liquid FX major from the approved card basket.
- `USDJPY.DWX` — liquid FX major from the approved card basket.
- `XAUUSD.DWX` — liquid metal CFD from the approved card basket.

**Explicitly NOT for:**
- Non-DWX symbols — the V5 research and backtest workflow requires canonical `.DWX` symbols.
- Symbols outside the approved R3 basket — this build registers only the card's portable P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1 RSI(14)` confirmation and `D1 ATR(14)` stop-cap check |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | Up to 10 H1 bars unless TP, SL, Friday close, or opposite signal fires first. |
| Expected drawdown profile | Reversal strategy with fixed ATR risk and one active position per symbol/magic. |
| Regime preference | RSI reversal with higher-timeframe confirmation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** Vladimir Pastushak, "VR Rsi Robot is a multi-timeframe trading strategy", MQL5 CodeBase, published 2026-03-18, https://www.mql5.com/en/code/70465
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10441_mql5-vr-rsi.md`

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
| v1 | 2026-05-28 | Initial build from card | 9eebf514-b39b-430c-a5aa-10a2abd2881a |
