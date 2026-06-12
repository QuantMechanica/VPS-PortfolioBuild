# QM5_10291_cinar-alligator - Strategy Spec

**EA ID:** QM5_10291
**Slug:** `cinar-alligator`
**Source:** `1b906e79-c619-5a61-90db-ee19ac95a19f` (see `sources/github-topic-algorithmic-trading`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades the Cinar Alligator trend rule on D1 closed bars. It computes SMMA(5), SMMA(8), and SMMA(13) from close. It opens long when the fast lip average is above both slower averages, opens short when the lip average is below both slower averages, and holds through mixed stacks. When the opposite stack appears, it closes the existing position and opens the reverse side with a 2.0 x ATR(14) catastrophic stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lip_period` | 5 | `1+` | Fast Alligator SMMA period. |
| `strategy_teeth_period` | 8 | `1+` | Middle Alligator SMMA period. |
| `strategy_jaw_period` | 13 | `1+` | Slow Alligator SMMA period. |
| `strategy_atr_period` | 14 | `1+` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.0 | `>0` | ATR multiplier for the catastrophic stop. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `AUDCHF.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `AUDJPY.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `AUDNZD.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `AUDUSD.DWX` - DWX major FX pair with daily close data suitable for SMMA trend following.
- `CADCHF.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `CADJPY.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `CHFJPY.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `EURAUD.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `EURCAD.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `EURCHF.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `EURGBP.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `EURJPY.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `EURNZD.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `EURUSD.DWX` - DWX major FX pair with daily close data suitable for SMMA trend following.
- `GBPAUD.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `GBPCAD.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `GBPCHF.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `GBPJPY.DWX` - Card-named DWX forex cross with daily close data suitable for SMMA trend following.
- `GBPNZD.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `GBPUSD.DWX` - DWX major FX pair with daily close data suitable for SMMA trend following.
- `GDAXI.DWX` - Available DWX DAX custom symbol used for the card's DAX target.
- `NDX.DWX` - Card-named DWX index CFD for US large-cap trend exposure.
- `NZDCAD.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `NZDCHF.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `NZDJPY.DWX` - DWX forex cross with daily close data suitable for SMMA trend following.
- `NZDUSD.DWX` - DWX major FX pair with daily close data suitable for SMMA trend following.
- `SP500.DWX` - DWX S&P 500 custom symbol; backtest-only but valid for build registration.
- `UK100.DWX` - DWX index CFD with daily close data suitable for SMMA trend following.
- `USDCAD.DWX` - DWX major FX pair with daily close data suitable for SMMA trend following.
- `USDCHF.DWX` - DWX major FX pair with daily close data suitable for SMMA trend following.
- `USDJPY.DWX` - DWX major FX pair with daily close data suitable for SMMA trend following.
- `WS30.DWX` - Card-named DWX index CFD for US large-cap trend exposure.
- `XAGUSD.DWX` - DWX metal with daily close data suitable for SMMA trend following.
- `XAUUSD.DWX` - Card-named DWX metal with daily close data suitable for SMMA trend following.
- `XNGUSD.DWX` - DWX commodity with daily close data suitable for SMMA trend following.
- `XTIUSD.DWX` - DWX commodity with daily close data suitable for SMMA trend following.

**Explicitly NOT for:**
- `DAX.DWX` - Not present in `dwx_symbol_matrix.csv`; this build uses `GDAXI.DWX` as the available DAX symbol.
- Any symbol absent from `framework/registry/dwx_symbol_matrix.csv` - no broker/custom tick coverage for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `20` |
| Typical hold time | Not specified in card frontmatter; stop-and-reverse daily trend positions imply multi-day holds. |
| Expected drawdown profile | Not specified in card frontmatter; catastrophic stop is 2.0 x ATR(14). |
| Regime preference | Trend following. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub repository
**Pointer:** `https://github.com/cinar/indicator/blob/master/strategy/trend/alligator_strategy.go` and `https://github.com/cinar/indicator/blob/master/trend/smma.go`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10291_cinar-alligator.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | 40da011d-8737-4e29-afc8-c4bd801702a5 |
