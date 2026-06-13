# QM5_10436_mql5-h4m15-sweep - Strategy Spec

**EA ID:** QM5_10436
**Slug:** `mql5-h4m15-sweep`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA finds confirmed H4 swing highs and lows using a symmetric `Range` window. On each completed M15 candle it checks whether price swept through the most recent valid H4 swing level and then closed back inside the level. A sweep below an H4 swing low opens a long trade at market on the next tick; a sweep above an H4 swing high opens a short trade. Exits are only the fixed SL/TP bracket and framework exits such as Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_swing_range_h4` | 21 | 1+ | Number of H4 bars on each side required to confirm a swing high or swing low. |
| `strategy_level_max_age_h4` | 60 | 22+ | Maximum age in H4 bars for a swing level to remain eligible. |
| `strategy_sl_points` | 1500 | 1+ | Minimum stop distance in symbol points from the market entry. |
| `strategy_rr` | 0.2 | >0 | Take-profit distance as a multiple of stop distance. |
| `strategy_atr_period_m15` | 14 | 1+ | M15 ATR period used by the excessive stop-distance filter. |
| `strategy_max_stop_atr_mult` | 4.0 | >0 | Skip entries where stop distance exceeds this multiple of M15 ATR. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card primary FX target and present in the DWX matrix.
- `GBPUSD.DWX` - card portable FX target and present in the DWX matrix.
- `USDJPY.DWX` - card portable FX target and present in the DWX matrix.
- `XAUUSD.DWX` - card portable metals target and present in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - registry and backtest use canonical `.DWX` symbols only.
- Symbols outside the approved R3 basket - not listed by the card for P2 saturation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_H4` swing highs/lows, `PERIOD_M15` sweep candle and ATR filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Intraday to multi-session, depending on fixed SL/TP hit timing |
| Expected drawdown profile | Many small defensive targets with occasional full stop losses |
| Regime preference | Liquidity-sweep mean reversion around confirmed H4 swing levels |
| Win rate target (qualitative) | High |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/68951`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10436_mql5-h4m15-sweep.md`

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
| v1 | 2026-06-13 | Initial build from card | 3c16c228-760d-4e89-8199-9a485f389202 |
