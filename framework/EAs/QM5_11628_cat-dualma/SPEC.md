# QM5_11628_cat-dualma - Strategy Spec

**EA ID:** QM5_11628
**Slug:** `cat-dualma`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the Catalyst dual moving average rule on completed M1 bars. It enters one long position when SMA(50) is above SMA(200) and this EA has no open position for the current magic number. It exits the long position when SMA(50) is below SMA(200). The original source has no protective stop, so the V5 implementation adds a configurable ATR catastrophic stop at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_fast_period` | 50 | integer > 0 | Fast SMA period used for long exposure state. |
| `strategy_sma_slow_period` | 200 | integer > 0 | Slow SMA period used for long exposure state. |
| `strategy_atr_period` | 14 | integer > 0 | ATR period for the catastrophic protective stop. |
| `strategy_sl_atr_mult` | 3.0 | double > 0 | ATR multiple used to place the catastrophic stop below long entry. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-targeted DWX FX symbol with available M1 bars.
- `XAUUSD.DWX` - Card-targeted DWX metal symbol with available M1 bars.
- `GDAXI.DWX` - Registered DAX equivalent because card-stated `GER40.DWX` is not present in `framework/registry/dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `GER40.DWX` - Not in the DWX symbol matrix; use `GDAXI.DWX` for this build.
- Non-DWX symbols - Research and backtest artifacts must use canonical `.DWX` names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Not specified in frontmatter; trend-state hold, from minutes to multiple days depending on SMA state duration. |
| Expected drawdown profile | Trend-following exposure with losses bounded by the ATR catastrophic stop and framework risk sizing. |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Not specified in frontmatter; medium is assumed for a moving-average trend rule. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** GitHub repository example
**Pointer:** `scrtlabs/catalyst`, `catalyst/examples/dual_moving_average.py`, https://github.com/scrtlabs/catalyst/blob/master/catalyst/examples/dual_moving_average.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11628_cat-dualma.md`

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
| v1 | 2026-06-20 | Initial build from card | 23cfca1c-ea34-40a6-9006-360031c61e8e |
