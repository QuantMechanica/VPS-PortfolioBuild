# QM5_10549_mql5-rideallig - Strategy Spec

**EA ID:** QM5_10549
**Slug:** `mql5-rideallig`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades the RideAlligator closed-bar trend trigger from the MQL5 source. It computes an Alligator-style LWMA on median price, with the base period expanded by the golden ratio into lips, teeth, and jaws periods and shifts. A long entry fires when the lips line is above jaws, teeth is below jaws, and lips crossed up from below jaws on the previous closed bar; a short entry mirrors that condition. Open positions close when the current Alligator state no longer supports the position direction, while the P2 baseline uses a 2.0 x ATR(14) hard stop and 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_alligator_period` | 5 | `1+` | Base period used to derive the source Alligator periods and visual shifts. |
| `strategy_alligator_method` | `MODE_LWMA` | `ENUM_MA_METHOD` | Moving-average method; source default is LWMA. |
| `strategy_atr_period` | 14 | `1+` | ATR period for the P2 hard stop and optional ADX floor period. |
| `strategy_atr_sl_mult` | 2.0 | `0.1+` | ATR multiple for the catastrophic stop. |
| `strategy_take_rr` | 1.5 | `0.1+` | Take-profit distance in R multiples from entry to stop. |
| `strategy_adx_floor` | 0.0 | `0+` | Optional P3 trend-floor sweep; zero disables it for P2. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX symbol with native DWX OHLC coverage.
- `GBPUSD.DWX` - card-listed liquid FX symbol with native DWX OHLC coverage.
- `USDJPY.DWX` - card-listed liquid FX symbol with native DWX OHLC coverage.
- `GDAXI.DWX` - canonical DWX DAX symbol used because the card-listed `GER40.DWX` is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `GER40.DWX` - not in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.
- Non-DWX symbols - build and pipeline use `.DWX` symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | Not specified in frontmatter; expected to hold until Alligator state loss, SL/TP, or Friday close. |
| Expected drawdown profile | Trend-following ATR-stop drawdowns during range-bound Alligator whipsaws. |
| Regime preference | Alligator trend-state entries on H1/H4; trend-following regime. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/17116`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10549_mql5-rideallig.md`.

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
| v1 | 2026-06-13 | Initial build from card | 3b30195b-d127-468f-a337-74388046c56e |
