# QM5_10510_mql5-absorb-stop - Strategy Spec

**EA ID:** QM5_10510
**Slug:** mql5-absorb-stop
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `sources/mql5-codebase-mt5-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades the MQL5 Absorption pattern on completed H1 bars. It looks for bar 1 or bar 2 to fully absorb its neighbor by high/low range and to be the recent low or high over the configured extreme-search window. A low-side absorption places a Buy Stop above the recent high; a high-side absorption places a Sell Stop below the recent low. Orders expire after the configured lifetime, and filled trades exit by the framework Friday close, stop loss, or 1.5R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_extreme_search_bars` | 10 | 2+ | Closed-bar lookback used to find the recent high/low and classify bar 1 or 2 as the extreme absorption bar. |
| `strategy_indent_points` | 10 | 1+ | Point offset added beyond the recent high or low for pending stop placement and structure stop padding. |
| `strategy_expiration_hours` | 8 | 1+ | Lifetime for each pending Buy Stop or Sell Stop order. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the stop-loss volatility floor. |
| `strategy_atr_sl_mult` | 1.5 | >0 | ATR multiplier for the minimum stop-loss distance. |
| `strategy_tp_rr` | 1.5 | >0 | Fixed reward/risk take-profit multiple. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 lists this DWX major FX pair as portable for the H1 OHLC absorption breakout.
- `GBPUSD.DWX` - Card R3 lists this DWX major FX pair as portable for the H1 OHLC absorption breakout.
- `USDJPY.DWX` - Card R3 lists this DWX major FX pair as portable for the H1 OHLC absorption breakout.
- `XAUUSD.DWX` - Card R3 lists this DWX metal symbol as portable for the H1 OHLC absorption breakout.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable to DWX backtest infrastructure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Pending orders expire after 8 hours; filled trades hold until 1.5R TP, structure/ATR SL, or Friday close. |
| Expected drawdown profile | Fixed-risk breakout losses bounded by the wider of structure or ATR stop. |
| Regime preference | Breakout and volatility expansion after absorption bars. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/20565 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10510_mql5-absorb-stop.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10510_mql5-absorb-stop.md`

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
| v1 | 2026-06-13 | Initial build from card | 87dc22d7-e28c-4670-8e89-e0c0fd607ff6 |
