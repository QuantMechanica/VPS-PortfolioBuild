# QM5_12934_aa-comm-spot-rev-card - Strategy Spec

**EA ID:** QM5_12934
**Slug:** aa-comm-spot-rev-card
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

On a D1 chart, the EA revalidates once per calendar month using the framework calendar-period key. It computes each commodity proxy's 260-D1-bar momentum with `QM_Momentum`; the lowest-ranked proxy is treated as the prior loser and receives a long signal, while the highest-ranked proxy is treated as the prior winner and receives a short signal. Existing positions are kept only while the symbol remains in its selected monthly reversal bucket, and positions that leave or reverse bucket are closed at the next monthly revalidation. Initial stop loss is 3.0 x ATR(20,D1); no take-profit, trailing, partial close, or pyramiding is specified.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_days` | 260 | 126-520 | D1 bars used as the 12-month spot return proxy. |
| `strategy_atr_period` | 20 | 5-100 | D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.5-10.0 | ATR multiple used for the initial stop distance. |
| `strategy_min_quintile_universe` | 10 | 2-52 | Minimum universe size before using true quintile bucket sizing; below this, bottom 1 and top 1 are used. |
| `strategy_max_spread_points` | 5000 | 0-100000 | Maximum positive modeled spread in points; zero spread remains tradeable for `.DWX` tests. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - gold spot CFD proxy in the approved commodity basket.
- `XAGUSD.DWX` - silver spot CFD proxy in the approved commodity basket.
- `XTIUSD.DWX` - WTI crude CFD proxy used in place of card-stated `USOIL.DWX`, which is not in the DWX symbol matrix.
- `XNGUSD.DWX` - additional matrix-listed commodity CFD, included because the card permits additional broker commodity CFDs with continuous history.

**Explicitly NOT for:**
- `USOIL.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `XTIUSD.DWX`.
- Non-commodity index or FX symbols - they are outside the spot/CFD commodity reversal thesis.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; momentum and ATR are D1-native |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with monthly cadence via `QM_CalendarPeriodKey(PERIOD_MN1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 from card frontmatter |
| Expected trade frequency | Monthly rank/rebalance cadence; card frontmatter does not provide a separate value |
| Typical hold time | Until monthly revalidation, unless ATR stop is hit |
| Expected drawdown profile | Commodity mean-reversion drawdowns can cluster when winners continue trending |
| Regime preference | Commodity-factor mean reversion |
| Win rate target (qualitative) | Medium; not specified numerically in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** Alpha Architect blog summary of academic commodity reversal research
**Pointer:** https://alphaarchitect.com/seven-centuries-of-commodity-reversals/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12934_aa-comm-spot-rev-card.md`

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
| v1 | 2026-07-07 | Initial build from card | 965a4062-511f-4c9d-b0d9-a2dcb6fb78a6 |
