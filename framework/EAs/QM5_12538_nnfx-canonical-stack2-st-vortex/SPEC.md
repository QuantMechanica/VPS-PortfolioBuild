# QM5_12538_nnfx-canonical-stack2-st-vortex - Strategy Spec

**EA ID:** QM5_12538
**Slug:** `nnfx-canonical-stack2-st-vortex`
**Source:** `nnfx-vp-canonical-2026-06-12` (see `strategy-seeds/sources/nnfx-vp-canonical-2026-06-12/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades the No Nonsense Forex D1 closed-bar stack from the approved card. It opens long when the D1 close has crossed above McGinley Dynamic(20) within the last three bars, the close is still within 1.0 ATR(14) of that baseline, SuperTrend(10, 3.0) is long, Vortex(14) has VI+ above VI-, and ADX(14) is at least 20 and rising. Shorts are the mirror image. The initial stop is 1.5 ATR(14), half the position is closed after a 1.0 ATR move in favor, the remaining runner moves to breakeven, and the runner exits on a SuperTrend flip or a close crossing back through the McGinley baseline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_mcginley_period` | 20 | >=2 | McGinley Dynamic baseline period. |
| `strategy_mcginley_warmup` | 120 | >=25 | Closed D1 bars used to stabilize the McGinley recurrence. |
| `strategy_supertrend_period` | 10 | >=1 | ATR period for SuperTrend. |
| `strategy_supertrend_mult` | 3.0 | >0 | SuperTrend ATR multiplier. |
| `strategy_supertrend_warmup` | 120 | >=15 | Closed D1 bars used to reconstruct SuperTrend state. |
| `strategy_vortex_period` | 14 | >=2 | Vortex indicator lookback. |
| `strategy_adx_period` | 14 | >=1 | ADX trend-strength period. |
| `strategy_adx_min` | 20.0 | >=0 | Minimum ADX value for the volume gate. |
| `strategy_atr_period` | 14 | >=1 | ATR period for proximity, stop, and TP-half management. |
| `strategy_atr_proximity_mult` | 1.0 | >0 | Maximum close-to-baseline distance as ATR multiple. |
| `strategy_sl_atr_mult` | 1.5 | >0 | Initial stop distance as ATR multiple. |
| `strategy_tp_half_atr_mult` | 1.0 | >0 | Move in ATR multiples that triggers half close and runner BE. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major.
- `GBPUSD.DWX` - card-listed liquid FX major.
- `USDJPY.DWX` - card-listed liquid FX major.
- `AUDUSD.DWX` - card-listed liquid FX major.
- `NZDUSD.DWX` - card-listed liquid FX major.
- `USDCAD.DWX` - card-listed liquid FX major.
- `USDCHF.DWX` - card-listed liquid FX major.
- `EURJPY.DWX` - card-listed liquid FX cross.
- `GBPJPY.DWX` - card-listed liquid FX cross.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the approved card targets the same nine liquid FX pairs as QM5_12534.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `18` |
| Typical hold time | days to weeks |
| Expected drawdown profile | D1 trend-following streakiness with expected DD around 12 percent from card frontmatter. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-vp-canonical-2026-06-12`
**Source type:** `blog / podcast / community-vetted indicator stack`
**Pointer:** `https://nononsenseforex.com/` and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12538_nnfx-canonical-stack2-st-vortex.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12538_nnfx-canonical-stack2-st-vortex.md`

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
| v1 | 2026-06-12 | Initial build from card | e2023327-5a01-4ab3-a5a4-a44cb916af2b |
