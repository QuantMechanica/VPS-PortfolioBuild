# QM5_12975_ehlers-pma-triple-swing - Strategy Spec

**EA ID:** QM5_12975
**Slug:** `ehlers-pma-triple-swing`
**Source:** `CEO-RU-MINING-2026-07-03`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements the approved Ehlers Projected Moving Average triple-screen
swing card. It is long only. Entry requires all three closed-bar conditions:
last closed W1 close above PMA(50), last closed D1 close above PMA(50), and
D1 PMA(10) above D1 PMA(50). PMA is computed as `SMA(L) + OLS_slope(L) * L/2`.

Exits occur when the last closed D1 close falls below PMA(50). The position also
uses a 2.5 x ATR(14, D1) initial stop and trails the stop from the best closed
D1 close since entry minus 2.5 x ATR(14).

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_pma_slow_period` | 50 | Slow D1/W1 PMA length |
| `strategy_pma_fast_period` | 10 | Fast D1 PMA length |
| `strategy_atr_period` | 14 | D1 ATR period for initial and trailing stop |
| `strategy_atr_mult` | 2.5 | ATR stop and trailing multiple |

## 3. Symbol Universe

- `NDX.DWX`, magic slot 0.
- `XAUUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Weekly confirmation: last closed W1 bar.
- Entry gating: `QM_IsNewBar()` on D1 chart setfiles.
- Signal reads use closed D1/W1 bars only.

## 5. Expected Behaviour

Expected frequency is low, around 5-10 trades per year per symbol, with
multi-week holds. The EA should only trade the two approved symbols on D1,
hold through weekends, avoid Friday-close flattening, and never pyramid, grid,
average down, or use ML/adaptive parameter logic.

## 6. Source Citation

Primary indicator lineage: John F. Ehlers, *Rocket Science for Traders* (Wiley,
2001), predictive and low-lag moving-average family. The concrete PMA triple
screen is from the approved Smart-Lab rule-set note cited in
`QM5_12975_ehlers-pma-triple-swing.md`; source results are treated as
hypothesis only, with the QM pipeline judging NDX/XAU performance.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. Live deployment remains
disabled until the normal Q02-Q13 gate sequence approves the EA and supplies a
portfolio weight. Friday close is disabled for the multi-week swing hold class.

Q02 queue note (2026-07-03): this build is intended to auto-enqueue one staged
Q02 work item per target symbol through `record-build`; no manual MT5 backtest
is launched by the build step.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-03 | Initial Codex build from approved card |
