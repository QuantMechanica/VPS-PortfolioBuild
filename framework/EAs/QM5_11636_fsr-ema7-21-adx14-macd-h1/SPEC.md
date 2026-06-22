# QM5_11636_fsr-ema7-21-adx14-macd-h1 - Strategy Spec

**EA ID:** QM5_11636
**Slug:** `fsr-ema7-21-adx14-macd-h1`
**Source:** `5e9e8c4d-0c88-5dc6-a550-b3b070a5b44d` (see `artifacts/cards_approved/QM5_11636_fsr-ema7-21-adx14-macd-h1.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades the H1 close after EMA(7) crosses EMA(21). A long entry requires EMA(7) crossing above EMA(21), ADX(14) above 25, and MACD(12,26,9) main rising from the prior closed bar. A short entry requires EMA(7) crossing below EMA(21), ADX(14) above 25, and MACD main falling. It skips entries when the MACD main value is below the configured near-zero consolidation floor, uses a 2 ATR(14) stop by default, has no fixed take-profit, and exits when EMA(7) crosses back against the held position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 7 | 2-50 | Fast EMA period used for the cross trigger. |
| `strategy_ema_slow_period` | 21 | 3-200 | Slow EMA period used for the cross trigger. |
| `strategy_adx_period` | 14 | 2-100 | ADX period used for trend-strength confirmation. |
| `strategy_adx_threshold` | 25.0 | 0.0-100.0 | Minimum ADX value required for entry. |
| `strategy_macd_fast` | 12 | 2-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 3-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 2-100 | MACD signal period. |
| `strategy_macd_consol_floor` | 0.0 | 0.0-0.01 | Skip entries when absolute MACD main is below this floor; 0 disables the filter. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for stop placement. |
| `strategy_sl_atr_mult` | 2.0 | 0.5-10.0 | Stop distance in ATR multiples. |
| `strategy_spread_pct_of_stop` | 15.0 | 0.0-100.0 | Blocks only genuinely wide spread when spread exceeds this percent of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid DWX forex pair for H1 trend/momentum testing.
- `GBPUSD.DWX` - card-listed liquid DWX forex pair for H1 trend/momentum testing.
- `USDJPY.DWX` - card-listed liquid DWX forex pair for H1 trend/momentum testing.
- `XAUUSD.DWX` - card-listed DWX gold symbol included by the approved card target list.

**Explicitly NOT for:**
- `SP500.DWX` - not part of the card's forex/metals target set.
- `NDX.DWX` - not part of the card's forex/metals target set.
- `WS30.DWX` - not part of the card's forex/metals target set.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `trend-following whipsaw risk during range-bound periods` |
| Regime preference | `trend / momentum` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `5e9e8c4d-0c88-5dc6-a550-b3b070a5b44d`
**Source type:** `forum / collection archive`
**Pointer:** `forex-strategies-revealed.com, Strategy #19 "Egudu Simple 4 Tools Trading"; local card D:/QM/strategy_farm/artifacts/cards_approved/QM5_11636_fsr-ema7-21-adx14-macd-h1.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11636_fsr-ema7-21-adx14-macd-h1.md`

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
| v1 | 2026-06-23 | Initial build from card | a9cc7c32-28ed-4e30-835e-8fe52690d4cd |
